# Skills Overview

CortexOS Server ships with 11 specialized skills for server management. Each skill is a self-contained module that the AI agent uses to perform specific tasks.

---

## Built-in Skills

### 📊 Monitoring
Real-time system metrics, health checks, and alerting.

**Example prompts:**
- "Run a full health check"
- "Show me CPU and memory usage"
- "What's the system load?"

### 🖥️ Server Monitor
Continuous server resource tracking and historical data.

**Example prompts:**
- "Show server resource trends"
- "Are there any performance anomalies?"

### 🐳 Docker Manager
Container lifecycle management, compose orchestration, image management.

**Example prompts:**
- "List all running containers"
- "Restart the nginx container"
- "Show me container resource usage"
- "Pull the latest postgres image"

### ⚙️ Systemd Manager
Service management, journalctl access, timer configuration.

**Example prompts:**
- "Show all failed services"
- "Restart the nginx service"
- "Show logs for ssh service"
- "Enable a service at boot"

### 🔒 Security Hardening
CIS benchmarks, fail2ban, SSH hardening, audit logging.

**Example prompts:**
- "Run a security audit"
- "Check SSH configuration"
- "Show failed login attempts"
- "Harden this server"

### 🌐 Network Manager
Interface configuration, DNS, routing, diagnostics.

**Example prompts:**
- "Show network interfaces"
- "Test connectivity to 8.8.8.8"
- "What's listening on port 80?"
- "Show routing table"

### 💾 Storage Manager
Disk management, mounts, LVM, SMART health monitoring.

**Example prompts:**
- "Show disk usage"
- "Check SMART health for all drives"
- "List mounted filesystems"
- "Show LVM volumes"

### 📦 Package Manager
apt package operations, system updates, cleanup.

**Example prompts:**
- "Check for updates"
- "Install nginx"
- "Show installed packages"
- "Clean up old packages"

### 👤 User Manager
User and group management, sudo configuration, SSH keys.

**Example prompts:**
- "List all users"
- "Add SSH key for user deploy"
- "Show who's logged in"
- "Check sudo permissions"

### 🛡️ Firewall Manager
UFW and iptables rule management.

**Example prompts:**
- "Show firewall status"
- "Allow port 443"
- "Block IP 10.0.0.5"
- "List all firewall rules"

### 💿 Backup Manager
Scheduled backups, verification, and recovery.

**Example prompts:**
- "Show backup status"
- "Create a backup of /etc"
- "List available backups"
- "Schedule daily backups at 2 AM"

---

## Skill Architecture

Each skill is a directory containing:

```
skill-name/
├── SKILL.md          # Skill definition and instructions
├── scripts/          # Optional helper scripts
│   ├── check.sh
│   └── report.sh
└── references/       # Optional reference docs
    └── commands.md
```

### SKILL.md Structure

The `SKILL.md` file is the core of every skill. It tells the AI agent:

1. **What** the skill does (description)
2. **When** to use it (triggers)
3. **How** to execute tasks (instructions, commands, scripts)
4. **What to watch out for** (safety, constraints)

```markdown
# Skill Name

## Description
What this skill does and when to use it.

## Capabilities
- List of things this skill can do
- With specific commands or approaches

## Instructions
Step-by-step guidance for common operations.

## Safety
- What NOT to do
- Confirmation requirements
- Destructive operation warnings
```

---

## Creating Custom Skills

### 1. Create the skill directory

```bash
mkdir -p /var/lib/cortexos/skills/my-custom-skill
```

### 2. Write the SKILL.md

```bash
cat > /var/lib/cortexos/skills/my-custom-skill/SKILL.md <<'EOF'
# My Custom Skill

## Description
Manages my custom application deployment.

## Capabilities
- Deploy new versions
- Check application health
- View application logs
- Rollback to previous version

## Instructions

### Deploy
1. Pull latest code from git
2. Run build command
3. Restart the service
4. Verify health endpoint

### Health Check
Run `curl -s http://localhost:3000/health` and report status.

### Logs
Show last 100 lines: `journalctl -u myapp -n 100`

## Safety
- Always create a backup before deploying
- Confirm with user before rollback
EOF
```

### 3. (Optional) Add helper scripts

```bash
mkdir -p /var/lib/cortexos/skills/my-custom-skill/scripts

cat > /var/lib/cortexos/skills/my-custom-skill/scripts/deploy.sh <<'EOF'
#!/bin/bash
set -euo pipefail
cd /opt/myapp
git pull
npm install --production
sudo systemctl restart myapp
curl -sf http://localhost:3000/health
EOF

chmod +x /var/lib/cortexos/skills/my-custom-skill/scripts/deploy.sh
```

### 4. Reload skills

```bash
sudo systemctl restart cortex-server
```

---

## Skill Best Practices

1. **Be specific** — The more detailed your SKILL.md instructions, the better the AI performs
2. **Include examples** — Show exact commands the AI should run
3. **Safety first** — Document what's dangerous and require confirmation
4. **Keep it focused** — One skill per domain; don't create a mega-skill
5. **Test thoroughly** — Try various prompts to make sure the skill responds correctly
6. **Use scripts** — For complex multi-step operations, write scripts and reference them

---

## Skill Bundles

CortexOS supports skill bundles for offline deployment:

```bash
# Build offline skill bundle
bash scripts/build-offline-bundle.sh --all

# Install bundle on air-gapped system
bash scripts/install-bundle.sh cortexos-skills-bundle.tar.gz
```

See [Air-Gapped Deployment](air-gapped.md) for details.
