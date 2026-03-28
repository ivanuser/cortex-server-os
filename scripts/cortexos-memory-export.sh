#!/bin/bash
# CortexOS Memory Export
# Reads all agent memory files and exports to JSON for management server
# Output: /var/lib/cortexos/dashboard/memory.json

set +e  # Don't exit on errors — be resilient
DASHBOARD_DIR="/var/lib/cortexos/dashboard"
mkdir -p "$DASHBOARD_DIR"

python3 << 'PYEOF'
import json, os, glob, time, re
from datetime import datetime, timezone

OUTPUT = "/var/lib/cortexos/dashboard/memory.json"

# Find the OpenClaw workspace — try multiple locations
WORKSPACE = None
candidates = [
    os.path.expanduser("~/.openclaw/workspace"),
    "/root/.openclaw/workspace",       # running as root
    "/home/ihoner/.openclaw/workspace", # running as ihoner
    os.path.expanduser("~"),          # workspace might be home dir itself
    "/home/ihoner",                    # common user on CortexOS agents
    "/root",                           # if running as root
]
# Also check openclaw config for workspace path
for cfg_path in [os.path.expanduser("~/.openclaw/openclaw.json"), "/root/.openclaw/openclaw.json"]:
    if os.path.isfile(cfg_path):
        try:
            with open(cfg_path) as f:
                cfg = json.load(f)
            ws = cfg.get("workspace") or cfg.get("agent", {}).get("workspace")
            if ws and os.path.isdir(ws):
                candidates.insert(0, ws)
        except:
            pass

for candidate in candidates:
    if candidate and os.path.isdir(candidate):
        # Check if it looks like an OpenClaw workspace (has MEMORY.md or SOUL.md or AGENTS.md)
        if any(os.path.isfile(os.path.join(candidate, f)) for f in ["MEMORY.md", "SOUL.md", "AGENTS.md", "USER.md"]):
            WORKSPACE = candidate
            break

if not WORKSPACE:
    # Fallback: use home dir
    WORKSPACE = os.path.expanduser("~")

print(f"Using workspace: {WORKSPACE}")

entries = []

def read_file(path):
    try:
        with open(path, encoding='utf-8', errors='ignore') as f:
            return f.read()
    except:
        return ""

def file_mtime(path):
    try:
        return int(os.path.getmtime(path))
    except:
        return 0

# ── MEMORY.md (long-term memory) ──────────────────────────
memory_md = os.path.join(WORKSPACE, "MEMORY.md")
if os.path.isfile(memory_md):
    content = read_file(memory_md)
    if content.strip():
        entries.append({
            "id": "memory-md",
            "category": "long-term",
            "label": "MEMORY.md",
            "title": "Long-Term Memory",
            "content": content,
            "date": datetime.fromtimestamp(file_mtime(memory_md), tz=timezone.utc).strftime("%Y-%m-%d"),
            "updated": file_mtime(memory_md),
            "path": "MEMORY.md"
        })

# ── Daily memory logs ──────────────────────────────────────
memory_dir = os.path.join(WORKSPACE, "memory")
if os.path.isdir(memory_dir):
    for f in sorted(glob.glob(os.path.join(memory_dir, "*.md")), reverse=True)[:90]:
        basename = os.path.basename(f)
        # Parse date from filename
        date_match = re.match(r'(\d{4}-\d{2}-\d{2})\.md', basename)
        if not date_match:
            continue
        date = date_match.group(1)
        content = read_file(f)
        if not content.strip():
            continue
        entries.append({
            "id": f"daily-{date}",
            "category": "daily",
            "label": date,
            "title": f"Daily Log — {date}",
            "content": content,
            "date": date,
            "updated": file_mtime(f),
            "path": f"memory/{basename}"
        })

    # Dreams
    dreams_dir = os.path.join(memory_dir, "dreams")
    if os.path.isdir(dreams_dir):
        for f in sorted(glob.glob(os.path.join(dreams_dir, "*.md")), reverse=True)[:30]:
            basename = os.path.basename(f)
            date_match = re.match(r'(\d{4}-\d{2}-\d{2})\.md', basename)
            date = date_match.group(1) if date_match else basename.replace('.md','')
            content = read_file(f)
            if not content.strip():
                continue
            entries.append({
                "id": f"dream-{date}",
                "category": "dreams",
                "label": date,
                "title": f"Dreams — {date}",
                "content": content,
                "date": date,
                "updated": file_mtime(f),
                "path": f"memory/dreams/{basename}"
            })

    # Shadow work (if accessible)
    shadow_dir = os.path.join(memory_dir, "shadow")
    if os.path.isdir(shadow_dir):
        for f in sorted(glob.glob(os.path.join(shadow_dir, "*.md")), reverse=True)[:20]:
            basename = os.path.basename(f)
            date_match = re.match(r'(\d{4}-\d{2}-\d{2})\.md', basename)
            date = date_match.group(1) if date_match else basename.replace('.md','')
            content = read_file(f)
            if not content.strip():
                continue
            entries.append({
                "id": f"shadow-{date}",
                "category": "shadow",
                "label": date,
                "title": f"Shadow Work — {date}",
                "content": content,
                "date": date,
                "updated": file_mtime(f),
                "path": f"memory/shadow/{basename}"
            })

# ── SOUL.md, USER.md, IDENTITY.md (context files) ─────────
for fname, cat, title in [
    ("SOUL.md", "context", "Soul — Agent Identity"),
    ("IDENTITY.md", "context", "Identity"),
    ("USER.md", "context", "User Profile"),
    ("AGENTS.md", "context", "Agent Config"),
]:
    fpath = os.path.join(WORKSPACE, fname)
    if os.path.isfile(fpath):
        content = read_file(fpath)
        if content.strip():
            entries.append({
                "id": fname.lower().replace('.', '-'),
                "category": cat,
                "label": fname,
                "title": title,
                "content": content,
                "date": datetime.fromtimestamp(file_mtime(fpath), tz=timezone.utc).strftime("%Y-%m-%d"),
                "updated": file_mtime(fpath),
                "path": fname
            })

# ── Heartbeat state ────────────────────────────────────────
hb_state = os.path.join(WORKSPACE, "memory", "heartbeat-state.json")
if os.path.isfile(hb_state):
    try:
        with open(hb_state) as f:
            hb = json.load(f)
        entries.append({
            "id": "heartbeat-state",
            "category": "system",
            "label": "Heartbeat State",
            "title": "Heartbeat State",
            "content": json.dumps(hb, indent=2),
            "date": datetime.now(tz=timezone.utc).strftime("%Y-%m-%d"),
            "updated": file_mtime(hb_state),
            "path": "memory/heartbeat-state.json"
        })
    except:
        pass

# Sort by date desc
entries.sort(key=lambda e: e.get('updated', 0), reverse=True)

output = {
    "exported_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "total": len(entries),
    "workspace": WORKSPACE,
    "entries": entries
}

with open(OUTPUT, "w") as f:
    json.dump(output, f, indent=2)

print(f"Memory export: {len(entries)} entries → {OUTPUT}")
PYEOF
