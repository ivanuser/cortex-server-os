#!/bin/bash
# CortexOS System Info Collector
# Generates JSON files for dashboard panels (services, docker, network, packages, logs)
# Run by cortexos-stats timer every 30 seconds

DASHBOARD_DIR="/var/lib/cortexos/dashboard"
mkdir -p "$DASHBOARD_DIR"

python3 -c "
import json, subprocess, os, time

def cmd(c):
    try:
        return subprocess.check_output(c, shell=True, text=True, stderr=subprocess.DEVNULL, timeout=10).strip()
    except:
        return ''

ts = int(time.time())
dashboard = '$DASHBOARD_DIR'

# ═══════════════════════════════════════════════════════════
# SERVICES
# ═══════════════════════════════════════════════════════════
try:
    lines = cmd('systemctl list-units --type=service --no-pager --no-legend --all').split('\n')
    services = []
    running = failed = inactive = 0
    for line in lines:
        if not line.strip():
            continue
        parts = line.split()
        if len(parts) < 4:
            continue
        name = parts[0].replace('.service', '').lstrip('●').strip()
        if not name:
            continue
        load_state = parts[1] if len(parts) > 1 else 'unknown'
        active_state = parts[2] if len(parts) > 2 else 'unknown'
        sub_state = parts[3] if len(parts) > 3 else 'unknown'
        desc = ' '.join(parts[4:]) if len(parts) > 4 else ''
        
        status = 'running' if sub_state == 'running' else 'failed' if sub_state == 'failed' else 'exited' if sub_state == 'exited' else 'inactive' if active_state == 'inactive' else sub_state
        
        services.append({
            'name': name,
            'status': status,
            'active': active_state,
            'sub': sub_state,
            'description': desc
        })
        if sub_state == 'running':
            running += 1
        elif sub_state == 'failed':
            failed += 1
        elif active_state == 'inactive':
            inactive += 1
    
    json.dump({
        'services': services,
        'running': running,
        'failed': failed,
        'inactive': inactive,
        'total': len(services),
        'ts': ts
    }, open(os.path.join(dashboard, 'services.json'), 'w'))
except Exception as e:
    json.dump({'services': [], 'running': 0, 'failed': 0, 'error': str(e), 'ts': ts}, open(os.path.join(dashboard, 'services.json'), 'w'))

