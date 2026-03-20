#!/bin/bash
# Build offline skill bundles for air-gapped CortexOS deployments
# Usage: bash build-offline-bundle.sh [--all | --web-server | --database | --full-stack]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_REPO="/home/ihoner/projects/cortex-server-skills"
BUNDLE_DIR="$PROJECT_ROOT/bundles"
BUILD_DIR="/tmp/cortexos-bundle-build-$$"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[bundle]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }
info() { echo -e "${BLUE}[info]${NC} $1"; }

cleanup() { rm -rf "$BUILD_DIR"; }
trap cleanup EXIT

# Create directories
mkdir -p "$BUNDLE_DIR" "$BUILD_DIR"

# ==================== Collect Skills ====================
collect_skill() {
  local skill_dir="$1"
  local skill_name="$(basename "$skill_dir")"
  local dest="$BUILD_DIR/skills/$skill_name"

  if [ ! -d "$skill_dir" ]; then
    warn "Skill directory not found: $skill_dir"
    return 1
  fi

  mkdir -p "$dest"

  # Copy SKILL.md (required)
  if [ -f "$skill_dir/SKILL.md" ]; then
    cp "$skill_dir/SKILL.md" "$dest/"
  else
    warn "No SKILL.md in $skill_dir — skipping"
    rm -rf "$dest"
    return 1
  fi

  # Copy any reference files, scripts, templates
  for subdir in references scripts templates; do
    if [ -d "$skill_dir/$subdir" ]; then
      cp -r "$skill_dir/$subdir" "$dest/"
    fi
  done

  # Copy manifest/config files
  for f in manifest.json config.json package.json; do
    if [ -f "$skill_dir/$f" ]; then
      cp "$skill_dir/$f" "$dest/"
    fi
  done

  log "  ✓ $skill_name"
  return 0
}

collect_all_skills() {
  log "Collecting skills from cortex-server-os..."
  local count=0

  # Core skills from cortex-server-os
  if [ -d "$PROJECT_ROOT/skills" ]; then
    for skill_dir in "$PROJECT_ROOT/skills"/*/; do
      [ -d "$skill_dir" ] || continue
      collect_skill "$skill_dir" && count=$((count + 1)) || true
    done
  fi

  # Extended skills from cortex-server-skills
  if [ -d "$SKILLS_REPO" ]; then
    log "Collecting skills from cortex-server-skills..."
    for category in server apps infra runtime cloud; do
      if [ -d "$SKILLS_REPO/$category" ]; then
        for skill_dir in "$SKILLS_REPO/$category"/*/; do
          [ -d "$skill_dir" ] || continue
          collect_skill "$skill_dir" && count=$((count + 1)) || true
        done
      fi
    done
  else
    warn "cortex-server-skills repo not found at $SKILLS_REPO"
  fi

  log "Collected $count skills total"
}

# ==================== Install Script ====================
create_install_script() {
  cat > "$BUILD_DIR/install.sh" << 'INSTALL_EOF'
#!/bin/bash
# CortexOS Offline Skill Installer
# Usage: sudo bash install.sh [--dest /path/to/skills]

set -euo pipefail

DEST="${1:-/var/lib/cortexos/skills}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SCRIPT_DIR/skills"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}CortexOS Offline Skill Installer${NC}"
echo "Installing to: $DEST"
echo "─────────────────────────────────"

# Create destination
mkdir -p "$DEST"

if [ ! -d "$SKILL_SRC" ]; then
  echo "Error: No skills directory found in bundle"
  exit 1
fi

count=0
for skill_dir in "$SKILL_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  echo -e "  ${GREEN}✓${NC} Installing $skill_name"
  cp -r "$skill_dir" "$DEST/"
  ((count++))
done

echo "─────────────────────────────────"
echo -e "${GREEN}✅ Installed $count skills to $DEST${NC}"

# Update manifest if cortexos-skill exists
if command -v cortexos-skill &>/dev/null; then
  echo "Updating skill manifest..."
  cortexos-skill refresh 2>/dev/null || true
fi
INSTALL_EOF
  chmod +x "$BUILD_DIR/install.sh"
}

# ==================== Bundle Builders ====================
build_bundle() {
  local bundle_name="$1"
  shift
  local skills=("$@")
  local bundle_build="/tmp/cortexos-${bundle_name}-$$"

  mkdir -p "$bundle_build/skills"

  local found=0
  for skill_name in "${skills[@]}"; do
    if [ -d "$BUILD_DIR/skills/$skill_name" ]; then
      cp -r "$BUILD_DIR/skills/$skill_name" "$bundle_build/skills/"
      found=$((found + 1))
    else
      warn "  Skill '$skill_name' not found in collected skills"
    fi
  done

  if [ "$found" -eq 0 ]; then
    warn "No skills found for bundle '$bundle_name' — skipping"
    rm -rf "$bundle_build"
    return
  fi

  # Add install script
  cp "$BUILD_DIR/install.sh" "$bundle_build/"

  # Add bundle metadata
  cat > "$bundle_build/BUNDLE.md" << EOF
# CortexOS Skill Bundle: $bundle_name

**Built:** $(date -u +"%Y-%m-%d %H:%M UTC")
**Skills:** $found

## Installation

\`\`\`bash
tar xzf ${bundle_name}.tar.gz
cd ${bundle_name}
sudo bash install.sh
\`\`\`

## Contents
$(for s in "${skills[@]}"; do
  if [ -d "$bundle_build/skills/$s" ]; then
    echo "- $s"
  fi
done)
EOF

  # Create tar.gz
  (cd /tmp && tar czf "$BUNDLE_DIR/${bundle_name}.tar.gz" -C "$bundle_build" .)
  local size=$(du -sh "$BUNDLE_DIR/${bundle_name}.tar.gz" | cut -f1)
  log "📦 ${bundle_name}.tar.gz ($found skills, $size)"
  rm -rf "$bundle_build"
}

# ==================== Main ====================
BUILD_TARGET="${1:---all}"

log "Building CortexOS offline skill bundles..."
echo ""

# Step 1: Collect all skills
collect_all_skills
create_install_script
echo ""

# Step 2: Build bundles
case "$BUILD_TARGET" in
  --web-server)
    log "Building web-server bundle..."
    build_bundle "web-server" nginx apache caddy haproxy certbot
    ;;
  --database)
    log "Building database bundle..."
    build_bundle "database" postgres mysql redis mongodb elasticsearch cassandra sqlite
    ;;
  --full-stack)
    log "Building full-stack bundle..."
    all_skills=()
    for d in "$BUILD_DIR/skills"/*/; do
      [ -d "$d" ] && all_skills+=("$(basename "$d")")
    done
    build_bundle "full-stack" "${all_skills[@]}"
    ;;
  --all|*)
    log "Building all bundles..."
    echo ""

    info "→ web-server bundle"
    build_bundle "web-server" nginx apache caddy haproxy certbot

    info "→ database bundle"
    build_bundle "database" postgres mysql redis mongodb elasticsearch cassandra sqlite

    info "→ full-stack bundle (all skills)"
    all_skills=()
    for d in "$BUILD_DIR/skills"/*/; do
      [ -d "$d" ] && all_skills+=("$(basename "$d")")
    done
    build_bundle "full-stack" "${all_skills[@]}"
    ;;
esac

echo ""
log "✅ Bundles built in $BUNDLE_DIR/"
ls -lh "$BUNDLE_DIR/"*.tar.gz 2>/dev/null || true
