# Configuration Reference

CortexOS Server configuration lives in two places: the OpenClaw config file and environment variables.

---

## OpenClaw Configuration File

**Location:** `/root/.openclaw/openclaw.json` (bare metal: `/home/cortex/.openclaw/openclaw.json`)

```json
{
  "version": 1,
  "gateway": {
    "bind": "0.0.0.0",
    "port": 18789,
    "token": "your-access-token"
  },
  "skills": {
    "directories": ["/var/lib/cortexos/skills"]
  },
  "models": {
    "default": "anthropic/claude-sonnet-4-20250514",
    "providers": {
      "anthropic": {
        "apiKey": "sk-ant-..."
      },
      "openai": {
        "apiKey": "sk-..."
      },
      "ollama": {
        "baseUrl": "http://localhost:11434"
      }
    }
  },
  "ui": {
    "assistant": {
      "name": "CortexOS",
      "avatar": "/var/lib/cortexos/branding/logo.png"
    }
  }
}
```

### Gateway Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `gateway.bind` | string | `"127.0.0.1"` | Bind address (`"0.0.0.0"` for all interfaces) |
| `gateway.port` | number | `18789` | Gateway WebSocket/HTTP port |
| `gateway.token` | string | auto-generated | Access token for authentication |

### Skills Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `skills.directories` | string[] | `[]` | Additional skill directories to load |

### Model Settings

| Key | Type | Description |
|-----|------|-------------|
| `models.default` | string | Default model for conversations |
| `models.providers.anthropic.apiKey` | string | Anthropic API key |
| `models.providers.openai.apiKey` | string | OpenAI API key |
| `models.providers.ollama.baseUrl` | string | Ollama server URL |

---

## Environment Variables

Environment variables override config file values. Set these in `.env` (Docker) or `/etc/cortexos/cortexos.env` (bare metal).

### Core

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | — | Anthropic API key for Claude models |
| `OPENAI_API_KEY` | — | OpenAI API key for GPT models |
| `GATEWAY_TOKEN` | `auto` | Gateway access token (`auto` = auto-generate) |
| `OLLAMA_HOST` | `http://localhost:11434` | Ollama server URL |

### Server

| Variable | Default | Description |
|----------|---------|-------------|
| `CORTEX_PORT` | `18789` | Gateway port |
| `CORTEX_BIND` | `0.0.0.0` | Gateway bind address |
| `DASHBOARD_PORT` | `8443` | Dashboard HTTPS port (bare metal only) |
| `NODE_ENV` | `production` | Node.js environment |

### Management Server Integration

| Variable | Default | Description |
|----------|---------|-------------|
| `MGMT_URL` | — | Management server URL for auto-enrollment |
| `MGMT_TOKEN` | — | Enrollment token from management server |
| `MGMT_API_PROVIDER` | — | AI provider passed from management server |
| `MGMT_API_KEY` | — | API key passed from management server |

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `info` | Log verbosity: `debug`, `info`, `warn`, `error` |
| `LOG_DIR` | `/var/log/cortex-server` | Log file directory |

---

## Dashboard Configuration

The web dashboard (bare metal install) runs on nginx with a self-signed TLS certificate.

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8443 | HTTPS | Web dashboard |
| 18789 | HTTP/WS | Gateway API and WebSocket |

### Customizing the Dashboard

The dashboard is a single HTML file at `/var/lib/cortexos/dashboard/index.html`. You can:

1. Edit it directly for simple changes
2. Replace it entirely with a custom UI
3. Proxy it behind your own reverse proxy (nginx, Caddy, Traefik)

### Reverse Proxy Example (nginx)

```nginx
server {
    listen 443 ssl;
    server_name cortexos.example.com;

    ssl_certificate     /etc/ssl/certs/your-cert.pem;
    ssl_certificate_key /etc/ssl/private/your-key.pem;

    # Dashboard
    location / {
        proxy_pass http://127.0.0.1:8443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Gateway WebSocket
    location /ws {
        proxy_pass http://127.0.0.1:18789;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

---

## AI Provider Configuration

### Anthropic (Recommended)

```bash
# Set via environment
export ANTHROPIC_API_KEY="sk-ant-..."

# Or configure directly
openclaw models auth --provider anthropic
```

### OpenAI

```bash
export OPENAI_API_KEY="sk-..."
openclaw models auth --provider openai
```

### Ollama (Local)

```bash
# Start Ollama
ollama serve

# Pull a model
ollama pull llama3.1

# CortexOS auto-detects Ollama on localhost:11434
```

### Multiple Providers

You can configure multiple providers simultaneously. CortexOS will use the default model specified in `models.default`, but individual skills can request specific models.

---

## Security Considerations

1. **API Keys** — Never commit `.env` files or API keys to version control
2. **Gateway Token** — Use a strong token in production; don't expose the gateway to the public internet without one
3. **Dashboard** — The self-signed cert triggers browser warnings; use a real cert in production
4. **Firewall** — Only expose ports 8443 and 18789 to trusted networks
5. **Docker** — Don't run the container with `--privileged` unless absolutely necessary
