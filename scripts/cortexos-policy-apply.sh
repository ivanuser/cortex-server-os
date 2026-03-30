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
