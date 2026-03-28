#!/bin/bash
# CortexOS DefenseClaw Installer
# Installs Cisco AI DefenseClaw security governance on a CortexOS agent
# https://github.com/cisco-ai-defense/defenseclaw

set -euo pipefail

LOGFILE="/var/lib/cortexos/dashboard/defenseclaw-install.log"
STATUS_FILE="/var/lib/cortexos/dashboard/defenseclaw-status.json"
VENV_DIR="/var/lib/cortexos/defenseclaw-venv"
BINARY_TARGET="/usr/local/bin/defenseclaw-gateway"
SERVICE_FILE="/etc/systemd/system/cortexos-defenseclaw.service"
TODAY=$(date +%Y-%m-%d)

mkdir -p /var/lib/cortexos/dashboard

# Redirect all output to log
exec > >(tee -a "$LOGFILE") 2>&1

echo "═══════════════════════════════════════════"
echo "🛡️  CortexOS DefenseClaw Installer"
echo "    $(date)"
echo "═══════════════════════════════════════════"

write_status() {
    echo "$1" > "$STATUS_FILE"
}

fail_status() {
    local msg="$1"
    echo "❌ $msg"
    write_status "{\"installed\": false, \"error\": \"$msg\", \"updated\": \"$TODAY\"}"
    exit 1
}

# ─── Step 1: Detect architecture ─────────────────────────
echo ""
echo "📐 Detecting architecture..."
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        DL_ARCH="amd64"
        echo "  Architecture: x86_64 (amd64)"
        ;;
    aarch64|arm64)
        DL_ARCH="arm64"
        echo "  Architecture: $ARCH (arm64)"
        ;;
    *)
        fail_status "binary not available for arch: $ARCH"
        ;;
esac

# ─── Step 2: Download pre-built binary ───────────────────
echo ""
echo "📥 Downloading DefenseClaw gateway binary..."
RELEASE_URL="https://github.com/cisco-ai-defense/defenseclaw/releases/latest/download/defenseclaw-gateway-linux-${DL_ARCH}"

if curl -sfL --connect-timeout 15 --max-time 120 "$RELEASE_URL" -o /tmp/defenseclaw-gateway 2>/dev/null; then
    chmod +x /tmp/defenseclaw-gateway
    mv /tmp/defenseclaw-gateway "$BINARY_TARGET"
    echo "  ✅ Binary installed to $BINARY_TARGET"
    BINARY_INSTALLED=true
else
    echo "  ⚠️  Pre-built binary not available, will rely on Python CLI only"
    BINARY_INSTALLED=false
fi

# ─── Step 3: Install Python CLI ──────────────────────────
echo ""
echo "🐍 Installing DefenseClaw Python CLI..."
CLI_INSTALLED=false
CLI_PATH="defenseclaw"

# Try system-wide first
if python3 -m pip install defenseclaw --break-system-packages 2>/dev/null; then
    echo "  ✅ Python CLI installed system-wide"
    CLI_INSTALLED=true
    CLI_PATH="defenseclaw"
else
    echo "  ⚠️  System-wide install failed, trying venv..."
    # Create a venv
    mkdir -p "$VENV_DIR"
    if python3 -m venv "$VENV_DIR" 2>/dev/null; then
        if "$VENV_DIR/bin/pip" install defenseclaw 2>/dev/null; then
            echo "  ✅ Python CLI installed in venv: $VENV_DIR"
            CLI_INSTALLED=true
            CLI_PATH="$VENV_DIR/bin/defenseclaw"
        else
            echo "  ⚠️  Venv pip install failed"
        fi
    else
        echo "  ⚠️  Could not create venv"
    fi
fi

# If neither binary nor CLI installed, fail
if [ "$BINARY_INSTALLED" = false ] && [ "$CLI_INSTALLED" = false ]; then
    fail_status "could not install binary or Python CLI"
fi

# ─── Step 4: Get version ─────────────────────────────────
echo ""
echo "🔍 Detecting installed version..."
DC_VERSION="unknown"
if [ "$BINARY_INSTALLED" = true ] && "$BINARY_TARGET" --version 2>/dev/null; then
    DC_VERSION=$("$BINARY_TARGET" --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1 || echo "unknown")
elif [ "$CLI_INSTALLED" = true ]; then
    DC_VERSION=$("$CLI_PATH" --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1 || echo "unknown")
fi
[ "$DC_VERSION" = "" ] && DC_VERSION="unknown"
echo "  Version: $DC_VERSION"

# ─── Step 5: Initialize DefenseClaw ──────────────────────
echo ""
echo "⚙️  Initializing DefenseClaw..."
if [ "$CLI_INSTALLED" = true ]; then
    $CLI_PATH init --enable-guardrail 2>/dev/null || echo "  ⚠️  Init returned non-zero (may already be initialized)"
    echo "  ✅ DefenseClaw initialized"
else
    echo "  ⚠️  Skipping init — Python CLI not available"
fi

# ─── Step 6: Create systemd service ──────────────────────
echo ""
echo "📝 Creating systemd service..."

if [ "$BINARY_INSTALLED" = true ]; then
    EXEC_START="$BINARY_TARGET serve"
else
    EXEC_START="$CLI_PATH serve"
fi

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=CortexOS DefenseClaw Security Gateway
After=network.target
Documentation=https://github.com/cisco-ai-defense/defenseclaw

[Service]
Type=simple
ExecStart=$EXEC_START
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=defenseclaw
Environment=HOME=/var/lib/cortexos

[Install]
WantedBy=multi-user.target
EOF

echo "  ✅ Service file created: $SERVICE_FILE"

# ─── Step 7: Enable and start ────────────────────────────
echo ""
echo "🚀 Enabling and starting DefenseClaw service..."
systemctl daemon-reload
systemctl enable cortexos-defenseclaw 2>/dev/null || true

if systemctl start cortexos-defenseclaw 2>/dev/null; then
    echo "  ✅ Service started successfully"
    SVC_STATUS="running"
else
    echo "  ⚠️  Service failed to start (check journalctl -u cortexos-defenseclaw)"
    SVC_STATUS="installed-not-running"
fi

# ─── Step 8: Write status JSON ───────────────────────────
echo ""
echo "📊 Writing status..."
write_status "{\"installed\": true, \"version\": \"$DC_VERSION\", \"status\": \"$SVC_STATUS\", \"binary\": $BINARY_INSTALLED, \"cli\": $CLI_INSTALLED, \"updated\": \"$TODAY\"}"
echo "  ✅ Status written to $STATUS_FILE"

# ─── Done ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "✅ DefenseClaw installation complete!"
echo "   Binary: $BINARY_INSTALLED"
echo "   CLI:    $CLI_INSTALLED"
echo "   Status: $SVC_STATUS"
echo "═══════════════════════════════════════════"
