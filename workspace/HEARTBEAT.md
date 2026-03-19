# HEARTBEAT.md - Periodic Checks

On each heartbeat, run a quick health check:

```bash
# Quick health snapshot
echo "=== $(hostname) ===" && \
echo "Uptime: $(uptime -p)" && \
echo "Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')" && \
echo "RAM: $(free -h | awk '/Mem:/{printf "%s/%s", $3, $2}')" && \
echo "Disk: $(df -h / | awk 'NR==2{printf "%s (%s)", $3, $5}')" && \
echo "Failed services: $(systemctl --failed --no-legend | wc -l)"
```

**Alert the user if:**
- CPU load > cores × 2
- RAM > 90%
- Disk > 85%
- Any failed services
- Pending security updates (check once per day)

**Otherwise:** HEARTBEAT_OK
