#!/bin/bash
# CortexOS Server Updater
# Downloads latest scripts and skills from GitHub

set -euo pipefail
REPO_BASE="https://raw.githubusercontent.com/ivanuser/cortex-server-os/main"

echo "🔄 CortexOS Update starting..."

# Update scripts
for script in cortexos-sysinfo.sh cortexos-compliance-scan.sh cortexos-skill-update.sh cortexos-notify.sh cortexos-update.sh cortexos-memory-export.sh cortexos-defenseclaw.sh cortexos-policy-apply.sh cortexos-defenseclaw-export.sh; do
    target="/usr/local/bin/${script%.sh}"
    [ "$script" = "cortexos-skill-update.sh" ] && target="/usr/local/bin/cortexos-skill"
    [ "$script" = "cortexos-memory-export.sh" ] && target="/usr/local/bin/cortexos-memory-export"
    [ "$script" = "cortexos-defenseclaw.sh" ] && target="/usr/local/bin/cortexos-defenseclaw"
    [ "$script" = "cortexos-policy-apply.sh" ] && target="/usr/local/bin/cortexos-policy-apply"
    [ "$script" = "cortexos-defenseclaw-export.sh" ] && target="/usr/local/bin/cortexos-defenseclaw-export"
    curl -sfL "$REPO_BASE/scripts/$script" -o "$target" 2>/dev/null && chmod +x "$target" && echo "  ✅ $target" || echo "  ⚠️ $target (failed)"
done

# Update skills
/usr/local/bin/cortexos-skill update 2>/dev/null || true

# Update dashboard
curl -sfL "$REPO_BASE/dashboard/index.html" -o /var/lib/cortexos/dashboard/index.html 2>/dev/null && echo "  ✅ dashboard" || true
curl -sfL "$REPO_BASE/dashboard/logo.png" -o /var/lib/cortexos/dashboard/logo.png 2>/dev/null || true

# Update version file
curl -sfL "$REPO_BASE/scripts/cortexos-version.json" -o /var/lib/cortexos/version.json 2>/dev/null || true
cp /var/lib/cortexos/version.json /var/lib/cortexos/dashboard/version.json 2>/dev/null || true

# Push workspace files (MANAGEMENT_TRUST.md etc.)
WORKSPACE_DIR=""
for d in /root/.openclaw/workspace /home/cortex/.openclaw/workspace; do
    [ -d "$d" ] && WORKSPACE_DIR="$d" && break
done
if [ -n "$WORKSPACE_DIR" ]; then
    curl -sfL "$REPO_BASE/workspace/MANAGEMENT_TRUST.md" -o "$WORKSPACE_DIR/MANAGEMENT_TRUST.md" 2>/dev/null && \
        echo "  ✅ MANAGEMENT_TRUST.md → $WORKSPACE_DIR" || \
        echo "  ⚠️ Could not push MANAGEMENT_TRUST.md"
fi

# Regenerate sysinfo
/usr/local/bin/cortexos-sysinfo 2>/dev/null || true

# Run memory export
/usr/local/bin/cortexos-memory-export 2>/dev/null || true

# Set up memory export cron (every 30 min) if not already scheduled
if ! crontab -l 2>/dev/null | grep -q cortexos-memory-export; then
    TMPCRON=$(mktemp)
    crontab -l 2>/dev/null > "$TMPCRON" || true
    echo "*/30 * * * * /usr/local/bin/cortexos-memory-export 2>/dev/null" >> "$TMPCRON"
    crontab "$TMPCRON"
    rm -f "$TMPCRON"
    echo "  ✅ Memory export cron scheduled (every 30 min)"
fi

# Set up defenseclaw export cron (every 5 min) if not already scheduled
if ! crontab -l 2>/dev/null | grep -q cortexos-defenseclaw-export; then
    TMPCRON=$(mktemp)
    crontab -l 2>/dev/null > "$TMPCRON" || true
    echo "*/5 * * * * /usr/local/bin/cortexos-defenseclaw-export 2>/dev/null" >> "$TMPCRON"
    crontab "$TMPCRON"
    rm -f "$TMPCRON"
    echo "  ✅ DefenseClaw export cron scheduled (every 5 min)"
fi

# Run defenseclaw export now if installed
if [ -f /usr/local/bin/cortexos-defenseclaw-export ]; then
    /usr/local/bin/cortexos-defenseclaw-export 2>/dev/null || true
fi

# Install DefenseClaw if not already installed
if [ ! -f /var/lib/cortexos/dashboard/defenseclaw-status.json ] || \
   python3 -c "import json; d=json.load(open('/var/lib/cortexos/dashboard/defenseclaw-status.json')); exit(0 if d.get('installed') else 1)" 2>/dev/null; then
    echo "  ⏭️ DefenseClaw already installed"
else
    echo "  🛡️ Installing DefenseClaw..."
    /usr/local/bin/cortexos-defenseclaw 2>&1 | tail -5 || echo "  ⚠️ DefenseClaw install failed (will retry on next update)"
fi

# Ensure mgmt-token directory exists
mkdir -p /var/lib/cortexos 2>/dev/null || true

# If management token config doesn't exist, create a placeholder
if [ ! -f /var/lib/cortexos/mgmt-token.conf ]; then
    cat > /var/lib/cortexos/mgmt-token.conf << 'EOF'
# CortexOS Management Trust Token
# This file is auto-populated when the management server pushes a trust token.
# DO NOT edit manually — use the management dashboard to manage tokens.
MGMT_TOKEN=
MGMT_SERVER=
MGMT_AUTHORIZED=false
EOF
    echo "  ✅ mgmt-token.conf placeholder created"
fi

# Restart gateway
systemctl restart cortex-server 2>/dev/null || true

echo "✅ CortexOS Update complete!"
