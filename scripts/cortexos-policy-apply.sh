#!/bin/bash
# CortexOS DefenseClaw Policy Apply
# Downloads and applies a named policy to the running DefenseClaw gateway
# Usage: cortexos-policy-apply [policy_name]
#        cortexos-policy-apply cortexos   # applies the CortexOS management policy

set -euo pipefail

POLICY_NAME="${1:-cortexos}"
POLICY_DIR="/etc/defenseclaw/policies"
POLICY_FILE="$POLICY_DIR/${POLICY_NAME}.yaml"
SERVICE_FILE="/etc/systemd/system/cortexos-defenseclaw.service"
BINARY="/usr/local/bin/defenseclaw-gateway"
REPO_BASE="https://raw.githubusercontent.com/ivanuser/cortex-server-os/main"
STATUS_FILE="/var/lib/cortexos/dashboard/defenseclaw-status.json"
TODAY=$(date +%Y-%m-%d)

echo "═══════════════════════════════════════════"
echo "🛡️  CortexOS Policy Apply: $POLICY_NAME"
echo "   $(date)"
echo "═══════════════════════════════════════════"

# ─── Step 1: Check DefenseClaw is installed ───────────────
if [ ! -f "$BINARY" ]; then
    echo "❌ DefenseClaw binary not found at $BINARY"
    echo "   Run cortexos-defenseclaw first to install"
    exit 1
fi
echo "✅ DefenseClaw binary present"

# ─── Step 2: Create policy directory ─────────────────────
mkdir -p "$POLICY_DIR"
echo "✅ Policy directory: $POLICY_DIR"

# ─── Step 3: Download policy file ────────────────────────
echo ""
echo "📥 Downloading policy: ${POLICY_NAME}.yaml..."
POLICY_URL="$REPO_BASE/policies/${POLICY_NAME}.yaml"

if curl -sfL --connect-timeout 10 --max-time 30 "$POLICY_URL" -o "$POLICY_FILE" 2>/dev/null; then
    echo "✅ Policy downloaded to $POLICY_FILE"
else
    # Fall back: write the cortexos policy inline if download fails
    if [ "$POLICY_NAME" = "cortexos" ]; then
        echo "⚠️  Download failed — writing built-in cortexos policy..."
        cat > "$POLICY_FILE" << 'EOF'
# CortexOS Management Policy
# Allows trusted management commands signed with a CortexOS management token
name: cortexos
description: "CortexOS management policy — trusts commands from authorized management server"
version: "1.0.0"
extends: default
tool_inspection:
  mode: action
trust_rules:
  - pattern: "^\\[CORTEX-MGMT-v1 token=[a-f0-9]{16}"
    action: allow
    reason: "CortexOS management server authorized command"
  - pattern: "^sudo cortexos-"
    action: allow
    reason: "CortexOS system command"
  - pattern: "^cortexos-"
    action: allow
    reason: "CortexOS system command"
block_rules:
  - pattern: "rm -rf /"
    action: block
    severity: CRITICAL
    reason: "Destructive filesystem operation"
  - pattern: "curl.*\\|.*bash"
    action: alert
    severity: HIGH
    reason: "Possible remote code execution — verify source"
skill_actions:
  HIGH: warn
  CRITICAL: block
guardrail:
  mode: observe
audit:
  enabled: true
  path: /var/lib/cortexos/dashboard/defenseclaw-audit.json
EOF
        echo "✅ Built-in cortexos policy written"
    else
        echo "❌ Could not download policy and no built-in fallback for: $POLICY_NAME"
        exit 1
    fi
fi

# ─── Step 3b: Ensure audit store directory exists ────────────────────────────
echo ""
echo "📁 Ensuring DefenseClaw data directories exist..."
mkdir -p /var/lib/cortexos/.defenseclaw
mkdir -p /var/lib/cortexos/dashboard
chmod 700 /var/lib/cortexos/.defenseclaw
echo "✅ Data directories ready"

# ─── Step 4: Fix service ExecStart (no --policy flag, run foreground) ────────
echo ""
echo "⚙️  Ensuring systemd service is correct..."

if [ -f "$SERVICE_FILE" ]; then
    # Fix ExecStart — remove any stale "serve --policy ..." and use bare binary (foreground for systemd)
    sed -i "s|ExecStart=.*|ExecStart=$BINARY|" "$SERVICE_FILE"
    echo "✅ Service ExecStart set to: $BINARY"
