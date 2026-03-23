#!/bin/bash
# CortexOS Compliance Scanner
# NIST 800-53 r5 + CMMC Level 1/2 control checks
# Outputs: /var/lib/cortexos/dashboard/compliance.json

DASHBOARD_DIR="/var/lib/cortexos/dashboard"
mkdir -p "$DASHBOARD_DIR"

python3 << 'PYEOF'
import json, subprocess, os, time, re, sys
from datetime import datetime, timezone

def cmd(c, timeout=15):
    try:
        return subprocess.check_output(c, shell=True, text=True, stderr=subprocess.DEVNULL, timeout=timeout).strip()
    except Exception:
        return ""

def file_exists(p):
    return os.path.isfile(p)

def file_read(p):
    try:
        with open(p) as f:
            return f.read()
    except Exception:
        return ""

def file_perm(p):
    try:
        return oct(os.stat(p).st_mode)[-3:]
    except Exception:
        return ""

results = []

# ═══════════════════════════════════════════════════════════
# AC - ACCESS CONTROL
# ═══════════════════════════════════════════════════════════

# AC-2: Account Management
def check_ac2():
    findings = []
    evidence = []
    status = "pass"

    # Check for unauthorized UID 0
    uid0 = cmd("awk -F: '$3 == 0 && $1 != \"root\" {print $1}' /etc/passwd")
    if uid0:
        findings.append(f"Unauthorized UID 0 accounts: {uid0}")
        evidence.append(f"UID 0: {uid0}")
        status = "fail"

    # Accounts with empty passwords
    empty_pw = cmd("awk -F: '($2 == \"\" || $2 == \"!\") {print $1}' /etc/shadow 2>/dev/null")
    # Filter out system accounts
    if empty_pw:
        real_empty = [u for u in empty_pw.split('\n') if u.strip() and u.strip() not in ('*', '')]
        # Check if they have login shells
        login_shells = cmd("awk -F: '$7 !~ /(nologin|false|sync|halt|shutdown)/ {print $1}' /etc/passwd").split('\n')
        empty_login = [u for u in real_empty if u in login_shells]
        if empty_login:
            findings.append(f"Accounts with no password: {', '.join(empty_login)}")
            evidence.append(f"No-password users: {', '.join(empty_login)}")
            status = "fail"

    # Check password expiration - PASS_MAX_DAYS in login.defs
    max_days = cmd("grep '^PASS_MAX_DAYS' /etc/login.defs 2>/dev/null | awk '{print $2}'")
    if not max_days or int(max_days or "99999") > 365:
        findings.append("No password expiration policy (PASS_MAX_DAYS > 365 or not set)")
        evidence.append(f"PASS_MAX_DAYS={max_days or 'not set'}")
        if status == "pass":
            status = "partial"

    # Check for inactive accounts (users with login shells but never logged in)
    inactive = cmd("lastlog 2>/dev/null | awk 'NR>1 && /Never logged in/ {print $1}'")
    login_users = cmd("awk -F: '$3>=1000 && $7!~/nologin|false/ {print $1}' /etc/passwd").split('\n')
    inactive_login = [u for u in (inactive.split('\n') if inactive else []) if u.strip() in login_users] if inactive else []
    if len(inactive_login) > 2:
        evidence.append(f"Never-logged-in accounts: {', '.join(inactive_login[:5])}")

    finding_text = "; ".join(findings) if findings else "All accounts properly managed"
    evidence_text = " | ".join(evidence) if evidence else "No issues found"
    remediation = "Lock unauthorized accounts: sudo passwd -l <user>; Set expiry: sudo chage -M 90 <user>" if status != "pass" else ""

    return {
        "id": "AC-2", "family": "AC", "title": "Account Management",
        "status": status, "severity": "high", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text, "remediation": remediation
    }

# AC-3: Access Enforcement
def check_ac3():
    findings = []
    evidence = []
    status = "pass"

    checks = {
        "/etc/passwd": ("644", "root"),
        "/etc/shadow": ("640", "root"),
        "/etc/group": ("644", "root"),
    }

    for path, (expected_perm, expected_owner) in checks.items():
        if not file_exists(path):
            continue
        perm = file_perm(path)
        owner = cmd(f"stat -c '%U' {path}")
        if int(perm) > int(expected_perm):
            findings.append(f"{path} has perm {perm} (expected ≤{expected_perm})")
            evidence.append(f"{path}={perm}")
            status = "fail"
        if owner and owner != expected_owner:
            findings.append(f"{path} owned by {owner} (expected {expected_owner})")
            status = "fail"

    # Check for world-writable files in /etc
    ww = cmd("find /etc -perm -002 -type f 2>/dev/null | head -10")
    if ww:
        count = len(ww.strip().split('\n'))
        findings.append(f"{count} world-writable files in /etc")
        evidence.append(f"World-writable: {ww.split(chr(10))[0]}...")
        status = "fail"

    # SSH config permissions
    sshd_perm = file_perm("/etc/ssh/sshd_config")
    if sshd_perm and int(sshd_perm) > 644:
        findings.append(f"sshd_config has perm {sshd_perm} (expected ≤644)")
        status = "fail"

    finding_text = "; ".join(findings) if findings else "Critical file permissions are correct"
    evidence_text = " | ".join(evidence) if evidence else "All permissions verified"
    remediation = "Fix permissions: sudo chmod 644 /etc/passwd; sudo chmod 640 /etc/shadow" if status != "pass" else ""

    return {
        "id": "AC-3", "family": "AC", "title": "Access Enforcement",
        "status": status, "severity": "high", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text, "remediation": remediation
    }

