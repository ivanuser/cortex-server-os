# Systemd Manager Skill

Complete systemd service, timer, and system state management for OpenClaw agents.

## Description

This skill provides comprehensive systemd management capabilities, allowing agents to monitor services, manage startup/shutdown, analyze boot performance, and handle systemd timers. Perfect for maintaining server infrastructure and debugging service issues.

## Commands

### Service Management
- `service_status [name]` — Status of a service or all failed services
- `service_restart <name>` — Restart a service safely
- `service_stop <name>` — Stop a service gracefully
- `service_start <name>` — Start a stopped service
- `service_enable <name>` — Enable a service to start on boot
- `service_disable <name>` — Disable a service from starting on boot

### Monitoring & Diagnostics
- `service_logs <name>` — Recent journal logs for a service
- `service_list_failed` — All failed services with details
- `service_dependencies <name>` — Show service dependencies
- `service_config <name>` — Show service configuration

### System Analysis
- `timer_list` — All active timers with next run time
- `boot_time` — System boot analysis (systemd-analyze)
- `systemd_health` — Overall systemd system health
- `system_targets` — Show system targets and their status

## Scripts

### service_status
```bash
#!/bin/bash
# service_status - Show service status or all failed services
set -euo pipefail

SERVICE_NAME="${1:-}"

if [ -z "$SERVICE_NAME" ]; then
    echo "🔍 SYSTEMD SERVICE STATUS - ALL FAILED SERVICES"
    echo "=============================================="
    echo "Generated: $(date)"
    echo
    
    # Count failed services
    failed_count=$(systemctl --failed --no-legend | wc -l)
    
    if [ "$failed_count" -eq 0 ]; then
        echo "✅ No failed services found"
        echo
        echo "📊 System service summary:"
        systemctl list-units --type=service --no-legend | \
            awk '{print $4}' | sort | uniq -c | \
            awk '{printf "  %-12s %s\n", $2, $1}'
        exit 0
    fi
    
    echo "❌ Found $failed_count failed service(s):"
    echo
    
    systemctl --failed --no-legend | while read -r service load active sub description; do
        echo "🔴 $service"
        echo "   Status: $load $active $sub"
        echo "   Description: $description"
        
        # Get recent logs for failed service
        echo "   Recent logs:"
        systemctl status "$service" --lines=3 --no-pager 2>/dev/null | \
            grep -E "^\s*(Active:|Process:|Main PID:|CGroup:)" | \
            sed 's/^/     /'
        echo
    done
    
else
    # Show specific service status
    echo "🔍 SERVICE STATUS: $SERVICE_NAME"
    echo "$(printf '=%.0s' {1..40})"
    echo
    
    if ! systemctl list-unit-files "$SERVICE_NAME" >/dev/null 2>&1; then
        echo "❌ Service '$SERVICE_NAME' not found"
        echo
        echo "💡 Similar services:"
        systemctl list-unit-files --type=service | grep -i "$SERVICE_NAME" | head -5 || echo "   None found"
        exit 1
    fi
    
    # Detailed status
    systemctl status "$SERVICE_NAME" --no-pager || true
    
    echo
    echo "📋 Service Information:"
    echo "  Unit File: $(systemctl show "$SERVICE_NAME" --property=FragmentPath --value)"
    echo "  Enabled: $(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo 'unknown')"
    echo "  Active: $(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo 'unknown')"
    echo "  Load: $(systemctl show "$SERVICE_NAME" --property=LoadState --value)"
    
    # Memory and CPU if running
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        echo "  Memory: $(systemctl show "$SERVICE_NAME" --property=MemoryCurrent --value | awk '{if($1>0) printf "%.1f MB", $1/1024/1024; else print "N/A"}')"
        cpu_usage=$(systemctl show "$SERVICE_NAME" --property=CPUUsageNSec --value)
        if [ "$cpu_usage" != "0" ] && [ -n "$cpu_usage" ]; then
            echo "  CPU Time: $(echo "$cpu_usage" | awk '{printf "%.2f seconds", $1/1000000000}')"
        fi
    fi
fi
```

