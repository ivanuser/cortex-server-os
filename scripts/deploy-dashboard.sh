#!/bin/bash
# Deploy CortexOS dashboard to test server
# Auto-bumps version and adds build timestamp

set -euo pipefail

DASHBOARD="/home/ihoner/projects/cortex-server-os/dashboard/index.html"
SERVER="192.168.1.249"
SERVER_USER="ihoner"
SERVER_PASS="soccer"

# Auto-bump patch version
CURRENT_VERSION=$(grep -oP 'v\d+\.\d+\.\d+' "$DASHBOARD" | head -1)
if [ -n "$CURRENT_VERSION" ]; then
    MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1 | tr -d 'v')
    MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
    PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="v${MAJOR}.${MINOR}.${NEW_PATCH}"
    sed -i "s/$CURRENT_VERSION/$NEW_VERSION/" "$DASHBOARD"
    echo "Version: $CURRENT_VERSION → $NEW_VERSION"
else
    NEW_VERSION="v0.0.1"
    echo "No version found, starting at $NEW_VERSION"
fi

# Add build timestamp
BUILD_TIME=$(date -u +"%Y-%m-%d %H:%M UTC")
# Update or add build time comment at top of file
if grep -q 'data-build=' "$DASHBOARD"; then
    sed -i "s/data-build=\"[^\"]*\"/data-build=\"$BUILD_TIME\"/" "$DASHBOARD"
else
    sed -i "s/<html /<html data-build=\"$BUILD_TIME\" /" "$DASHBOARD"
fi

echo "Build: $BUILD_TIME"

# Deploy
sshpass -p "$SERVER_PASS" scp -o StrictHostKeyChecking=no "$DASHBOARD" "$SERVER_USER@$SERVER:/tmp/index.html"
sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER" \
    "echo $SERVER_PASS | sudo -S bash -c 'cp /tmp/index.html /var/lib/cortexos/dashboard/index.html'"

echo "✅ Deployed $NEW_VERSION ($BUILD_TIME) to $SERVER"
