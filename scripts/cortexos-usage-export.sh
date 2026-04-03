#!/bin/bash
# CortexOS Usage Export
# Collects basic usage stats and writes to dashboard dir

set -euo pipefail

DASHBOARD="/var/lib/cortexos/dashboard"
USAGE_FILE="$DASHBOARD/usage.json"

mkdir -p "$DASHBOARD"

# Find openclaw config
OC_CONFIG=""
for f in /root/.openclaw/openclaw.json /home/ihoner/.openclaw/openclaw.json; do
    [ -f "$f" ] && OC_CONFIG="$f" && break
done

if [ -z "$OC_CONFIG" ]; then
    echo '{"error":"no config"}' > "$USAGE_FILE"
    exit 0
fi

# Extract model and basic info from config
python3 << PYEOF
import json, os, time, glob

config_path = '$OC_CONFIG'
dashboard = '$DASHBOARD'
usage_file = '$USAGE_FILE'

with open(config_path) as f:
    cfg = json.load(f)

model = cfg.get('agents', {}).get('defaults', {}).get('model', {}).get('primary', 'unknown')

# Count session files for activity estimate
oc_dir = os.path.dirname(config_path)
session_files = glob.glob(os.path.join(oc_dir, 'completions', '**', '*.jsonl'), recursive=True)
total_sessions = len(session_files)

# Count total messages across all session files
total_messages = 0
total_tool_calls = 0
for sf in session_files[-10:]:  # Only check recent 10 for performance
    try:
        with open(sf) as f:
            for line in f:
                total_messages += 1
                if '"tool_use"' in line or '"tool_call"' in line:
                    total_tool_calls += 1
    except:
        pass

# Get system uptime
try:
    uptime = float(open('/proc/uptime').read().split()[0])
except:
    uptime = 0

# Get audit DB stats if available
audit_events = 0
try:
    audit_db = os.path.join(oc_dir, 'audit.db')
    if os.path.exists(audit_db):
        import sqlite3
        conn = sqlite3.connect(audit_db)
        audit_events = conn.execute('SELECT COUNT(*) FROM events').fetchone()[0]
        conn.close()
except:
    pass

usage = {
    'model': model,
    'total_sessions': total_sessions,
    'messages_sampled': total_messages,
    'tool_calls_sampled': total_tool_calls,
    'audit_events': audit_events,
    'uptime_seconds': int(uptime),
    'exported': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    'source': 'local'
}

with open(usage_file, 'w') as f:
    json.dump(usage, f)
print(f'Usage exported: {total_sessions} sessions, {total_messages} messages sampled')
PYEOF
