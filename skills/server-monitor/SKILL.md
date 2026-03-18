# Server Monitor Skill

Monitor system health, resource usage, and performance metrics for proactive server management.

## Description

This skill provides comprehensive system monitoring capabilities for OpenClaw agents. It combines real-time metrics with alerting logic to help maintain server health and prevent issues before they become critical.

## Commands

### System Overview
- `server_health` — CPU, RAM, disk, load average, uptime overview
- `server_processes` — Top processes by CPU/memory usage
- `server_disk` — Disk usage per mount point, SMART status
- `server_network` — Network interfaces, bandwidth, connections
- `server_temps` — CPU/GPU temperatures (if sensors available)

### Monitoring & Alerts
- `server_alerts` — Check for concerning conditions and generate alerts
- `server_metrics_json` — Export all metrics as JSON for integration
- `server_summary` — Human-readable system summary

## Usage

The agent should run these checks during heartbeats and proactively alert when issues are detected. Typical heartbeat flow:

1. Run `server_alerts` to check for immediate issues
2. Periodically run `server_health` for general status
3. Use `server_summary` for user-friendly reports

## Scripts

### server_health
```bash
#!/bin/bash
# server_health - System health overview
set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "=== SYSTEM HEALTH OVERVIEW ==="
echo "Timestamp: $(date)"
echo

# Uptime
echo "📊 UPTIME"
uptime
echo

# CPU Usage
echo "🖥️  CPU USAGE"
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
cpu_float=$(echo "$cpu_usage" | tr -d 'us,')
cpu_int=$(printf "%.0f" "$cpu_float")

if [ "$cpu_int" -gt 90 ]; then
    echo -e "${RED}CPU: ${cpu_usage}% (HIGH)${NC}"
elif [ "$cpu_int" -gt 70 ]; then
    echo -e "${YELLOW}CPU: ${cpu_usage}% (ELEVATED)${NC}"
else
    echo -e "${GREEN}CPU: ${cpu_usage}% (NORMAL)${NC}"
fi
echo

# Memory Usage
echo "💾 MEMORY USAGE"
mem_info=$(free -h | grep '^Mem:')
mem_total=$(echo "$mem_info" | awk '{print $2}')
mem_used=$(echo "$mem_info" | awk '{print $3}')
mem_available=$(echo "$mem_info" | awk '{print $7}')

# Calculate percentage
mem_percent=$(free | grep '^Mem:' | awk '{printf "%.0f", ($3/$2)*100}')

if [ "$mem_percent" -gt 85 ]; then
    echo -e "${RED}Memory: ${mem_used}/${mem_total} (${mem_percent}% - HIGH)${NC}"
elif [ "$mem_percent" -gt 70 ]; then
    echo -e "${YELLOW}Memory: ${mem_used}/${mem_total} (${mem_percent}% - ELEVATED)${NC}"
else
    echo -e "${GREEN}Memory: ${mem_used}/${mem_total} (${mem_percent}% - NORMAL)${NC}"
fi
echo "Available: $mem_available"
echo

# Load Average
echo "⚡ LOAD AVERAGE"
load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')
cores=$(nproc)
load_1min=$(echo "$load_avg" | awk -F',' '{print $1}' | tr -d ' ')
load_float=$(printf "%.2f" "$load_1min")

if (( $(echo "$load_float > $cores" | bc -l) )); then
    echo -e "${RED}Load: $load_avg (cores: $cores) - HIGH${NC}"
elif (( $(echo "$load_float > $(echo "$cores * 0.7" | bc)" | bc -l) )); then
    echo -e "${YELLOW}Load: $load_avg (cores: $cores) - ELEVATED${NC}"
else
    echo -e "${GREEN}Load: $load_avg (cores: $cores) - NORMAL${NC}"
fi
echo

# Disk Usage
echo "💽 DISK USAGE"
df -h | grep -E '^/dev|^tmpfs' | grep -v '/snap' | while read line; do
    usage=$(echo "$line" | awk '{print $5}' | cut -d'%' -f1)
    mount=$(echo "$line" | awk '{print $6}')
    used=$(echo "$line" | awk '{print $3}')
    total=$(echo "$line" | awk '{print $2}')
    
    if [ "$usage" -gt 90 ]; then
        echo -e "${RED}$mount: ${used}/${total} (${usage}% - CRITICAL)${NC}"
    elif [ "$usage" -gt 80 ]; then
        echo -e "${YELLOW}$mount: ${used}/${total} (${usage}% - HIGH)${NC}"
    else
        echo -e "${GREEN}$mount: ${used}/${total} (${usage}% - NORMAL)${NC}"
    fi
done
```