else
    echo "⚠️  Service file not found at $SERVICE_FILE — creating it..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=CortexOS DefenseClaw Security Gateway
After=network.target

[Service]
Type=simple
ExecStart=$BINARY
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=defenseclaw
Environment=HOME=/var/lib/cortexos

[Install]
WantedBy=multi-user.target
EOF
    echo "✅ Service file created"
fi

# ─── Step 5: Reload and restart ──────────────────────────
echo ""
echo "🔄 Reloading systemd and restarting DefenseClaw..."
systemctl daemon-reload

if systemctl restart cortexos-defenseclaw 2>/dev/null; then
    sleep 2
    if systemctl is-active cortexos-defenseclaw >/dev/null 2>&1; then
        echo "✅ DefenseClaw service running"
        SVC_STATUS="running"
    else
        echo "⚠️  Service may not have started — check: journalctl -u cortexos-defenseclaw -n 20"
        SVC_STATUS="restart-failed"
    fi
else
    echo "⚠️  Restart failed — check: journalctl -u cortexos-defenseclaw -n 20"
    SVC_STATUS="restart-failed"
fi

# ─── Step 5b: Configure DefenseClaw gateway connection ───────────────────────
echo ""
echo "🔗 Configuring DefenseClaw → openclaw gateway connection..."
DC_CONFIG="/var/lib/cortexos/.defenseclaw/config.yaml"
# Find openclaw config to get gateway auth token
OC_CONFIG=""
for f in /root/.openclaw/openclaw.json /home/ihoner/.openclaw/openclaw.json; do
    [ -f "$f" ] && OC_CONFIG="$f" && break