### service_restart
```bash
#!/bin/bash
# service_restart - Restart a systemd service safely
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: service_restart <service_name>"
    echo
    echo "Running services:"
    systemctl list-units --type=service --state=running --no-legend | \
        awk '{print "  " $1}' | head -10
    exit 1
fi

SERVICE_NAME="$1"

# Validate service exists
if ! systemctl list-unit-files "$SERVICE_NAME" >/dev/null 2>&1; then
    echo "❌ Service '$SERVICE_NAME' not found"
    exit 1
fi

echo "🔄 RESTARTING SERVICE: $SERVICE_NAME"
echo "===================================="
echo "Service: $SERVICE_NAME"
echo "Timestamp: $(date)"
echo

# Check current status
current_status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "inactive")
enabled_status=$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo "unknown")

echo "Current status: $current_status"
echo "Enabled: $enabled_status"

# Show dependencies that might be affected
echo
echo "📋 Service dependencies:"
systemctl list-dependencies "$SERVICE_NAME" --plain | head -5

# Warn about critical services
case "$SERVICE_NAME" in
    "sshd"|"ssh"|"networking"|"systemd-networkd"|"docker")
        echo
        echo "⚠️  WARNING: $SERVICE_NAME is a critical service!"
        echo "   Restarting may affect connectivity or running containers."
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Restart cancelled"
            exit 1
        fi
        ;;
esac

# Perform restart
echo
echo "🔄 Restarting service..."
if systemctl restart "$SERVICE_NAME"; then
    echo "✅ Service restart command issued successfully"
    
    # Wait for service to stabilize
    echo "⏳ Waiting for service to stabilize..."
    sleep 3
    
    # Check final status
    new_status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "failed")
    echo "New status: $new_status"
    
    if [ "$new_status" = "active" ]; then
        echo "✅ Service is now active and running"
        
        # Show recent logs to verify startup
        echo
        echo "📋 Recent startup logs:"
        journalctl -u "$SERVICE_NAME" --since "1 minute ago" --no-pager -n 5 | \
            grep -v "^-- " || echo "   No recent logs found"
    else
        echo "❌ Service failed to start properly"
        echo
        echo "🔍 Recent error logs:"
        journalctl -u "$SERVICE_NAME" --since "1 minute ago" --no-pager -n 10 | \
            grep -v "^-- " || echo "   No logs available"
        exit 1
    fi
else
    echo "❌ Failed to restart service"
    echo
    echo "🔍 Service status:"
    systemctl status "$SERVICE_NAME" --no-pager | head -10
    exit 1
fi
```