### server_processes
```bash
#!/bin/bash
# server_processes - Top processes by resource usage
set -euo pipefail

echo "=== TOP PROCESSES BY CPU ==="
ps aux --sort=-%cpu | head -11 | awk 'BEGIN{printf "%-8s %-6s %-6s %-6s %-8s %s\n", "USER", "PID", "%CPU", "%MEM", "TIME", "COMMAND"} NR>1{printf "%-8s %-6s %-6s %-6s %-8s %s\n", $1, $2, $3, $4, $10, substr($0, index($0,$11))}'

echo
echo "=== TOP PROCESSES BY MEMORY ==="
ps aux --sort=-%mem | head -11 | awk 'BEGIN{printf "%-8s %-6s %-6s %-6s %-8s %s\n", "USER", "PID", "%CPU", "%MEM", "TIME", "COMMAND"} NR>1{printf "%-8s %-6s %-6s %-6s %-8s %s\n", $1, $2, $3, $4, $10, substr($0, index($0,$11))}'

echo
echo "=== PROCESS COUNT BY USER ==="
ps aux | awk 'NR>1{count[$1]++} END{for(user in count) printf "%-12s %d\n", user, count[user]}' | sort -k2 -nr
```

### server_disk
```bash
#!/bin/bash
# server_disk - Disk usage and SMART status
set -euo pipefail

echo "=== DISK USAGE BY MOUNT POINT ==="
df -h | grep -E '^/dev|^tmpfs' | sort -k5 -nr

echo
echo "=== INODE USAGE ==="
df -i | grep -E '^/dev|^tmpfs' | awk 'NR>1{if($5+0 > 80) print "⚠️  " $0; else print $0}'

echo
echo "=== LARGEST DIRECTORIES (/) ==="
du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10

if command -v smartctl >/dev/null 2>&1; then
    echo
    echo "=== SMART STATUS ==="
    for disk in $(lsblk -dpno NAME | grep -E '^/dev/[sv]d[a-z]$' | head -5); do
        echo "Checking $disk..."
        sudo smartctl -H "$disk" 2>/dev/null || echo "Cannot read SMART data for $disk"
    done
else
    echo
    echo "⚠️  smartmontools not installed - SMART status unavailable"
fi
```

### server_network
```bash
#!/bin/bash
# server_network - Network interface status and connections
set -euo pipefail

echo "=== NETWORK INTERFACES ==="
ip addr show | grep -E '^[0-9]+:|inet ' | awk '
/^[0-9]+:/ {
    iface = $2
    gsub(/:/, "", iface)
    state = ($3 == "UP") ? "🟢 UP" : "🔴 DOWN"
    printf "%-15s %s\n", iface, state
}
/inet / {
    if ($2 !~ /127\./) printf "%-15s %s\n", "", $2
}
'

echo
echo "=== DEFAULT ROUTE ==="
ip route | grep default

echo
echo "=== DNS CONFIGURATION ==="
if [ -f /etc/systemd/resolved.conf ]; then
    echo "Using systemd-resolved:"
    resolvectl status | grep -A 5 "Global"
else
    echo "Using /etc/resolv.conf:"
    grep nameserver /etc/resolv.conf 2>/dev/null || echo "No nameservers found"
fi

echo
echo "=== ACTIVE CONNECTIONS (TOP 10) ==="
ss -tuln | head -11

echo
echo "=== NETWORK STATISTICS ==="
cat /proc/net/dev | awk '
BEGIN{printf "%-10s %10s %10s %10s %10s\n", "Interface", "RX Bytes", "RX Packets", "TX Bytes", "TX Packets"}
NR>2{
    gsub(/:/, "", $1)
    printf "%-10s %10s %10s %10s %10s\n", $1, $2, $3, $10, $11
}'
```