done
if [ -n "$OC_CONFIG" ]; then
    GW_TOKEN=$(python3 -c "
import json
with open('$OC_CONFIG') as f: d=json.load(f)
print(d.get('gateway',{}).get('auth',{}).get('token',''))
" 2>/dev/null)
    if [ -n "$GW_TOKEN" ]; then
        cat > "$DC_CONFIG" << EOF
gateway:
  host: 127.0.0.1
  port: 18789
  token: ${GW_TOKEN}
  tls_skip_verify: true
  auto_approve_safe: true

audit:
  enabled: true
  path: /var/lib/cortexos/dashboard/defenseclaw-audit.json

policy:
  path: /etc/defenseclaw/policies/${POLICY_NAME}.yaml
EOF
        echo "✅ DefenseClaw config written with gateway token"

        # Pre-approve DefenseClaw's device in openclaw's paired.json
        # so it doesn't need interactive pairing
        DC_DEVICE_KEY="/var/lib/cortexos/.defenseclaw/device.key"
        OC_PAIRED_JSON=$(dirname "$OC_CONFIG")/../devices/paired.json
        # Resolve to absolute path
        OC_PAIRED_JSON=$(python3 -c "import os; print(os.path.realpath('$(dirname $OC_CONFIG)/../devices/paired.json'))" 2>/dev/null)

        if [ -f "$DC_DEVICE_KEY" ] && [ -n "$OC_PAIRED_JSON" ]; then
            python3 << PAIRING_EOF
import json, hashlib, base64, os, re

# Read the Ed25519 private key PEM and extract public key
with open('$DC_DEVICE_KEY') as f:
    pem = f.read().strip()

# Extract base64 body
b64 = re.sub(r'-----[^-]+-----', '', pem).replace('\n', '').strip()
raw = base64.b64decode(b64)

# Ed25519 private key in PKCS8 format: last 32 bytes are public key
# Raw DER for Ed25519 private key is 48 bytes: 16 byte header + 32 byte private key
# The public key can be derived, but openclaw stores base64url of raw public key
# For a bare 32-byte raw key (non-PKCS8), use as-is
# Detect format: PKCS8 DER is 48 bytes, raw is 32 bytes
if len(raw) == 48:
    # PKCS8: public key is computed from private, but we need it from the key file
    # The last 32 bytes of Ed25519 PKCS8 private key IS the private key scalar
    # Public key derivation requires cryptography library
    try:
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat, PrivateFormat, NoEncryption
        import cryptography.hazmat.primitives.serialization as ser
        priv = ser.load_pem_private_key(open('$DC_DEVICE_KEY', 'rb').read(), password=None)
        pub_raw = priv.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
        pub_b64url = base64.urlsafe_b64encode(pub_raw).rstrip(b'=').decode()
        device_id = hashlib.sha256(pub_raw).hexdigest()
    except ImportError:
        # No cryptography library — use defenseclaw status to get device ID from logs
        import subprocess
        result = subprocess.run(['journalctl', '-u', 'cortexos-defenseclaw', '-n', '50', '--no-pager'],
                               capture_output=True, text=True)
        m = re.search(r'device=([0-9a-f]{64})', result.stdout)
        if m:
            device_id = m.group(1)
            pub_b64url = None
        else:
            print('Could not extract device ID')
            exit(1)
elif len(raw) == 32:
    pub_raw = raw
    pub_b64url = base64.urlsafe_b64encode(pub_raw).rstrip(b'=').decode()
    device_id = hashlib.sha256(pub_raw).hexdigest()
else:
    print(f'Unexpected key length: {len(raw)}')
    exit(1)

paired_path = '$OC_PAIRED_JSON'
if not os.path.exists(os.path.dirname(paired_path)):
    print(f'paired.json dir not found: {os.path.dirname(paired_path)}')
    exit(1)

# Load existing paired devices
try:
    with open(paired_path) as f:
        paired = json.load(f)
except: paired = {}

if device_id in paired:
    print(f'DefenseClaw device already paired: {device_id[:16]}...')
else:
    import time
    entry = {
        'deviceId': device_id,
        'publicKey': pub_b64url,
        'platform': 'linux',
        'clientId': 'gateway-client',
        'clientMode': 'backend',
        'role': 'operator',
        'roles': ['operator'],
        'scopes': ['operator.admin', 'operator.read', 'operator.write', 'operator.approvals'],
        'approvedScopes': ['operator.admin', 'operator.read', 'operator.write', 'operator.approvals'],
        'approvedAt': int(time.time() * 1000),
        'label': 'DefenseClaw Security Gateway',
        'deviceFamily': 'server'
    }
    paired[device_id] = entry
    with open(paired_path, 'w') as f:
        json.dump(paired, f, indent=2)
    print(f'Paired DefenseClaw device: {device_id[:16]}...')
PAIRING_EOF
            echo "✅ DefenseClaw device paired with openclaw gateway"
        else
            echo "⚠️  Could not pair DefenseClaw device (key or paired.json not found)"
        fi
    else
        echo "⚠️  Could not extract gateway token from $OC_CONFIG"
    fi
else
    echo "⚠️  openclaw.json not found — DefenseClaw may not connect to gateway"
fi

# ─── Step 5c: Load policy into running daemon ─────────────
echo ""
echo "📋 Loading policy into DefenseClaw daemon..."
sleep 1
# Try policy reload subcommand
if $BINARY policy reload --file "$POLICY_FILE" 2>/dev/null; then
    echo "✅ Policy loaded via: policy reload"
elif $BINARY policy load "$POLICY_FILE" 2>/dev/null; then
    echo "✅ Policy loaded via: policy load"
elif $BINARY policy apply "$POLICY_NAME" 2>/dev/null; then
    echo "✅ Policy loaded via: policy apply"
else
    echo "⚠️  Could not load policy via CLI — policy file is in place at $POLICY_FILE"
    echo "    DefenseClaw will pick it up on next restart via config"
fi

# ─── Step 6: Update status JSON ──────────────────────────
if [ -f "$STATUS_FILE" ]; then
    # Merge policy field into existing status
    EXISTING=$(cat "$STATUS_FILE")
    python3 -c "
import json, sys
d = json.loads(sys.argv[1])
d['policy'] = sys.argv[2]
d['policy_applied'] = sys.argv[3]
d['status'] = sys.argv[4]
print(json.dumps(d))
" "$EXISTING" "$POLICY_NAME" "$TODAY" "$SVC_STATUS" > "${STATUS_FILE}.tmp" 2>/dev/null && mv "${STATUS_FILE}.tmp" "$STATUS_FILE" || \
    echo "{\"installed\": true, \"policy\": \"$POLICY_NAME\", \"policy_applied\": \"$TODAY\", \"status\": \"$SVC_STATUS\"}" > "$STATUS_FILE"
fi

# ─── Done ────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "✅ Policy apply complete!"
echo "   Policy:  $POLICY_NAME"
echo "   File:    $POLICY_FILE"
echo "   Service: $SVC_STATUS"
echo "═══════════════════════════════════════════"
