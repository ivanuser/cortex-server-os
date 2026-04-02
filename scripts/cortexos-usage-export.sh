#!/bin/bash
# CortexOS Usage Export
# Fetches usage stats from the local openclaw gateway and writes to dashboard dir
# Uses the gateway's WebSocket RPC to call usage.status

set -euo pipefail

DASHBOARD="/var/lib/cortexos/dashboard"
USAGE_FILE="$DASHBOARD/usage.json"

mkdir -p "$DASHBOARD"

# Find openclaw config to get gateway token
OC_CONFIG=""
for f in /root/.openclaw/openclaw.json /home/ihoner/.openclaw/openclaw.json; do
    [ -f "$f" ] && OC_CONFIG="$f" && break
done

if [ -z "$OC_CONFIG" ]; then
    echo '{"error":"no config"}' > "$USAGE_FILE"
    exit 1
fi

GW_TOKEN=$(python3 -c "
import json
with open('$OC_CONFIG') as f: d=json.load(f)
print(d.get('gateway',{}).get('auth',{}).get('token',''))
" 2>/dev/null)

GW_PORT=$(python3 -c "
import json
with open('$OC_CONFIG') as f: d=json.load(f)
print(d.get('gateway',{}).get('port', 18789))
" 2>/dev/null)

# Use Python websocket to call usage.status RPC
python3 << PYEOF
import json, time, sys

try:
    import websocket
except ImportError:
    # Try without websocket library — use the gateway CLI instead
    import subprocess
    result = subprocess.run(
        ['openclaw-cortex', 'gateway', 'call', 'usage.status', '--json', '--token', '$GW_TOKEN'],
        capture_output=True, text=True, timeout=10
    )
    if result.returncode == 0:
        with open('$USAGE_FILE', 'w') as f:
            f.write(result.stdout)
        print('Usage exported via CLI')
    else:
        # Fallback: just write basic stats from /proc
        import os
        stats = {
            'exported': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'uptime_seconds': float(open('/proc/uptime').read().split()[0]),
            'load_avg': os.getloadavg(),
            'source': 'fallback'
        }
        with open('$USAGE_FILE', 'w') as f:
            json.dump(stats, f)
        print('Usage exported (fallback)')
    sys.exit(0)

# WebSocket approach
ws = websocket.WebSocket()
ws.settimeout(10)
ws.connect(f'ws://127.0.0.1:$GW_PORT')

# Wait for challenge
msg = json.loads(ws.recv())
if msg.get('type') == 'event' and msg.get('event') == 'connect.challenge':
    nonce = msg['payload']['nonce']

# Send connect
ws.send(json.dumps({
    'type': 'req', 'id': 'c1', 'method': 'connect',
    'params': {
        'minProtocol': 3, 'maxProtocol': 3,
        'client': {'id': 'webchat-ui', 'version': '1.0.0', 'platform': 'linux', 'mode': 'webchat'},
        'scopes': ['operator.admin'],
        'auth': {'token': '$GW_TOKEN'}
    }
}))

# Read connect response
msg = json.loads(ws.recv())

# Request usage.status
ws.send(json.dumps({
    'type': 'req', 'id': 'u1', 'method': 'usage.status',
    'params': {}
}))

# Read response
for _ in range(10):
    msg = json.loads(ws.recv())
    if msg.get('type') == 'res' and msg.get('id') == 'u1':
        if msg.get('ok'):
            data = msg.get('payload', {})
            data['exported'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
            with open('$USAGE_FILE', 'w') as f:
                json.dump(data, f)
            print('Usage exported via WebSocket')
        else:
            print(f'Usage RPC failed: {msg.get("error",{})}')
        break

ws.close()
PYEOF
