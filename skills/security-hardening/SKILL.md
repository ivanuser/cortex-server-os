# Security Hardening Skill

Comprehensive security audit and hardening capabilities for OpenClaw agents managing server infrastructure.

## Description

This skill provides extensive security assessment and hardening automation for Linux servers. It includes vulnerability scanning, configuration auditing, and automated hardening measures with clear pass/fail/warning status reporting.

## Commands

### Security Auditing
- `security_audit` — Complete security posture assessment
- `security_ssh_check` — SSH-specific hardening verification
- `security_ports` — Open ports and listening services analysis
- `security_users` — User accounts and permissions audit  
- `security_updates` — Pending security updates check
- `security_firewall` — Firewall configuration assessment
- `security_permissions` — File permissions and SUID audit

### Hardening Actions
- `harden_ssh` — Apply SSH security best practices
- `harden_firewall` — Configure UFW with secure defaults
- `harden_updates` — Enable automatic security updates
- `harden_permissions` — Fix common permission vulnerabilities
- `security_report` — Generate comprehensive security report

## Scripts

### security_audit
```bash
#!/bin/bash
# security_audit - Complete security posture assessment
set -euo pipefail

REPORT_FILE="/tmp/security_audit_$(date +%Y%m%d_%H%M%S).txt"
SCORE=100
ISSUES=()

log_result() {
    local status="$1"
    local check="$2"
    local details="$3"
    local deduction="${4:-0}"
    
    case "$status" in
        "PASS")
            echo "✅ PASS: $check" | tee -a "$REPORT_FILE"
            ;;
        "WARN")
            echo "⚠️  WARN: $check - $details" | tee -a "$REPORT_FILE"
            SCORE=$((SCORE - deduction))
            ISSUES+=("$check")
            ;;
        "FAIL")
            echo "❌ FAIL: $check - $details" | tee -a "$REPORT_FILE"
            SCORE=$((SCORE - deduction))
            ISSUES+=("$check")
            ;;
    esac
}

echo "🔒 COMPREHENSIVE SECURITY AUDIT"
echo "==============================="
echo "Started: $(date)" | tee "$REPORT_FILE"
echo "Hostname: $(hostname)" | tee -a "$REPORT_FILE"
echo "Kernel: $(uname -r)" | tee -a "$REPORT_FILE"
echo | tee -a "$REPORT_FILE"

# SSH Security Check
echo "🔐 SSH CONFIGURATION" | tee -a "$REPORT_FILE"
echo "====================" | tee -a "$REPORT_FILE"

if [ -f /etc/ssh/sshd_config ]; then
    # Root login check
    root_login=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "yes")
    if [ "$root_login" = "no" ]; then
        log_result "PASS" "SSH Root Login Disabled"
    else
        log_result "FAIL" "SSH Root Login Enabled" "Root login should be disabled" 15
    fi
    
    # Password authentication check
    pass_auth=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}' || echo "yes")
    if [ "$pass_auth" = "no" ]; then
        log_result "PASS" "SSH Password Authentication Disabled"
    else
        log_result "WARN" "SSH Password Authentication Enabled" "Consider key-only auth" 10
    fi
    
    # SSH Protocol check
    protocol=$(grep -i "^Protocol" /etc/ssh/sshd_config | awk '{print $2}' 2>/dev/null || echo "2")
    if [ "$protocol" = "2" ]; then
        log_result "PASS" "SSH Protocol 2 Enabled"
    else
        log_result "FAIL" "SSH Protocol Not Set to 2" "Use only SSHv2" 10
    fi
    
    # Empty passwords check
    empty_pass=$(grep -i "^PermitEmptyPasswords" /etc/ssh/sshd_config | awk '{print $2}' || echo "no")
    if [ "$empty_pass" = "no" ]; then
        log_result "PASS" "SSH Empty Passwords Disabled"
    else
        log_result "FAIL" "SSH Empty Passwords Allowed" "Disable empty passwords" 15
    fi
    
    # SSH Port check
    ssh_port=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
    if [ "$ssh_port" != "22" ]; then
        log_result "PASS" "SSH Port Changed from Default" "Port $ssh_port"
    else
        log_result "WARN" "SSH Using Default Port 22" "Consider changing port" 5
    fi
else
    log_result "FAIL" "SSH Config File Missing" "/etc/ssh/sshd_config not found" 20
fi

echo | tee -a "$REPORT_FILE"

# Firewall Check
echo "🛡️  FIREWALL STATUS" | tee -a "$REPORT_FILE"
echo "==================" | tee -a "$REPORT_FILE"

if command -v ufw >/dev/null 2>&1; then
    ufw_status=$(ufw status | head -1 | awk '{print $2}')
    if [ "$ufw_status" = "active" ]; then
        log_result "PASS" "UFW Firewall Active"
        
        # Check for overly permissive rules
        permissive_rules=$(ufw status numbered | grep -c "0.0.0.0/0\|Anywhere" || echo 0)
        if [ "$permissive_rules" -gt 3 ]; then
            log_result "WARN" "UFW Has Many Permissive Rules" "$permissive_rules rules allow from anywhere" 5
        else
            log_result "PASS" "UFW Rules Reasonably Restrictive"
        fi
    else
        log_result "FAIL" "UFW Firewall Inactive" "Firewall should be enabled" 20
    fi
elif command -v iptables >/dev/null 2>&1; then
    iptables_rules=$(iptables -L | wc -l)
    if [ "$iptables_rules" -gt 8 ]; then
        log_result "PASS" "Iptables Rules Present" "$iptables_rules total rules"
    else
        log_result "WARN" "Minimal Iptables Rules" "Consider more restrictive rules" 15
    fi
else
    log_result "FAIL" "No Firewall Detected" "Install UFW or configure iptables" 25
fi

echo | tee -a "$REPORT_FILE"

# Open Ports Check
echo "🌐 OPEN PORTS ANALYSIS" | tee -a "$REPORT_FILE"
echo "======================" | tee -a "$REPORT_FILE"

open_ports=$(ss -tlnp | grep LISTEN | wc -l)
log_result "INFO" "Open Listening Ports" "$open_ports ports found"

# Check for risky open ports
risky_ports=()
ss -tlnp | grep LISTEN | while read -r line; do
    port=$(echo "$line" | awk '{print $4}' | cut -d':' -f2)
    case "$port" in
        "21")   # FTP
            risky_ports+=("FTP ($port)")
            ;;
        "23")   # Telnet
            risky_ports+=("Telnet ($port)")
            ;;
        "25")   # SMTP
            risky_ports+=("SMTP ($port)")
            ;;
        "53")   # DNS
            risky_ports+=("DNS ($port)")
            ;;
        "111")  # RPC
            risky_ports+=("RPC ($port)")
            ;;
        "139"|"445") # SMB
            risky_ports+=("SMB ($port)")
            ;;
        "3306") # MySQL
            risky_ports+=("MySQL ($port)")
            ;;
        "5432") # PostgreSQL
            risky_ports+=("PostgreSQL ($port)")
            ;;
        "6379") # Redis
            risky_ports+=("Redis ($port)")
            ;;
    esac
done

if [ ${#risky_ports[@]} -eq 0 ]; then
    log_result "PASS" "No High-Risk Ports Open"
else
    log_result "WARN" "High-Risk Ports Detected" "${risky_ports[*]}" 10
fi

echo | tee -a "$REPORT_FILE"

# User Account Security
echo "👤 USER ACCOUNT SECURITY" | tee -a "$REPORT_FILE"
echo "========================" | tee -a "$REPORT_FILE"

# Check for users with UID 0 (root privileges)
root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd | grep -v "^root$" | wc -l)
if [ "$root_users" -eq 0 ]; then
    log_result "PASS" "No Additional Root Users"
else
    additional_root=$(awk -F: '$3 == 0 {print $1}' /etc/passwd | grep -v "^root$" | tr '\n' ' ')
    log_result "FAIL" "Additional Root Users Found" "$additional_root" 15
fi

# Check for users with empty passwords
empty_passwd_users=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null | wc -l || echo 0)
if [ "$empty_passwd_users" -eq 0 ]; then
    log_result "PASS" "No Users with Empty Passwords"
else
    log_result "FAIL" "Users with Empty Passwords" "$empty_passwd_users users found" 20
fi

# Check for users with shell access
shell_users=$(grep -E "/bin/(bash|sh|zsh|fish)" /etc/passwd | wc -l)
log_result "INFO" "Users with Shell Access" "$shell_users users"

if [ "$shell_users" -gt 10 ]; then
    log_result "WARN" "Many Users with Shell Access" "Review necessity of shell access" 5
fi

echo | tee -a "$REPORT_FILE"

# File Permissions Check
echo "📂 FILE PERMISSIONS" | tee -a "$REPORT_FILE"
echo "==================" | tee -a "$REPORT_FILE"

# World-writable files in /etc
world_writable_etc=$(find /etc -type f -perm -002 2>/dev/null | wc -l)
if [ "$world_writable_etc" -eq 0 ]; then
    log_result "PASS" "No World-Writable Files in /etc"
else
    log_result "FAIL" "World-Writable Files in /etc" "$world_writable_etc files found" 15
fi

# SUID binaries check
suid_count=$(find /usr/bin /usr/sbin /bin /sbin -type f -perm -4000 2>/dev/null | wc -l)
log_result "INFO" "SUID Binaries Found" "$suid_count binaries"

# Check for unusual SUID binaries
unusual_suid=$(find / -type f -perm -4000 2>/dev/null | grep -v -E "(passwd|sudo|su|ping|mount|umount|chfn|chsh|newgrp)" | wc -l)
if [ "$unusual_suid" -eq 0 ]; then
    log_result "PASS" "No Unusual SUID Binaries"
else
    log_result "WARN" "Unusual SUID Binaries Found" "$unusual_suid binaries need review" 10
fi

# /tmp permissions
tmp_perms=$(stat -c %a /tmp 2>/dev/null || echo "000")
if [ "$tmp_perms" = "1777" ]; then
    log_result "PASS" "/tmp Permissions Correct"
else
    log_result "WARN" "/tmp Permissions Incorrect" "Should be 1777, found $tmp_perms" 5
fi

echo | tee -a "$REPORT_FILE"

# Security Updates Check
echo "🔄 SECURITY UPDATES" | tee -a "$REPORT_FILE"
echo "==================" | tee -a "$REPORT_FILE"

if command -v apt >/dev/null 2>&1; then
    # Update package list quietly
    apt list --upgradable 2>/dev/null | grep -i security | wc -l > /tmp/security_updates_count 2>/dev/null &
    sleep 2
    security_updates=$(cat /tmp/security_updates_count 2>/dev/null || echo "unknown")
    
    if [ "$security_updates" = "0" ]; then
        log_result "PASS" "No Pending Security Updates"
    elif [ "$security_updates" != "unknown" ] && [ "$security_updates" -gt 0 ]; then
        log_result "WARN" "Pending Security Updates" "$security_updates updates available" 10
    fi
    
    # Check if unattended-upgrades is enabled
    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
        if systemctl is-enabled unattended-upgrades >/dev/null 2>&1; then
            log_result "PASS" "Automatic Security Updates Enabled"
        else
            log_result "WARN" "Automatic Security Updates Disabled" "Enable unattended-upgrades" 5
        fi
    else
        log_result "WARN" "Unattended Upgrades Not Configured" "Consider enabling automatic updates" 5
    fi
elif command -v yum >/dev/null 2>&1; then
    security_updates=$(yum check-update --security 2>/dev/null | grep -c "updates" || echo 0)
    if [ "$security_updates" -eq 0 ]; then
        log_result "PASS" "No Pending Security Updates (YUM)"
    else
        log_result "WARN" "Pending Security Updates (YUM)" "$security_updates updates" 10
    fi
fi

echo | tee -a "$REPORT_FILE"

# Network Security
echo "🌐 NETWORK SECURITY" | tee -a "$REPORT_FILE"
echo "==================" | tee -a "$REPORT_FILE"

# Check for IP forwarding
ip_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "0")
if [ "$ip_forward" = "0" ]; then
    log_result "PASS" "IP Forwarding Disabled"
else
    log_result "WARN" "IP Forwarding Enabled" "May not be needed on most servers" 5
fi

# Check for ICMP redirects
icmp_redirects=$(cat /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null || echo "1")
if [ "$icmp_redirects" = "0" ]; then
    log_result "PASS" "ICMP Redirects Disabled"
else
    log_result "WARN" "ICMP Redirects Enabled" "Consider disabling for security" 5
fi

echo | tee -a "$REPORT_FILE"

# Log Analysis
echo "📋 LOG ANALYSIS" | tee -a "$REPORT_FILE"
echo "===============" | tee -a "$REPORT_FILE"

if [ -f /var/log/auth.log ]; then
    # Failed SSH attempts today
    today=$(date '+%b %d')
    failed_ssh_today=$(grep "Failed password" /var/log/auth.log | grep "$today" | wc -l)
    
    if [ "$failed_ssh_today" -eq 0 ]; then
        log_result "PASS" "No Failed SSH Attempts Today"
    elif [ "$failed_ssh_today" -lt 10 ]; then
        log_result "INFO" "Few Failed SSH Attempts" "$failed_ssh_today attempts today"
    elif [ "$failed_ssh_today" -lt 50 ]; then
        log_result "WARN" "Moderate SSH Attack Activity" "$failed_ssh_today failed attempts today" 5
    else
        log_result "FAIL" "High SSH Attack Activity" "$failed_ssh_today failed attempts today" 10
    fi
    
    # Successful SSH logins from unusual IPs
    unusual_ips=$(grep "Accepted password\|Accepted publickey" /var/log/auth.log | grep "$today" | \
        awk '{print $11}' | sort | uniq | grep -v "127.0.0.1\|192.168\|10\.\|172\." | wc -l)
    
    if [ "$unusual_ips" -eq 0 ]; then
        log_result "PASS" "No External SSH Logins Today"
    else
        log_result "WARN" "External SSH Logins Detected" "$unusual_ips unique external IPs" 5
    fi
elif [ -f /var/log/secure ]; then
    # RHEL/CentOS log location
    today=$(date '+%b %d')
    failed_ssh_today=$(grep "Failed password" /var/log/secure | grep "$today" | wc -l)
    if [ "$failed_ssh_today" -gt 20 ]; then
        log_result "WARN" "High SSH Attack Activity (RHEL)" "$failed_ssh_today failed attempts" 10
    fi
else
    log_result "INFO" "SSH Attack Analysis Skipped" "Log file not accessible"
fi

echo | tee -a "$REPORT_FILE"

# Final Security Score
echo "🎯 SECURITY ASSESSMENT SUMMARY" | tee -a "$REPORT_FILE"
echo "===============================" | tee -a "$REPORT_FILE"

# Ensure score doesn't go negative
if [ "$SCORE" -lt 0 ]; then
    SCORE=0
fi

echo "Security Score: $SCORE/100" | tee -a "$REPORT_FILE"

if [ "$SCORE" -ge 90 ]; then
    echo "✅ EXCELLENT - Strong security posture" | tee -a "$REPORT_FILE"
elif [ "$SCORE" -ge 75 ]; then
    echo "✅ GOOD - Minor improvements recommended" | tee -a "$REPORT_FILE"
elif [ "$SCORE" -ge 60 ]; then
    echo "⚠️  FAIR - Several security issues need attention" | tee -a "$REPORT_FILE"
elif [ "$SCORE" -ge 40 ]; then
    echo "⚠️  POOR - Significant security vulnerabilities" | tee -a "$REPORT_FILE"
else
    echo "❌ CRITICAL - Immediate security action required" | tee -a "$REPORT_FILE"
fi

if [ ${#ISSUES[@]} -gt 0 ]; then
    echo | tee -a "$REPORT_FILE"
    echo "🔧 ISSUES REQUIRING ATTENTION:" | tee -a "$REPORT_FILE"
    for issue in "${ISSUES[@]}"; do
        echo "  • $issue" | tee -a "$REPORT_FILE"
    done
    
    echo | tee -a "$REPORT_FILE"
    echo "💡 RECOMMENDED ACTIONS:" | tee -a "$REPORT_FILE"
    echo "  • Run 'harden_ssh' to secure SSH configuration" | tee -a "$REPORT_FILE"
    echo "  • Run 'harden_firewall' to configure UFW" | tee -a "$REPORT_FILE"
    echo "  • Run 'harden_updates' to enable automatic security updates" | tee -a "$REPORT_FILE"
    echo "  • Review and remove unnecessary user accounts" | tee -a "$REPORT_FILE"
    echo "  • Apply pending security updates" | tee -a "$REPORT_FILE"
fi

echo | tee -a "$REPORT_FILE"
echo "Full report saved to: $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "Generated: $(date)" | tee -a "$REPORT_FILE"

# Return non-zero exit code if score is poor
if [ "$SCORE" -lt 60 ]; then
    exit 1
fi
```