### service_logs
```bash
#!/bin/bash
# service_logs - Show recent journal logs for a service
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: service_logs <service_name> [lines] [time_period]"
    echo "Examples:"
    echo "  service_logs nginx"
    echo "  service_logs docker 100"
    echo "  service_logs sshd 50 '1 hour ago'"
    echo
    echo "Available services:"
    systemctl list-units --type=service --no-legend | \
        awk '{print "  " $1}' | head -10
    exit 1
fi

SERVICE_NAME="$1"
LINES="${2:-50}"
TIME_PERIOD="${3:-1 hour ago}"

# Validate service exists
if ! systemctl list-unit-files "$SERVICE_NAME" >/dev/null 2>&1; then
    echo "❌ Service '$SERVICE_NAME' not found"
    echo
    echo "💡 Did you mean:"
    systemctl list-unit-files --type=service | grep -i "$SERVICE_NAME" | head -3 | \
        awk '{print "  " $1}' || echo "  No similar services found"
    exit 1
fi

echo "📋 LOGS for $SERVICE_NAME"
echo "$(printf '=%.0s' {1..50})"
echo "Service: $SERVICE_NAME"
echo "Lines: $LINES"
echo "Since: $TIME_PERIOD"
echo "Generated: $(date)"
echo "$(printf '=%.0s' {1..50})"

# Get service status first
status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "inactive")
enabled=$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo "unknown")
echo "Status: $status | Enabled: $enabled"
echo

# Show logs with color coding
journalctl -u "$SERVICE_NAME" --since "$TIME_PERIOD" --no-pager -n "$LINES" --output=short | \
    while IFS= read -r line; do
        # Color code log levels
        if [[ "$line" =~ systemd\[.*\]: ]]; then
            echo -e "\033[0;35m$line\033[0m"  # Purple for systemd messages
        elif [[ "$line" =~ (ERROR|error|Error|FATAL|fatal|Fatal|CRIT|crit|Critical) ]]; then
            echo -e "\033[0;31m$line\033[0m"  # Red for errors
        elif [[ "$line" =~ (WARN|warn|Warn|WARNING|warning|Warning) ]]; then
            echo -e "\033[1;33m$line\033[0m"  # Yellow for warnings
        elif [[ "$line" =~ (INFO|info|Info|NOTICE|notice|Notice) ]]; then
            echo -e "\033[0;32m$line\033[0m"  # Green for info
        elif [[ "$line" =~ (DEBUG|debug|Debug|TRACE|trace|Trace) ]]; then
            echo -e "\033[0;36m$line\033[0m"  # Cyan for debug
        else
            echo "$line"
        fi
    done

echo
echo "📊 Log Statistics (last $LINES lines):"
log_stats=$(journalctl -u "$SERVICE_NAME" --since "$TIME_PERIOD" --no-pager -n "$LINES" --output=short)
if [ -n "$log_stats" ]; then
    error_count=$(echo "$log_stats" | grep -i "error\|fatal\|crit" | wc -l || echo 0)
    warn_count=$(echo "$log_stats" | grep -i "warn" | wc -l || echo 0)
    total_lines=$(echo "$log_stats" | wc -l)
    
    echo "  Total lines: $total_lines"
    echo "  Errors: $error_count"
    echo "  Warnings: $warn_count"
    
    if [ "$error_count" -gt 0 ]; then
        echo "  ⚠️  Service has recent errors - review logs above"
    elif [ "$warn_count" -gt 5 ]; then
        echo "  ⚠️  Service has many warnings - monitor closely"
    else
        echo "  ✅ Log levels appear normal"
    fi
else
    echo "  No logs found for specified time period"
fi

echo
echo "💡 Tip: Use 'journalctl -u $SERVICE_NAME -f' for live log monitoring"
```

### service_enable
```bash
#!/bin/bash
# service_enable - Enable a service to start on boot
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: service_enable <service_name>"
    echo
    echo "Available services (currently disabled):"
    systemctl list-unit-files --type=service --state=disabled | \
        awk 'NR>1{print "  " $1}' | head -10
    exit 1
fi

SERVICE_NAME="$1"

# Validate service exists
if ! systemctl list-unit-files "$SERVICE_NAME" >/dev/null 2>&1; then
    echo "❌ Service '$SERVICE_NAME' not found"
    exit 1
fi

echo "🔧 ENABLING SERVICE: $SERVICE_NAME"
echo "=================================="
echo "Service: $SERVICE_NAME"
echo "Timestamp: $(date)"
echo

# Check current status
current_enabled=$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo "unknown")
current_active=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "inactive")

echo "Current enabled state: $current_enabled"
echo "Current active state: $current_active"

if [ "$current_enabled" = "enabled" ]; then
    echo "ℹ️  Service is already enabled"
    exit 0
fi

# Enable the service
echo
echo "🔧 Enabling service..."
if systemctl enable "$SERVICE_NAME"; then
    echo "✅ Service enabled successfully"
    
    # Check if we should start it now
    if [ "$current_active" != "active" ]; then
        echo
        echo "Service is enabled but not currently running."
        read -p "Start the service now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "🚀 Starting service..."
            if systemctl start "$SERVICE_NAME"; then
                echo "✅ Service started successfully"
                
                # Verify it's running
                new_status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "failed")
                echo "Service status: $new_status"
            else
                echo "❌ Failed to start service"
                echo "Service is enabled but failed to start"
                exit 1
            fi
        fi
    fi
else
    echo "❌ Failed to enable service"
    exit 1
fi
```

