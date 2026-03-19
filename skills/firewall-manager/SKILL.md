# firewall-manager — Firewall & Network Security

Manage UFW, iptables, fail2ban, and network security policies.

## Quick Reference

### UFW (Uncomplicated Firewall)
```bash
# Status
sudo ufw status verbose
sudo ufw status numbered

# Enable/disable
sudo ufw enable
sudo ufw disable

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow port
sudo ufw allow 22/tcp              # SSH
sudo ufw allow 80/tcp              # HTTP
sudo ufw allow 443/tcp             # HTTPS
sudo ufw allow 18789/tcp           # OpenClaw Gateway

# Allow from specific IP
sudo ufw allow from 192.168.1.0/24
sudo ufw allow from 192.168.1.100 to any port 22

# Allow port range
sudo ufw allow 8000:9000/tcp

# Deny
sudo ufw deny from 10.0.0.5
sudo ufw deny 3306/tcp             # Block MySQL externally

# Delete rule
sudo ufw delete allow 80/tcp
sudo ufw delete <number>           # By number from 'status numbered'

# Rate limiting (brute force protection)
sudo ufw limit ssh/tcp

# Logging
sudo ufw logging on
sudo ufw logging medium             # low/medium/high/full

# Reset all rules
sudo ufw reset
```

### iptables (Advanced)
```bash
# List all rules
sudo iptables -L -v -n --line-numbers

# List NAT rules
sudo iptables -t nat -L -v -n

# Save rules
sudo iptables-save > /etc/iptables/rules.v4

# Restore rules
sudo iptables-restore < /etc/iptables/rules.v4

# Flush all rules (DANGEROUS — drops all connections!)
sudo iptables -F

# Allow established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Block IP
sudo iptables -A INPUT -s <ip> -j DROP

# Port forwarding
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

# Log dropped packets
sudo iptables -A INPUT -j LOG --log-prefix "DROPPED: " --log-level 4
```

### fail2ban
```bash
# Install
sudo apt install -y fail2ban

# Status
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Active bans
sudo fail2ban-client get sshd banned

# Unban IP
sudo fail2ban-client set sshd unbanip <ip>

# Ban IP manually
sudo fail2ban-client set sshd banip <ip>

# Configuration
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Custom jail for SSH
sudo tee /etc/fail2ban/jail.d/sshd.conf << 'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
EOF

sudo systemctl restart fail2ban

# Check jail config
sudo fail2ban-client get sshd maxretry
sudo fail2ban-client get sshd bantime

# Recent ban activity
sudo grep "Ban " /var/log/fail2ban.log | tail -20
```

### Port Scanning & Analysis
```bash
# Check listening ports
ss -tulnp

# Check specific port
ss -tulnp | grep <port>

# Established connections
ss -tunap state established

# Connection count by remote IP
ss -tunap | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20

# Check for open ports from outside (if nmap available)
nmap -sT localhost

# Check what's on a port
sudo lsof -i :<port>
```

### GeoIP Blocking (Optional)
```bash
# Install xtables-addons for geoip
sudo apt install -y xtables-addons-common libtext-csv-xs-perl

# Download GeoIP database
sudo mkdir -p /usr/share/xt_geoip
sudo /usr/lib/xtables-addons/xt_geoip_dl
sudo /usr/lib/xtables-addons/xt_geoip_build -D /usr/share/xt_geoip

# Block country (example: block CN)
sudo iptables -A INPUT -m geoip --src-cc CN -j DROP
```

### Common Security Setups

#### Web Server (HTTP/HTTPS only)
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw limit ssh/tcp
sudo ufw enable
```

#### CortexOS Server
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp                    # SSH
sudo ufw allow 18789/tcp                 # OpenClaw Gateway
sudo ufw allow from 192.168.1.0/24      # Local network
sudo ufw limit ssh/tcp
sudo ufw enable
```

## Safety Rules

- **Never flush iptables on a remote server** without console access — you'll lock yourself out
- **Always allow SSH** before enabling firewall
- **Use `ufw limit`** for SSH — built-in brute force protection
- **Test firewall rules** before making them permanent
- **Keep fail2ban running** — automated ban for repeated failures
- **Log denied traffic** for security analysis
- **Default deny incoming** is the safest baseline
