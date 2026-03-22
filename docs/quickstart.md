# Quickstart — 5 Minutes to AI-Managed Server

Get CortexOS Server running on your Ubuntu machine in under 5 minutes.

---

## Prerequisites

- **Ubuntu 22.04+** (Server or Desktop)
- **2 GB RAM** minimum (4 GB+ recommended with Ollama)
- **10 GB disk** free
- **Root access** (or sudo)
- **Internet access** during install
- **AI provider API key** (Anthropic or OpenAI) — or use local Ollama

---

## Option A: Bare Metal Install (Recommended)

### 1. Run the installer

```bash
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh && sudo bash install.sh
```

The installer will:
- Install Node.js 22 via nvm
- Install and configure OpenClaw
- Install Ollama (optional — you can skip this)
- Deploy 11 server management skills
- Set up the web dashboard on port 8443
- Create a `cortex-server` systemd service

### 2. Set your API key

```bash
sudo -u cortex bash -c 'export ANTHROPIC_API_KEY="sk-ant-YOUR-KEY" && openclaw models auth'
sudo systemctl restart cortex-server
```

### 3. Open the dashboard

```
https://<your-server-ip>:8443
```

Log in with the access token shown at the end of installation.

### 4. Start talking to your server

Try these commands in the dashboard chat:
- "Run a full system health check"
- "Show me disk usage"
- "List all running Docker containers"
- "Check for security vulnerabilities"

---

## Option B: Docker Install

### 1. Run the one-liner

```bash
ANTHROPIC_API_KEY=sk-ant-YOUR-KEY bash <(curl -sSL https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/scripts/docker-install.sh)
```

### 2. Access the gateway

```
http://<your-server-ip>:18789
```

### 3. (Optional) Add Ollama

```bash
cd ~/cortexos
docker compose --profile local-ai up -d
```

---

## Option C: Docker Compose (Manual)

### 1. Clone the repo

```bash
git clone https://github.com/ivanuser/cortex-server-os.git
cd cortex-server-os
```

### 2. Create `.env`

```bash
cat > .env <<EOF
ANTHROPIC_API_KEY=sk-ant-YOUR-KEY
GATEWAY_TOKEN=auto
EOF
```

### 3. Build and run

```bash
docker compose up -d
```

---

## Verify It's Working

### Check service status (bare metal)

```bash
sudo systemctl status cortex-server
sudo journalctl -u cortex-server -f
```

### Check container status (Docker)

```bash
docker compose ps
docker compose logs -f cortexos
```

### Test the gateway

```bash
curl http://localhost:18789/health
```

Expected response: `{"status":"ok"}`

---

## Next Steps

- **[Configuration](configuration.md)** — Customize AI providers, ports, and features
- **[Skills](skills.md)** — Explore the 11 built-in skills
- **[Management Server](management-server.md)** — Set up multi-node fleet management
- **[Troubleshooting](troubleshooting.md)** — If something went wrong