### service_list_failed
```bash
#!/bin/bash
# service_list_failed - Show all failed services with detailed information
set -euo pipefail

echo "❌ FAILED SYSTEMD SERVICES"
echo "=========================="
echo "Generated: $(date)"
echo

# Get failed services
failed_services=$(systemctl --failed --no-legend)

if [ -z "$failed_services" ]; then
    echo "✅ No failed services found!"
    
    # Show summary of all service states
    echo
    echo "📊 Service state summary:"
    systemctl list-units --type=service --no-legend | \
        awk '{print $4}' | sort | uniq -c | \
        awk '{printf "  %-12s %s services\n", $2, $1}'
    exit 0
fi

failed_count=$(echo "$failed_services" | wc -l)
echo "Found $failed_count failed service(s):"
echo

# Process each failed service
echo "$failed_services" | while read -r service load active sub description; do
    echo "🔴 $service"
    echo "   State: $load $active $sub"
    echo "   Description: $description"
    
    # Get the last few log entries
    echo "   Recent logs:"
    journalctl -u "$service" --no-pager -n 3 --since "24 hours ago" --output=short-precise 2>/dev/null | \
        while IFS= read -r log_line; do
            if [[ "$log_line" =~ ^-- ]]; then
                continue
            fi
            echo "     $log_line"
        done | head -3
    
    # Get exit status if available
    exit_status=$(systemctl show "$service" --property=ExecMainStatus --value 2>/dev/null || echo "")
    if [ -n "$exit_status" ] && [ "$exit_status" != "0" ]; then
        echo "   Exit code: $exit_status"
    fi
    
    # Check if it's enabled (should restart on boot)
    enabled_status=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
    echo "   Boot enabled: $enabled_status"
    
    echo
done

echo "🔧 RECOMMENDATIONS"
echo "=================="
echo "For each failed service, you can:"
echo "  • Check logs: service_logs <service_name>"
echo "  • Try restart: service_restart <service_name>"
echo "  • Check config: service_config <service_name>"
echo "  • Disable if not needed: service_disable <service_name>"
echo
echo "💡 Quick fix command:"
echo "  systemctl reset-failed  # Clear failed state for all services"
```

