<![CDATA[<div align="center">

# CortexOS Server

**AI-powered server management in one install.**

<!-- badges -->
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.2.7-green.svg)](ROADMAP.md)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)](docker-compose.yml)

Turn any Ubuntu server into an AI-managed infrastructure node in under 5 minutes.
CortexOS installs [OpenClaw](https://github.com/anthropics/openclaw) with purpose-built server management skills,
[Ollama](https://ollama.com) for local AI inference, and a real-time web dashboard —
giving you conversational control over your entire server from day one.

<!-- ![CortexOS Dashboard](branding/screenshot.png) -->

</div>

---

## One-Liner Install

### Bare Metal (Ubuntu)

```bash
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh && sudo bash install.sh
```

### Docker

```bash
docker compose up -d                         # Cloud AI provider
docker compose --profile local-ai up -d      # With Ollama (CPU)
docker compose --profile local-ai-gpu up -d  # With Ollama (NVIDIA GPU)
```

> **Want to review first?** `wget` the installer, read it, then run it:
> ```bash
> wget https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh
> less install.sh
> sudo bash install.sh
> ```

---

## What It Does

CortexOS wraps a full AI agent around your server. You talk to it in natural language — through the web dashboard, chat, or terminal panel — and it manages packages, containers, firewalls, backups, users, networking, and more using specialized skill packs.

It's not a monitoring dashboard with a chatbot bolted on. The AI is the primary interface; the dashboard visualizes what the AI already knows.

---

## Features

| Category | What You Get |
|----------|--------------|
| 🤖 **AI-First Management** | Manage your server through natural language — chat or terminal |
| 🌐 **Web Dashboard** | Real-time UI with chat, system stats, quick commands (port 8443) |
| 🧠 **12 Core Skills** | Docker, systemd, security, networking, storage, monitoring, and more |
| 📦 **35+ Extended Skills** | Databases, web servers, CI/CD, cloud CLIs, runtimes, Kubernetes |
| 💻 **Terminal Panel** | Run commands through the AI with full history |
| 💬 **Chat Interface** | Streaming responses, markdown rendering, code syntax highlighting |
| 📎 **File Upload** | Click, drag-drop, or paste — images preview inline |
| 🎨 **Syntax Highlighting** | Keywords, strings, comments highlighted + one-click copy |
| 📊 **System Stats** | Live CPU, RAM, disk, network — polled every 10 seconds |
| 👤 **Agent Profile** | Custom avatar, personality, skills display, settings |
| 🔄 **Auto-Reconnect** | 3-second reconnect with visual indicator — never lose the session |
| 📱 **Mobile Responsive** | Hamburger menu, sidebar overlay — works on any screen |
| ⌨️ **Keyboard Shortcuts** | Ctrl+1–8 for quick commands |
| 🧩 **Skills Management UI** | Browse, install, and manage skills from the dashboard |
| 🦙 **Local AI (Ollama)** | Run models locally for privacy — no cloud calls needed |

---

## Requirements

| Component | Minimum |
|-----------|---------|
| **OS** | Ubuntu 22.04+ (Server or Desktop) |
| **RAM** | 2 GB (4 GB+ recommended for local AI) |
| **Disk** | 10 GB free |
| **CPU** | 2+ cores recommended |
| **Network** | Internet access during install (or use [air-gapped mode](#air-gapped--offline-deployment)) |

---

## Install Options

### 1. Bare Metal (recommended)

```bash
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh && sudo bash install.sh
```

The installer handles everything: Node.js, OpenClaw, Ollama, skills, dashboard, systemd service, SSL cert, firewall rules.

### 2. Docker

```bash
git clone https://github.com/ivanuser/cortex-server-os.git
cd cortex-server-os

# Set your API key
export ANTHROPIC_API_KEY="sk-ant-..."

# Start
docker compose up -d
```

Access at `http://localhost:18789`. Add `--profile local-ai` for Ollama sidecar, or `--profile local-ai-gpu` for NVIDIA GPU support.

### 3. Via Management Server

For fleet deployments, the [Management Server](https://github.com/ivanuser/cortex-management-server) generates install tokens:

```bash
curl -sO https://mgmt.example.com/install.sh?token=ctx_srv_XXXXX && sudo bash install.sh
```

The server auto-registers with the management dashboard and starts reporting health within 30 seconds. See [cortex-management-server](https://github.com/ivanuser/cortex-management-server) for details.

---

<!-- ## Dashboard Screenshots

> Screenshots coming soon — the dashboard includes chat, system stats sidebar, skills grid, terminal panel, and agent profile.

--- -->

## Skills

### Core Skills (12 — bundled with installer)

| Skill | Description |
|-------|-------------|
| 📊 **monitoring** | System health monitoring & alerting |
| 🖥️ **server-monitor** | Real-time server resource tracking |
| 🐳 **docker-manager** | Container lifecycle, compose, images |
| ⚙️ **systemd-manager** | Service management, journalctl, timers |
| 🔒 **security-hardening** | CIS benchmarks, fail2ban, SSH hardening |
| 🌐 **network-manager** | Interfaces, DNS, routing, diagnostics |
| 💾 **storage-manager** | Disks, mounts, LVM, SMART health |
| 📦 **package-manager** | apt operations, updates, cleanup |
| 👤 **user-manager** | Users, groups, sudo, SSH keys |
| 🛡️ **firewall-manager** | UFW / iptables rules and policies |
| 💿 **backup-manager** | Scheduled backups, verify, restore |
| ☁️ **cloudflare** | Tunnel installation + operations & routing |

Skills are installed to `/var/lib/cortexos/skills/` and can be customized or extended.

### Extended Skills (35 — install from dashboard or CLI)

Install individually via the dashboard Skills page or the `cortexos-skill` CLI:

| Category | Skills |
|----------|--------|
| **Server** | nginx, apache, postgres, mysql, redis, mongodb, sqlite, cassandra, elasticsearch, rabbitmq, memcached, caddy, haproxy, wireguard, cloudflare |
| **Apps** | nextcloud, discourse |
| **Infrastructure** | kubernetes, docker-compose, jenkins, ansible, terraform, certbot, gitlab-runner, grafana, prometheus |
| **Cloud** | aws-cli, gcloud, azure-cli |
| **Runtime** | nodejs, python, golang, java, rust |

Full list and docs: [cortex-server-skills](https://github.com/ivanuser/cortex-server-skills)

---

## Configuration

### API Key Setup

CortexOS works with cloud AI providers or local models. Configure during install or anytime after:

**Option 1: Anthropic (Claude)**
```bash
sudo -u cortex bash -c 'export ANTHROPIC_API_KEY="sk-ant-..." && openclaw models auth'
sudo systemctl restart cortex-server
```

**Option 2: OpenAI**
```bash
sudo -u cortex bash -c 'export OPENAI_API_KEY="sk-..." && openclaw models auth'
sudo systemctl restart cortex-server
```

**Option 3: Local Ollama (installed automatically)**
```bash
ollama pull llama3.1
# Configure in dashboard settings or openclaw.json
```

**Option 4: Claude Setup Token**
```bash
# On a machine with Claude CLI:
claude setup-token
# On the CortexOS server:
openclaw models auth paste-token --provider anthropic
sudo systemctl restart cortex-server
```

### Service Management

```bash
sudo systemctl status cortex-server     # Check status
sudo journalctl -u cortex-server -f     # View logs
sudo systemctl restart cortex-server    # Restart
```

### Dashboard Access

After installation, open your browser:

```
https://<server-ip>:8443
```

Log in with the access token shown at the end of installation. The AI agent introduces itself, runs an initial health check, and you're ready to go.

**Quick commands in the sidebar:** System Health, Security Audit, Services, Updates, Disk Usage, Network, Docker, Firewall, Auth Logs, Backups.

---

## Air-Gapped / Offline Deployment

CortexOS supports fully disconnected environments — classified networks, air-gapped facilities, secure enclaves.

### Build offline package (on a connected machine)

```bash
./scripts/build-offline-bundle.sh
# Creates: cortexos-server-offline-v0.x.x.tar.gz (~500MB)
# Contains: installer, Node.js, OpenClaw, Ollama, AI models, all skills, dashboard
```

### Install (on the air-gapped machine)

```bash
tar xzf cortexos-server-offline-v0.x.x.tar.gz
cd cortexos-server-offline
sudo bash install.sh --offline
```

**What's included:** Node.js runtime, OpenClaw agent, Ollama + bundled models (llama3.1:8b, nomic-embed-text), all core + extended skills, dashboard files, workspace templates.

**Zero network calls** — no npm, no GitHub, no cloud APIs during install or operation. Local AI only.

See [AIR-GAPPED.md](AIR-GAPPED.md) for full details.

---

## Docker Quick Start

```bash
# Clone
git clone https://github.com/ivanuser/cortex-server-os.git
cd cortex-server-os

# Cloud AI (Anthropic)
ANTHROPIC_API_KEY=sk-ant-... docker compose up -d

# Local AI with Ollama (CPU)
docker compose --profile local-ai up -d

# Local AI with Ollama (NVIDIA GPU)
docker compose --profile local-ai-gpu up -d
```

| Container | Port | Purpose |
|-----------|------|---------|
| `cortexos` | 18789 | Gateway + Dashboard |
| `cortexos-ollama` | 11434 | Local AI inference (optional) |

**Volumes:** `cortexos-data` (config), `cortexos-logs` (logs), `cortexos-ollama-data` (models).

Health check runs every 30s against `/health`.

---

## Management Server

For managing multiple CortexOS nodes from a single dashboard, see the **[Cortex Management Server](https://github.com/ivanuser/cortex-management-server)**.

Features: fleet dashboard, embedded server management (chat + skills + terminal), auth with 2FA, server templates, install tokens, health monitoring, incident response, scheduled operations, webhooks, centralized backups, analytics, and audit logging.

**Workflow:**
1. Generate install token in management dashboard
2. Run installer with `--management-url` and `--token` on target server
3. Server auto-registers and appears in fleet dashboard within 30 seconds

---

## Project Structure

```
cortex-server-os/
├── install.sh              # Main installer (bare metal)
├── Dockerfile              # Docker image build
├── docker-compose.yml      # Docker Compose (+ Ollama profiles)
├── dashboard/
│   ├── index.html          # Main dashboard SPA
│   └── managed.html        # Management-mode dashboard variant
├── skills/                 # 12 core skill packs
│   ├── monitoring/
│   ├── docker-manager/
│   ├── systemd-manager/
│   ├── security-hardening/
│   ├── network-manager/
│   ├── storage-manager/
│   ├── package-manager/
│   ├── user-manager/
│   ├── firewall-manager/
│   ├── backup-manager/
│   ├── server-monitor/
│   ├── cloudflare-install/
│   ├── cloudflare-ops/
│   └── manifest.json
├── scripts/                # Deploy, bundle, and utility scripts
├── workspace/              # Default agent workspace (SOUL, IDENTITY, BOOTSTRAP)
├── branding/               # Logo and assets
├── docs/                   # Additional documentation
├── ROADMAP.md              # Full development roadmap
├── AIR-GAPPED.md           # Offline deployment guide
├── MULTI-SERVER.md         # Fleet management architecture
├── CONTRIBUTING.md         # Contribution guide
├── DESIGN.md               # Architecture decisions
└── WINDOWS.md              # Windows support notes
```

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

**Areas where help is most valuable:**
- New skills — database management, log analysis, cloud integrations
- Dashboard — charts, themes, mobile UX
- Installer — more distro support, edge cases
- Documentation — guides, tutorials, troubleshooting
- Testing — automated tests, multi-platform validation
- Security — audit the installer and skills, report vulnerabilities responsibly

---

## Roadmap

- [x] **Phase 0:** Foundation — installer, skills, systemd, Ollama, gateway config
- [x] **Phase 1:** Dashboard — chat, terminal, stats, file upload, syntax highlighting, mobile responsive
- [x] **Phase 2:** Skills Ecosystem — 35 extended skills, CLI tool, dashboard management, air-gapped bundles
- [x] **Phase 3:** Management Server — fleet dashboard, auth, health monitoring, install tokens, WS proxy
- [ ] **Phase 4:** Advanced — incident response, predictive monitoring, compliance, webhooks, scheduled ops
- [ ] **Phase 5:** Platform — Docker image, ISO, AWS AMI, Proxmox template, docs site, marketplace

See [ROADMAP.md](ROADMAP.md) for the full breakdown.

---

## License

[MIT](LICENSE)

---

## Links

- 📦 [Management Server](https://github.com/ivanuser/cortex-management-server) — Fleet management for multiple CortexOS nodes
- 🧩 [Extended Skills](https://github.com/ivanuser/cortex-server-skills) — 35+ additional skill packs
- 📖 [Roadmap](ROADMAP.md) — Development phases and progress
- 🔒 [Air-Gapped Guide](AIR-GAPPED.md) — Offline / classified deployment
- 🤝 [Contributing](CONTRIBUTING.md) — How to help

---

<div align="center">

**CortexOS Server** — AI-managed infrastructure, one `curl` away.

Built by [@ivanuser](https://github.com/ivanuser)

</div>
]]>