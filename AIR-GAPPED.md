# CortexOS Server — Air-Gapped / Classified Deployment

## Overview

For servers with no internet access (classified networks, air-gapped environments, secure facilities), CortexOS Server needs a fully offline deployment path.

## Key Requirements

1. **Zero network calls** — no npm, no GitHub, no API endpoints during install
2. **Local AI only** — Ollama with bundled models, no cloud providers
3. **Skill bundles** — all skills pre-packaged, no downloads
4. **No telemetry** — no update checks, no phone-home, no analytics
5. **STIG/CMMC compliance** — hardened by default

## Offline Installer Package

### Build (on connected machine)
```bash
# Run on a machine with internet access
./build-offline-package.sh

# Creates: cortexos-server-offline-v0.1.0.tar.gz (~500MB)
# Contains:
#   - install.sh (modified for offline mode)
#   - node-v22.x-linux-x64.tar.xz
#   - openclaw-cortex-2026.3.18.tgz (npm pack)
#   - ollama binary
#   - AI models (llama3.1:8b, nomic-embed-text)
#   - All skills (core + extended)
#   - Dashboard files
#   - Workspace templates
```

### Install (on air-gapped machine)
```bash
# Transfer via USB/SCP
# Extract and install
tar xzf cortexos-server-offline-v0.1.0.tar.gz
cd cortexos-server-offline
sudo bash install.sh --offline
```

### build-offline-package.sh
```bash
#!/bin/bash
# Build offline CortexOS package
set -euo pipefail

VERSION="0.1.0"
BUILD_DIR="cortexos-server-offline"
NODE_VERSION="22"

mkdir -p "$BUILD_DIR"/{bin,npm,models,skills,dashboard,workspace}

# 1. Node.js binary
echo "Downloading Node.js..."
curl -sLO "https://nodejs.org/dist/latest-v${NODE_VERSION}.x/node-v${NODE_VERSION}*-linux-x64.tar.xz"
mv node-*-linux-x64.tar.xz "$BUILD_DIR/bin/"

# 2. OpenClaw package
echo "Downloading OpenClaw..."
npm pack openclaw-cortex --pack-destination "$BUILD_DIR/npm/"

# 3. Ollama binary
echo "Downloading Ollama..."
curl -sL "https://ollama.com/download/ollama-linux-amd64" -o "$BUILD_DIR/bin/ollama"
chmod +x "$BUILD_DIR/bin/ollama"

# 4. AI Models (pull then export)
echo "Downloading models..."
ollama pull llama3.1:8b
ollama pull nomic-embed-text
# Export model blobs
cp -r ~/.ollama/models "$BUILD_DIR/models/"

# 5. Skills
echo "Packaging skills..."
cp -r ../cortex-server-os/skills/* "$BUILD_DIR/skills/"
cp -r ../cortex-server-skills/server/* "$BUILD_DIR/skills/"
cp -r ../cortex-server-skills/apps/* "$BUILD_DIR/skills/"
cp -r ../cortex-server-skills/infra/* "$BUILD_DIR/skills/"

# 6. Dashboard
cp -r ../cortex-server-os/dashboard/* "$BUILD_DIR/dashboard/"

# 7. Workspace templates
cp -r ../cortex-server-os/workspace/* "$BUILD_DIR/workspace/"

# 8. Offline installer
cp ../cortex-server-os/install.sh "$BUILD_DIR/install.sh"

# 9. Package it
echo "Creating archive..."
tar czf "cortexos-server-offline-v${VERSION}.tar.gz" "$BUILD_DIR"
echo "Done: cortexos-server-offline-v${VERSION}.tar.gz ($(du -h cortexos-server-offline-v${VERSION}.tar.gz | awk '{print $1}'))"
```

## Offline Mode Changes to install.sh

When `--offline` flag is used:
- Skip all `curl`/`wget` downloads
- Install Node.js from local tarball
- Install OpenClaw from local .tgz (`npm install -g ./npm/openclaw-cortex-*.tgz`)
- Install Ollama from local binary
- Load models from local blob directory
- Copy skills from local directory
- Skip update checks
- Set `gateway.updateCheck.enabled: false` in config

## AI Provider for Air-Gapped

Without internet, cloud AI providers won't work. Options:

1. **Ollama (bundled)** — llama3.1:8b runs on CPU, slow but works
   - Config: `agents.defaults.model.primary: "ollama/llama3.1:8b"`
2. **Local GPU server** — if a GPU box is available on the isolated network
   - Point Ollama to the GPU server: `OLLAMA_HOST=http://gpu-server:11434`
3. **vLLM / llama.cpp** — alternative inference servers on the network

## Security Hardening for Classified

Additional hardening for classified environments:
- Disable all external network calls (update checks, telemetry)
- FIPS-compliant crypto if required
- Audit logging enabled by default
- STIG-compliant SSH config
- SELinux/AppArmor profiles
- Classification banner in dashboard (configurable)
- Session timeout (auto-disconnect after inactivity)

## Status

- [ ] build-offline-package.sh script
- [ ] Offline mode in install.sh
- [ ] Bundled Ollama models
- [ ] Classification banner in dashboard
- [ ] STIG hardening profile
- [ ] Session timeout
- [ ] Testing on disconnected VM