# AC-6: Least Privilege
def check_ac6():
    findings = []
    evidence = []
    status = "pass"

    # NOPASSWD in sudoers
    nopasswd = cmd("grep -r 'NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v '^#'")
    if nopasswd:
        count = len([l for l in nopasswd.split('\n') if l.strip()])
        findings.append(f"{count} NOPASSWD entries in sudoers")
        evidence.append(f"NOPASSWD found in sudoers")
        status = "fail"

    # Root login
    root_login = cmd("grep -i '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'")
    if root_login and root_login.lower() not in ('no', 'prohibit-password', 'forced-commands-only'):
        findings.append(f"SSH root login is '{root_login}'")
        evidence.append(f"PermitRootLogin={root_login}")
        status = "fail"

    # Number of sudo users
    sudo_users = cmd("getent group sudo 2>/dev/null | cut -d: -f4")
    wheel_users = cmd("getent group wheel 2>/dev/null | cut -d: -f4")
    all_sudo = [u for u in (sudo_users + "," + wheel_users).split(",") if u.strip()]
    if len(all_sudo) > 5:
        findings.append(f"Too many sudo/wheel users: {len(all_sudo)}")
        evidence.append(f"Sudo users: {', '.join(all_sudo[:5])}...")
        if status == "pass":
            status = "partial"

    finding_text = "; ".join(findings) if findings else "Least privilege controls properly configured"
    evidence_text = " | ".join(evidence) if evidence else "No issues"
    remediation = "Remove NOPASSWD entries from sudoers; Disable root SSH login" if status != "pass" else ""

    return {
        "id": "AC-6", "family": "AC", "title": "Least Privilege",
        "status": status, "severity": "high", "cmmc_level": 2,
        "finding": finding_text, "evidence": evidence_text, "remediation": remediation
    }

# AC-7: Unsuccessful Logon Attempts
def check_ac7():
    findings = []
    evidence = []
    status = "pass"

    faillock = cmd("grep -r 'pam_faillock\\|pam_tally2' /etc/pam.d/ 2>/dev/null")
    faillock_conf = file_read("/etc/security/faillock.conf")

    if not faillock and not faillock_conf:
        findings.append("No account lockout mechanism configured (faillock/pam_tally2)")
        status = "fail"
    else:
        evidence.append("Lockout mechanism detected in PAM config")
        if faillock_conf:
            deny_match = re.search(r'deny\s*=\s*(\d+)', faillock_conf)
            if deny_match:
                evidence.append(f"Lockout after {deny_match.group(1)} attempts")

    finding_text = "; ".join(findings) if findings else "Account lockout configured"
    evidence_text = " | ".join(evidence) if evidence else "faillock/pam_tally2 present"
    remediation = "Configure /etc/security/faillock.conf: deny=5 unlock_time=900" if status != "pass" else ""

    return {
        "id": "AC-7", "family": "AC", "title": "Unsuccessful Logon Attempts",
        "status": status, "severity": "medium", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text, "remediation": remediation
    }

# AC-8: System Use Notification
def check_ac8():
    findings = []
    evidence = []
    status = "pass"

    issue = file_read("/etc/issue").strip()
    issue_net = file_read("/etc/issue.net").strip()
    motd = file_read("/etc/motd").strip()

    has_banner = False
    for name, content in [("/etc/issue", issue), ("/etc/issue.net", issue_net), ("/etc/motd", motd)]:
        if content and len(content) > 20 and any(w in content.lower() for w in ['authorized', 'warning', 'notice', 'consent', 'monitor']):
            has_banner = True
            evidence.append(f"{name}: banner present ({len(content)} chars)")

    if not has_banner:
        findings.append("No login banner with authorized-use warning found")
        status = "fail"
        if issue:
            evidence.append(f"/etc/issue exists but may lack warning text ({len(issue)} chars)")

    # SSH banner
    ssh_banner = cmd("grep -i '^Banner' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'")
    if not ssh_banner or ssh_banner == "none":
        findings.append("SSH Banner not configured")
        if status == "pass":
            status = "partial"
    else:
        evidence.append(f"SSH Banner={ssh_banner}")

    finding_text = "; ".join(findings) if findings else "Login banners properly configured"
    evidence_text = " | ".join(evidence) if evidence else "Banners verified"
    remediation = "Set warning banner in /etc/issue and /etc/issue.net; Add 'Banner /etc/issue.net' to sshd_config" if status != "pass" else ""

    return {
        "id": "AC-8", "family": "AC", "title": "System Use Notification",
        "status": status, "severity": "low", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text, "remediation": remediation
    }

# AC-17: Remote Access
def check_ac17():
    findings = []
    evidence = []
    status = "pass"

    # Parse SSH config
    ssh_config = cmd("sshd -T 2>/dev/null") or file_read("/etc/ssh/sshd_config")

    checks = {
        "permitrootlogin": ("no", ["no", "prohibit-password", "forced-commands-only"]),
        "passwordauthentication": ("no", ["no"]),
        "permitemptypasswords": ("no", ["no"]),
        "x11forwarding": ("no", ["no"]),
        "maxauthtries": ("5", None),
    }

    for key, (ideal, allowed) in checks.items():
        val_match = re.search(rf'^{key}\s+(\S+)', ssh_config, re.MULTILINE | re.IGNORECASE)
        if val_match:
            val = val_match.group(1).lower()
            evidence.append(f"{key}={val}")
            if allowed and val not in allowed:
                findings.append(f"SSH {key} is '{val}' (expected {ideal})")
                status = "fail"
            elif key == "maxauthtries" and int(val) > 6:
                findings.append(f"SSH MaxAuthTries is {val} (expected ≤5)")
                status = "fail"
        elif key == "passwordauthentication":
            # Default is 'yes' which is insecure
            findings.append("SSH PasswordAuthentication defaults to yes")
            if status == "pass":
                status = "partial"

    # Check for insecure services
    insecure = cmd("ss -tlnp 2>/dev/null | grep -E ':23\\b|:21\\b|:5900\\b'")
    if insecure:
        findings.append("Insecure remote access services detected (telnet/ftp/vnc)")
        evidence.append(f"Insecure ports: {insecure[:100]}")
        status = "fail"

    finding_text = "; ".join(findings) if findings else "SSH and remote access properly configured"
    evidence_text = " | ".join(evidence) if evidence else "SSH config verified"
    remediation = "Harden sshd_config: PermitRootLogin no, PasswordAuthentication no, MaxAuthTries 5" if status != "pass" else ""

    return {
        "id": "AC-17", "family": "AC", "title": "Remote Access",
        "status": status, "severity": "high", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text, "remediation": remediation
    }


