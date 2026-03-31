#!/bin/bash
# CortexOS Token Sync
# Fetches the agent's trust token from the management server
# and writes it to mgmt-token.conf for local verification

set -euo pipefail

TOKEN_CONF="/var/lib/cortexos/mgmt-token.conf"
OC_CONFIG=""

# Find openclaw config to get gateway token (used as install token for identity)
for f in /root/.openclaw/openclaw.json /home/ihoner/.openclaw/openclaw.json; do
    [ -f "$f" ] && OC_CONFIG="$f" && break
done

if [ -z "$OC_CONFIG" ]; then
    echo "⚠️  openclaw.json not found — cannot sync token"
    exit 1
fi

# Extract gateway token (this identifies us to the management server)
GW_TOKEN=$(python3 -c "
import json
with open('$OC_CONFIG') as f: d=json.load(f)
print(d.get('gateway',{}).get('auth',{}).get('token',''))
" 2>/dev/null)

if [ -z "$GW_TOKEN" ]; then
    echo "⚠️  No gateway token in $OC_CONFIG"
    exit 1
fi

# Fetch our trust token from the management server
MGMT_URL="https://cortex-manage.honercloud.com"
RESPONSE=$(curl -sf --connect-timeout 10 --max-time 15 "$MGMT_URL/api/v1/agent-token/$GW_TOKEN" 2>/dev/null || echo "")

if [ -z "$RESPONSE" ]; then
    echo "⚠️  Could not reach management server"
    exit 1
fi

# Parse response
TOKEN=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null)
SERVER_NAME=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('server_name',''))" 2>/dev/null)
MGMT_SERVER=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('mgmt_server',''))" 2>/dev/null)
EXPIRES=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('expires_at',''))" 2>/dev/null)
ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',''))" 2>/dev/null)

if [ -n "$ERROR" ]; then
    echo "⚠️  Management server: $ERROR"
    exit 1
fi

if [ -z "$TOKEN" ]; then
    echo "⚠️  No token in response"
    exit 1
fi

# Write token config
cat > "$TOKEN_CONF" << EOF
# CortexOS Management Trust Token
# Auto-synced from management server — do not edit manually
# Server: $SERVER_NAME
# Synced: $(date -u +%Y-%m-%dT%H:%M:%SZ)
MGMT_TOKEN=$TOKEN
MGMT_SERVER=$MGMT_SERVER
MGMT_EXPIRES=$EXPIRES
MGMT_AUTHORIZED=true
EOF

chmod 600 "$TOKEN_CONF"
echo "✅ Token synced for $SERVER_NAME (expires: $EXPIRES)"
