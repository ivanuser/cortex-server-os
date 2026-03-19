# monitoring — System Monitoring & Health

Server health monitoring, metrics collection, and alerting for CortexOS Server.

## Description

Monitor system health, track resource usage trends, and detect anomalies. This skill gives you real-time visibility into CPU, memory, disk, network, and service status.

## Quick Reference

### System Overview
```bash
# One-liner health dashboard
echo "=== $(hostname) Health ===" && \
echo "Uptime: $(uptime -p)" && \
echo "Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')" && \
echo "CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}')% used" && \
echo "RAM: $(free -h | awk '/Mem:/{printf "%s/%s (%s used)", $3, $2, $3/$2*100}')" && \
echo "Disk: $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')" && \
echo "Swap: $(free -h | awk '/Swap:/{printf "%s/%s", $3, $2}')"
```

### CPU Monitoring
```bash
# Real-time CPU by core
mpstat -P ALL 1 5

# Top CPU consumers
ps aux --sort=-%cpu | head -11

# CPU temperature (if sensors available)
sensors 2>/dev/null || cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | awk '{printf "%.1f°C\n", $1/1000}'

# Historical load average (1, 5, 15 min)
cat /proc/loadavg
```

### Memory Monitoring
```bash
# Detailed memory breakdown
free -h

# Top memory consumers
ps aux --sort=-%mem | head -11

# Memory info detailed
cat /proc/meminfo | head -20

# OOM killer recent activity
dmesg | grep -i "out of memory\|oom" | tail -5
```

### Disk Monitoring
```bash
# All filesystems
df -hT

# Inode usage (can fill up even with free space)
df -i

# Largest directories
du -sh /* 2>/dev/null | sort -rh | head -10

# Disk I/O stats
iostat -xz 1 3 2>/dev/null || cat /proc/diskstats

# Files changed in last 24h
find / -maxdepth 3 -mtime -1 -type f 2>/dev/null | head -20
```

### Network Monitoring
```bash
# Active connections
ss -tunapl | head -20

# Bandwidth usage per interface
cat /proc/net/dev | awk 'NR>2{printf "%-12s RX: %10.2f MB  TX: %10.2f MB\n", $1, $2/1048576, $10/1048576}'

# Connection count by state
ss -s

# DNS resolution check
dig +short google.com
```

### Service Health
```bash
# Failed services
systemctl --failed

# Recently started services
systemctl list-units --type=service --state=running --no-pager | head -20

# Service resource usage
systemd-cgtop -n 1 --order=cpu 2>/dev/null || true
```

### Log Monitoring
```bash
# Recent errors across all services
journalctl -p err --since "1 hour ago" --no-pager | tail -30

# Auth failures
journalctl -u ssh --since "1 hour ago" --no-pager | grep -i "failed\|invalid" | tail -10

# Kernel messages
dmesg --time-format iso | tail -20
```

## Alerting Thresholds

When checking health, flag these conditions:

| Metric | Warning | Critical |
|--------|---------|----------|
| CPU usage | > 80% sustained | > 95% sustained |
| Memory | > 85% used | > 95% used |
| Disk | > 80% full | > 90% full |
| Swap | > 50% used | > 80% used |
| Load avg | > CPU cores × 1.5 | > CPU cores × 3 |
| Failed services | Any | Critical services |
| OOM events | Any recent | - |

## Automation

### Periodic Health Check Script
```bash
#!/bin/bash
# Save as /usr/local/bin/cortexos-health-check
WARN=0 CRIT=0

# CPU check
CPU=$(top -bn1 | grep 'Cpu(s)' | awk '{print int($2)}')
[ "$CPU" -gt 95 ] && CRIT=$((CRIT+1)) && echo "CRITICAL: CPU at ${CPU}%"
[ "$CPU" -gt 80 ] && WARN=$((WARN+1)) && echo "WARNING: CPU at ${CPU}%"

# Memory check  
MEM=$(free | awk '/Mem:/{printf "%d", $3/$2*100}')
[ "$MEM" -gt 95 ] && CRIT=$((CRIT+1)) && echo "CRITICAL: Memory at ${MEM}%"
[ "$MEM" -gt 85 ] && WARN=$((WARN+1)) && echo "WARNING: Memory at ${MEM}%"

# Disk check
DISK=$(df / | awk 'NR==2{print int($5)}')
[ "$DISK" -gt 90 ] && CRIT=$((CRIT+1)) && echo "CRITICAL: Disk at ${DISK}%"
[ "$DISK" -gt 80 ] && WARN=$((WARN+1)) && echo "WARNING: Disk at ${DISK}%"

# Failed services
FAILED=$(systemctl --failed --no-legend | wc -l)
[ "$FAILED" -gt 0 ] && WARN=$((WARN+1)) && echo "WARNING: $FAILED failed services"

echo "Health: ${CRIT} critical, ${WARN} warnings"
exit $CRIT
```

## Notes

- Always check both percentage AND absolute values — 90% of 1TB is different from 90% of 10GB
- Load average should be compared against CPU core count
- Check swap usage alongside RAM — heavy swap = performance problem
- `dmesg` errors may indicate hardware issues