# ═══════════════════════════════════════════════════════════
# AU - AUDIT & ACCOUNTABILITY
# ═══════════════════════════════════════════════════════════

# AU-2: Event Logging
def check_au2():
    auditd_installed = bool(cmd("which auditd 2>/dev/null") or cmd("dpkg -l auditd 2>/dev/null | grep '^ii'") or cmd("rpm -q audit 2>/dev/null | grep -v 'not installed'"))
    auditd_running = cmd("systemctl is-active auditd 2>/dev/null") == "active"

    if auditd_installed and auditd_running:
        status = "pass"
        finding = "auditd installed and running"
        evidence = "auditd service: active"
    elif auditd_installed:
        status = "partial"
        finding = "auditd installed but not running"
        evidence = "auditd installed, service inactive"
    else:
        status = "fail"
        finding = "auditd not installed"
        evidence = "Package not found"

    return {
        "id": "AU-2", "family": "AU", "title": "Event Logging",
        "status": status, "severity": "high", "cmmc_level": 2,
        "finding": finding, "evidence": evidence,
        "remediation": "sudo apt install -y auditd && sudo systemctl enable --now auditd" if status != "pass" else ""
    }

# AU-3: Content of Audit Records
def check_au3():
    rules = cmd("auditctl -l 2>/dev/null")
    rule_files = cmd("cat /etc/audit/rules.d/*.rules 2>/dev/null") or cmd("cat /etc/audit/audit.rules 2>/dev/null")

    if not rules and not rule_files:
        if cmd("systemctl is-active auditd 2>/dev/null") != "active":
            return {
                "id": "AU-3", "family": "AU", "title": "Content of Audit Records",
                "status": "fail", "severity": "medium", "cmmc_level": 2,
                "finding": "auditd not running — no audit rules active",
                "evidence": "No rules", "remediation": "Install auditd and configure audit rules"
            }
    
    rule_text = rules or rule_files or ""
    key_rules = sum(1 for kw in ['passwd', 'shadow', 'sudoers', 'auth', 'login', 'execve', 'sshd']
                     if kw in rule_text.lower())

    if key_rules >= 3:
        status = "pass"
        finding = f"Audit rules configured covering {key_rules} key areas"
    elif key_rules >= 1:
        status = "partial"
        finding = f"Audit rules present but only cover {key_rules} key areas"
    else:
        status = "fail"
        finding = "No meaningful audit rules configured"

    rule_count = len([l for l in rule_text.split('\n') if l.strip() and not l.strip().startswith('#')])
    return {
        "id": "AU-3", "family": "AU", "title": "Content of Audit Records",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding, "evidence": f"{rule_count} audit rules loaded",
        "remediation": "Add audit rules for identity files, auth events, and privileged commands" if status != "pass" else ""
    }

# AU-6: Audit Review
def check_au6():
    tools = []
    if cmd("which logwatch 2>/dev/null"):
        tools.append("logwatch")
    if cmd("which aide 2>/dev/null"):
        tools.append("AIDE")
    if cmd("systemctl is-active wazuh-agent 2>/dev/null") == "active":
        tools.append("Wazuh")
    if cmd("dpkg -l rsyslog 2>/dev/null | grep '^ii'"):
        tools.append("rsyslog")

    # Check for centralized logging
    central = cmd("grep -r '@@\\|@[^@]' /etc/rsyslog.d/ /etc/rsyslog.conf 2>/dev/null | grep -v '^#' | head -3")

    if tools and (central or "Wazuh" in tools):
        status = "pass"
        finding = f"Log review tools: {', '.join(tools)}" + ("; centralized logging configured" if central else "")
    elif tools:
        status = "partial"
        finding = f"Log tools present ({', '.join(tools)}) but no centralized logging"
    else:
        status = "fail"
        finding = "No log monitoring/review tools detected"

    return {
        "id": "AU-6", "family": "AU", "title": "Audit Review, Analysis, and Reporting",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding, "evidence": f"Tools: {', '.join(tools) if tools else 'none'}",
        "remediation": "Install logwatch or configure Wazuh agent for log review" if status != "pass" else ""
    }

# AU-8: Time Stamps
def check_au8():
    synced = cmd("timedatectl 2>/dev/null | grep -i 'synchronized' | awk '{print $NF}'")
    ntp_svc = cmd("systemctl is-active chronyd 2>/dev/null") == "active" or \
              cmd("systemctl is-active ntp 2>/dev/null") == "active" or \
              cmd("systemctl is-active systemd-timesyncd 2>/dev/null") == "active"

    if ntp_svc and synced and synced.lower() == "yes":
        status = "pass"
        finding = "NTP synchronized"
    elif ntp_svc:
        status = "partial"
        finding = "NTP service running but sync status uncertain"
    else:
        status = "fail"
        finding = "No NTP service active"

    svc_name = "unknown"
    for s in ["chronyd", "ntp", "systemd-timesyncd"]:
        if cmd(f"systemctl is-active {s} 2>/dev/null") == "active":
            svc_name = s
            break

    return {
        "id": "AU-8", "family": "AU", "title": "Time Stamps",
        "status": status, "severity": "medium", "cmmc_level": 1,
        "finding": finding, "evidence": f"NTP service: {svc_name}, synced: {synced or 'unknown'}",
        "remediation": "sudo timedatectl set-ntp true; or install chrony" if status != "pass" else ""
    }