### timer_list
```bash
#!/bin/bash
# timer_list - Show all systemd timers and their status
set -euo pipefail

echo "⏰ SYSTEMD TIMERS"
echo "================"
echo "Generated: $(date)"
echo

# Check if any timers exist
timer_count=$(systemctl list-timers --no-legend | wc -l)

if [ "$timer_count" -eq 0 ]; then
    echo "No systemd timers found"
    exit 0
fi

echo "📊 Timer Summary: $timer_count timer(s) found"
echo

# Show active timers
echo "🟢 ACTIVE TIMERS"
echo "==============="
systemctl list-timers --no-legend | head -20

echo
echo "📋 TIMER DETAILS"
echo "==============="

# Get detailed info for each timer
systemctl list-timers --no-legend | while read -r next left last passed unit activates; do
    # Skip empty lines
    [ -z "$unit" ] && continue
    
    echo "⏰ $unit"
    echo "   Next run: $next ($left left)"
    echo "   Last run: $last ($passed ago)"
    echo "   Triggers: $activates"
    
    # Get timer configuration details
    timer_file=$(systemctl show "$unit" --property=FragmentPath --value 2>/dev/null)
    if [ -n "$timer_file" ] && [ -f "$timer_file" ]; then
        # Extract OnCalendar or OnBootSec settings
        calendar=$(grep "^OnCalendar=" "$timer_file" 2>/dev/null | cut -d'=' -f2- || echo "")
        boot_sec=$(grep "^OnBootSec=" "$timer_file" 2>/dev/null | cut -d'=' -f2- || echo "")
        unit_sec=$(grep "^OnUnitActiveSec=" "$timer_file" 2>/dev/null | cut -d'=' -f2- || echo "")
        
        if [ -n "$calendar" ]; then
            echo "   Schedule: $calendar"
        fi
        if [ -n "$boot_sec" ]; then
            echo "   Runs: $boot_sec after boot"
        fi
        if [ -n "$unit_sec" ]; then
            echo "   Interval: Every $unit_sec"
        fi
    fi
    
    # Check if the triggered service exists and its status
    service_name=$(echo "$activates" | sed 's/\.timer$/.service/')
    if systemctl list-unit-files "$service_name" >/dev/null 2>&1; then
        service_status=$(systemctl is-active "$service_name" 2>/dev/null || echo "inactive")
        echo "   Service status: $service_status"
        
        # If service recently ran, show last few log lines
        if [ "$passed" != "n/a" ]; then
            recent_logs=$(journalctl -u "$service_name" --since "24 hours ago" --no-pager -n 1 2>/dev/null | grep -v "^--" | tail -1)
            if [ -n "$recent_logs" ]; then
                echo "   Last log: $recent_logs"
            fi
        fi
    fi
    
    echo
done

echo "📊 TIMER STATISTICS"
echo "=================="

# Count timers by status
active_timers=$(systemctl list-timers --state=active --no-legend | wc -l)
inactive_timers=$(systemctl list-timers --all --no-legend | wc -l)
total_timers=$((inactive_timers))

echo "Active timers: $active_timers"
echo "Total timers: $total_timers"

# Check for timers that haven't run recently
echo
echo "⚠️  POTENTIAL ISSUES"
echo "==================="

systemctl list-timers --no-legend | while read -r next left last passed unit activates; do
    [ -z "$unit" ] && continue
    
    # Check if timer hasn't run in over a day
    if [[ "$passed" == *"day"* ]] && ! [[ "$passed" == "1 day"* ]]; then
        echo "⚠️  $unit hasn't run for $passed"
    fi
    
    # Check if next run is far in the future (might be misconfigured)
    if [[ "$left" == *"year"* ]] || [[ "$left" == *"month"* ]]; then
        echo "⚠️  $unit next run in $left (might be misconfigured)"
    fi
done | head -5

echo
echo "💡 Timer management commands:"
echo "  systemctl start <timer>     # Start a timer"
echo "  systemctl stop <timer>      # Stop a timer"
echo "  systemctl enable <timer>    # Enable timer on boot"
echo "  systemd-analyze calendar 'schedule'  # Test timer schedule"
```

