# CortexOS Server — Design Document

## Vision

CortexOS Server turns any Ubuntu Server into an AI-managed infrastructure node. Install one script, get an AI sysadmin that knows Linux inside and out.

**Not a toy. Not a demo. A production server management platform.**

## Architecture

```
┌────────────────────────────────────────────────┐
│              CortexOS Dashboard                 │
│   (Custom Web UI — token auth, no pairing)      │
├────────────────────────────────────────────────┤
│            OpenClaw Gateway (cortex)            │
│   (AI agent runtime — chat, tools, skills)      │
├────────────────────────────────────────────────┤
│              Skills Engine                       │
│   (Modular skill packs — updatable, offline)    │
├────────────────────────────────────────────────┤
│               Ollama (optional)                  │
│         (Local AI inference — CPU/GPU)           │
├────────────────────────────────────────────────┤
│            Ubuntu Server 22.04+                  │
└────────────────────────────────────────────────┘
```

## Components

### 1. Installer (`install.sh`)
Single script that transforms Ubuntu Server into CortexOS:
- Installs Node.js (nvm), OpenClaw (cortex), Ollama
- Creates systemd service (`cortex-server.service`)
- Deploys skills, dashboard, workspace files
- Configures gateway with token auth
- Sets up MOTD, firewall rules
- Interactive + unattended modes

### 2. Dashboard (Custom Web UI)
**NOT the OpenClaw Control UI.** Purpose-built for server management.

- Token-based login (shown during install)
- Chat interface for AI sysadmin
- System stats sidebar (CPU, RAM, disk, network)
- Quick command buttons
- Skill update notifications
- Terminal panel (future)
- Dark theme with accent color — looks good, not bland
- Pure HTML/CSS/JS — no build step, instant load
- Served directly by the gateway

### 3. Skills Ecosystem
Modular skill packs that teach the AI how to manage specific things.

#### Core Skills (bundled with installer)
- `monitoring` — system health, alerting, resource tracking
- `package-manager` — apt, snap, updates, security patches
- `docker-manager` — containers, compose, images, volumes
- `systemd-manager` — services, timers, boot targets
- `security-hardening` — SSH, firewall, auditing, compliance
- `network-manager` — interfaces, DNS, routing, diagnostics
- `storage-manager` — disks, LVM, NFS, SMART health
- `user-manager` — users, groups, sudo, SSH keys
- `firewall-manager` — UFW, iptables, fail2ban
- `backup-manager` — tar, rsync, cron backups, restore

#### Extended Skills (separate repo, downloadable)
Server-specific:
- `nginx` — config, virtual hosts, SSL, load balancing
- `apache` — httpd config, modules, virtual hosts
- `postgres` — databases, users, backups, tuning
- `mysql` — databases, users, replication, optimization
- `redis` — config, persistence, clustering
- `mongodb` — collections, indexes, replica sets

Application-specific:
- `nextcloud` — installation, config, maintenance mode
- `discourse` — setup, plugins, backups, upgrades
- `gitlab` — installation, runners, registry, backup
- `wordpress` — setup, plugins, security, performance
- `home-assistant` — config, integrations, automations
- `proxmox` — VMs, containers, storage, networking

Infrastructure:
- `kubernetes` — kubectl, helm, deployments, troubleshooting
- `terraform` — state, plan, apply, modules
- `ansible` — playbooks, inventory, roles
- `cloudflare` — DNS, tunnels, WAF, pages

#### Skill Update Flow
1. Skills repo gets updated (new skill or updated SKILL.md)
2. CortexOS servers check for updates (configurable interval)
3. Dashboard shows notification: "3 skill updates available"
4. User clicks update → skills pulled and deployed
5. **Air-gapped mode:** Download skill bundle → USB → manual install

### 4. Air-Gapped / Classified Support
For servers with no internet access:
- Offline installer package (all dependencies bundled)
- Skill bundles as tar.gz files
- Manual update via USB/SCP
- No phone-home, no telemetry, no external calls
- All AI inference via local Ollama (no cloud API keys needed)