### harden_ssh
```bash
#!/bin/bash
# harden_ssh - Apply SSH security hardening
set -euo pipefail

SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"

if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root"
    echo "   Use: sudo harden_ssh"
    exit 1
fi

echo "🔐 SSH SECURITY HARDENING"
echo "========================="
echo "This will modify your SSH configuration for better security."
echo "A backup will be created at: $BACKUP_FILE"
echo

# Check if SSH config exists
if [ ! -f "$SSH_CONFIG" ]; then
    echo "❌ SSH configuration file not found: $SSH_CONFIG"
    exit 1
fi

# Create backup
echo "💾 Creating backup of SSH configuration..."
cp "$SSH_CONFIG" "$BACKUP_FILE"
echo "✅ Backup created: $BACKUP_FILE"

echo
echo "🔧 Applying SSH hardening settings..."

# Function to update or add SSH configuration
update_ssh_config() {
    local setting="$1"
    local value="$2"
    local config_file="$SSH_CONFIG"
    
    if grep -q "^#*$setting" "$config_file"; then
        # Setting exists (commented or not), replace it
        sed -i "s|^#*$setting.*|$setting $value|" "$config_file"
        echo "✅ Updated: $setting $value"
    else
        # Setting doesn't exist, add it
        echo "$setting $value" >> "$config_file"
        echo "✅ Added: $setting $value"
    fi
}

# Apply hardening settings
update_ssh_config "PermitRootLogin" "no"
update_ssh_config "PasswordAuthentication" "no"
update_ssh_config "PermitEmptyPasswords" "no"
update_ssh_config "X11Forwarding" "no"
update_ssh_config "MaxAuthTries" "3"
update_ssh_config "ClientAliveInterval" "300"
update_ssh_config "ClientAliveCountMax" "2"
update_ssh_config "Protocol" "2"
update_ssh_config "IgnoreRhosts" "yes"
update_ssh_config "HostbasedAuthentication" "no"
update_ssh_config "PermitUserEnvironment" "no"

# Add security-focused settings if not present
if ! grep -q "AllowUsers\|AllowGroups" "$SSH_CONFIG"; then
    echo
    echo "⚠️  Consider adding AllowUsers or AllowGroups to restrict SSH access"
    echo "   Example: AllowUsers username1 username2"
    echo "   Example: AllowGroups ssh-users"
fi

# Suggest changing default port
current_port=$(grep "^Port" "$SSH_CONFIG" | awk '{print $2}' || echo "22")
if [ "$current_port" = "22" ]; then
    echo
    echo "⚠️  SSH is still using default port 22"
    read -p "Change SSH port? (recommended) [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Enter new SSH port (1024-65535):"
        read -r new_port
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1024 ] && [ "$new_port" -le 65535 ]; then
            update_ssh_config "Port" "$new_port"
            echo "⚠️  IMPORTANT: SSH port changed to $new_port"
            echo "   Update firewall rules before disconnecting!"
            echo "   UFW: sudo ufw allow $new_port"
        else
            echo "❌ Invalid port number"
        fi
    fi
fi

echo
echo "🔍 Validating SSH configuration..."
if sshd -t; then
    echo "✅ SSH configuration is valid"
    
    echo
    echo "🔄 Restarting SSH service..."
    if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
        echo "✅ SSH service restarted successfully"
        
        echo
        echo "🎯 SSH HARDENING COMPLETE"
        echo "========================"
        echo "Applied security settings:"
        echo "  ✅ Root login disabled"
        echo "  ✅ Password authentication disabled"
        echo "  ✅ Empty passwords prohibited"
        echo "  ✅ X11 forwarding disabled"
        echo "  ✅ Max auth attempts: 3"
        echo "  ✅ Connection timeouts configured"
        
        echo
        echo "⚠️  IMPORTANT SECURITY NOTES:"
        echo "  • Ensure you have SSH key access before disconnecting"
        echo "  • Test SSH connection from another terminal"
        echo "  • Backup file available: $BACKUP_FILE"
        
        if [ "$current_port" != "22" ] && [ -n "${new_port:-}" ]; then
            echo "  • SSH port changed to $new_port - update firewall!"
        fi
    else
        echo "❌ Failed to restart SSH service"
        echo "⚠️  Restoring backup configuration..."
        cp "$BACKUP_FILE" "$SSH_CONFIG"
        echo "🔄 Attempting to restart SSH with original config..."
        systemctl restart sshd || systemctl restart ssh
        exit 1
    fi
else
    echo "❌ SSH configuration validation failed"
    echo "⚠️  Restoring backup..."
    cp "$BACKUP_FILE" "$SSH_CONFIG"
    echo "❌ Hardening aborted - original configuration restored"
    exit 1
fi
```

