#!/bin/bash
# CortexOS DefenseClaw Export
# Fetches alerts and status from the local DefenseClaw API and writes them
# to /var/lib/cortexos/dashboard/ so the management server can fetch them
# Runs via cron every 5 minutes

set -euo pipefail

DC_API="http://127.0.0.1:18970"
DASHBOARD="/var/lib/cortexos/dashboard"
TODAY=$(date +%Y-%m-%d)
STATUS_FILE="$DASHBOARD/defenseclaw-status.json"
ALERTS_FILE="$DASHBOARD/defenseclaw-alerts.json"

mkdir -p "$DASHBOARD"

# ─── Fetch alerts ─────────────────────────────────────────
ALERTS=$(curl -sf --connect-timeout 3 --max-time 5 "$DC_API/alerts" 2>/dev/null || echo "")

if [ -n "$ALERTS" ] && echo "$ALERTS" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    # Wrap in object if it's a bare array
    IS_ARRAY=$(echo "$ALERTS" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if isinstance(d,list) else 'no')" 2>/dev/null || echo "no")
    if [ "$IS_ARRAY" = "yes" ]; then
        echo "$ALERTS" | python3 -c "
import sys, json
alerts = json.load(sys.stdin)
print(json.dumps({'alerts': alerts, 'count': len(alerts), 'exported': '$TODAY'}))
" > "$ALERTS_FILE"
    else
        echo "$ALERTS" > "$ALERTS_FILE"
    fi
    ALERT_COUNT=$(python3 -c "import json; d=json.load(open('$ALERTS_FILE')); print(len(d.get('alerts',d if isinstance(d,list) else [])))" 2>/dev/null || echo "?")
    echo "✅ Alerts exported: $ALERT_COUNT alerts → $ALERTS_FILE"
else
    # DefenseClaw API not reachable — write empty alerts
    echo '{"alerts":[],"count":0,"exported":"'"$TODAY"'","note":"defenseclaw-api-unreachable"}' > "$ALERTS_FILE"
    echo "⚠️  DefenseClaw API unreachable (port 18970) — wrote empty alerts"
fi

# ─── Fetch status from API and merge with status file ─────
DC_STATUS=$(curl -sf --connect-timeout 3 --max-time 5 "$DC_API/status" 2>/dev/null || echo "")

if [ -n "$DC_STATUS" ] && echo "$DC_STATUS" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    # Merge API status into our status file (preserves policy, version, etc.)
    if [ -f "$STATUS_FILE" ]; then
        python3 -c "
import sys, json
existing = json.load(open('$STATUS_FILE'))
api_status = json.loads('''$DC_STATUS''')
# Update service status from live API
if api_status.get('healthy'):
    existing['status'] = 'running'
elif 'status' in api_status:
    existing['status'] = api_status.get('status', existing.get('status','unknown'))
existing['api_reachable'] = True
existing['gateway_connected'] = api_status.get('gateway_connected', api_status.get('connected', False))
existing['last_export'] = '$TODAY'
print(json.dumps(existing))
" > "${STATUS_FILE}.tmp" 2>/dev/null && mv "${STATUS_FILE}.tmp" "$STATUS_FILE" || true
        echo "✅ Status updated from live API"
    fi
else
    # API not reachable — update status to reflect this
    if [ -f "$STATUS_FILE" ]; then
        python3 -c "
import sys, json
existing = json.load(open('$STATUS_FILE'))
# Check systemd status instead
import subprocess
result = subprocess.run(['systemctl', 'is-active', 'cortexos-defenseclaw'],
                       capture_output=True, text=True)
existing['status'] = result.stdout.strip() if result.returncode == 0 else 'inactive'
existing['api_reachable'] = False
existing['last_export'] = '$TODAY'
print(json.dumps(existing))
" > "${STATUS_FILE}.tmp" 2>/dev/null && mv "${STATUS_FILE}.tmp" "$STATUS_FILE" || true
        echo "⚠️  DefenseClaw API unreachable — status updated from systemd"
    fi
fi

# ─── Fetch activity log (blocked + allowed events) ────────
BLOCKED=$(curl -sf --connect-timeout 3 --max-time 5 "$DC_API/enforce/blocked" 2>/dev/null || echo "[]")
ALLOWED=$(curl -sf --connect-timeout 3 --max-time 5 "$DC_API/enforce/allowed" 2>/dev/null || echo "[]")

python3 << PYEOF
import json, os
today = '$TODAY'
dashboard = '$DASHBOARD'

try:
    blocked = json.loads('''$BLOCKED''') if '$BLOCKED' != '[]' else []
    blocked = blocked if isinstance(blocked, list) else blocked.get('items', blocked.get('events', []))
except: blocked = []

try:
    allowed = json.loads('''$ALLOWED''') if '$ALLOWED' != '[]' else []
    allowed = allowed if isinstance(allowed, list) else allowed.get('items', allowed.get('events', []))
except: allowed = []

# Tag each event with action
for e in blocked: e['action'] = 'BLOCK'
for e in allowed: e['action'] = 'ALLOW'

events = sorted(blocked + allowed, key=lambda x: x.get('timestamp',''), reverse=True)[:100]
result = {'events': events, 'count': len(events), 'blocked': len(blocked), 'allowed': len(allowed), 'exported': today}
with open(os.path.join(dashboard, 'defenseclaw-activity.json'), 'w') as f:
    json.dump(result, f)
print(f'  exported {len(events)} events ({len(blocked)} blocked, {len(allowed)} allowed)')
PYEOF
echo "✅ Activity export complete"

echo "✅ DefenseClaw export complete"
