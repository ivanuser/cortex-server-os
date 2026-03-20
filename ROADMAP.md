# CortexOS Server — Project Roadmap

> Last updated: 2026-03-20
> Current version: v0.2.7

## Overview

CortexOS Server transforms any Linux server into an AI-managed infrastructure node. This document outlines the complete development roadmap from single-server tool to enterprise fleet management platform.

---

## Phase 0: Foundation ✅ (Complete)

**Goal:** Working installer that transforms Ubuntu Server into a CortexOS node.

| Item | Status | Notes |
|------|--------|-------|
| Single-script installer (install.sh) | ✅ | Interactive + unattended modes |
| Node.js runtime (nvm) | ✅ | Auto-install v22 |
| OpenClaw gateway (openclaw-cortex) | ✅ | npm package with sharp image support |
| Ollama local AI (optional) | ✅ | CPU inference, auto-download models |
| Systemd service (cortex-server.service) | ✅ | Auto-start, restart on failure |
| System stats collector (systemd timer) | ✅ | CPU/RAM/disk/uptime every 10s |
| MOTD login banner | ✅ | ASCII art + quick commands |
| Firewall rules (UFW) | ✅ | Port 18789 + dashboard |
| SSL self-signed cert | ✅ | Auto-generated during install |
| Gateway config generation | ✅ | Token auth, trusted proxies, allowed origins |
| API key setup (Anthropic/OpenAI/Google) | ✅ | Interactive during install |
| 12 core skill packs | ✅ | 5,900+ lines of tested commands |
| Workspace files (SOUL, BOOTSTRAP, IDENTITY) | ✅ | AI onboarding experience |

**Bug fixes during Phase 0:** 15+ issues resolved (npm package name, PATH resolution, systemd config, sharp module, trusted proxies, origin allowlist, etc.)

---

## Phase 1: Dashboard ✅ (Complete)

**Goal:** Custom web UI purpose-built for server management. No OpenClaw Control UI pairing flow.

| Item | Status | Version | Notes |
|------|--------|---------|-------|
| Token-based login (no device pairing) | ✅ | v0.1.0 | Clean login page |
| Chat interface with streaming | ✅ | v0.1.0 | Real-time AI responses |
| System stats sidebar (live polling) | ✅ | v0.2.0 | stats.json every 10s |
| Quick command buttons (10 commands) | ✅ | v0.1.0 | One-click server tasks |
| Agent profile panel | ✅ | v0.2.0 | Avatar, skills, personality, settings |
| Avatar upload + display | ✅ | v0.2.5 | In sidebar, profile, chat messages |
| File upload (click, drag-drop, paste) | ✅ | v0.2.0 | Images + documents |
| Image preview in chat | ✅ | v0.2.0 | Inline thumbnails |
| Chat history persistence | ✅ | v0.2.0 | localStorage, survives refresh |
| Markdown rendering | ✅ | v0.2.0 | Headers, lists, bold, code blocks |
| Code syntax highlighting | ✅ | v0.2.7 | Keywords, strings, comments + copy button |
| Settings panel | ✅ | v0.2.0 | Token, model, user name, clear history |
| Skills management page | ✅ | v0.2.4 | Grid view, install buttons, dynamic counts |
| Terminal panel | ✅ | v0.2.7 | Command input, history, through AI |
| Auto-reconnect | ✅ | v0.2.0 | 3s reconnect with visual indicator |
| Mobile responsive | ✅ | v0.2.0 | Hamburger menu, sidebar overlay |
| Keyboard shortcuts | ✅ | v0.2.0 | Ctrl+1-8 for quick commands |
| Dynamic AI name from gateway | ✅ | v0.2.3 | Reads branding.assistantName |
| Version number in UI | ✅ | v0.2.1 | Auto-bumped by deploy script |
| Deploy script (auto-version) | ✅ | v0.2.1 | scripts/deploy-dashboard.sh |

---

## Phase 2: Skills Ecosystem ✅ (Complete)

**Goal:** Modular, updatable, installable skill packs with offline support.

| Item | Status | Notes |
|------|--------|-------|
| Core skills repo (cortex-server-os/skills/) | ✅ | 12 skills bundled with installer |
| Extended skills repo (cortex-server-skills) | ✅ | 35 skills across 6 categories |
| Skill manifest (manifest.json) | ✅ | Version tracking for updates |
| CLI tool (cortexos-skill) | ✅ | list, check, update, install, available, info |
| Skill discovery from GitHub | ✅ | Pull SKILL.md from remote repo |
| Update checking | ✅ | Compare local vs remote manifest |
| Dashboard skill management UI | ✅ | Grid view with install/info buttons |
| Air-gapped skill bundles | ✅ | build-offline-bundle.sh, 3 bundle types |
| Community contributions | 🔜 | PR workflow, skill submission guidelines |