### harden_firewall
```bash
#!/bin/bash
# harden_firewall - Configure UFW with secure defaults
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root"
    echo "   Use: sudo harden_firewall"
    exit 1
fi

echo "🛡️  FIREWALL HARDENING"
echo "====================="

# Install UFW if not present
if ! command -v ufw >/dev/null 2>&1; then
    echo "📦 Installing UFW..."
    if command -v apt >/dev/null 2>&1; then
        apt update && apt install -y ufw
    elif command -v yum >/dev/null 2>&1; then
        yum install -y ufw
    else
        echo "❌ Cannot install UFW automatically"
        echo "   Please install UFW manually and run this script again"
        exit 1
    fi
fi

echo "🔧 Configuring UFW with secure defaults..."

# Reset UFW to defaults (in case it was configured before)
echo "🔄 Resetting UFW to defaults..."
ufw --force reset

# Set default policies
echo "🔒 Setting default policies..."
ufw default deny incoming
ufw default allow outgoing
ufw default deny forward

# Allow SSH (detect current SSH port)
ssh_port=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
echo "🔑 Allowing SSH on port $ssh_port..."
ufw allow "$ssh_port/tcp"

# Allow common necessary services with restrictions
echo "🌐 Configuring common service access..."

# Ask about each service
services=(
    "80:HTTP (web server)"
    "443:HTTPS (secure web)"
    "25:SMTP (email sending)"
    "587:SMTP submission"
    "993:IMAPS (secure email)"
    "995:POP3S (secure email)"
)

for service in "${services[@]}"; do
    port=$(echo "$service" | cut -d':' -f1)
    desc=$(echo "$service" | cut -d':' -f2)
    
    echo
    read -p "Allow $desc (port $port)? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ufw allow "$port/tcp"
        echo "✅ Allowed: $desc"
    fi
done

# Rate limiting for SSH
echo
echo "🛡️  Applying rate limiting to SSH..."
ufw limit "$ssh_port/tcp"

# Add some additional hardening rules
echo
echo "🔧 Applying additional security rules..."

# Deny all UDP except DNS
ufw allow out 53/udp
ufw allow out 123/udp  # NTP

# Allow loopback
ufw allow in on lo
ufw allow out on lo

# Log dropped packets
ufw logging on

echo
echo "🔍 UFW Configuration Summary:"
ufw --dry-run enable

echo
read -p "Apply this firewall configuration? [Y/n]: " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "🚀 Enabling UFW..."
    ufw --force enable
    
    echo
    echo "✅ FIREWALL HARDENING COMPLETE"
    echo "=============================="
    echo
    echo "UFW Status:"
    ufw status verbose
    
    echo
    echo "🎯 Security improvements applied:"
    echo "  ✅ Default deny incoming connections"
    echo "  ✅ Default allow outgoing connections"
    echo "  ✅ SSH access allowed on port $ssh_port"
    echo "  ✅ SSH rate limiting enabled"
    echo "  ✅ Logging enabled"
    
    echo
    echo "⚠️  IMPORTANT NOTES:"
    echo "  • Test your access before disconnecting"
    echo "  • Monitor logs: tail -f /var/log/ufw.log"
    echo "  • Add rules as needed: ufw allow <port>"
    echo "  • Current SSH port: $ssh_port"
else
    echo "❌ Firewall configuration cancelled"
fi
```

