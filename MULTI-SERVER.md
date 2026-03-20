# CortexOS Server — Multi-Server Management

## Vision

A central CortexOS dashboard that manages multiple servers. Each server runs its own CortexOS instance. The central dashboard aggregates health, lets you chat with any server's AI, and run fleet-wide operations.

## Architecture

```
┌──────────────────────────────────────────────┐
│           Central Dashboard                    │
│   (cortex-fleet.honercloud.com)                │
├──────────────────────────────────────────────┤
│                                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Server A  │  │ Server B  │  │ Server C  │   │
│  │ Athena    │  │ Nova      │  │ Sentinel  │   │
│  │ .249:18789│  │ .250:18789│  │ .251:18789│   │
│  └──────────┘  └──────────┘  └──────────┘    │
│                                                │
│  Health Aggregation | Fleet Commands           │
│  Cross-Server Ops   | Centralized Alerts       │
└──────────────────────────────────────────────┘
```

## Features

### Phase 1: Fleet Overview
- Register multiple CortexOS servers (URL + token)
- Aggregate health dashboard (all servers' CPU/RAM/disk)
- Quick-switch between servers to chat with each AI
- Color-coded health status (green/yellow/red)

### Phase 2: Fleet Operations
- Run commands across multiple servers simultaneously
- "Update all servers" → apt upgrade on every box
- "Security audit fleet" → each AI runs its audit
- Centralized alert notifications

### Phase 3: Cross-Server Intelligence
- AI on Server A can ask Server B for info
- Coordinated deployments (deploy app across multiple servers)
- Shared knowledge base (security findings, common configs)
- Fleet-wide compliance reporting

## Implementation

### Server Registration
Each server is registered with:
```json
{
  "id": "server-a",
  "name": "Web Server",
  "url": "wss://server-a.example.com",
  "token": "...",
  "agent": "Athena",
  "tags": ["production", "web"],
  "added": "2026-03-20"
}
```

Stored in `fleet.json` on the central dashboard.

### Central Dashboard Changes
- New "Fleet" page showing all servers
- Server cards with health stats
- Click a server to open its chat
- Sidebar shows server list instead of single-server stats
- Fleet-wide quick commands

### API for Server Discovery
Optional: servers can announce themselves via mDNS/Bonjour (already built into OpenClaw) for automatic LAN discovery.

## Status

- [ ] Fleet registration UI
- [ ] Health aggregation
- [ ] Server switching in dashboard
- [ ] Fleet-wide commands
- [ ] Auto-discovery (mDNS)
- [ ] Cross-server communication
