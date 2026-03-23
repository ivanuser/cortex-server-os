#!/bin/bash
# CortexOS Server Updater
# Downloads latest scripts and skills from GitHub

set -euo pipefail
REPO_BASE="https://raw.githubusercontent.com/ivanuser/cortex-server-os/main"

echo "🔄 CortexOS Update starting..."

# Update scripts
for script in cortexos-sysinfo.sh cortexos-compliance-scan.sh cortexos-skill-update.sh cortexos-notify.sh cortexos-update.sh; do
    target="/usr/local/bin/${script%.sh}"
    [ "$script" = "cortexos-skill-update.sh" ] && target="/usr/local/bin/cortexos-skill"
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

# Restart gateway
systemctl restart cortex-server 2>/dev/null || true

echo "✅ CortexOS Update complete!"
