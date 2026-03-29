#!/bin/bash
# CortexOS Server Updater
# Downloads latest scripts and skills from GitHub

set -euo pipefail
REPO_BASE="https://raw.githubusercontent.com/ivanuser/cortex-server-os/main"

echo "🔄 CortexOS Update starting..."

# Update scripts
for script in cortexos-sysinfo.sh cortexos-compliance-scan.sh cortexos-skill-update.sh cortexos-notify.sh cortexos-update.sh cortexos-memory-export.sh cortexos-defenseclaw.sh; do
    target="/usr/local/bin/${script%.sh}"
    [ "$script" = "cortexos-skill-update.sh" ] && target="/usr/local/bin/cortexos-skill"
    [ "$script" = "cortexos-memory-export.sh" ] && target="/usr/local/bin/cortexos-memory-export"
    [ "$script" = "cortexos-defenseclaw.sh" ] && target="/usr/local/bin/cortexos-defenseclaw"
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

# Install DefenseClaw if not already installed
if [ ! -f /var/lib/cortexos/dashboard/defenseclaw-status.json ] || \
   python3 -c "import json; d=json.load(open('/var/lib/cortexos/dashboard/defenseclaw-status.json')); exit(0 if d.get('installed') else 1)" 2>/dev/null; then
    echo "  ⏭️ DefenseClaw already installed"
else
    echo "  🛡️ Installing DefenseClaw..."
    /usr/local/bin/cortexos-defenseclaw 2>&1 | tail -5 || echo "  ⚠️ DefenseClaw install failed (will retry on next update)"
fi

# Restart gateway
systemctl restart cortex-server 2>/dev/null || true

echo "✅ CortexOS Update complete!"
