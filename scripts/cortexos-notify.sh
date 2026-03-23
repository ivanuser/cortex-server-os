#!/bin/bash
# Send notification to management server
# Usage: cortexos-notify "alert" "Disk usage at 90%"
# Called by the agent during heartbeats when issues are found

MGMT_URL="${MGMT_URL:-$(cat /etc/cortexos/mgmt-url 2>/dev/null)}"
SERVER_ID="${SERVER_ID:-$(cat /etc/cortexos/server-id 2>/dev/null)}"
GATEWAY_TOKEN="${GATEWAY_TOKEN:-$(python3 -c "import json; print(json.load(open('/root/.openclaw/openclaw.json'))['gateway']['auth']['token'])" 2>/dev/null)}"

TYPE="${1:-info}"  # info, warning, alert, critical
MESSAGE="${2:-No message}"

if [ -n "$MGMT_URL" ]; then
  curl -sf -X POST "$MGMT_URL/api/v1/notifications" \
    -H "Content-Type: application/json" \
    -H "X-Server-Token: $GATEWAY_TOKEN" \
    -d "{\"server_id\":\"$SERVER_ID\",\"type\":\"$TYPE\",\"message\":\"$MESSAGE\",\"ts\":$(date +%s)}" \
    2>/dev/null || true
fi
