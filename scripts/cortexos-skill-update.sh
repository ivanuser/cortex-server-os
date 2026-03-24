#!/bin/bash
# CortexOS Skill Updater
# Checks for skill updates from the GitHub repo and applies them

set -euo pipefail

SKILLS_DIR="/var/lib/cortexos/skills"
MANIFEST_URL="https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/skills/manifest.json"
SKILL_BASE_URL="https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/skills"
LOCAL_MANIFEST="$SKILLS_DIR/manifest.json"
TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "CortexOS Skill Manager"
    echo ""
    echo "Usage: cortexos-skill [command]"
    echo ""
    echo "Commands:"
    echo "  check       Check for available updates"
    echo "  update      Download and install skill updates"
    echo "  list        List installed skills"
    echo "  install     Install a skill from the extended repo"
    echo "  info        Show info about a specific skill
  available   Show skills available to install from extended repo"
    echo ""
}

cmd_list() {
    echo -e "${BLUE}Installed Skills:${NC}"
    echo ""
    if [ -f "$LOCAL_MANIFEST" ]; then
        python3 -c "
import json
with open('$LOCAL_MANIFEST') as f:
    m = json.load(f)
for name, info in sorted(m.get('skills', {}).items()):
    print(f'  {name:25s} v{info[\"version\"]:8s} {info.get(\"description\",\"\")}')
print(f'\nTotal: {len(m.get(\"skills\",{}))} skills (manifest v{m.get(\"version\",\"?\")})')
"
    else
        for skill in "$SKILLS_DIR"/*/; do
            name=$(basename "$skill")
            [ -f "$skill/SKILL.md" ] && echo "  $name"
        done
    fi
}

cmd_check() {
    echo -e "${BLUE}Checking for skill updates...${NC}"
    
    # Download remote manifest
    if ! curl -sfL "$MANIFEST_URL" -o "$TEMP_DIR/remote-manifest.json" 2>/dev/null; then
        echo "Failed to fetch remote manifest. Are you online?"
        exit 1
    fi
    
    python3 -c "
import json, sys

try:
    with open('$LOCAL_MANIFEST') as f:
        local = json.load(f)
except:
    local = {'skills': {}, 'version': '0.0.0'}

with open('$TEMP_DIR/remote-manifest.json') as f:
    remote = json.load(f)

updates = []
new_skills = []

for name, info in remote.get('skills', {}).items():
    local_info = local.get('skills', {}).get(name)
    if local_info is None:
        new_skills.append((name, info))
    elif info.get('version', '0') > local_info.get('version', '0'):
        updates.append((name, local_info.get('version','?'), info.get('version','?'), info))

if updates:
    print(f'Updates available ({len(updates)}):')
    for name, old_v, new_v, info in updates:
        print(f'  {name:25s} {old_v} → {new_v}  {info.get(\"description\",\"\")}')
else:
    print('All skills are up to date.')

if new_skills:
    print(f'\nNew skills available ({len(new_skills)}):')
    for name, info in new_skills:
        print(f'  {name:25s} v{info.get(\"version\",\"?\")}  {info.get(\"description\",\"\")}')

if not updates and not new_skills:
    print('Nothing to update.')
    sys.exit(0)
else:
    print(f'\nRun \"cortexos-skill update\" to apply.')
"
}

cmd_update() {
    echo -e "${BLUE}Updating skills...${NC}"
    
    # Download remote manifest
    if ! curl -sfL "$MANIFEST_URL" -o "$TEMP_DIR/remote-manifest.json" 2>/dev/null; then
        echo "Failed to fetch remote manifest."
        exit 1
    fi
    
    python3 -c "
import json
with open('$TEMP_DIR/remote-manifest.json') as f:
    remote = json.load(f)
try:
    with open('$LOCAL_MANIFEST') as f:
        local = json.load(f)
except:
    local = {'skills': {}, 'version': '0.0.0'}

to_update = []
for name, info in remote.get('skills', {}).items():
    local_info = local.get('skills', {}).get(name)
    if local_info is None or info.get('version','0') > local_info.get('version','0'):
        to_update.append(name)

with open('$TEMP_DIR/to-update.txt', 'w') as f:
    f.write('\n'.join(to_update))
print(f'{len(to_update)} skills to update')
"
    
    while IFS= read -r skill; do
        [ -z "$skill" ] && continue
        echo -ne "  Updating ${skill}... "
        mkdir -p "$SKILLS_DIR/$skill"
        if curl -sfL "$SKILL_BASE_URL/$skill/SKILL.md" -o "$SKILLS_DIR/$skill/SKILL.md" 2>/dev/null; then
            echo -e "${GREEN}✅${NC}"
        else
            echo -e "${YELLOW}⚠️ failed${NC}"
        fi
    done < "$TEMP_DIR/to-update.txt"
    
    # Update local manifest
    cp "$TEMP_DIR/remote-manifest.json" "$LOCAL_MANIFEST"
    echo -e "${GREEN}Skills updated!${NC}"
    
    # Symlink into gateway if needed
    if [ ! -L /root/.openclaw/skills ]; then
        ln -sfn "$SKILLS_DIR" /root/.openclaw/skills 2>/dev/null || true
    fi
}

cmd_install() {
    local skill_name="${1:-}"
    if [ -z "$skill_name" ]; then
        echo "Usage: cortexos-skill install <skill-name>"
        echo ""
        echo "Run 'cortexos-skill available' to see installable skills"
        exit 1
    fi
    
    local EXT_MANIFEST_URL="https://raw.githubusercontent.com/ivanuser/cortex-server-skills/main/manifest.json"
    local EXT_BASE="https://raw.githubusercontent.com/ivanuser/cortex-server-skills/main"
    
    echo -e "${BLUE}Installing skill: ${skill_name}${NC}"
    
    # Download manifest to find the exact path for this skill
    if ! curl -sfL "$EXT_MANIFEST_URL" -o "$TEMP_DIR/ext-manifest.json" 2>/dev/null; then
        echo "Failed to fetch skill manifest. Are you online?"
        exit 1
    fi
    
    # Look up the skill path from the manifest
    local skill_path=$(python3 -c "
import json
m = json.load(open('$TEMP_DIR/ext-manifest.json'))
for key in m.get('skills', {}):
    if key.endswith('/$skill_name') or key == '$skill_name' or key.split('/')[-1] == '$skill_name':
        print(key)
        break
" 2>/dev/null)
    
    if [ -z "$skill_path" ]; then
        echo -e "${YELLOW}Skill '$skill_name' not found in manifest. Trying directory search...${NC}"
        # Fallback: try each directory
        for prefix in "server" "apps" "infra" "security" "cloud" "runtime"; do
            local url="$EXT_BASE/$prefix/$skill_name/SKILL.md"
            if curl -sfL "$url" -o "$TEMP_DIR/SKILL.md" 2>/dev/null; then
                skill_path="$prefix/$skill_name"
                break
            fi
        done
    fi
    
    if [ -z "$skill_path" ]; then
        echo -e "${RED}Skill '$skill_name' not found in the extended repo.${NC}"
        echo "Run 'cortexos-skill available' to see installable skills"
        exit 1
    fi
    
    # Download the SKILL.md
    local url="$EXT_BASE/$skill_path/SKILL.md"
    if curl -sfL "$url" -o "$TEMP_DIR/SKILL.md" 2>/dev/null; then
        mkdir -p "$SKILLS_DIR/$skill_name"
        cp "$TEMP_DIR/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"
        echo -e "${GREEN}✅ Installed $skill_name (from $skill_path)${NC}"
        
        # Update local manifest
        python3 -c "
import json
try:
    ext = json.load(open('$TEMP_DIR/ext-manifest.json'))
    local_path = '$SKILLS_DIR/manifest.json'
    try:
        local_m = json.load(open(local_path))
    except:
        local_m = {'version': '0.0.0', 'skills': {}}
    for key, info in ext.get('skills', {}).items():
        if key.split('/')[-1] == '$skill_name':
            local_m['skills']['$skill_name'] = info
            break
    json.dump(local_m, open(local_path, 'w'), indent=2)
except: pass
" 2>/dev/null
        
        # Regenerate skills.json for dashboard
        /usr/local/bin/cortexos-sysinfo 2>/dev/null || true
        
        # Ensure symlink exists
        if [ ! -L /root/.openclaw/skills ]; then
            ln -sfn "$SKILLS_DIR" /root/.openclaw/skills 2>/dev/null || true
        fi
        
        return 0
    else
        echo -e "${RED}Failed to download $skill_name from $url${NC}"
        exit 1
    fi
}

cmd_info() {
    local skill_name="${1:-}"
    if [ -z "$skill_name" ]; then
        echo "Usage: cortexos-skill info <skill-name>"
        exit 1
    fi
    
    local skill_file="$SKILLS_DIR/$skill_name/SKILL.md"
    if [ -f "$skill_file" ]; then
        head -5 "$skill_file"
        echo ""
        echo "Lines: $(wc -l < "$skill_file")"
        echo "Size: $(du -h "$skill_file" | awk '{print $1}')"
    else
        echo "Skill '$skill_name' not installed."
    fi
}


cmd_available() {
    echo -e "${BLUE}Available Skills (Extended Repo):${NC}"
    echo ""
    
    local EXT_MANIFEST_URL="https://raw.githubusercontent.com/ivanuser/cortex-server-skills/main/manifest.json"
    
    if ! curl -sfL "$EXT_MANIFEST_URL" -o "$TEMP_DIR/ext-manifest.json" 2>/dev/null; then
        echo "Failed to fetch extended skills manifest. Are you online?"
        exit 1
    fi
    
    python3 -c "
import json, os

with open('$TEMP_DIR/ext-manifest.json') as f:
    ext = json.load(f)

installed = set()
for d in os.listdir('$SKILLS_DIR'):
    if os.path.isdir(os.path.join('$SKILLS_DIR', d)):
        installed.add(d)

print('Not Installed:')
for name, info in sorted(ext.get('skills', {}).items()):
    short = name.split('/')[-1]
    if short not in installed:
        print(f'  {short:25s} v{info.get(chr(34)+chr(118)+chr(101)+chr(114)+chr(115)+chr(105)+chr(111)+chr(110)+chr(34),chr(63)):8s} {info.get(chr(34)+chr(100)+chr(101)+chr(115)+chr(99)+chr(114)+chr(105)+chr(112)+chr(116)+chr(105)+chr(111)+chr(110)+chr(34),chr(34)+chr(34))}')

print()
print('Already Installed:')
for name, info in sorted(ext.get('skills', {}).items()):
    short = name.split('/')[-1]
    if short in installed:
        print(f'  {short:25s} (installed)')

print()
print('Install with: cortexos-skill install <name>')
"
}

# Main
case "${1:-}" in
    list)    cmd_list ;;
    check)   cmd_check ;;
    update)  cmd_update ;;
    install) cmd_install "${2:-}" ;;
    info)    cmd_info "${2:-}" ;;
    available) cmd_available ;;
    *)       usage ;;
esac
