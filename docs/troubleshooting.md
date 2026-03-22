# Troubleshooting

Common issues and how to fix them.

---

## Installation Issues

### Installer fails with permission error

**Symptom:** `Permission denied` or `EACCES` errors during install.

**Fix:** Run with sudo:
```bash
sudo bash install.sh
```

### Node.js installation fails

**Symptom:** nvm install hangs or errors out.

**Fix:**
```bash
# Check if nvm is already installed
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install 22

# If nvm itself failed, install manually:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install 22
```

### OpenClaw npm install fails

**Symptom:** `npm install -g openclaw` errors with network or dependency issues.

**Fix:**
```bash
# Clear npm cache
npm cache clean --force

# Retry
npm install -g openclaw

# If behind a proxy:
npm config set proxy http://proxy:port
npm config set https-proxy http://proxy:port
```

---

## Service Issues

### cortex-server won't start

**Symptom:** `systemctl start cortex-server` fails.

**Diagnose:**
```bash
# Check status
sudo systemctl status cortex-server

# View detailed logs
sudo journalctl -u cortex-server -n 50 --no-pager

# Check if port is already in use
sudo ss -tlnp | grep 18789
```

**Common causes:**
- Port 18789 already in use → change port or stop conflicting service
- Missing API key → set `ANTHROPIC_API_KEY` and restart
- Node.js not found → check nvm is sourced in the service environment

### Gateway not responding

**Symptom:** `curl http://localhost:18789/health` times out or connection refused.

**Fix:**
```bash
# Check if process is running
ps aux | grep openclaw

# Check bind address
grep -r "bind" /root/.openclaw/openclaw.json

# Restart
sudo systemctl restart cortex-server
```

### Dashboard shows "Connection Lost"

**Symptom:** Web dashboard can't connect to the gateway WebSocket.

**Fix:**
1. Check gateway is running: `sudo systemctl status cortex-server`
2. Check nginx is running: `sudo systemctl status nginx`
3. Verify the WebSocket proxy in nginx config:
   ```bash
   sudo cat /etc/nginx/sites-enabled/cortexos-dashboard
   ```
4. Check firewall:
   ```bash
   sudo ufw status
   # Should show 8443 and 18789 allowed
   ```

---

## Docker Issues

### Container exits immediately

**Symptom:** Container starts then immediately stops.

**Diagnose:**
```bash
docker compose logs cortexos
```

**Common causes:**
- Missing `ANTHROPIC_API_KEY` — add to `.env`
- Port conflict — change `ports` in `docker-compose.yml`
- Volume permission issues — check Docker volume ownership

### Can't connect to Ollama sidecar

**Symptom:** CortexOS can't reach Ollama at `http://ollama:11434`.

**Fix:**
1. Make sure you started with the profile:
   ```bash
   docker compose --profile local-ai up -d
   ```
2. Check Ollama is running:
   ```bash
   docker compose logs ollama
   ```
3. Verify the `OLLAMA_HOST` environment variable:
   ```bash
   docker compose exec cortexos env | grep OLLAMA
   ```

### Build fails

**Symptom:** `docker compose build` errors out.

**Fix:**
```bash
# Clean build (no cache)
docker compose build --no-cache

# Check disk space
df -h

# Prune old Docker data
docker system prune -f
```

---

## AI Provider Issues

### "No API key configured"

**Symptom:** Gateway starts but AI features don't work.

**Fix:**
```bash
# Bare metal
sudo -u cortex bash -c 'export ANTHROPIC_API_KEY="sk-ant-..." && openclaw models auth'
sudo systemctl restart cortex-server

# Docker — update .env and restart
echo 'ANTHROPIC_API_KEY=sk-ant-...' >> .env
docker compose restart cortexos
```

### "Rate limit exceeded"

**Symptom:** AI responses fail with 429 errors.

**Fix:**
- Wait and retry — rate limits are temporary
- Consider using a local Ollama model for high-frequency tasks
- Upgrade your API plan with the provider

### Ollama models not loading

**Symptom:** Ollama is running but models fail to load.

**Fix:**
```bash
# Check available models
ollama list

# Pull a model
ollama pull llama3.1

# Check system resources (models need RAM)
free -h

# For GPU models, check NVIDIA drivers
nvidia-smi
```

---

## Management Server Issues

### Node enrollment fails

**Symptom:** Node can't register with management server.

**Fix:**
1. Verify the enrollment token is valid (not expired)
2. Check network connectivity:
   ```bash
   curl -s http://management-server:9443/api/health
   ```
3. Verify the node's gateway is accessible from the management server:
   ```bash
   # From management server
   curl -s http://node-ip:18789/health
   ```

### Health poller shows all nodes offline

**Symptom:** Management dashboard shows all nodes as offline despite them running.

**Fix:**
1. Check management server logs for connection errors
2. Verify firewall rules allow management server to reach nodes on port 18789
3. Check if gateway tokens are correct in the management database

---

## Performance Issues

### High CPU usage

**Symptom:** CortexOS process consuming excessive CPU.

**Diagnose:**
```bash
# Check process resource usage
top -p $(pgrep -f openclaw)

# Check if Ollama is the culprit
top -p $(pgrep ollama)
```

**Fix:**
- Reduce health check frequency
- Use cloud AI instead of local models on low-powered servers
- Check for runaway skill processes

### High memory usage

**Symptom:** Server running out of RAM.

**Fix:**
```bash
# Check memory usage
free -h

# If Ollama is using too much:
# Use smaller models (e.g., llama3.1:7b instead of 70b)
# Or switch to cloud AI

# Check for memory leaks
sudo journalctl -u cortex-server | grep -i "memory\|oom"
```

---

## Getting Help

If none of the above resolves your issue:

1. **Check existing issues:** [GitHub Issues](https://github.com/ivanuser/cortex-server-os/issues)
2. **Collect diagnostics:**
   ```bash
   # System info
   uname -a
   cat /etc/os-release
   node --version
   
   # Service status
   sudo systemctl status cortex-server
   
   # Recent logs
   sudo journalctl -u cortex-server -n 100 --no-pager
   
   # OpenClaw version
   openclaw --version
   ```
3. **Open a new issue** with the diagnostics above