### security_ports
```bash
#!/bin/bash
# security_ports - Analyze open ports and listening services
set -euo pipefail

echo "🌐 OPEN PORTS SECURITY ANALYSIS"
echo "==============================="
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo

# Get all listening ports
echo "📋 LISTENING PORTS OVERVIEW"
echo "============================"
echo "Proto Local Address           Process"
echo "===== ==================== ==============================="

ss -tlnp | grep LISTEN | while IFS= read -r line; do
    proto=$(echo "$line" | awk '{print $1}')
    local_addr=$(echo "$line" | awk '{print $4}')
    process=$(echo "$line" | awk '{print $6}' | cut -d'"' -f2 | head -c 30)
    
    printf "%-5s %-20s %s\n" "$proto" "$local_addr" "$process"
done

echo
echo "🔍 SECURITY RISK ANALYSIS"
echo "=========================="

# Define risk categories
declare -A HIGH_RISK_PORTS=(
    ["21"]="FTP - Unencrypted file transfer"
    ["23"]="Telnet - Unencrypted remote access"
    ["25"]="SMTP - Email server (check if needed)"
    ["53"]="DNS - Potential amplification attacks"
    ["69"]="TFTP - Unencrypted file transfer"
    ["111"]="RPC - Remote procedure calls"
    ["135"]="Microsoft RPC"
    ["139"]="NetBIOS - Windows file sharing"
    ["445"]="SMB - Windows file sharing"
    ["512"]="rexec - Remote execution"
    ["513"]="rlogin - Remote login"
    ["514"]="rshell - Remote shell"
    ["1433"]="MS SQL Server"
    ["1521"]="Oracle Database"
    ["2049"]="NFS - Network File System"
    ["3389"]="RDP - Windows Remote Desktop"
    ["5900"]="VNC - Remote desktop"
    ["6000"]="X11 - X Window System"
)

declare -A MEDIUM_RISK_PORTS=(
    ["80"]="HTTP - Unencrypted web (use HTTPS)"
    ["143"]="IMAP - Unencrypted email"
    ["110"]="POP3 - Unencrypted email"
    ["161"]="SNMP - Network monitoring"
    ["993"]="IMAPS - Secure email (OK)"
    ["995"]="POP3S - Secure email (OK)"
    ["3306"]="MySQL - Database server"
    ["5432"]="PostgreSQL - Database server"
    ["6379"]="Redis - Database server"
    ["8080"]="HTTP Alt - Web server"
    ["9000"]="Various applications"
)

declare -A LOW_RISK_PORTS=(
    ["22"]="SSH - Secure remote access (OK)"
    ["443"]="HTTPS - Secure web (OK)"
    ["587"]="SMTP Submission - Secure email (OK)"
    ["993"]="IMAPS - Secure email (OK)"
    ["995"]="POP3S - Secure email (OK)"
)

# Analyze each open port
high_risk_found=0
medium_risk_found=0
unknown_ports=()

ss -tlnp | grep LISTEN | while IFS= read -r line; do
    local_addr=$(echo "$line" | awk '{print $4}')
    port=$(echo "$local_addr" | cut -d':' -f2)
    ip=$(echo "$local_addr" | cut -d':' -f1)
    process=$(echo "$line" | awk '{print $6}' | cut -d'"' -f2)
    
    # Skip if binding only to localhost
    if [[ "$ip" =~ ^127\. ]] || [[ "$ip" == "::1" ]]; then
        continue
    fi
    
    # Check risk level
    if [[ -n "${HIGH_RISK_PORTS[$port]:-}" ]]; then
        echo "🔴 HIGH RISK - Port $port: ${HIGH_RISK_PORTS[$port]}"
        echo "   Process: $process"
        echo "   Binding: $local_addr"
        high_risk_found=1
        echo
    elif [[ -n "${MEDIUM_RISK_PORTS[$port]:-}" ]]; then
        echo "🟡 MEDIUM RISK - Port $port: ${MEDIUM_RISK_PORTS[$port]}"
        echo "   Process: $process"
        echo "   Binding: $local_addr"
        medium_risk_found=1
        echo
    elif [[ -n "${LOW_RISK_PORTS[$port]:-}" ]]; then
        echo "🟢 LOW RISK - Port $port: ${LOW_RISK_PORTS[$port]}"
        echo "   Process: $process"
        echo
    else
        # Check if it's a common safe port range
        if [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
            unknown_ports+=("$port($process)")
        else
            echo "❓ UNKNOWN - Port $port: Review manually"
            echo "   Process: $process"
            echo "   Binding: $local_addr"
            echo
        fi
    fi
done > /tmp/port_analysis.txt

# Display results
cat /tmp/port_analysis.txt

# Summary and recommendations
echo "📊 ANALYSIS SUMMARY"
echo "==================="

high_count=$(grep -c "🔴 HIGH RISK" /tmp/port_analysis.txt || echo 0)
medium_count=$(grep -c "🟡 MEDIUM RISK" /tmp/port_analysis.txt || echo 0)
low_count=$(grep -c "🟢 LOW RISK" /tmp/port_analysis.txt || echo 0)
unknown_count=$(grep -c "❓ UNKNOWN" /tmp/port_analysis.txt || echo 0)

echo "High risk ports: $high_count"
echo "Medium risk ports: $medium_count"  
echo "Low risk ports: $low_count"
echo "Unknown ports: $unknown_count"

if [ "$high_count" -gt 0 ]; then
    echo
    echo "🚨 IMMEDIATE ACTION REQUIRED"
    echo "============================"
    echo "High-risk services detected. Consider:"
    echo "• Disabling unnecessary services"
    echo "• Restricting access with firewall rules"
    echo "• Using secure alternatives (SSH instead of Telnet)"
    echo "• Binding services to localhost if possible"
fi

if [ "$medium_count" -gt 0 ]; then
    echo
    echo "⚠️  RECOMMENDATIONS"
    echo "==================="
    echo "Medium-risk services found. Consider:"
    echo "• Using encrypted alternatives where possible"
    echo "• Restricting access to trusted networks"
    echo "• Regular security updates"
    echo "• Monitoring access logs"
fi

echo
echo "🔧 FIREWALL RECOMMENDATIONS"
echo "==========================="

# Check if UFW is active
if command -v ufw >/dev/null 2>&1; then
    ufw_status=$(ufw status | head -1 | awk '{print $2}')
    if [ "$ufw_status" = "active" ]; then
        echo "✅ UFW firewall is active"
        
        # Check for overly permissive rules
        echo
        echo "Current UFW rules:"
        ufw status numbered | grep -v "^Status:" | head -10
    else
        echo "❌ UFW firewall is inactive"
        echo "   Run 'harden_firewall' to configure secure defaults"
    fi
else
    echo "❌ UFW not installed"
    echo "   Install and configure: apt install ufw && harden_firewall"
fi

# Service-specific recommendations
echo
echo "💡 SERVICE-SPECIFIC RECOMMENDATIONS"
echo "===================================="

ss -tlnp | grep LISTEN | while IFS= read -r line; do
    port=$(echo "$line" | awk '{print $4}' | cut -d':' -f2)
    case "$port" in
        "21")
            echo "📂 FTP (21): Use SFTP (SSH) instead of FTP"
            ;;
        "23")
            echo "💻 Telnet (23): Use SSH (22) instead of Telnet"
            ;;
        "25")
            echo "📧 SMTP (25): Ensure proper authentication and TLS"
            ;;
        "3306")
            echo "🗄️  MySQL (3306): Bind to 127.0.0.1, use strong passwords"
            ;;
        "5432")
            echo "🗄️  PostgreSQL (5432): Configure pg_hba.conf properly"
            ;;
        "6379")
            echo "🗄️  Redis (6379): Enable authentication, consider TLS"
            ;;
    esac
done | sort | uniq

rm -f /tmp/port_analysis.txt
```

