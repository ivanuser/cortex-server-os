#!/bin/bash
# CortexOS DefenseClaw Pairing
# Pre-approves DefenseClaw's device key in openclaw's paired.json
# Run once after defenseclaw is installed to allow gateway connection

set -euo pipefail

DC_KEY="/var/lib/cortexos/.defenseclaw/device.key"
PAIRED_JSON=$(find /root /home -maxdepth 6 -name "paired.json" -path "*openclaw/devices*" 2>/dev/null | head -1)

echo "═══════════════════════════════════════════"
echo "🔗 DefenseClaw Device Pairing"
echo "   $(date)"
echo "═══════════════════════════════════════════"

if [ ! -f "$DC_KEY" ]; then
    echo "❌ DefenseClaw device key not found at $DC_KEY"
    echo "   Run cortexos-defenseclaw first"
    exit 1
fi

if [ -z "$PAIRED_JSON" ]; then
    echo "❌ openclaw paired.json not found"
    exit 1
fi

echo "✅ Device key: $DC_KEY"
echo "✅ Paired devices: $PAIRED_JSON"
echo ""

python3 << PYEOF
import json, hashlib, base64, time, sys

try:
    import cryptography.hazmat.primitives.serialization as ser
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
    with open('$DC_KEY', 'rb') as f:
        priv = ser.load_pem_private_key(f.read(), password=None)
    pub_raw = priv.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
except ImportError:
    # Fallback: parse raw Ed25519 key manually
    import re, base64 as b64mod
    with open('$DC_KEY') as f: pem = f.read()
    raw_b64 = re.sub(r'-----[^-]+-----|\n', '', pem).strip()
    raw = b64mod.b64decode(raw_b64)
    # Ed25519 PKCS8: 48 bytes total, last 32 are private key
    # We need device ID from journal logs as fallback
    import subprocess
    result = subprocess.run(['journalctl','-u','cortexos-defenseclaw','-n','100','--no-pager'],
                           capture_output=True, text=True)
    import re as re2
    m = re2.search(r'device=([0-9a-f]{64})', result.stdout)
    if not m:
        print('ERROR: Cannot extract device ID — install python3-cryptography: apt install python3-cryptography')
        sys.exit(1)
    device_id = m.group(1)
    pub_b64url = None
    print(f'Using device ID from logs: {device_id[:16]}...')
else:
    pub_b64url = base64.urlsafe_b64encode(pub_raw).rstrip(b'=').decode()
    device_id = hashlib.sha256(pub_raw).hexdigest()
    print(f'Device ID: {device_id[:16]}...')

with open('$PAIRED_JSON') as f:
    paired = json.load(f)

if device_id in paired:
    print('✅ DefenseClaw already paired — nothing to do')
    sys.exit(0)

paired[device_id] = {
    'deviceId': device_id,
    'publicKey': pub_b64url,
    'platform': 'linux',
    'clientId': 'gateway-client',
    'clientMode': 'backend',
    'role': 'operator',
    'roles': ['operator'],
    'scopes': ['operator.admin','operator.read','operator.write','operator.approvals'],
    'approvedScopes': ['operator.admin','operator.read','operator.write','operator.approvals'],
    'approvedAt': int(time.time() * 1000),
    'label': 'DefenseClaw Security Gateway',
    'deviceFamily': 'server'
}
with open('$PAIRED_JSON', 'w') as f:
    json.dump(paired, f, indent=2)
print('✅ DefenseClaw device paired successfully')
PYEOF

echo ""
echo "🔄 Restarting openclaw gateway..."
systemctl restart cortex-server 2>/dev/null || true
sleep 3

echo "🔄 Restarting DefenseClaw..."
systemctl restart cortexos-defenseclaw 2>/dev/null || true
sleep 3

# Check if connected
if journalctl -u cortexos-defenseclaw -n 20 --no-pager 2>/dev/null | grep -q "handshake complete"; then
    echo "✅ DefenseClaw connected to gateway!"
else
    echo "⏳ Check status: journalctl -u cortexos-defenseclaw -n 10 --no-pager"
fi

echo ""
echo "═══════════════════════════════════════════"
echo "✅ Pairing complete"
echo "═══════════════════════════════════════════"