### boot_time
```bash
#!/bin/bash
# boot_time - Analyze system boot performance
set -euo pipefail

echo "🚀 SYSTEM BOOT ANALYSIS"
echo "======================="
echo "Generated: $(date)"
echo

# Check if systemd-analyze is available
if ! command -v systemd-analyze >/dev/null 2>&1; then
    echo "❌ systemd-analyze not available"
    exit 1
fi

# Overall boot time
echo "⏱️  BOOT TIME SUMMARY"
echo "===================="
systemd-analyze

echo
echo "📊 BOOT STAGE BREAKDOWN"
echo "======================="
systemd-analyze blame | head -15

echo
echo "🔗 CRITICAL CHAIN"
echo "================="
systemd-analyze critical-chain | head -10

# Service startup times
echo
echo "⏰ SLOWEST SERVICES"
echo "=================="
echo "Services that took longest to start:"
systemd-analyze blame | head -10 | while read -r time service; do
    # Convert time to seconds for comparison
    time_num=$(echo "$time" | sed 's/[a-z]*$//')
    if [[ "$time" =~ s$ ]] && (( $(echo "$time_num > 5" | bc -l 2>/dev/null || echo 0) )); then
        echo "🐌 $service: $time (SLOW)"
    elif [[ "$time" =~ ms$ ]] && (( $(echo "$time_num > 1000" | bc -l 2>/dev/null || echo 0) )); then
        echo "🐌 $service: $time (SLOW)"
    else
        echo "✅ $service: $time"
    fi
done

# Check for failed services during boot
echo
echo "❌ BOOT FAILURES"
echo "==============="
failed_during_boot=$(systemctl --failed --no-legend | wc -l)
if [ "$failed_during_boot" -eq 0 ]; then
    echo "✅ No services failed during boot"
else
    echo "⚠️  $failed_during_boot service(s) failed during boot:"
    systemctl --failed --no-legend | awk '{print "  " $1 " (" $4 ")"}'
fi

# Security analysis
echo
echo "🔒 BOOT SECURITY"
echo "==============="

# Check for services running as root
root_services=$(systemctl list-units --type=service --state=running --no-legend | \
    while read -r service; do
        user=$(systemctl show "$service" --property=User --value 2>/dev/null)
        if [ -z "$user" ] || [ "$user" = "root" ]; then
            echo "$service"
        fi
    done | wc -l)

echo "Services running as root: $root_services"

# Check for services with high privileges
if command -v systemctl >/dev/null 2>&1; then
    privileged_services=$(systemctl list-units --type=service --state=running --no-legend | \
        while read -r service; do
            capabilities=$(systemctl show "$service" --property=AmbientCapabilities --value 2>/dev/null)
            if [ -n "$capabilities" ] && [ "$capabilities" != "0" ]; then
                echo "$service"
            fi
        done | wc -l)
    echo "Services with elevated capabilities: $privileged_services"
fi

# Boot target information
echo
echo "🎯 BOOT TARGET"
echo "============="
default_target=$(systemctl get-default)
echo "Default target: $default_target"
current_target=$(systemctl list-units --type=target --state=active | grep "\.target" | grep "active" | awk '{print $1}' | head -1)
echo "Current target: $current_target"

# Kernel boot time (if available)
echo
echo "⚡ KERNEL BOOT TIME"
echo "=================="
if [ -f /proc/uptime ]; then
    uptime_seconds=$(awk '{print $1}' /proc/uptime)
    echo "System uptime: $uptime_seconds seconds"
    
    # Try to get kernel boot time from dmesg
    if dmesg | grep -q "Freeing unused kernel memory"; then
        kernel_time=$(dmesg | grep "Freeing unused kernel memory" | head -1 | awk '{print $2}' | sed 's/\]//')
        echo "Kernel boot completed: ~${kernel_time}s"
    fi
fi

echo
echo "💡 OPTIMIZATION TIPS"
echo "==================="
echo "To improve boot time:"

# Analyze slow services and suggest optimizations
systemd-analyze blame | head -5 | while read -r time service; do
    service_name=$(echo "$service" | sed 's/\.service$//')
    case "$service_name" in
        "NetworkManager-wait-online"|"systemd-networkd-wait-online")
            echo "  • Consider disabling wait-online services if not needed"
            echo "    systemctl disable $service"
            ;;
        "plymouth"*)
            echo "  • Consider disabling Plymouth boot splash for faster boot"
            echo "    systemctl disable $service"
            ;;
        "snapd"*)
            echo "  • Snap services can be slow - consider alternatives if possible"
            ;;
        *)
            time_val=$(echo "$time" | sed 's/[a-z]*$//')
            if [[ "$time" =~ s$ ]] && (( $(echo "$time_val > 10" | bc -l 2>/dev/null || echo 0) )); then
                echo "  • Investigate why $service takes $time to start"
                echo "    service_logs $service_name"
            fi
            ;;
    esac
done | head -3

echo "  • Run 'systemd-analyze plot > boot.svg' to generate visual timeline"
echo "  • Use 'systemctl disable <service>' to prevent unnecessary services from starting"
```

