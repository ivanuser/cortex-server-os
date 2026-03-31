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
import json, hashlib, base64, time, sys, re, subprocess

# Get device ID directly from DefenseClaw logs — most reliable method
result = subprocess.run(['journalctl','-u','cortexos-defenseclaw','-n','200','--no-pager'],
                       capture_output=True, text=True)
m = re.search(r'device=([0-9a-f]{64})', result.stdout)
if not m:
    # Try starting defenseclaw briefly to get device ID
    subprocess.run(['systemctl','start','cortexos-defenseclaw'], capture_output=True)
    import time as t; t.sleep(3)
    result = subprocess.run(['journalctl','-u','cortexos-defenseclaw','-n','50','--no-pager'],
                           capture_output=True, text=True)
    m = re.search(r'device=([0-9a-f]{64})', result.stdout)

if not m:
    print('ERROR: Could not find device ID in logs')
    sys.exit(1)

device_id = m.group(1)
print(f'Device ID from logs: {device_id[:16]}...')

# Try to get public key via openssl
import subprocess as sp
try:
    # Convert PEM to DER and extract public key bytes using openssl
    r = sp.run(['openssl','pkey','-in','$DC_KEY','-pubout','-outform','DER'],
               capture_output=True)
    if r.returncode == 0:
        # DER public key for Ed25519: 12-byte header + 32-byte key
        pub_der = r.stdout
        pub_raw = pub_der[-32:]
        pub_b64url = base64.urlsafe_b64encode(pub_raw).rstrip(b'=').decode()
        # Verify device ID matches
        computed_id = hashlib.sha256(pub_raw).hexdigest()
        if computed_id == device_id:
            print(f'Public key verified via openssl')
        else:
            print(f'Warning: computed device ID mismatch, using log device ID')
            pub_b64url = None
    else:
        pub_b64url = None
except Exception as e:
    pub_b64url = None

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
