# CortexOS Server v1.0.0

**AI-powered server management in one install.**

Turn any Ubuntu server into an AI-managed infrastructure node in under 5 minutes. CortexOS installs OpenClaw with purpose-built server management skills, Ollama for local AI inference, and a real-time web dashboard — giving you conversational control over your entire server from day one.

## One-Liner Install

```bash
# Bare Metal
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh && sudo bash install.sh

# Docker
git clone https://github.com/ivanuser/cortex-server-os.git && cd cortex-server-os
export ANTHROPIC_API_KEY="sk-ant-..."
docker compose up -d
```

## What It Does

CortexOS wraps a full AI agent around your server. You talk to it in natural language — through the web dashboard, chat, or terminal panel — and it manages packages, containers, firewalls, backups, users, networking, and more using specialized skill packs.

The AI is the primary interface; the dashboard visualizes what the AI already knows.

## Features

- **Web Dashboard** — Real-time UI with chat, system stats, quick commands (port 18789)
- **Real-Time Tool Event Streaming** — See what AI is doing as it works (tool calls, exec commands, completions live)
- **12 Core Skills** — Docker, systemd, security, networking, storage, monitoring, and more
- **35+ Extended Skills** — Databases, web servers, CI/CD, cloud CLIs, runtimes, Kubernetes
- **Terminal Panel** — Run commands through the AI with full history
- **Chat Interface** — Streaming responses, markdown rendering, code syntax highlighting
- **File Upload** — Click, drag-drop, or paste — images preview inline
- **System Stats** — Live CPU, RAM, disk, network — polled every 10 seconds
- **Agent Profile** — Custom avatar, personality, skills display, settings
- **Auto-Reconnect** — 3-second reconnect with visual indicator
- **Mobile Responsive** — Hamburger menu, sidebar overlay
- **Keyboard Shortcuts** — Ctrl+1-8 for quick commands
- **Skills Management UI** — Browse, install, and manage skills from the dashboard
- **Local AI (Ollama)** — Run models locally for privacy — no cloud calls needed

## Requirements

| Component | Minimum |
|-----------|---------|
| **OS** | Ubuntu 22.04+ (Server or Desktop) |
| **RAM** | 2 GB (4 GB+ recommended for local AI) |
| **Disk** | 10 GB free |
| **CPU** | 2+ cores recommended |
| **Network** | Internet access during install (or use air-gapped mode) |

## Install Options

### 1. Bare Metal (recommended)

```bash
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh
sudo bash install.sh
```

The installer handles everything: Node.js, OpenClaw, Ollama, skills, dashboard, systemd service, SSL cert, firewall rules.

### 2. Docker

```bash
git clone https://github.com/ivanuser/cortex-server-os.git
cd cortex-server-os
export ANTHROPIC_API_KEY="sk-ant-..."
docker compose up -d
```

Access at `http://localhost:18789`. Add `--profile local-ai` for Ollama sidecar, or `--profile local-ai-gpu` for NVIDIA GPU support.

### 3. Via Management Server

For fleet deployments, the [Management Server](https://github.com/ivanuser/cortex-management-server) generates install tokens:

```bash
curl -sSL "https://mgmt.example.com/install.sh?token=ctx_srv_XXXXX" | sudo bash
```

The server auto-registers with the management dashboard and starts reporting health within 30 seconds.

## Skills

### Core Skills (12 — bundled with installer)

| Skill | Description |
|-------|-------------|
| **monitoring** | System health monitoring & alerting |
| **docker-manager** | Docker container management |
| **systemd-manager** | Systemd service management |
| **security-hardening** | Security auditing & hardening |
| **network-manager** | Network configuration & diagnostics |
| **storage-manager** | Disk, LVM, NFS & SMART management |
| **package-manager** | Package & update management |
| **user-manager** | User, group & SSH key management |
| **firewall-manager** | UFW, iptables & fail2ban management |
| **backup-manager** | Backup & disaster recovery |
| **cloudflare-install** | Cloudflare Tunnel installation |
| **cloudflare-ops** | Cloudflare Tunnel operations & routing |

### Extended Skills (35 — install with `cortexos-skill install <name>`)

| Category | Skills |
|----------|--------|
| **Server** | nginx, apache, postgres, mysql, redis, mongodb, elasticsearch, cassandra, sqlite, caddy, haproxy, rabbitmq, memcached, wireguard |
| **Apps** | nextcloud, discourse |
| **Infrastructure** | kubernetes, terraform, ansible, prometheus, grafana, jenkins, gitlab-runner, certbot, docker-compose |
| **Cloud** | aws-cli, gcloud, azure-cli |
| **Runtimes** | nodejs, python, golang, java, rust |

```bash
# Install a skill
cortexos-skill install nginx

# List available
cortexos-skill available

# Check for updates
cortexos-skill check
```

## AI Provider Setup

CortexOS needs an AI provider. Options:

| Provider | How |
|----------|-----|
| **Anthropic (Claude)** | API key from console.anthropic.com or `claude setup-token` |
| **OpenAI (GPT)** | API key from platform.openai.com |
| **Google (Gemini)** | API key from ai.google.dev |
| **Local (Ollama)** | Bundled during install, no key needed |

## Air-Gapped / Offline

For servers with no internet:

```bash
# Build offline bundle (on connected machine)
bash scripts/build-offline-bundle.sh

# Transfer and install (on air-gapped machine)
tar xzf cortexos-server-offline-v1.0.0.tar.gz
cd cortexos-server-offline && sudo bash install.sh --offline
```

## Management Server

For managing multiple CortexOS instances from one dashboard, see [CortexOS Management Server](https://github.com/ivanuser/cortex-management-server).

Features: fleet dashboard, embedded chat/skills/terminal per server, auth with 2FA, server templates, install tokens, health monitoring, incident response, scheduled operations, webhook notifications, centralized backups, analytics.

## Project Structure

```
cortex-server-os/
├── install.sh              # Main installer
├── dashboard/              # Custom web UI (single HTML file)
├── skills/                 # 12 core skill packs
├── workspace/              # Agent workspace files (SOUL, BOOTSTRAP, etc.)
├── scripts/                # Deploy, stats, skill manager, offline bundle
├── docs/                   # Documentation
├── site/                   # Landing page
├── Dockerfile              # Docker image
├── docker-compose.yml      # Docker Compose
├── ROADMAP.md              # Development roadmap
└── branding/               # Logo and assets
```

## Related Repos

- [cortex-management-server](https://github.com/ivanuser/cortex-management-server) — Fleet management
- [cortex-server-skills](https://github.com/ivanuser/cortex-server-skills) — Extended skill packs

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.