### systemd_health
```bash
#!/bin/bash
# systemd_health - Overall systemd system health check
set -euo pipefail

echo "🏥 SYSTEMD SYSTEM HEALTH"
echo "========================"
echo "Generated: $(date)"
echo

# Overall system state
echo "📊 SYSTEM STATE"
echo "=============="
system_state=$(systemctl is-system-running 2>/dev/null || echo "unknown")
echo "System state: $system_state"

case "$system_state" in
    "running")
        echo "✅ System is running normally"
        ;;
    "degraded")
        echo "⚠️  System is degraded (some services failed)"
        ;;
    "maintenance")
        echo "🔧 System is in maintenance mode"
        ;;
    "initializing")
        echo "🚀 System is still initializing"
        ;;
    *)
        echo "❓ System state unknown"
        ;;
esac

# Service statistics
echo
echo "📈 SERVICE STATISTICS"
echo "===================="
total_services=$(systemctl list-units --type=service --no-legend | wc -l)
active_services=$(systemctl list-units --type=service --state=active --no-legend | wc -l)
failed_services=$(systemctl list-units --type=service --state=failed --no-legend | wc -l)
inactive_services=$((total_services - active_services - failed_services))

echo "Total services: $total_services"
echo "Active services: $active_services"
echo "Failed services: $failed_services"
echo "Inactive services: $inactive_services"

# Calculate health percentage
if [ "$total_services" -gt 0 ]; then
    health_percent=$(( (active_services * 100) / total_services ))
    echo "Health score: ${health_percent}%"
else
    echo "Health score: N/A"
fi

# Failed services details
if [ "$failed_services" -gt 0 ]; then
    echo
    echo "❌ FAILED SERVICES"
    echo "=================="
    systemctl list-units --type=service --state=failed --no-legend | \
        head -5 | awk '{print "  🔴 " $1 " (" $3 " " $4 ")"}'
    
    if [ "$failed_services" -gt 5 ]; then
        echo "  ... and $((failed_services - 5)) more"
    fi
fi

# Timer health
echo
echo "⏰ TIMER HEALTH"
echo "=============="
total_timers=$(systemctl list-timers --all --no-legend | wc -l)
active_timers=$(systemctl list-timers --state=active --no-legend | wc -l)

echo "Total timers: $total_timers"
echo "Active timers: $active_timers"

if [ "$total_timers" -gt 0 ] && [ "$active_timers" -eq "$total_timers" ]; then
    echo "✅ All timers are active"
elif [ "$active_timers" -eq 0 ]; then
    echo "⚠️  No active timers"
else
    echo "⚠️  Some timers are inactive"
fi

# System resource usage by systemd
echo
echo "💾 SYSTEMD RESOURCE USAGE"
echo "========================"

# Get systemd's own resource usage
systemd_memory=$(systemctl show --property=MemoryCurrent --value init.scope 2>/dev/null || echo "0")
if [ "$systemd_memory" != "0" ] && [ -n "$systemd_memory" ]; then
    systemd_memory_mb=$(( systemd_memory / 1024 / 1024 ))
    echo "Systemd memory usage: ${systemd_memory_mb} MB"
fi

# Count total processes managed by systemd
total_processes=$(systemctl show --property=TasksCurrent --value user.slice system.slice 2>/dev/null | \
    awk '{sum += $1} END {print sum}' || echo "unknown")
if [ "$total_processes" != "unknown" ] && [ "$total_processes" -gt 0 ]; then
    echo "Processes under systemd: $total_processes"
fi

# Journal size
if command -v journalctl >/dev/null 2>&1; then
    journal_size=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMGT]B' || echo "unknown")
    echo "Journal disk usage: $journal_size"
fi

# Boot performance summary
echo
echo "🚀 BOOT PERFORMANCE"
echo "=================="
if command -v systemd-analyze >/dev/null 2>&1; then
    boot_time=$(systemd-analyze 2>/dev/null | head -1 | grep -o '[0-9.]*s' | head -1 || echo "unknown")
    if [ "$boot_time" != "unknown" ]; then
        boot_time_num=$(echo "$boot_time" | sed 's/s$//')
        echo "Last boot time: $boot_time"
        
        if (( $(echo "$boot_time_num > 60" | bc -l 2>/dev/null || echo 0) )); then
            echo "⚠️  Boot time is slow (>60s)"
        elif (( $(echo "$boot_time_num > 30" | bc -l 2>/dev/null || echo 0) )); then
            echo "⚠️  Boot time is moderate (>30s)"
        else
            echo "✅ Boot time is good (<30s)"
        fi
    fi
fi

# Overall health assessment
echo
echo "🎯 OVERALL ASSESSMENT"
echo "===================="

health_issues=()
health_score=100

if [ "$failed_services" -gt 0 ]; then
    health_score=$((health_score - (failed_services * 10)))
    health_issues+=("$failed_services failed services")
fi

if [ "$system_state" != "running" ]; then
    health_score=$((health_score - 20))
    health_issues+=("system not in running state")
fi

if [ "$total_timers" -gt 0 ] && [ "$active_timers" -lt "$total_timers" ]; then
    health_score=$((health_score - 5))
    health_issues+=("inactive timers")
fi

# Ensure health score doesn't go negative
if [ "$health_score" -lt 0 ]; then
    health_score=0
fi

if [ ${#health_issues[@]} -eq 0 ]; then
    echo "✅ Systemd health: ${health_score}% - Excellent"
    echo "   All services running normally"
else
    echo "⚠️  Systemd health: ${health_score}%"
    echo "   Issues detected:"
    for issue in "${health_issues[@]}"; do
        echo "   - $issue"
    done
    
    echo
    echo "💡 Recommended actions:"
    if [ "$failed_services" -gt 0 ]; then
        echo "   - Review failed services: service_list_failed"
        echo "   - Restart critical services: service_restart <service>"
    fi
    if [ "$system_state" != "running" ]; then
        echo "   - Check system status: systemctl status"
    fi
fi
```