### Skill Categories

| Category | Count | Examples |
|----------|-------|---------|
| Core (bundled) | 12 | monitoring, docker, systemd, security, network, storage, packages, users, firewall, backup, cloudflare-install, cloudflare-ops |
| Server | 14 | nginx, apache, postgres, mysql, redis, mongodb, elasticsearch, cassandra, sqlite, caddy, haproxy, rabbitmq, memcached, wireguard |
| Apps | 2 | nextcloud, discourse |
| Infrastructure | 9 | kubernetes, terraform, ansible, prometheus, grafana, jenkins, gitlab-runner, certbot, docker-compose |
| Cloud | 3 | aws-cli, gcloud, azure-cli |
| Runtimes | 5 | nodejs, python, golang, java, rust |
| **Total** | **45** | |

---

## Phase 3: Management Server 🔜 (Next)

**Goal:** Central management platform for multi-server CortexOS deployments.

### Architecture

```
CortexOS Management Server
├── Auth System (username/password + 2FA/TOTP)
├── User Database (PostgreSQL)
├── Fleet Dashboard
│   ├── Server Overview (health cards, alerts)
│   ├── Server Detail (chat with individual AI agents)
│   ├── Add Server (generate token + install command)
│   ├── Fleet Commands (run across all/selected servers)
│   ├── Backups (centralized backup management)
│   └── Users & Roles (RBAC)
├── Registration API (servers phone home)
├── Health Aggregation (poll all servers)
└── Agent State Storage (central DB for all agents)

Attached CortexOS Servers
├── Local AI agent (runs independently)
├── Reports health to management server
├── Agent state synced to management DB
├── Local WebUI disabled by default (configurable)
└── Installed via: install.sh --management-url=URL --token=TOKEN
```

### Components

| Component | Description | Priority |
|-----------|-------------|----------|
| **Management installer flag** | `install.sh --management` installs fleet UI + registration endpoint + database | P0 |
| **Token generation** | Management dashboard generates install tokens for new servers | P0 |
| **Server registration protocol** | New server → management handshake using token | P0 |
| **Install with token** | `install.sh --management-url=URL --token=TOKEN` auto-registers | P0 |
| **Auth system** | Username/password login with bcrypt hashing | P0 |
| **2FA (TOTP)** | Time-based one-time password (Google Authenticator compatible) | P1 |
| **User database** | PostgreSQL for users, servers, tokens, audit log | P0 |
| **Role-based access** | Admin, Operator, Viewer roles | P1 |
| **Fleet overview dashboard** | Health cards for all servers, aggregate stats | P0 |
| **Server detail view** | Chat with individual server AI, view its stats/skills | P0 |
| **Fleet commands** | Run operations across multiple servers | P1 |
| **Centralized backups** | Management server stores backups from all instances | P2 |
| **Agent state sync** | Agents save memory/state to management DB | P2 |
| **Local WebUI disable** | Attached servers disable local dashboard by default | P1 |
| **Audit logging** | All actions logged with user, timestamp, server | P0 |
| **Session management** | Login sessions, timeout, concurrent session limits | P1 |
| **API endpoints** | REST API for server registration, health, commands | P0 |

### Install Flow

```bash
# 1. Install Management Server
curl -sO .../install.sh && sudo bash install.sh --management

# 2. In Management Dashboard:
#    → Add Server → generates token + command

# 3. On new server:
curl -sO .../install.sh && sudo bash install.sh \
  --management-url=https://mgmt.example.com \
  --token=ctx_srv_A8f3k2m9xB7...

# Result:
# - CortexOS installed on new server
# - Auto-registered with management server
# - Local WebUI disabled
# - Health reporting started
# - Visible in management dashboard within 30 seconds
```

### Database Schema (PostgreSQL)

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255),
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'viewer', -- admin, operator, viewer
    totp_secret VARCHAR(64),           -- 2FA secret (encrypted)
    totp_enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ,
    active BOOLEAN DEFAULT true
);

-- Registered servers
CREATE TABLE servers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    hostname VARCHAR(255),
    ip_address VARCHAR(45),
    gateway_url VARCHAR(500) NOT NULL,
    gateway_token VARCHAR(255) NOT NULL,  -- encrypted
    agent_name VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending', -- pending, online, offline, error
    last_seen TIMESTAMPTZ,
    registered_at TIMESTAMPTZ DEFAULT NOW(),
    registered_by UUID REFERENCES users(id),
    tags TEXT[],                           -- for grouping
    config JSONB DEFAULT '{}'
);