### security_users
```bash
#!/bin/bash
# security_users - User accounts and permissions audit
set -euo pipefail

echo "👤 USER SECURITY AUDIT"
echo "======================"
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo

# User account analysis
echo "📊 USER ACCOUNT OVERVIEW"
echo "========================"

total_users=$(wc -l < /etc/passwd)
shell_users=$(grep -E "/bin/(bash|sh|zsh|fish|csh|tcsh)" /etc/passwd | wc -l)
system_users=$(awk -F: '$3 < 1000 && $3 != 0 {print $1}' /etc/passwd | wc -l)
regular_users=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd | wc -l)

echo "Total users: $total_users"
echo "Users with shell access: $shell_users"
echo "System users: $system_users"
echo "Regular users (UID ≥ 1000): $regular_users"

echo
echo "🔍 SECURITY RISK ANALYSIS"
echo "=========================="

# Check for root privileges (UID 0)
echo "👑 USERS WITH ROOT PRIVILEGES (UID 0):"
root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
if [ -n "$root_users" ]; then
    echo "$root_users" | while read -r user; do
        if [ "$user" = "root" ]; then
            echo "✅ root (expected)"
        else
            echo "⚠️  $user (REVIEW NEEDED)"
        fi
    done
else
    echo "✅ Only root user has UID 0"
fi

echo
echo "🔑 PASSWORD SECURITY:"

# Check for empty passwords (requires shadow access)
if [ -r /etc/shadow ]; then
    empty_passwd=$(awk -F: '$2 == "" || $2 == "!" {print $1}' /etc/shadow 2>/dev/null | grep -v "^#" | wc -l)
    if [ "$empty_passwd" -eq 0 ]; then
        echo "✅ No users with empty passwords"
    else
        echo "⚠️  $empty_passwd user(s) with empty/disabled passwords:"
        awk -F: '$2 == "" || $2 == "!" {print "  " $1}' /etc/shadow 2>/dev/null | head -5
    fi
    
    # Check for weak password indicators
    weak_passwords=$(awk -F: 'length($2) < 10 && $2 != "!" && $2 != "*" {print $1}' /etc/shadow 2>/dev/null | wc -l)
    if [ "$weak_passwords" -gt 0 ]; then
        echo "⚠️  $weak_passwords user(s) may have weak passwords (short hashes)"
    fi
else
    echo "⚠️  Cannot access /etc/shadow - run as root for password analysis"
fi

echo
echo "🐚 SHELL ACCESS ANALYSIS:"
grep -E "/bin/(bash|sh|zsh|fish|csh|tcsh)" /etc/passwd | while IFS=: read -r username password uid gid gecos home shell; do
    last_login=""
    if command -v lastlog >/dev/null 2>&1; then
        last_login=$(lastlog -u "$username" 2>/dev/null | tail -1 | grep -v "Never" || echo "Never logged in")
    fi
    
    if [ "$uid" -ge 1000 ]; then
        echo "👤 $username (UID: $uid)"
        echo "   Home: $home"
        echo "   Shell: $shell"
        if [ -n "$last_login" ] && [ "$last_login" != "Never logged in" ]; then
            echo "   Last login: $last_login"
        else
            echo "   Last login: Never"
        fi
        
        # Check if home directory exists and permissions
        if [ -d "$home" ]; then
            home_perms=$(stat -c %a "$home" 2>/dev/null || echo "unknown")
            echo "   Home permissions: $home_perms"
            
            # Check for SSH keys
            if [ -f "$home/.ssh/authorized_keys" ]; then
                ssh_keys=$(wc -l < "$home/.ssh/authorized_keys" 2>/dev/null || echo 0)
                echo "   SSH keys: $ssh_keys"
            fi
        else
            echo "   ⚠️  Home directory does not exist"
        fi
        echo
    elif [ "$uid" -lt 1000 ] && [ "$uid" -ne 0 ]; then
        echo "⚠️  System user with shell: $username (UID: $uid)"
        echo
    fi
done

echo "🔐 SUDO PRIVILEGES:"
if [ -f /etc/sudoers ]; then
    # Check for users in sudo group
    sudo_group_users=$(getent group sudo 2>/dev/null | cut -d: -f4)
    if [ -n "$sudo_group_users" ]; then
        echo "Users in sudo group: $sudo_group_users"
    fi
    
    admin_group_users=$(getent group admin 2>/dev/null | cut -d: -f4)
    if [ -n "$admin_group_users" ]; then
        echo "Users in admin group: $admin_group_users"
    fi
    
    wheel_group_users=$(getent group wheel 2>/dev/null | cut -d: -f4)
    if [ -n "$wheel_group_users" ]; then
        echo "Users in wheel group: $wheel_group_users"
    fi
    
    # Check for NOPASSWD sudo entries
    nopasswd_users=$(grep "NOPASSWD" /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -v "^#" | wc -l)
    if [ "$nopasswd_users" -gt 0 ]; then
        echo "⚠️  $nopasswd_users NOPASSWD sudo entries found (review needed)"
    fi
else
    echo "⚠️  Cannot access /etc/sudoers"
fi

echo
echo "🏠 HOME DIRECTORY SECURITY:"
awk -F: '$3 >= 1000 {print $1 ":" $6}' /etc/passwd | while IFS=: read -r user home; do
    if [ -d "$home" ]; then
        perms=$(stat -c %a "$home")
        owner=$(stat -c %U "$home")
        
        # Check for world-readable home directories
        if [ "${perms:2:1}" -gt 0 ]; then
            echo "⚠️  $user: Home directory $home is world-accessible ($perms)"
        fi
        
        # Check if home directory is owned by user
        if [ "$owner" != "$user" ]; then
            echo "⚠️  $user: Home directory $home not owned by user (owned by $owner)"
        fi
        
        # Check for world-writable files in home
        if [ -d "$home" ]; then
            world_writable=$(find "$home" -type f -perm -002 2>/dev/null | wc -l)
            if [ "$world_writable" -gt 0 ]; then
                echo "⚠️  $user: $world_writable world-writable files in home directory"
            fi
        fi
    fi
done

echo
echo "🔑 SSH KEY ANALYSIS:"
ssh_key_users=0
for user_home in /home/*; do
    if [ -d "$user_home/.ssh" ]; then
        username=$(basename "$user_home")
        
        if [ -f "$user_home/.ssh/authorized_keys" ]; then
            key_count=$(wc -l < "$user_home/.ssh/authorized_keys")
            ssh_key_users=$((ssh_key_users + 1))
            echo "👤 $username: $key_count authorized SSH key(s)"
            
            # Check key permissions
            auth_keys_perms=$(stat -c %a "$user_home/.ssh/authorized_keys" 2>/dev/null)
            if [ "$auth_keys_perms" != "600" ] && [ "$auth_keys_perms" != "644" ]; then
                echo "   ⚠️  Incorrect authorized_keys permissions: $auth_keys_perms"
            fi
            
            # Check for weak key algorithms
            weak_keys=$(grep -E "(ssh-rsa|ssh-dss)" "$user_home/.ssh/authorized_keys" 2>/dev/null | wc -l || echo 0)
            if [ "$weak_keys" -gt 0 ]; then
                echo "   ⚠️  $weak_keys potentially weak key(s) (RSA/DSA - consider Ed25519)"
            fi
        fi
        
        # Check SSH directory permissions
        ssh_dir_perms=$(stat -c %a "$user_home/.ssh")
        if [ "$ssh_dir_perms" != "700" ]; then
            echo "   ⚠️  $username: Incorrect .ssh directory permissions: $ssh_dir_perms"
        fi
    fi
done

if [ "$ssh_key_users" -eq 0 ]; then
    echo "⚠️  No SSH keys found - users may be using password authentication"
fi

echo
echo "📊 ACCOUNT ACTIVITY:"
echo "==================="

# Recent login analysis
if command -v last >/dev/null 2>&1; then
    echo "Recent logins (last 10):"
    last -10 | head -10 | while read -r line; do
        if [[ "$line" =~ ^[a-zA-Z] ]]; then
            echo "  $line"
        fi
    done
fi

# Failed login attempts
if [ -f /var/log/auth.log ]; then
    today=$(date '+%b %d')
    failed_logins_today=$(grep "Failed password" /var/log/auth.log | grep "$today" | wc -l)
    if [ "$failed_logins_today" -gt 0 ]; then
        echo "⚠️  $failed_logins_today failed login attempts today"
        
        # Show top failed usernames
        echo "Most targeted usernames:"
        grep "Failed password" /var/log/auth.log | grep "$today" | \
            awk '{print $9}' | sort | uniq -c | sort -nr | head -5 | \
            while read -r count username; do
                echo "  $username: $count attempts"
            done
    fi
fi

echo
echo "💡 SECURITY RECOMMENDATIONS"
echo "==========================="

recommendations=()

if [ "$shell_users" -gt 5 ]; then
    recommendations+=("Review necessity of shell access for all users")
fi

if [ "$ssh_key_users" -eq 0 ]; then
    recommendations+=("Set up SSH key authentication and disable password auth")
fi

nopasswd_count=$(grep -c "NOPASSWD" /etc/sudoers /etc/sudoers.d/* 2>/dev/null || echo 0)
if [ "$nopasswd_count" -gt 0 ]; then
    recommendations+=("Review NOPASSWD sudo entries for security implications")
fi

if [ ${#recommendations[@]} -gt 0 ]; then
    for rec in "${recommendations[@]}"; do
        echo "  • $rec"
    done
else
    echo "✅ User security configuration appears reasonable"
fi

echo
echo "🔧 Quick fixes:"
echo "  • Remove unused user accounts: userdel -r <username>"
echo "  • Lock accounts: passwd -l <username>"
echo "  • Set up SSH keys: ssh-copy-id user@server"
echo "  • Review sudo access: visudo"
```