## Installation

Copy this skill to your OpenClaw skills directory:
```bash
cp -r systemd-manager ~/.openclaw/skills/
```

Or install via ClawHub (when published):
```bash
openclaw skill install systemd-manager
```

## Dependencies

- systemd (present on most modern Linux distributions)
- systemctl command
- journalctl for log access
- Optional: systemd-analyze for boot analysis
- Optional: bc for numerical calculations

## Security Notes

- Service control commands require appropriate user permissions
- Critical services (SSH, networking) have confirmation prompts
- No automatic service deletion - only start/stop/restart/enable/disable
- Log access respects systemd journal permissions

## Integration Examples

### Heartbeat Monitoring
Add to `HEARTBEAT.md`:
```bash
# Check for failed services every ~3 hours
failed_count=$(systemctl --failed --no-legend | wc -l)
if [ "$failed_count" -gt 0 ]; then
    echo "⚠️  $failed_count systemd service(s) failed"
    service_list_failed
fi
```

### Automated Service Recovery
```bash
# Auto-restart critical services if they fail
critical_services=("nginx" "docker" "ssh")
for service in "${critical_services[@]}"; do
    if ! systemctl is-active "$service" >/dev/null 2>&1; then
        echo "🔄 Auto-restarting critical service: $service"
        service_restart "$service"
    fi
done
```

### Boot Performance Monitoring
```bash
# Alert if boot time is excessive (run after reboot)
if command -v systemd-analyze >/dev/null 2>&1; then
    boot_time=$(systemd-analyze | grep -o '[0-9.]*s' | head -1 | sed 's/s$//')
    if (( $(echo "$boot_time > 120" | bc -l 2>/dev/null || echo 0) )); then
        echo "⚠️  Slow boot detected: ${boot_time}s"
        boot_time
    fi
fi
```