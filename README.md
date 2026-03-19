# CortexOS Server

**Turn any Ubuntu server into an AI-managed infrastructure node in under 5 minutes.**

CortexOS Server installs [OpenClaw](https://github.com/anthropics/openclaw) with purpose-built server management skills, [Ollama](https://ollama.com) for local AI inference, and a real-time web dashboard — giving you conversational control over your entire server from day one.

![CortexOS Dashboard](https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/branding/screenshot.png)

---

## Quick Install

```bash
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh && sudo bash install.sh
```

That's it. The installer handles everything — dependencies, configuration, services, and the web dashboard.

> **Want to review first?** Download with `wget`, read it, then run it:
> ```bash
> wget https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh
> less install.sh
> sudo bash install.sh
> ```

---

## Features

- 🤖 **AI-First Server Management** — Manage your server through natural language via SSH or the web dashboard
- 🌐 **Web Dashboard** — Beautiful real-time UI with chat, system stats, and quick commands (port 8443)
- 🧠 **11 Specialized Skills** — Docker, systemd, security, networking, storage, monitoring, and more
- 🦙 **Local AI with Ollama** — Run models locally for privacy and speed (optional cloud providers too)
- 🔒 **Security Hardening** — CIS benchmarks, fail2ban, firewall management, audit logging
- 🐳 **Docker Management** — Container lifecycle, health monitoring, compose orchestration
- 📊 **Real-Time Monitoring** — CPU, RAM, disk, network stats polled every 30 seconds
- 💾 **Backup Management** — Automated scheduling, verification, and recovery
- ⚡ **One-Command Install** — From bare Ubuntu to fully managed server in minutes
- 📱 **Responsive UI** — Works on desktop and mobile browsers

---

## Requirements

| Component | Minimum |
|-----------|---------|
| **OS** | Ubuntu 22.04+ (Server or Desktop) |
| **RAM** | 2 GB |
| **Disk** | 10 GB free |
| **CPU** | 2+ cores recommended |
| **Network** | Internet access during install |

---

## What Gets Installed

The installer sets up the following on your system:

| Component | Purpose |
|-----------|---------|
| **Node.js 22** | Runtime (via nvm) |
| **OpenClaw** | AI agent gateway + orchestration |
| **Ollama** | Local LLM inference engine |
| **11 Server Skills** | Specialized management agents |
| **Web Dashboard** | Browser UI on port 8443 (nginx) |
| **systemd Services** | `cortex-server` auto-starts on boot |

All components run under a dedicated `cortex` system user.

---

## Dashboard Access

After installation, open your browser:

```
https://<server-ip>:8443
```

1. Log in with the access token shown at the end of installation
2. The AI agent introduces itself and runs an initial health check
3. Use the chat or sidebar quick commands to manage your server

**Quick commands available in the sidebar:**
- System Health — Full overview
- Security Audit — Check hardening status
- Services — List running systemd services
- Updates — Check for package updates
- Disk Usage — Storage breakdown
- Network — Interfaces and connections
- Docker — Container status
- Firewall — UFW rules and status
- Auth Logs — Failed login attempts
- Backups — Backup status and schedule

---

## Skills

CortexOS ships with 11 server management skills:

| Skill | Description |
|-------|-------------|
| 📊 **monitoring** | System metrics, health checks, alerting |
| 🖥️ **server-monitor** | Real-time server resource tracking |
| 🐳 **docker-manager** | Container lifecycle, compose, images |
| ⚙️ **systemd-manager** | Service management, journalctl, timers |
| 🔒 **security-hardening** | CIS benchmarks, fail2ban, SSH hardening |
| 🌐 **network-manager** | Interfaces, DNS, routing, diagnostics |
| 💾 **storage-manager** | Disks, mounts, LVM, SMART health |
| 📦 **package-manager** | apt operations, updates, cleanup |
| 👤 **user-manager** | Users, groups, sudo, SSH keys |
| 🛡️ **firewall-manager** | UFW/iptables rules and policies |
| 💿 **backup-manager** | Scheduled backups, verify, restore |

Skills are installed to `/var/lib/cortexos/skills/` and can be customized or extended.

---

## Configuration

### AI Provider Setup

CortexOS works with cloud AI providers or local models:

**Option 1: Anthropic API Key**
```bash
sudo -u cortex bash -c 'export ANTHROPIC_API_KEY="sk-ant-..." && openclaw models auth'
sudo systemctl restart cortex-server
```

**Option 2: Local Ollama (installed automatically)**
```bash
# Ollama is installed by default — pull a model:
ollama pull llama3.1
# Configure OpenClaw to use it via the dashboard
```

**Option 3: Claude Setup Token**
```bash
# On a machine with Claude CLI:
claude setup-token
# On the CortexOS server:
openclaw models auth paste-token --provider anthropic
sudo systemctl restart cortex-server
```

### Service Management

```bash
# Check status
sudo systemctl status cortex-server

# View logs
sudo journalctl -u cortex-server -f

# Restart
sudo systemctl restart cortex-server
```

---

## Air-Gapped / Offline Mode (Planned)

CortexOS is designed to work in disconnected environments:

- **Offline installer** — Pre-bundled `.deb` packages and Node modules for installation without internet
- **Local-only AI** — Ollama models run entirely on-device, no cloud calls needed
- **Skill bundles** — Download skill packs for transfer to air-gapped networks
- **Update packages** — Export/import update bundles via USB or local network

> This feature is in development. Track progress in [GitHub Issues](https://github.com/ivanuser/cortex-server-os/issues).

---

## Project Structure

```
cortex-server-os/
├── install.sh           # Main installer script
├── dashboard/
│   └── index.html       # Single-page web dashboard
├── skills/              # Server management skill definitions
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
│   └── server-monitor/
├── workspace/           # Default agent workspace
├── branding/            # Logo and branding assets
├── DESIGN.md            # Architecture and design decisions
└── PHASE1.md            # Phase 1 development plan
```

---

## Contributing

Contributions welcome! Here's how:

1. **Fork** the repo
2. **Create a branch** (`git checkout -b feature/my-improvement`)
3. **Make your changes** and test on a fresh Ubuntu VM
4. **Commit** (`git commit -m "Add: description of change"`)
5. **Push** and open a **Pull Request**

### Areas we'd love help with:

- **New skills** — Database management, log analysis, K8s, cloud provider integrations
- **Dashboard improvements** — Charts, graphs, mobile UX, dark/light themes
- **Installer hardening** — More distro support, edge case handling
- **Documentation** — Guides, tutorials, troubleshooting
- **Testing** — Automated tests, multi-platform validation
- **Security** — Audit the installer and skills, report vulnerabilities responsibly

---

## Roadmap

- [x] Phase 1: Install script + web dashboard + 11 skills
- [ ] Phase 2: Custom Ubuntu Server ISO with AI-guided setup
- [ ] Phase 3: Multi-server fleet management
- [ ] Phase 4: Enterprise features (RBAC, compliance, API)

---

## License

[MIT](LICENSE)

---

**CortexOS Server** — AI-managed infrastructure, one `curl` away.

Built by [@ivanuser](https://github.com/ivanuser)
