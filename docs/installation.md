# Installation Guide

Three ways to deploy CortexOS Server, from simplest to most flexible.

---

## Method 1: Bare Metal Install

Best for dedicated servers where you want full system integration (systemd, nginx dashboard, Ollama).

### Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Ubuntu 22.04+ | Ubuntu 24.04 LTS |
| RAM | 2 GB | 8 GB (with Ollama) |
| Disk | 10 GB | 50 GB (for models) |
| CPU | 1 core | 4+ cores |
| GPU | — | NVIDIA (for local AI) |

### Install

```bash
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh && sudo bash install.sh
```

### Unattended Install

For automation and scripting:

```bash
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh
sudo bash install.sh --unattended
```

The installer automatically runs unattended when piped:

```bash
curl -sSL https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh | sudo bash
```

### What Gets Installed

| Component | Location | Purpose |
|-----------|----------|---------|
| Node.js 22 | `/root/.nvm/` | JavaScript runtime |
| OpenClaw | Global npm | AI gateway |
| Ollama | `/usr/local/bin/ollama` | Local AI inference |
| Skills | `/var/lib/cortexos/skills/` | Management modules |
| Dashboard | `/var/lib/cortexos/dashboard/` | Web UI |
| Config | `/etc/cortexos/` | Server configuration |
| Data | `/var/lib/cortexos/` | Persistent data |
| Logs | `/var/log/cortex-server/` | Service logs |
| Service | `cortex-server.service` | systemd unit |

### Post-Install

1. **Set your AI provider API key:**
   ```bash
   sudo -u cortex bash -c 'export ANTHROPIC_API_KEY="sk-ant-..." && openclaw models auth'
   sudo systemctl restart cortex-server
   ```

2. **Access the dashboard:**
   ```
   https://<server-ip>:8443
   ```

3. **Pull an Ollama model (optional):**
   ```bash
   ollama pull llama3.1
   ```

---

## Method 2: Docker

Best for quick deployments, testing, and environments where you don't want system-level changes.

### Requirements

- Docker Engine 24+
- Docker Compose v2
- An AI provider API key

### Quick Install

```bash
ANTHROPIC_API_KEY=sk-ant-... bash <(curl -sSL https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/scripts/docker-install.sh)
```

### Manual Docker Setup

```bash
# Clone
git clone https://github.com/ivanuser/cortex-server-os.git
cd cortex-server-os

# Configure
cat > .env <<EOF
ANTHROPIC_API_KEY=sk-ant-YOUR-KEY
GATEWAY_TOKEN=auto
EOF

# Build and run
docker compose up -d

# (Optional) Add Ollama sidecar
docker compose --profile local-ai up -d

# (Optional) Ollama with GPU
docker compose --profile local-ai-gpu up -d
```

### Docker Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `cortexos-data` | `/root/.openclaw` | Gateway config & state |
| `cortexos-logs` | `/var/log/cortex-server` | Application logs |
| `cortexos-ollama-data` | `/root/.ollama` | Ollama models (if enabled) |

### Management Commands

```bash
# View logs
docker compose logs -f cortexos

# Restart
docker compose restart cortexos

# Stop everything
docker compose down

# Rebuild after updates
git pull
docker compose build --no-cache
docker compose up -d
```

---

## Method 3: Management Server + Fleet

Best for managing multiple CortexOS nodes from a central dashboard.

### Architecture

```
┌──────────────────────┐
│  Management Server   │  ← Central control (port 9443)
│  (cortex-management) │
└──────┬───────────────┘
       │
       ├──── CortexOS Node 1 (port 18789)
       ├──── CortexOS Node 2 (port 18789)
       └──── CortexOS Node N (port 18789)
```

### 1. Deploy the Management Server

```bash
git clone https://github.com/ivanuser/cortex-management-server.git
cd cortex-management-server
npm install
npm start
```

Or with Docker:

```bash
cd cortex-management-server
docker compose up -d
```

### 2. Deploy CortexOS Nodes

On each server you want to manage:

```bash
MGMT_URL=https://management-server:9443 \
MGMT_TOKEN=your-enroll-token \
curl -sSL https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh | sudo bash
```

The node will auto-register with the management server.

### 3. Access the Fleet Dashboard

```
http://management-server:9443
```

See [Management Server Guide](management-server.md) for full details.

---

## Upgrading

### Bare Metal

```bash
# Re-run the installer — it detects existing installations
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh && sudo bash install.sh
```

### Docker

```bash
cd ~/cortexos  # or wherever you cloned
git pull
docker compose build --no-cache
docker compose up -d
```

---

## Uninstalling

### Bare Metal

```bash
sudo systemctl stop cortex-server
sudo systemctl disable cortex-server
sudo rm /etc/systemd/system/cortex-server.service
sudo systemctl daemon-reload
sudo userdel -r cortex 2>/dev/null
sudo rm -rf /var/lib/cortexos /etc/cortexos /var/log/cortex-server
```

### Docker

```bash
cd ~/cortexos
docker compose down -v  # -v removes volumes too
rm -rf ~/cortexos
```