## Installation

Copy this skill to your OpenClaw skills directory:
```bash
cp -r security-hardening ~/.openclaw/skills/
```

Or install via ClawHub (when published):
```bash
openclaw skill install security-hardening
```

## Dependencies

- Standard Linux utilities (ss, grep, awk, etc.)
- UFW for firewall management (installed by harden_firewall if needed)
- Root access for hardening commands
- Optional: fail2ban for additional intrusion prevention

## Security Notes

- Hardening commands require root privileges
- SSH hardening creates backups before making changes
- Firewall changes can lock you out - test thoroughly
- Always maintain alternative access methods

## Integration Examples

### Automated Security Monitoring
Add to `HEARTBEAT.md`:
```bash
# Run security audit weekly
if [ "$(date +%u)" = "1" ] && [ "$(date +%H)" = "06" ]; then
    echo "🔒 Weekly security audit"
    if ! security_audit >/dev/null 2>&1; then
        echo "⚠️  Security issues detected"
        security_audit | tail -20
    fi
fi
```

### Alert Integration
```bash
# Alert on security score below threshold
score=$(security_audit | grep "Security Score:" | awk '{print $3}' | cut -d'/' -f1)
if [ "$score" -lt 75 ]; then
    echo "🚨 Security score below threshold: $score/100"
    security_report
fi
```

### Automated Hardening
```bash
# Apply basic hardening to new servers
if [ ! -f /var/log/security_hardened ]; then
    echo "🔒 Applying security hardening to new server"
    harden_ssh && harden_firewall && harden_updates
    touch /var/log/security_hardened
fi
```