### 5. Onboarding Experience
First connection after install:
1. AI introduces itself as the server's management agent
2. Runs immediate health check (CPU, RAM, disk, services)
3. Reports security status (firewall, SSH, updates)
4. Asks what the server will be used for
5. Recommends relevant extended skills
6. Updates workspace files based on conversation

## Target Users

1. **Home lab enthusiasts** — want AI help managing their servers
2. **Small business IT** — one person managing multiple servers
3. **DevOps/SRE** — quick server setup and management
4. **Classified/air-gapped** — government/military environments
5. **Education** — learning Linux server administration with AI help

## Tech Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Base OS | Ubuntu Server 22.04+ | Most popular server distro |
| AI Runtime | OpenClaw (cortex fork) | Our fork, we control it |
| Local AI | Ollama | Simple, works on CPU |
| Dashboard | Vanilla HTML/CSS/JS | No build step, instant load |
| Auth | Token-based | Simple, secure, no pairing |
| Service | systemd | Standard Linux service manager |
| Skills | Markdown files | Easy to write, version, distribute |

## Roadmap

### Phase 0: Foundation ✅
- [x] Installer script (install.sh)
- [x] 10 core skills with real content
- [x] Systemd service
- [x] MOTD banner
- [x] Workspace files (SOUL, BOOTSTRAP, IDENTITY, etc.)
- [x] Gateway config with token auth
- [x] Custom dashboard (basic)

### Phase 1: Dashboard (Current)
- [ ] Polished UI with good design (not bland)
- [ ] Real-time system stats (poll from AI or direct)
- [ ] Markdown rendering in chat
- [ ] Code block syntax highlighting
- [ ] Terminal panel
- [ ] Skill management page
- [ ] Settings page (change token, configure AI model)

### Phase 2: Skills Ecosystem
- [ ] Skills repo (cortex-server-skills)
- [ ] Skill discovery and installation
- [ ] Update checking and notification
- [ ] Air-gapped skill bundles
- [ ] Community skill contributions

### Phase 3: Multi-Server
- [ ] Central dashboard managing multiple CortexOS servers
- [ ] Server groups and tags
- [ ] Cross-server operations
- [ ] Fleet health overview

### Phase 4: Advanced
- [ ] Automated incident response
- [ ] Predictive monitoring (AI-driven)
- [ ] Configuration drift detection
- [ ] Compliance reporting
- [ ] Voice interface

## Repository Structure

```
cortex-server-os/
├── install.sh              # Main installer
├── DESIGN.md               # This document
├── README.md               # User-facing docs
├── dashboard/              # Custom web UI
│   ├── index.html          # Single-page dashboard
│   ├── css/                # Styles (future)
│   └── js/                 # Scripts (future)
├── skills/                 # Core skill packs
│   ├── monitoring/
│   ├── docker-manager/
│   ├── systemd-manager/
│   ├── security-hardening/
│   ├── network-manager/
│   ├── storage-manager/
│   ├── package-manager/
│   ├── user-manager/
│   ├── firewall-manager/
│   └── backup-manager/
├── workspace/              # Agent workspace files
│   ├── AGENTS.md
│   ├── SOUL.md
│   ├── BOOTSTRAP.md
│   ├── IDENTITY.md
│   ├── USER.md
│   ├── TOOLS.md
│   └── HEARTBEAT.md
└── branding/               # Logos, assets
```

## Skills Repo (separate)

```
cortex-server-skills/
├── README.md
├── manifest.json           # Skill catalog with versions
├── server/                 # Server software skills
│   ├── nginx/
│   ├── apache/
│   ├── postgres/
│   ├── mysql/
│   └── redis/
├── apps/                   # Application skills
│   ├── nextcloud/
│   ├── discourse/
│   ├── gitlab/
│   └── wordpress/
├── infra/                  # Infrastructure skills
│   ├── kubernetes/
│   ├── terraform/
│   └── ansible/
└── bundles/                # Air-gapped packages
    ├── web-server.tar.gz
    ├── database.tar.gz
    └── full-stack.tar.gz
```