# AU-9: Protection of Audit Information
def check_au9():
    findings = []
    evidence = []
    status = "pass"

    log_checks = [
        ("/var/log/auth.log", "640"),
        ("/var/log/syslog", "640"),
        ("/var/log/audit/audit.log", "600"),
    ]

    for path, max_perm in log_checks:
        if not file_exists(path):
            continue
        perm = file_perm(path)
        if perm and int(perm) > int(max_perm):
            findings.append(f"{path} perm {perm} (expected ≤{max_perm})")
            status = "fail"
        evidence.append(f"{path}={perm or 'n/a'}")

    finding_text = "; ".join(findings) if findings else "Log file permissions are correct"
    evidence_text = " | ".join(evidence) if evidence else "Log files checked"

    return {
        "id": "AU-9", "family": "AU", "title": "Protection of Audit Information",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "Fix log permissions: sudo chmod 640 /var/log/auth.log; sudo chmod 600 /var/log/audit/audit.log" if status != "pass" else ""
    }

# AU-12: Audit Record Generation
def check_au12():
    rsyslog = cmd("systemctl is-active rsyslog 2>/dev/null") == "active"
    journald = cmd("systemctl is-active systemd-journald 2>/dev/null") == "active"

    journal_persistent = os.path.isdir("/var/log/journal")
    journal_conf = file_read("/etc/systemd/journald.conf")
    storage_persistent = "Storage=persistent" in journal_conf if journal_conf else False

    if (rsyslog or journald):
        if journal_persistent or storage_persistent or rsyslog:
            status = "pass"
            finding = f"Logging active: rsyslog={'yes' if rsyslog else 'no'}, journald={'yes' if journald else 'no'}, persistent={'yes' if (journal_persistent or storage_persistent) else 'no'}"
        else:
            status = "partial"
            finding = "Logging active but journal storage may be volatile"
    else:
        status = "fail"
        finding = "Neither rsyslog nor journald is running"

    return {
        "id": "AU-12", "family": "AU", "title": "Audit Record Generation",
        "status": status, "severity": "high", "cmmc_level": 2,
        "finding": finding, "evidence": f"rsyslog={rsyslog}, journald={journald}, persistent={journal_persistent or storage_persistent}",
        "remediation": "sudo systemctl enable --now rsyslog; configure persistent journald storage" if status != "pass" else ""
    }


# ═══════════════════════════════════════════════════════════
# CM - CONFIGURATION MANAGEMENT
# ═══════════════════════════════════════════════════════════

# CM-2: Baseline Configuration
def check_cm2():
    pkg_count = cmd("dpkg -l 2>/dev/null | grep '^ii' | wc -l") or cmd("rpm -qa 2>/dev/null | wc -l") or "0"
    svc_count = cmd("systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | wc -l") or "0"

    has_baseline = os.path.isdir("/var/lib/cortexos/baseline")
    has_cm_tool = bool(cmd("which ansible 2>/dev/null") or cmd("which puppet 2>/dev/null"))

    if has_baseline or has_cm_tool:
        status = "pass"
        finding = f"Baseline available: {pkg_count} packages, {svc_count} enabled services"
    else:
        status = "partial"
        finding = f"System inventoriable ({pkg_count} pkgs, {svc_count} svcs) but no baseline snapshot exists"

    return {
        "id": "CM-2", "family": "CM", "title": "Baseline Configuration",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding, "evidence": f"Packages: {pkg_count}, Services: {svc_count}, Baseline dir: {has_baseline}",
        "remediation": "Create baseline: sudo mkdir -p /var/lib/cortexos/baseline && dpkg -l > /var/lib/cortexos/baseline/packages.txt" if status != "pass" else ""
    }

# CM-6: Configuration Settings (kernel hardening)
def check_cm6():
    findings = []
    evidence = []
    status = "pass"

    sysctl_checks = {
        "net.ipv4.ip_forward": "0",
        "net.ipv4.conf.all.accept_redirects": "0",
        "net.ipv4.conf.all.send_redirects": "0",
        "net.ipv4.conf.all.accept_source_route": "0",
        "net.ipv4.tcp_syncookies": "1",
        "kernel.randomize_va_space": "2",
    }

    for param, expected in sysctl_checks.items():
        val = cmd(f"sysctl -n {param} 2>/dev/null").strip()
        if val != expected:
            # ip_forward may be intentional on routers/Docker hosts
            if param == "net.ipv4.ip_forward" and val == "1":
                # Check if Docker is running — ip_forward=1 is expected
                if cmd("systemctl is-active docker 2>/dev/null") == "active":
                    evidence.append(f"{param}={val} (Docker host — expected)")
                    continue
            findings.append(f"{param}={val} (expected {expected})")
            if status == "pass":
                status = "fail"
        else:
            evidence.append(f"{param}={val} ✓")

    finding_text = "; ".join(findings) if findings else "Kernel security parameters properly configured"
    evidence_text = " | ".join(evidence[:5]) if evidence else "Checked sysctl params"

    return {
        "id": "CM-6", "family": "CM", "title": "Configuration Settings",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "Apply hardening: sudo sysctl -w <param>=<value>; persist in /etc/sysctl.d/99-hardening.conf" if status != "pass" else ""
    }