### server_temps
```bash
#!/bin/bash
# server_temps - CPU/GPU temperature monitoring
set -euo pipefail

echo "=== TEMPERATURE MONITORING ==="

# Check if sensors command is available
if command -v sensors >/dev/null 2>&1; then
    echo "🌡️  Hardware Sensors:"
    sensors | grep -E '(Core|temp|fan).*:' | while IFS= read -r line; do
        temp=$(echo "$line" | grep -oE '\+[0-9]+\.[0-9]+°C' | head -1)
        if [ -n "$temp" ]; then
            temp_val=$(echo "$temp" | grep -oE '[0-9]+' | head -1)
            if [ "$temp_val" -gt 80 ]; then
                echo "🔥 $line"
            elif [ "$temp_val" -gt 70 ]; then
                echo "🟡 $line"
            else
                echo "🟢 $line"
            fi
        else
            echo "$line"
        fi
    done
else
    echo "⚠️  lm-sensors not installed - hardware temperature monitoring unavailable"
fi

# Thermal zones (Linux kernel thermal interface)
echo
echo "🌡️  Kernel Thermal Zones:"
for thermal_zone in /sys/class/thermal/thermal_zone*/; do
    if [ -d "$thermal_zone" ]; then
        zone_type=$(cat "$thermal_zone/type" 2>/dev/null || echo "unknown")
        temp_millic=$(cat "$thermal_zone/temp" 2>/dev/null || echo "0")
        temp_c=$((temp_millic / 1000))
        
        if [ "$temp_c" -gt 0 ]; then
            if [ "$temp_c" -gt 80 ]; then
                echo "🔥 $zone_type: ${temp_c}°C"
            elif [ "$temp_c" -gt 70 ]; then
                echo "🟡 $zone_type: ${temp_c}°C"
            else
                echo "🟢 $zone_type: ${temp_c}°C"
            fi
        fi
    fi
done

# GPU temperatures (if nvidia-smi available)
if command -v nvidia-smi >/dev/null 2>&1; then
    echo
    echo "🎮 GPU Temperatures:"
    nvidia-smi --query-gpu=name,temperature.gpu --format=csv,noheader,nounits | while IFS=',' read -r gpu_name gpu_temp; do
        gpu_temp=$(echo "$gpu_temp" | tr -d ' ')
        if [ "$gpu_temp" -gt 80 ]; then
            echo "🔥 $gpu_name: ${gpu_temp}°C"
        elif [ "$gpu_temp" -gt 70 ]; then
            echo "🟡 $gpu_name: ${gpu_temp}°C"
        else
            echo "🟢 $gpu_name: ${gpu_temp}°C"
        fi
    done
fi
```

### server_alerts
```bash
#!/bin/bash
# server_alerts - Check for concerning system conditions
set -euo pipefail

ALERT_LOG="/tmp/server_alerts.log"
ALERTS_FOUND=0

log_alert() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') ALERT: $1" | tee -a "$ALERT_LOG"
    ALERTS_FOUND=1
}

echo "=== SYSTEM ALERTS CHECK ==="
echo "Checking for concerning conditions..."
echo

# CPU Usage Check
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | tr -d 'us,')
cpu_int=$(printf "%.0f" "$cpu_usage")
if [ "$cpu_int" -gt 90 ]; then
    log_alert "HIGH CPU: ${cpu_usage}% (threshold: 90%)"
fi

# Memory Usage Check
mem_percent=$(free | grep '^Mem:' | awk '{printf "%.0f", ($3/$2)*100}')
if [ "$mem_percent" -gt 85 ]; then
    log_alert "HIGH MEMORY: ${mem_percent}% (threshold: 85%)"
fi

# Disk Usage Check
df -h | grep -E '^/dev' | while read line; do
    usage=$(echo "$line" | awk '{print $5}' | cut -d'%' -f1)
    mount=$(echo "$line" | awk '{print $6}')
    if [ "$usage" -gt 90 ]; then
        log_alert "DISK FULL: $mount at ${usage}% (threshold: 90%)"
    fi
done

# Load Average Check
load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
cores=$(nproc)
if (( $(echo "$load_1min > $cores" | bc -l 2>/dev/null || echo 0) )); then
    log_alert "HIGH LOAD: $load_1min (cores: $cores, threshold: >cores)"
fi

# Temperature Check (if available)
if command -v sensors >/dev/null 2>&1; then
    sensors | grep -oE 'Core [0-9]+:.*?\+[0-9]+\.[0-9]+°C' | while IFS= read -r line; do
        temp=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        temp_int=$(printf "%.0f" "$temp")
        if [ "$temp_int" -gt 85 ]; then
            log_alert "HIGH TEMPERATURE: $line (threshold: 85°C)"
        fi
    done
fi

# Check for OOM kills in recent dmesg
if dmesg -T 2>/dev/null | grep -i "killed process" | tail -5 | grep -q "$(date '+%Y-%m-%d')"; then
    log_alert "OOM KILLER ACTIVE: Recent out-of-memory kills detected"
fi

# Check for failed systemd services
failed_services=$(systemctl --failed --no-legend | wc -l)
if [ "$failed_services" -gt 0 ]; then
    log_alert "FAILED SERVICES: $failed_services systemd services in failed state"
fi

# Check SSH login failures
if [ -f /var/log/auth.log ]; then
    recent_failures=$(grep "Failed password" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l)
    if [ "$recent_failures" -gt 10 ]; then
        log_alert "SSH ATTACKS: $recent_failures failed SSH attempts today"
    fi
fi

if [ "$ALERTS_FOUND" -eq 0 ]; then
    echo "✅ No alerts - system appears healthy"
    echo "Last check: $(date)" > "$ALERT_LOG"
else
    echo
    echo "⚠️  ALERTS DETECTED - check $ALERT_LOG for details"
    echo
    echo "Recent alerts:"
    tail -10 "$ALERT_LOG"
fi

exit "$ALERTS_FOUND"
```