-- Install tokens (one-time use)
CREATE TABLE install_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token VARCHAR(255) UNIQUE NOT NULL,
    server_name VARCHAR(100),            -- pre-assigned name
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    used_at TIMESTAMPTZ,
    used_by_server UUID REFERENCES servers(id),
    active BOOLEAN DEFAULT true
);

-- Health snapshots
CREATE TABLE health_snapshots (
    id BIGSERIAL PRIMARY KEY,
    server_id UUID REFERENCES servers(id),
    cpu_percent INTEGER,
    memory_used_mb INTEGER,
    memory_total_mb INTEGER,
    memory_percent INTEGER,
    disk_used_gb INTEGER,
    disk_total_gb INTEGER,
    disk_percent INTEGER,
    uptime VARCHAR(100),
    load_average VARCHAR(20),
    skills_count INTEGER,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Agent state backups
CREATE TABLE agent_backups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID REFERENCES servers(id),
    agent_id VARCHAR(100),
    file_name VARCHAR(255),
    content TEXT,
    backed_up_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit log
CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    server_id UUID REFERENCES servers(id),
    action VARCHAR(100) NOT NULL,
    details JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Auth Flow

```
1. User → Management Server login page
2. Enter username + password
3. Server validates against bcrypt hash in DB
4. If 2FA enabled → prompt for TOTP code
5. Server validates TOTP against stored secret
6. Issue session token (JWT, 24h expiry)
7. All subsequent requests include session token
8. Audit log entry for login
```

### Registration Protocol

```
1. Management Server generates install token (ctx_srv_XXXXX)
2. Token stored in install_tokens table with metadata
3. User runs installer with --management-url + --token
4. Installer:
   a. Installs CortexOS normally
   b. Generates local gateway token
   c. Calls management API: POST /api/v1/servers/register
      Body: { installToken, hostname, ip, gatewayUrl, gatewayToken }
   d. Management server validates install token (one-time use)
   e. Management server stores server record
   f. Returns: { serverId, managementWsUrl, config }
   g. Installer writes management config to openclaw.json
5. Server starts reporting health to management every 30s
6. Management dashboard shows new server within seconds
```

---

## Phase 4: Advanced Features 🔮 (Future)

**Goal:** Intelligent automation, predictive monitoring, and compliance.

| Item | Description | Priority |
|------|-------------|----------|
| Automated incident response | AI detects issues and auto-remediate (restart services, clear disk, etc.) | P1 |
| Predictive monitoring | AI analyzes trends and warns before problems occur | P2 |
| Configuration drift detection | Compare server configs against baseline, alert on changes | P1 |
| Compliance reporting | Generate STIG/CMMC/CIS compliance reports | P1 |
| Voice interface | Talk to your server AI via microphone | P3 |
| Classification banners | DoD-style classification markings in dashboard | P1 |
| Webhook integrations | Slack/Teams/Discord notifications for alerts | P2 |
| Custom skill builder | Create skills from the dashboard UI | P2 |
| Server templates | Pre-configured server profiles (web server, DB server, etc.) | P2 |
| Scheduled operations | Cron-like scheduled commands across fleet | P1 |

---

## Phase 5: Platform & Distribution 🔮 (Future)

**Goal:** Make CortexOS Server a distributable product.

| Item | Description |
|------|-------------|
| Windows installer (WSL2-based) | PowerShell script for Windows Server/Pro |
| Docker image | `docker run cortexos/server` |
| Proxmox template | Pre-built VM template |
| AWS AMI | One-click deploy on EC2 |
| ISO image | Bootable CortexOS installer (like Ubuntu Server ISO) |
| Package repository | apt repo for updates (`apt install cortexos-server`) |
| Marketplace listings | AWS Marketplace, DigitalOcean, Linode |
| Documentation site | docs.cortexos.dev |
| Landing page | cortexos.dev |

---

## Repository Structure

```
GitHub/GitLab Repos:

ivanuser/cortex-server-os          — Main installer + dashboard + core skills
ivanuser/cortex-server-skills      — Extended skill packs (35+)
ivanuser/cortex-management-server  — Management server (Phase 3)
ivanuser/cortex-server-docs        — Documentation site (Phase 5)
```

---

## Version History

| Version | Date | Milestone |
|---------|------|-----------|
| v0.1.0 | 2026-03-18 | First working installer |
| v0.2.0 | 2026-03-19 | Custom dashboard, file upload, agent profile |
| v0.2.5 | 2026-03-20 | Chat avatars, settings, dynamic skills |
| v0.2.7 | 2026-03-20 | Phase 1+2 complete. Syntax highlighting, terminal, air-gapped bundles |
| v0.3.0 | TBD | Phase 3: Management Server |
| v1.0.0 | TBD | Production-ready release |
