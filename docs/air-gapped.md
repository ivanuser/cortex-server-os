# Air-Gapped Deployment Guide

Deploy CortexOS Server in environments with no internet access.

---

## Overview

Air-gapped (offline) deployments require pre-packaging all dependencies on a connected machine, transferring them to the target, and installing locally. CortexOS supports this through offline bundles.

### What You Need

1. **A connected machine** — To download and package everything
2. **Transfer medium** — USB drive, local network share, or sneakernet
3. **Target machine** — Ubuntu 22.04+ with no internet

---

## Step 1: Build Offline Bundle (Connected Machine)

On a machine with internet access:

```bash
git clone https://github.com/ivanuser/cortex-server-os.git
cd cortex-server-os

# Build the complete offline bundle
bash scripts/build-offline-bundle.sh --all
```

This creates a tarball containing:

| Component | Size (approx.) | Contents |
|-----------|-----------------|----------|
| Node.js 22 | ~25 MB | Linux x64 binary |
| OpenClaw | ~50 MB | npm package + dependencies |
| Skills | ~2 MB | All 11 management skills |
| Dashboard | ~500 KB | Web UI |
| Installer | ~50 KB | Modified offline installer |
| Ollama (optional) | ~100 MB | Ollama binary (no models) |

### Bundle Options

```bash
# Full bundle (everything except Ollama models)
bash scripts/build-offline-bundle.sh --all

# Minimal (Node.js + OpenClaw + skills only)
bash scripts/build-offline-bundle.sh --minimal

# With a specific Ollama model
bash scripts/build-offline-bundle.sh --all --model llama3.1:7b
# Warning: Models can be 4-50+ GB
```

### Output

```
cortexos-offline-bundle-v0.1.0-linux-x64.tar.gz
```

---

## Step 2: Transfer

Copy the bundle to your air-gapped machine via:

- **USB drive:** `cp cortexos-offline-bundle-*.tar.gz /mnt/usb/`
- **SCP (if local network exists):** `scp cortexos-offline-bundle-*.tar.gz user@target:/tmp/`
- **NFS/SMB share:** Copy to shared mount point

---

## Step 3: Install (Air-Gapped Machine)

On the target machine with no internet:

```bash
# Extract the bundle
tar xzf cortexos-offline-bundle-*.tar.gz
cd cortexos-offline-bundle/

# Run the offline installer
sudo bash install-offline.sh
```

The offline installer:
1. Installs Node.js from the local binary
2. Installs OpenClaw from the local npm package
3. Deploys skills from the bundle
4. Sets up the dashboard and systemd service
5. (Optional) Installs Ollama from the local binary

### Offline Installer Options

```bash
# Standard install
sudo bash install-offline.sh

# Skip Ollama
sudo bash install-offline.sh --skip-ollama

# Unattended mode
sudo bash install-offline.sh --unattended

# Custom install directory
sudo bash install-offline.sh --install-dir /opt/cortexos
```

---

## Step 4: Configure AI Provider

In an air-gapped environment, you have two options:

### Option A: Local Ollama (Recommended for Air-Gap)

```bash
# If Ollama was included in the bundle:
ollama serve &

# If a model was bundled:
ollama create llama3.1 -f /var/lib/cortexos/models/llama3.1.Modelfile

# If you need to import a model from a file:
# Transfer the model blob and import it
ollama import llama3.1 /path/to/model-blob
```

### Option B: API Key (If Network Allows Outbound to API)

Some "air-gapped" environments allow specific outbound HTTPS connections:

```bash
# If api.anthropic.com is whitelisted:
sudo -u cortex bash -c 'export ANTHROPIC_API_KEY="sk-ant-..." && openclaw models auth'
sudo systemctl restart cortex-server
```

---

## Updating Air-Gapped Installations

### Build an Update Bundle

On a connected machine:

```bash
# Pull latest changes
cd cortex-server-os
git pull

# Build update-only bundle (smaller than full bundle)
bash scripts/build-offline-bundle.sh --update-only
```

### Apply the Update

On the air-gapped machine:

```bash
tar xzf cortexos-update-*.tar.gz
cd cortexos-update/
sudo bash apply-update.sh
```

---

## Skill Bundles

You can also create targeted skill bundles for specific use cases:

```bash
# Web server management skills
bash scripts/build-offline-bundle.sh --web-server

# Database management skills
bash scripts/build-offline-bundle.sh --database

# Full stack (web + database + monitoring)
bash scripts/build-offline-bundle.sh --full-stack
```

Install a skill bundle on an existing CortexOS instance:

```bash
tar xzf cortexos-skills-*.tar.gz -C /var/lib/cortexos/skills/
sudo systemctl restart cortex-server
```

---

## Verification

After offline installation, verify everything is working:

```bash
# Check service status
sudo systemctl status cortex-server

# Test gateway
curl http://localhost:18789/health

# Check skills are loaded
ls /var/lib/cortexos/skills/

# Test Ollama (if installed)
ollama list
curl http://localhost:11434/api/tags
```

---

## Troubleshooting

### "command not found: node"

Node.js wasn't installed correctly from the bundle:
```bash
export NVM_DIR="/root/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use 22
```

### "npm ERR! network"

The installer is trying to reach the internet. Make sure you're using the offline installer (`install-offline.sh`), not the regular one.

### Ollama model too large for USB

Large models (30B+) may not fit on a standard USB drive. Options:
- Use smaller models (7B fits on any USB)
- Split across multiple drives: `split -b 4G model.blob model-part-`
- Transfer via local network if available

### Dashboard can't reach gateway

Check nginx proxy configuration:
```bash
sudo nginx -t
sudo systemctl restart nginx
```

---

## Security Notes

1. **Verify bundle integrity** — Always verify checksums when transferring bundles
2. **Scan before transfer** — Run antivirus/malware scans on bundles before importing to secure environments
3. **Model provenance** — Ensure Ollama models come from trusted sources
4. **Audit the installer** — Review `install-offline.sh` before running on sensitive systems