# ═══════════════════════════════════════════════════════════
# DOCKER
# ═══════════════════════════════════════════════════════════
try:
    docker_path = cmd('which docker')
    if docker_path:
        lines = cmd(\"docker ps -a --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}' 2>/dev/null\").split('\n')
        containers = []
        for line in lines:
            if not line.strip():
                continue
            parts = line.split('|')
            if len(parts) >= 4:
                status_str = parts[3].strip().lower()
                status = 'running' if status_str.startswith('up') else 'exited' if 'exited' in status_str else 'restarting' if 'restarting' in status_str else 'dead' if 'dead' in status_str else status_str
                containers.append({
                    'id': parts[0].strip(),
                    'name': parts[1].strip(),
                    'image': parts[2].strip(),
                    'status': parts[3].strip(),
                    'status_short': status,
                    'ports': parts[4].strip() if len(parts) > 4 else ''
                })
        
        json.dump({
            'installed': True,
            'containers': containers,
            'running': sum(1 for c in containers if c['status_short'] == 'running'),
            'total': len(containers),
            'ts': ts
        }, open(os.path.join(dashboard, 'docker.json'), 'w'))
    else:
        json.dump({'installed': False, 'ts': ts}, open(os.path.join(dashboard, 'docker.json'), 'w'))
except Exception as e:
    json.dump({'installed': False, 'error': str(e), 'ts': ts}, open(os.path.join(dashboard, 'docker.json'), 'w'))

# ═══════════════════════════════════════════════════════════
# NETWORK
# ═══════════════════════════════════════════════════════════
try:
    # Interfaces
    iface_lines = cmd('ip -br addr').split('\n')
    interfaces = []
    for line in iface_lines:
        if not line.strip():
            continue
        parts = line.split()
        if len(parts) >= 2:
            name = parts[0]
            status = parts[1]
            ips = ' '.join(parts[2:]) if len(parts) > 2 else ''
            # Get MAC address
            mac = cmd(f'cat /sys/class/net/{name}/address 2>/dev/null')
            interfaces.append({
                'name': name,
                'status': status,
                'ip': ips,
                'mac': mac
            })
    
    # Listening ports
    port_lines = cmd('ss -tlnp 2>/dev/null').split('\n')
    ports = []
    for line in port_lines[1:]:  # skip header
        if not line.strip():
            continue
        parts = line.split()
        if len(parts) >= 5:
            local = parts[3]
            addr_parts = local.rsplit(':', 1)
            port_num = addr_parts[-1] if addr_parts else ''
            addr = addr_parts[0] if len(addr_parts) > 1 else '*'
            # Extract process info
            process = ''
            for p in parts[5:]:
                if 'users:' in p:
                    import re
                    m = re.search(r'\\(\"([^\"]+)\"', p)
                    if m:
                        process = m.group(1)
            ports.append({
                'port': int(port_num) if port_num.isdigit() else port_num,
                'proto': 'tcp',
                'address': addr,
                'process': process
            })
    
    # Connection count
    conn_output = cmd('ss -s 2>/dev/null')
    connections = 0
    for line in conn_output.split('\n'):
        if 'estab' in line:
            import re
            m = re.search(r'(\\d+)\\s+estab', line)
            if m:
                connections = int(m.group(1))
                break
    
    # Firewall
    ufw_output = cmd('sudo ufw status 2>/dev/null || echo inactive')
    fw_enabled = 'active' in ufw_output.lower() and 'inactive' not in ufw_output.lower()
    fw_rules = []
    if fw_enabled:
        for line in ufw_output.split('\n'):
            line = line.strip()
            if line and not line.startswith('Status') and not line.startswith('To') and not line.startswith('--'):
                fw_rules.append(line)
    
    json.dump({
        'interfaces': interfaces,
        'ports': ports,
        'connections': connections,
        'firewall': {
            'enabled': fw_enabled,
            'rules': fw_rules
        },
        'ts': ts
    }, open(os.path.join(dashboard, 'network.json'), 'w'))
except Exception as e:
    json.dump({'interfaces': [], 'ports': [], 'connections': 0, 'firewall': {'enabled': False, 'rules': []}, 'error': str(e), 'ts': ts}, open(os.path.join(dashboard, 'network.json'), 'w'))

# ═══════════════════════════════════════════════════════════
# PACKAGES
# ═══════════════════════════════════════════════════════════
try:
    # Count installed packages
    count_output = cmd('dpkg --list 2>/dev/null | grep -c \"^ii\"')
    installed_count = int(count_output) if count_output.isdigit() else 0
    
    # Check for updates (use cached apt data, don't run apt update)
    upgrade_lines = cmd('apt list --upgradable 2>/dev/null').split('\n')
    updates = []
    for line in upgrade_lines:
        if not line.strip() or line.startswith('Listing') or line.startswith('WARNING'):
            continue
        import re
        m = re.match(r'^(\\S+?)/(\\S+)\\s+(\\S+)', line)
        if m:
            pkg_name = m.group(1)
            new_ver = m.group(3)
            old_match = re.search(r'\\[upgradable from: (\\S+?)\\]', line)
            old_ver = old_match.group(1) if old_match else ''
            updates.append({
                'name': pkg_name,
                'current': old_ver,
                'new': new_ver
            })
    
    json.dump({
        'installed_count': installed_count,
        'updates': updates,
        'update_count': len(updates),
        'ts': ts
    }, open(os.path.join(dashboard, 'packages.json'), 'w'))
except Exception as e:
    json.dump({'installed_count': 0, 'updates': [], 'update_count': 0, 'error': str(e), 'ts': ts}, open(os.path.join(dashboard, 'packages.json'), 'w'))

# ═══════════════════════════════════════════════════════════
# CRON
# ═══════════════════════════════════════════════════════════
try:
    import re as _re
    cron_entries = []

    # Current user crontab
    user_cron = cmd('crontab -l 2>/dev/null')
    current_user = cmd('whoami')
    for line in user_cron.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        m = _re.match(r'^(@\w+|(?:[^\s]+\s+){5})(.+)$', line)
        if m:
            sched = m.group(1).strip()
            command = m.group(2).strip()
            cron_entries.append({'user': current_user, 'schedule': sched, 'command': command})

    # System crontab (/etc/crontab)
    etc_cron = cmd('cat /etc/crontab 2>/dev/null')
    for line in etc_cron.split('\n'):
        line = line.strip()
        if not line or line.startswith('#') or line.startswith('SHELL') or line.startswith('PATH') or line.startswith('MAILTO') or line.startswith('HOME'):
            continue
        # /etc/crontab has user field after schedule
        m = _re.match(r'^(@\w+|(?:[^\s]+\s+){5})(\S+)\s+(.+)$', line)
        if m:
            sched = m.group(1).strip()
            user = m.group(2).strip()
            command = m.group(3).strip()
            cron_entries.append({'user': user, 'schedule': sched, 'command': command})

    # Per-user crontabs from /var/spool/cron/crontabs/
    spool_users = cmd('sudo ls /var/spool/cron/crontabs/ 2>/dev/null')
    for spool_user in spool_users.split('\n'):
        spool_user = spool_user.strip()
        if not spool_user or spool_user == current_user:
            continue
        user_lines = cmd(f'sudo cat /var/spool/cron/crontabs/{spool_user} 2>/dev/null')
        for line in user_lines.split('\n'):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            m = _re.match(r'^(@\w+|(?:[^\s]+\s+){5})(.+)$', line)
            if m:
                sched = m.group(1).strip()
                command = m.group(2).strip()
                cron_entries.append({'user': spool_user, 'schedule': sched, 'command': command})

    # Cron.d directory
    crond_files = cmd('ls /etc/cron.d/ 2>/dev/null')
    for fname in crond_files.split('\n'):
        fname = fname.strip()
        if not fname or fname.startswith('.'):
            continue
        crond_content = cmd(f'cat /etc/cron.d/{fname} 2>/dev/null')
        for line in crond_content.split('\n'):
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('SHELL') or line.startswith('PATH') or line.startswith('MAILTO') or line.startswith('HOME'):
                continue
            m = _re.match(r'^(@\w+|(?:[^\s]+\s+){5})(\S+)\s+(.+)$', line)
            if m:
                sched = m.group(1).strip()
                user = m.group(2).strip()
                command = m.group(3).strip()
                cron_entries.append({'user': user, 'schedule': sched, 'command': command})

    json.dump({
        'system_cron': cron_entries,
        'ts': ts
    }, open(os.path.join(dashboard, 'cron.json'), 'w'))
except Exception as e:
    json.dump({'system_cron': [], 'error': str(e), 'ts': ts}, open(os.path.join(dashboard, 'cron.json'), 'w'))

# ═══════════════════════════════════════════════════════════
# LOGS (last 50 lines of cortex-server)
# ═══════════════════════════════════════════════════════════
try:
    log_output = cmd('journalctl -u cortex-server --no-pager -n 50 2>/dev/null || journalctl -u openclaw --no-pager -n 50 2>/dev/null')
    log_lines = []
    for line in log_output.split('\n'):
        if line.strip():
            level = 'info'
            ll = line.lower()
            if any(w in ll for w in ['error', 'fail', 'fatal', 'critical', 'panic']):
                level = 'error'
            elif 'warn' in ll:
                level = 'warn'
            log_lines.append({'text': line, 'level': level})
    
    json.dump({
        'service': 'cortex-server',
        'lines': log_lines,
        'count': len(log_lines),
        'ts': ts
    }, open(os.path.join(dashboard, 'logs.json'), 'w'))
except Exception as e:
    json.dump({'service': 'cortex-server', 'lines': [], 'count': 0, 'error': str(e), 'ts': ts}, open(os.path.join(dashboard, 'logs.json'), 'w'))
"
