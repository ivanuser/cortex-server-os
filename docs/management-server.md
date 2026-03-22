# Management Server Guide

The Cortex Management Server provides centralized fleet management for multiple CortexOS nodes. Monitor, configure, and control all your servers from a single dashboard.

---

## Overview

```
┌─────────────────────────────────────────────────┐
│            Management Server (:9443)             │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐ │
│  │ Dashboard │  │ REST API │  │ Health Poller │  │
│  └──────────┘  └──────────┘  └───────────────┘ │
└─────────┬──────────┬──────────────┬─────────────┘
          │          │              │
     ┌────┴────┐ ┌───┴────┐  ┌────┴────┐
     │ Node 1  │ │ Node 2 │  │ Node N  │
     │ :18789  │ │ :18789 │  │ :18789  │
     └─────────┘ └────────┘  └─────────┘
```

### Features

- **Fleet Dashboard** — View all nodes at a glance with health status
- **Remote Management** — Execute commands on any node from the central UI
- **Health Monitoring** — Automatic health polling with configurable intervals
- **Incident Response** — Automated incident detection and alerting
- **Scheduled Tasks** — Run maintenance tasks across your fleet on a schedule
- **Node Enrollment** — Simple token-based node registration
- **Role-Based Access** — Admin, operator, and viewer roles
- **Audit Logging** — Track all actions across the fleet

---

## Installation

### Option A: Standalone (npm)

```bash
git clone https://github.com/ivanuser/cortex-management-server.git
cd cortex-management-server
npm install
npm start
```

### Option B: Docker

```bash
git clone https://github.com/ivanuser/cortex-management-server.git
cd cortex-management-server
docker compose up -d
```

### Option C: Docker (Quick)

```bash
docker run -d \
  --name cortex-management \
  -p 9443:9443 \
  -v cortex-mgmt-data:/app/data \
  cortex-management-server:latest
```

---

## Initial Setup

### 1. Access the dashboard

```
http://your-server:9443
```

### 2. Create admin account

On first launch, you'll be prompted to create an admin account. Alternatively:

```bash
# Set admin password via environment
ADMIN_PASSWORD=your-secure-password npm start
```

### 3. Generate enrollment token

In the management dashboard, go to **Settings → Enrollment** and generate a token. This token is used by CortexOS nodes to register themselves.

---

## Enrolling Nodes

### Auto-enrollment (during install)

Pass the management server URL and token when installing CortexOS:

```bash
MGMT_URL=https://management-server:9443 \
MGMT_TOKEN=your-enroll-token \
curl -sSL https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh | sudo bash
```

### Manual enrollment

On an existing CortexOS node:

```bash
curl -X POST https://management-server:9443/api/fleet/enroll \
  -H "Content-Type: application/json" \
  -d '{
    "token": "your-enroll-token",
    "hostname": "my-server",
    "gatewayUrl": "http://this-server:18789",
    "gatewayToken": "node-gateway-token"
  }'
```

---

## Health Monitoring

The management server polls each node's health endpoint at configurable intervals.

### Health states

| State | Meaning |
|-------|---------|
| 🟢 `healthy` | Node responding normally |
| 🟡 `degraded` | Node responding with warnings |
| 🔴 `critical` | Node not responding or reporting errors |
| ⚫ `offline` | Node unreachable |

### Configuration

Health polling is configured in the management server's settings:

```json
{
  "health": {
    "pollInterval": 30,
    "timeout": 10,
    "retries": 3,
    "alertOnCritical": true
  }
}
```

---

## Incident Response

The management server automatically detects and tracks incidents:

- **Node goes offline** — Creates incident, attempts auto-recovery
- **High resource usage** — Alerts when CPU/RAM/disk exceeds thresholds
- **Service failures** — Detects and reports systemd service crashes
- **Security events** — Tracks failed login attempts, unauthorized access

### Incident Lifecycle

```
Detected → Acknowledged → Investigating → Resolved
```

All incidents are logged with timestamps, affected nodes, and resolution steps.

---

## Scheduled Tasks

Run maintenance across your fleet on a schedule:

```json
{
  "name": "Weekly Security Audit",
  "schedule": "0 2 * * 1",
  "nodes": ["all"],
  "command": "Run a full security audit and report findings"
}
```

Schedules use cron syntax. Tasks can target specific nodes, groups, or all nodes.

---

## Security

### Authentication

- JWT-based authentication with configurable expiry
- Optional 2FA (TOTP) for admin accounts
- Session management with revocation

### Network Security

- All management-to-node communication uses gateway tokens
- Encrypt traffic with TLS (recommended: reverse proxy with real certificates)
- Restrict management server access to trusted networks

### Best Practices

1. Use strong, unique passwords for admin accounts
2. Enable 2FA for all admin users
3. Place the management server behind a reverse proxy with TLS
4. Restrict network access to the management port (9443)
5. Regularly rotate enrollment tokens
6. Review audit logs for unauthorized access attempts

---

## Data & Backups

### Data Location

| Path | Contents |
|------|----------|
| `/app/data/management.db` | SQLite database (nodes, users, incidents) |
| `/app/data/audit.log` | Audit trail |

### Backup

```bash
# Docker
docker compose exec management-server cp /app/data/management.db /app/data/management.db.bak

# Standalone
cp data/management.db data/management.db.bak
```

---

## Next Steps

- **[API Reference](api.md)** — Full REST API documentation
- **[Configuration](configuration.md)** — Detailed config options
- **[Troubleshooting](troubleshooting.md)** — Common issues