### server_summary
```bash
#!/bin/bash
# server_summary - Human-readable system summary
set -euo pipefail

echo "🖥️  SERVER SUMMARY REPORT"
echo "=========================="
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo

# Quick health indicators
echo "📊 HEALTH INDICATORS"
echo "==================="

# CPU
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | tr -d 'us,')
echo "🖥️  CPU Usage: $cpu_usage%"

# Memory
mem_percent=$(free | grep '^Mem:' | awk '{printf "%.0f", ($3/$2)*100}')
mem_available=$(free -h | grep '^Mem:' | awk '{print $7}')
echo "💾 Memory Usage: $mem_percent% (Available: $mem_available)"

# Disk (highest usage)
max_disk=$(df -h | grep -E '^/dev' | awk '{print $5}' | cut -d'%' -f1 | sort -nr | head -1)
echo "💽 Disk Usage: $max_disk% (highest mount point)"

# Load
load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')
cores=$(nproc)
echo "⚡ Load Average: $load_avg (cores: $cores)"

# Network
active_connections=$(ss -tun | wc -l)
echo "🌐 Active Connections: $active_connections"

echo
echo "🔍 QUICK DIAGNOSTICS"
echo "===================="

# Check if any alerts would trigger
alerts_status="✅ All systems normal"
if command -v bc >/dev/null 2>&1; then
    cpu_int=$(printf "%.0f" "$cpu_usage")
    if [ "$cpu_int" -gt 90 ] || [ "$mem_percent" -gt 85 ] || [ "$max_disk" -gt 90 ]; then
        alerts_status="⚠️  Some thresholds exceeded - run server_alerts for details"
    fi
fi
echo "$alerts_status"

# Service status
failed_services=$(systemctl --failed --no-legend | wc -l)
if [ "$failed_services" -eq 0 ]; then
    echo "✅ All systemd services running normally"
else
    echo "❌ $failed_services systemd service(s) in failed state"
fi

echo
echo "💡 Tip: Run 'server_health' for detailed metrics or 'server_alerts' for threshold checks"
```

## Installation

Copy this skill to your OpenClaw skills directory:
```bash
cp -r server-monitor ~/.openclaw/skills/
```

Or install via ClawHub (when published):
```bash
openclaw skill install server-monitor
```

## Dependencies

- Standard Linux utilities (ps, df, free, top, ss, etc.)
- Optional: `lm-sensors` for hardware temperature monitoring
- Optional: `smartmontools` for disk health monitoring
- Optional: `bc` for floating point calculations

Install optional dependencies on Ubuntu:
```bash
sudo apt-get update
sudo apt-get install lm-sensors smartmontools bc
sudo sensors-detect --auto  # Initialize sensors
```

## Integration with Heartbeat

Add to your `HEARTBEAT.md`:
```markdown
## System Monitoring
- Check server alerts every ~2 hours
- Run server_summary during morning check
- Alert if server_alerts returns non-zero exit code
```

Example heartbeat logic:
```bash
# In your heartbeat routine
if ! server_alerts >/dev/null 2>&1; then
    echo "🚨 Server alerts detected - running diagnostics..."
    server_alerts
    server_health
fi
```