# CM-7: Least Functionality
def check_cm7():
    findings = []
    evidence = []
    status = "pass"

    # Check for unnecessary services
    bad_svcs = cmd("systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | grep -iE 'telnet|rsh|xinetd|avahi|cups' | awk '{print $1}'")
    if bad_svcs:
        svc_list = [s.replace('.service', '') for s in bad_svcs.strip().split('\n') if s.strip()]
        findings.append(f"Unnecessary services running: {', '.join(svc_list)}")
        evidence.append(f"Running: {', '.join(svc_list)}")
        status = "fail"

    # Count open ports
    open_ports = cmd("ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | grep -oE '[0-9]+$' | sort -un")
    port_list = [p for p in open_ports.split('\n') if p.strip()] if open_ports else []
    evidence.append(f"Open ports: {len(port_list)}")

    if len(port_list) > 20:
        findings.append(f"High number of open ports: {len(port_list)}")
        if status == "pass":
            status = "partial"

    finding_text = "; ".join(findings) if findings else "No unnecessary services or excessive ports detected"
    evidence_text = " | ".join(evidence) if evidence else "Services and ports checked"

    return {
        "id": "CM-7", "family": "CM", "title": "Least Functionality",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "Disable unnecessary services: sudo systemctl disable --now <service>" if status != "pass" else ""
    }

