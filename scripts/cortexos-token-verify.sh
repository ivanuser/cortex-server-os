#!/bin/bash
# CortexOS Token Verify
# Verifies a CORTEX-MGMT-v1 token prefix against stored token
# Usage: cortexos-token-verify "[CORTEX-MGMT-v1 token=abc123 ts=1234567890]"
# Exit 0 = valid, Exit 1 = invalid

set -euo pipefail

TOKEN_CONF="/var/lib/cortexos/mgmt-token.conf"
LOG_FILE="/var/lib/cortexos/dashboard/token-verify.log"

PREFIX="${1:-}"

if [ -z "$PREFIX" ]; then
    echo "Usage: cortexos-token-verify '<prefix>'"
    exit 1
fi

# Extract token from prefix
INCOMING_TOKEN=$(echo "$PREFIX" | grep -oP 'token=\K[a-f0-9]+' || echo "")
INCOMING_TS=$(echo "$PREFIX" | grep -oP 'ts=\K[0-9]+' || echo "")

if [ -z "$INCOMING_TOKEN" ]; then
    echo "REJECT: no token in prefix"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) REJECT no_token prefix='$PREFIX'" >> "$LOG_FILE"
    exit 1
fi

# Load stored token
if [ ! -f "$TOKEN_CONF" ]; then
    echo "REJECT: no token config"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) REJECT no_config incoming=$INCOMING_TOKEN" >> "$LOG_FILE"
    exit 1
fi

source "$TOKEN_CONF" 2>/dev/null || true

if [ -z "${MGMT_TOKEN:-}" ]; then
    echo "REJECT: stored token is empty"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) REJECT empty_stored incoming=$INCOMING_TOKEN" >> "$LOG_FILE"
    exit 1
fi

# Compare first 16 chars (management server sends truncated token in prefix)
STORED_PREFIX="${MGMT_TOKEN:0:16}"
INCOMING_PREFIX="${INCOMING_TOKEN:0:16}"

if [ "$STORED_PREFIX" = "$INCOMING_PREFIX" ]; then
    echo "ACCEPT: token verified"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ACCEPT token=${INCOMING_PREFIX}... ts=$INCOMING_TS" >> "$LOG_FILE"
    exit 0
else
    echo "REJECT: token mismatch"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) REJECT mismatch incoming=${INCOMING_PREFIX}... stored=${STORED_PREFIX}..." >> "$LOG_FILE"
    exit 1
fi
