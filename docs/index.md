# CortexOS Server Documentation

**Turn any Ubuntu server into an AI-managed infrastructure node in under 5 minutes.**

CortexOS Server combines [OpenClaw](https://openclaw.dev) with purpose-built server management skills, optional local AI inference via [Ollama](https://ollama.com), and a real-time web dashboard — giving you conversational control over your entire server from day one.

---

## What is CortexOS Server?

CortexOS Server is an open-source project that transforms a standard Ubuntu server into an AI-managed infrastructure node. Instead of memorizing CLI commands, writing scripts, or navigating complex dashboards, you simply tell your server what to do in plain English.

### Key Capabilities

- **Natural Language Server Management** — "Check disk usage", "restart nginx", "show failed SSH logins"
- **11 Specialized AI Skills** — Docker, systemd, security, networking, storage, monitoring, and more
- **Real-Time Web Dashboard** — Beautiful UI with chat interface, system stats, and quick commands
- **Local or Cloud AI** — Run Ollama models locally for privacy, or use Anthropic/OpenAI APIs
- **Fleet Management** — Manage multiple CortexOS nodes from a central management server
- **Air-Gapped Support** — Deploy in disconnected environments with offline bundles

### How It Works

```
┌─────────────┐     ┌──────────────┐     ┌────────────────┐
│   You        │────▶│  OpenClaw    │────▶│  Server Skills  │
│  (Chat/API)  │◀────│  Gateway     │◀────│  (11 modules)   │
└─────────────┘     └──────────────┘     └────────────────┘
                           │
                    ┌──────┴──────┐
                    │  AI Provider │
                    │ (Local/Cloud)│
                    └─────────────┘
```

You interact through the web dashboard or API. The OpenClaw gateway routes your requests to specialized skills that execute server management tasks. AI models (local or cloud) handle natural language understanding and response generation.

---

## Getting Started

### Quick Install (Bare Metal)

```bash
curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh && sudo bash install.sh
```

### Quick Install (Docker)

```bash
ANTHROPIC_API_KEY=sk-ant-... bash <(curl -sSL https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/scripts/docker-install.sh)
```

### What's Next?

- **[Quickstart Guide](quickstart.md)** — Get running in 5 minutes
- **[Full Installation Guide](installation.md)** — Bare metal, Docker, and management server options
- **[Configuration Reference](configuration.md)** — Customize your deployment
- **[Skills Overview](skills.md)** — What CortexOS can manage
- **[Troubleshooting](troubleshooting.md)** — Common issues and solutions

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Quickstart](quickstart.md) | 5-minute getting started |
| [Installation](installation.md) | Full install guide (bare metal, Docker, management server) |
| [Configuration](configuration.md) | Config reference (openclaw.json, env vars) |
| [Skills](skills.md) | Skills overview and custom skill creation |
| [Management Server](management-server.md) | Multi-node fleet management |
| [API Reference](api.md) | Management server REST API |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
| [Air-Gapped Deployment](air-gapped.md) | Offline and disconnected environments |

---

## Community

- **GitHub:** [github.com/ivanuser/cortex-server-os](https://github.com/ivanuser/cortex-server-os)
- **Issues:** [Report bugs or request features](https://github.com/ivanuser/cortex-server-os/issues)
- **Contributing:** [How to contribute](https://github.com/ivanuser/cortex-server-os/blob/main/CONTRIBUTING.md)

---

## License

CortexOS Server is released under the [MIT License](https://github.com/ivanuser/cortex-server-os/blob/main/LICENSE).