# CM-8: System Component Inventory
def check_cm8():
    pkg_count = cmd("dpkg -l 2>/dev/null | grep '^ii' | wc -l") or cmd("rpm -qa 2>/dev/null | wc -l") or "0"
    os_info = cmd("cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"'") or "unknown"
    kernel = cmd("uname -r")

    return {
        "id": "CM-8", "family": "CM", "title": "System Component Inventory",
        "status": "pass", "severity": "low", "cmmc_level": 1,
        "finding": f"Inventory available: {os_info}, kernel {kernel}, {pkg_count} packages",
        "evidence": f"OS: {os_info} | Kernel: {kernel} | Packages: {pkg_count}",
        "remediation": ""
    }


# ═══════════════════════════════════════════════════════════
# IA - IDENTIFICATION & AUTHENTICATION
# ═══════════════════════════════════════════════════════════

# IA-2: Identification and Authentication
def check_ia2():
    findings = []
    evidence = []
    status = "pass"

    # Check for duplicate UIDs
    dup_uids = cmd("awk -F: '{print $3}' /etc/passwd | sort | uniq -d")
    if dup_uids:
        findings.append(f"Duplicate UIDs found: {dup_uids}")
        status = "fail"

    # Check for duplicate usernames
    dup_names = cmd("awk -F: '{print $1}' /etc/passwd | sort | uniq -d")
    if dup_names:
        findings.append(f"Duplicate usernames: {dup_names}")
        status = "fail"

    # Check accounts without passwords that have login shells
    no_pw = cmd("awk -F: '($2 == \"\" ) {print $1}' /etc/shadow 2>/dev/null")
    login_shells = cmd("awk -F: '$7 !~ /(nologin|false)/ {print $1}' /etc/passwd").split('\n')
    no_pw_login = [u for u in (no_pw.split('\n') if no_pw else []) if u.strip() in login_shells]
    if no_pw_login:
        findings.append(f"Accounts without authentication: {', '.join(no_pw_login)}")
        status = "fail"

    user_count = len([u for u in login_shells if u.strip()])
    evidence.append(f"Interactive accounts: {user_count}")
    if dup_uids:
        evidence.append(f"Dup UIDs: {dup_uids}")

    finding_text = "; ".join(findings) if findings else "All users properly identified with unique accounts"
    evidence_text = " | ".join(evidence) if evidence else "User IDs verified"

    return {
        "id": "IA-2", "family": "IA", "title": "Identification and Authentication",
        "status": status, "severity": "high", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "Fix duplicate UIDs and set passwords on all interactive accounts" if status != "pass" else ""
    }

# IA-5: Authenticator Management
def check_ia5():
    findings = []
    evidence = []
    status = "pass"

    # Password aging
    max_days = cmd("grep '^PASS_MAX_DAYS' /etc/login.defs 2>/dev/null | awk '{print $2}'") or "99999"
    min_days = cmd("grep '^PASS_MIN_DAYS' /etc/login.defs 2>/dev/null | awk '{print $2}'") or "0"
    min_len = cmd("grep '^PASS_MIN_LEN' /etc/login.defs 2>/dev/null | awk '{print $2}'") or "5"
    warn_age = cmd("grep '^PASS_WARN_AGE' /etc/login.defs 2>/dev/null | awk '{print $2}'") or "7"

    evidence.append(f"MAX_DAYS={max_days}, MIN_DAYS={min_days}, MIN_LEN={min_len}, WARN={warn_age}")

    if int(max_days) > 90:
        findings.append(f"PASS_MAX_DAYS={max_days} (should be ≤90)")
        status = "fail"
    if int(min_len) < 8:
        findings.append(f"PASS_MIN_LEN={min_len} (should be ≥8)")
        if status == "pass":
            status = "partial"

    # Check pwquality
    pwq = file_read("/etc/security/pwquality.conf")
    if pwq:
        minlen_match = re.search(r'minlen\s*=\s*(\d+)', pwq)
        if minlen_match:
            pwq_minlen = int(minlen_match.group(1))
            evidence.append(f"pwquality minlen={pwq_minlen}")
            if pwq_minlen < 12:
                findings.append(f"Password complexity minlen={pwq_minlen} (recommended ≥12)")
                if status == "pass":
                    status = "partial"
        else:
            evidence.append("pwquality.conf exists but minlen not set")
    else:
        findings.append("No password complexity configuration (pwquality.conf missing)")
        if status == "pass":
            status = "fail"

    # Password history
    remember = cmd("grep -r 'remember=' /etc/pam.d/ 2>/dev/null | head -1")
    if remember:
        evidence.append("Password history enforcement found")
    else:
        findings.append("No password history enforcement")
        if status == "pass":
            status = "partial"

    finding_text = "; ".join(findings) if findings else "Password policy properly configured"
    evidence_text = " | ".join(evidence) if evidence else "Password settings checked"

    return {
        "id": "IA-5", "family": "IA", "title": "Authenticator Management",
        "status": status, "severity": "high", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "Set PASS_MAX_DAYS=90 in /etc/login.defs; configure /etc/security/pwquality.conf" if status != "pass" else ""
    }

# IA-6: Authenticator Feedback
def check_ia6():
    # Standard Linux PAM handles password masking by default
    pam_unix = cmd("grep -r 'pam_unix' /etc/pam.d/common-password 2>/dev/null /etc/pam.d/system-auth 2>/dev/null")

    return {
        "id": "IA-6", "family": "IA", "title": "Authenticator Feedback",
        "status": "pass", "severity": "low", "cmmc_level": 1,
        "finding": "Password input is obscured by default (standard PAM behavior)",
        "evidence": "PAM unix module handles password masking",
        "remediation": ""
    }


# ═══════════════════════════════════════════════════════════
# SC - SYSTEM & COMMUNICATIONS PROTECTION
# ═══════════════════════════════════════════════════════════

# SC-7: Boundary Protection
def check_sc7():
    findings = []
    evidence = []
    status = "pass"

    # Check UFW
    ufw_status = cmd("ufw status 2>/dev/null")
    if "Status: active" in (ufw_status or ""):
        evidence.append("UFW: active")
        if "deny (incoming)" in ufw_status.lower() or "deny" in cmd("ufw status verbose 2>/dev/null | grep Default | head -1").lower():
            evidence.append("Default deny inbound")
        else:
            findings.append("UFW active but default policy may not be deny")
            status = "partial"
    else:
        # Check iptables
        ipt = cmd("iptables -L INPUT -n 2>/dev/null | head -1")
        nft = cmd("nft list ruleset 2>/dev/null | head -5")
        if ipt and "DROP" in ipt:
            evidence.append("iptables: default DROP")
        elif ipt and "ACCEPT" in ipt:
            findings.append("iptables default policy is ACCEPT (should be DROP)")
            status = "fail"
        elif nft and "drop" in nft.lower():
            evidence.append("nftables: rules present")
        else:
            findings.append("No firewall detected (UFW/iptables/nftables)")
            status = "fail"

    finding_text = "; ".join(findings) if findings else "Firewall active with proper default-deny policy"
    evidence_text = " | ".join(evidence) if evidence else "Firewall status checked"

    return {
        "id": "SC-7", "family": "SC", "title": "Boundary Protection",
        "status": status, "severity": "high", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "sudo ufw default deny incoming && sudo ufw enable" if status != "pass" else ""
    }

# SC-8: Transmission Confidentiality and Integrity
def check_sc8():
    findings = []
    evidence = []
    status = "pass"

    ciphers = cmd("sshd -T 2>/dev/null | grep '^ciphers '") or cmd("grep -i '^Ciphers' /etc/ssh/sshd_config 2>/dev/null")
    weak_ciphers = ['arcfour', 'blowfish', '3des', 'cast128']

    if ciphers:
        ciphers_lower = ciphers.lower()
        weak_found = [c for c in weak_ciphers if c in ciphers_lower]
        if weak_found:
            findings.append(f"Weak SSH ciphers available: {', '.join(weak_found)}")
            status = "fail"
        else:
            evidence.append("SSH ciphers: no weak algorithms")

        # Check for CBC mode
        if '-cbc' in ciphers_lower:
            findings.append("CBC mode ciphers available in SSH")
            if status == "pass":
                status = "partial"
    else:
        evidence.append("Using SSH default ciphers")

    # Check MACs
    macs = cmd("sshd -T 2>/dev/null | grep '^macs '")
    if macs and 'md5' in macs.lower():
        findings.append("MD5-based MACs available in SSH")
        if status == "pass":
            status = "partial"

    finding_text = "; ".join(findings) if findings else "SSH encryption properly configured with strong algorithms"
    evidence_text = " | ".join(evidence) if evidence else "SSH crypto checked"

    return {
        "id": "SC-8", "family": "SC", "title": "Transmission Confidentiality and Integrity",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "Restrict SSH ciphers to AES-GCM/ChaCha20 in sshd_config" if status != "pass" else ""
    }

# SC-13: Cryptographic Protection
def check_sc13():
    findings = []
    evidence = []
    status = "pass"

    # Check SSH host key strengths
    keys = cmd("for f in /etc/ssh/ssh_host_*_key.pub; do ssh-keygen -l -f \"$f\" 2>/dev/null; done")
    if keys:
        for line in keys.strip().split('\n'):
            if not line.strip():
                continue
            parts = line.split()
            if len(parts) >= 2:
                bits = int(parts[0])
                key_type = parts[-1].strip('()') if '(' in parts[-1] else 'unknown'
                evidence.append(f"{key_type}: {bits} bits")
                if key_type == "RSA" and bits < 2048:
                    findings.append(f"RSA key too short: {bits} bits (minimum 2048)")
                    status = "fail"
                elif key_type == "DSA":
                    findings.append("DSA key found (deprecated)")
                    status = "fail"

    # OpenSSL version
    openssl_ver = cmd("openssl version 2>/dev/null")
    if openssl_ver:
        evidence.append(f"OpenSSL: {openssl_ver}")

    finding_text = "; ".join(findings) if findings else "Cryptographic algorithms meet minimum standards"
    evidence_text = " | ".join(evidence) if evidence else "Crypto checked"

    return {
        "id": "SC-13", "family": "SC", "title": "Cryptographic Protection",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "Regenerate weak keys: sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''" if status != "pass" else ""
    }

# SC-28: Protection of Information at Rest
def check_sc28():
    luks = cmd("lsblk -f 2>/dev/null | grep -i 'crypto\\|luks'")
    dm_crypt = cmd("dmsetup status 2>/dev/null | grep -i crypt")
    blkid_crypto = cmd("blkid 2>/dev/null | grep -i crypto_LUKS")

    has_encryption = bool(luks or dm_crypt or blkid_crypto)

    if has_encryption:
        status = "pass"
        finding = "Disk encryption detected (LUKS/dm-crypt)"
        evidence = luks or dm_crypt or blkid_crypto
        evidence = evidence[:200] if evidence else "Encrypted volumes found"
    else:
        # Check if this is a VM — encryption may be handled by hypervisor
        is_vm = bool(cmd("systemd-detect-virt 2>/dev/null"))
        if is_vm:
            status = "na"
            finding = "VM detected — disk encryption may be managed by hypervisor"
            evidence = f"Virtualization: {cmd('systemd-detect-virt 2>/dev/null')}"
        else:
            status = "fail"
            finding = "No disk encryption detected on physical host"
            evidence = "No LUKS/dm-crypt volumes found"

    return {
        "id": "SC-28", "family": "SC", "title": "Protection of Information at Rest",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding, "evidence": evidence,
        "remediation": "Enable full disk encryption at install time or encrypt sensitive partitions with LUKS" if status == "fail" else ""
    }


# ═══════════════════════════════════════════════════════════
# SI - SYSTEM & INFORMATION INTEGRITY
# ═══════════════════════════════════════════════════════════

# SI-2: Flaw Remediation
def check_si2():
    findings = []
    evidence = []
    status = "pass"

    # Pending updates
    updates = cmd("apt list --upgradable 2>/dev/null | grep -v '^Listing'")
    update_count = len([l for l in updates.split('\n') if l.strip()]) if updates else 0
    evidence.append(f"Pending updates: {update_count}")

    if update_count > 20:
        findings.append(f"{update_count} pending updates")
        status = "fail"
    elif update_count > 5:
        findings.append(f"{update_count} pending updates")
        if status == "pass":
            status = "partial"

    # Security updates specifically
    sec_updates = cmd("apt list --upgradable 2>/dev/null | grep -i security | wc -l") or "0"
    if int(sec_updates) > 0:
        findings.append(f"{sec_updates} pending security updates")
        evidence.append(f"Security updates: {sec_updates}")
        if status == "pass":
            status = "partial"

    # Unattended upgrades
    ua = cmd("dpkg -l unattended-upgrades 2>/dev/null | grep '^ii'")
    if ua:
        evidence.append("unattended-upgrades: installed")
    else:
        findings.append("unattended-upgrades not installed")
        if status == "pass":
            status = "partial"

    # Kernel
    kernel = cmd("uname -r")
    evidence.append(f"Kernel: {kernel}")

    finding_text = "; ".join(findings) if findings else "System is up to date"
    evidence_text = " | ".join(evidence) if evidence else "Update status checked"

    return {
        "id": "SI-2", "family": "SI", "title": "Flaw Remediation",
        "status": status, "severity": "high", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "sudo apt update && sudo apt upgrade -y; install unattended-upgrades" if status != "pass" else ""
    }

# SI-3: Malicious Code Protection
def check_si3():
    findings = []
    evidence = []
    status = "pass"

    has_av = False
    if cmd("which clamscan 2>/dev/null") or cmd("dpkg -l clamav 2>/dev/null | grep '^ii'"):
        has_av = True
        evidence.append("ClamAV: installed")
        freshclam = cmd("systemctl is-active clamav-freshclam 2>/dev/null")
        if freshclam == "active":
            evidence.append("freshclam: active")
        else:
            findings.append("ClamAV definitions updater (freshclam) not running")
            status = "partial"
    
    if cmd("which rkhunter 2>/dev/null"):
        has_av = True
        evidence.append("rkhunter: installed")
    
    if cmd("which chkrootkit 2>/dev/null"):
        has_av = True
        evidence.append("chkrootkit: installed")

    if not has_av:
        findings.append("No antivirus/malware detection installed")
        status = "fail"

    finding_text = "; ".join(findings) if findings else "Malware protection tools installed and active"
    evidence_text = " | ".join(evidence) if evidence else "AV checked"

    return {
        "id": "SI-3", "family": "SI", "title": "Malicious Code Protection",
        "status": status, "severity": "medium", "cmmc_level": 1,
        "finding": finding_text, "evidence": evidence_text,
        "remediation": "sudo apt install -y clamav clamav-daemon && sudo freshclam && sudo systemctl enable --now clamav-freshclam" if status != "pass" else ""
    }

# SI-4: System Monitoring
def check_si4():
    tools = []
    if cmd("systemctl is-active cortexos-stats.timer 2>/dev/null") == "active":
        tools.append("CortexOS stats")
    if cmd("which node_exporter 2>/dev/null") or cmd("systemctl is-active prometheus-node-exporter 2>/dev/null") == "active":
        tools.append("Prometheus node_exporter")
    if cmd("systemctl is-active wazuh-agent 2>/dev/null") == "active":
        tools.append("Wazuh agent")
    if cmd("systemctl is-active zabbix-agent2 2>/dev/null") == "active" or cmd("systemctl is-active zabbix-agent 2>/dev/null") == "active":
        tools.append("Zabbix agent")

    # Check stats freshness
    stats_file = "/var/lib/cortexos/dashboard/stats.json"
    stats_fresh = False
    if file_exists(stats_file):
        try:
            age = time.time() - os.path.getmtime(stats_file)
            stats_fresh = age < 300  # 5 minutes
        except:
            pass

    if tools and stats_fresh:
        status = "pass"
        finding = f"Monitoring active: {', '.join(tools)}"
    elif tools:
        status = "partial"
        finding = f"Monitoring tools present ({', '.join(tools)}) but stats may be stale"
    else:
        status = "fail"
        finding = "No system monitoring tools detected"

    return {
        "id": "SI-4", "family": "SI", "title": "System Monitoring",
        "status": status, "severity": "medium", "cmmc_level": 2,
        "finding": finding, "evidence": f"Tools: {', '.join(tools) if tools else 'none'}, stats_fresh: {stats_fresh}",
        "remediation": "Enable CortexOS monitoring: sudo systemctl enable --now cortexos-stats.timer" if status != "pass" else ""
    }

# SI-5: Security Alerts
def check_si5():
    tools = []
    if cmd("which apticron 2>/dev/null"):
        tools.append("apticron")
    if cmd("dpkg -l apt-listchanges 2>/dev/null | grep '^ii'"):
        tools.append("apt-listchanges")
    if cmd("dpkg -l update-notifier-common 2>/dev/null | grep '^ii'"):
        tools.append("update-notifier")
    if cmd("which needrestart 2>/dev/null"):
        tools.append("needrestart")
    if cmd("dpkg -l unattended-upgrades 2>/dev/null | grep '^ii'"):
        ua_conf = file_read("/etc/apt/apt.conf.d/50unattended-upgrades")
        if ua_conf and "mail" in ua_conf.lower():
            tools.append("unattended-upgrades (email configured)")
        else:
            tools.append("unattended-upgrades")

    if len(tools) >= 2:
        status = "pass"
        finding = f"Security notification tools: {', '.join(tools)}"
    elif tools:
        status = "partial"
        finding = f"Partial notification: {', '.join(tools)}"
    else:
        status = "fail"
        finding = "No security alert/notification tools configured"

    return {
        "id": "SI-5", "family": "SI", "title": "Security Alerts, Advisories, and Directives",
        "status": status, "severity": "low", "cmmc_level": 1,
        "finding": finding, "evidence": f"Tools: {', '.join(tools) if tools else 'none'}",
        "remediation": "sudo apt install -y apticron apt-listchanges; configure email in /etc/apticron/apticron.conf" if status != "pass" else ""
    }


# ═══════════════════════════════════════════════════════════
# RUN ALL CHECKS
# ═══════════════════════════════════════════════════════════

all_checks = [
    check_ac2, check_ac3, check_ac6, check_ac7, check_ac8, check_ac17,
    check_au2, check_au3, check_au6, check_au8, check_au9, check_au12,
    check_cm2, check_cm6, check_cm7, check_cm8,
    check_ia2, check_ia5, check_ia6,
    check_sc7, check_sc8, check_sc13, check_sc28,
    check_si2, check_si3, check_si4, check_si5
]

for check_fn in all_checks:
    try:
        result = check_fn()
        results.append(result)
    except Exception as e:
        # If a check crashes, record it as error
        fn_name = check_fn.__name__
        ctrl_id = fn_name.replace('check_', '').upper().replace('_', '-')
        results.append({
            "id": ctrl_id, "family": ctrl_id.split('-')[0],
            "title": f"Check Error: {fn_name}",
            "status": "fail", "severity": "high", "cmmc_level": 1,
            "finding": f"Check failed with error: {str(e)}",
            "evidence": str(e), "remediation": "Investigate check error"
        })


# ═══════════════════════════════════════════════════════════
# COMPILE RESULTS
# ═══════════════════════════════════════════════════════════

total = len(results)
pass_count = sum(1 for r in results if r["status"] == "pass")
fail_count = sum(1 for r in results if r["status"] == "fail")
partial_count = sum(1 for r in results if r["status"] == "partial")
na_count = sum(1 for r in results if r["status"] == "na")

# Score: pass = 1.0, partial = 0.5, na excluded
scoreable = total - na_count
score_raw = pass_count + (partial_count * 0.5)
score_pct = int(round(score_raw / scoreable * 100)) if scoreable > 0 else 0

# Family breakdown
families = {}
for r in results:
    fam = r["family"]
    if fam not in families:
        families[fam] = {"pass": 0, "fail": 0, "partial": 0, "na": 0, "total": 0}
    families[fam]["total"] += 1
    families[fam][r["status"]] = families[fam].get(r["status"], 0) + 1

# CMMC mapping
# Level 1 controls (basic cyber hygiene)
cmmc_l1_ids = {"AC-2", "AC-3", "AC-7", "AC-8", "AC-17", "AU-8", "CM-8", "IA-2", "IA-5", "IA-6", "SC-7", "SI-2", "SI-3", "SI-5"}
# Level 2 = all controls
cmmc_l1_controls = [r for r in results if r["id"] in cmmc_l1_ids]
cmmc_l2_controls = results

cmmc_l1_pass = sum(1 for r in cmmc_l1_controls if r["status"] == "pass")
cmmc_l1_total = len(cmmc_l1_controls)
cmmc_l2_pass = pass_count
cmmc_l2_total = total

output = {
    "scan_time": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "framework": "NIST-800-53-r5",
    "summary": {
        "total_controls": total,
        "pass": pass_count,
        "fail": fail_count,
        "partial": partial_count,
        "na": na_count,
        "score_percent": score_pct
    },
    "cmmc": {
        "level1": {
            "total": cmmc_l1_total,
            "pass": cmmc_l1_pass,
            "score": int(round(cmmc_l1_pass / cmmc_l1_total * 100)) if cmmc_l1_total > 0 else 0
        },
        "level2": {
            "total": cmmc_l2_total,
            "pass": cmmc_l2_pass,
            "score": int(round(cmmc_l2_pass / cmmc_l2_total * 100)) if cmmc_l2_total > 0 else 0
        }
    },
    "families": {k: {"pass": v["pass"], "fail": v["fail"], "partial": v.get("partial", 0), "total": v["total"]} for k, v in families.items()},
    "controls": results,
    "ts": int(time.time())
}

dashboard = os.environ.get("DASHBOARD_DIR", "/var/lib/cortexos/dashboard")
os.makedirs(dashboard, exist_ok=True)
with open(f"{dashboard}/compliance.json", "w") as f:
    json.dump(output, f, indent=2)

print(f"Compliance scan complete: {score_pct}% — {pass_count}/{total} pass, {fail_count} fail, {partial_count} partial, {na_count} n/a")
PYEOF
