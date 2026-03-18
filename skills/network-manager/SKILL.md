# Network Manager Skill

Comprehensive network management, monitoring, and diagnostics for OpenClaw agents.

## Description

This skill provides complete network infrastructure management capabilities, from interface configuration to connectivity testing and firewall management. Perfect for maintaining server network health and troubleshooting connectivity issues.

## Commands

### Network Status & Monitoring
- `net_status` — All interfaces with IPs, gateway, DNS configuration
- `net_connections` — Active connections with process information
- `net_bandwidth` — Current bandwidth usage per interface
- `net_interfaces` — Detailed interface configuration and statistics

### Connectivity Testing  
- `net_ping <host>` — Connectivity test with detailed analysis
- `net_trace <host>` — Traceroute with geographic information
- `net_dns_check` — DNS resolution testing and performance
- `net_speed_test` — Network speed test (if speedtest-cli available)

### Network Security & Firewall
- `net_firewall` — Current firewall rules and status
- `net_ports` — Listening ports with process information
- `net_scan <target>` — Network connectivity scan
- `net_security` — Network security assessment

### Troubleshooting & Diagnostics
- `net_diagnostics` — Complete network health check
- `net_routing` — Routing table and gateway analysis
- `net_arp` — ARP table and neighbor discovery

## Scripts

### net_status
```bash
#!/bin/bash
# net_status - Complete network interface and configuration overview
set -euo pipefail

echo "🌐 NETWORK STATUS OVERVIEW"
echo "=========================="
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo

# Network interfaces with IP addresses
echo "🔗 NETWORK INTERFACES"
echo "====================="

ip addr show | awk '
BEGIN { interface = "" }
/^[0-9]+:/ { 
    if (interface != "") print ""
    interface = $2
    gsub(/:/, "", interface)
    state = ($3 == "UP") ? "🟢 UP" : "🔴 DOWN"
    printf "%-15s %s", interface, state
    # Extract additional interface info
    getline
    while ($0 ~ /^ /) {
        if ($1 == "link/ether") {
            printf " (MAC: %s)", $2
        }
        getline
    }
    print ""
}
/inet / && !/127\.0\.0\.1/ {
    printf "%-15s %s\n", "", $2
}
/inet6/ && !/::1/ {
    printf "%-15s %s\n", "", $2
}'

echo
echo "🛣️  ROUTING INFORMATION"
echo "======================"

# Default gateway
default_route=$(ip route | grep default || echo "No default route")
if [[ "$default_route" != "No default route" ]]; then
    gateway_ip=$(echo "$default_route" | awk '{print $3}')
    gateway_interface=$(echo "$default_route" | awk '{print $5}')
    echo "Default Gateway: $gateway_ip via $gateway_interface"
    
    # Test gateway connectivity
    if ping -c 1 -W 2 "$gateway_ip" >/dev/null 2>&1; then
        echo "Gateway Status: ✅ Reachable"
    else
        echo "Gateway Status: ❌ Unreachable"
    fi
else
    echo "Default Gateway: ❌ Not configured"
fi

# Additional routes
route_count=$(ip route | grep -v default | wc -l)
if [ "$route_count" -gt 0 ]; then
    echo "Additional Routes: $route_count"
    ip route | grep -v default | head -5 | sed 's/^/  /'
fi

echo
echo "🔍 DNS CONFIGURATION"
echo "==================="

# DNS resolver status
if command -v systemd-resolve >/dev/null 2>&1 || command -v resolvectl >/dev/null 2>&1; then
    echo "DNS System: systemd-resolved"
    if command -v resolvectl >/dev/null 2>&1; then
        resolvectl status | grep -A 10 "Global" | head -10
    else
        systemd-resolve --status | grep -A 10 "Global" | head -10
    fi
else
    echo "DNS System: /etc/resolv.conf"
    if [ -f /etc/resolv.conf ]; then
        echo "DNS Servers:"
        grep nameserver /etc/resolv.conf | sed 's/^/  /'
        
        # Test DNS resolution
        echo
        echo "DNS Resolution Test:"
        for dns_server in $(grep nameserver /etc/resolv.conf | awk '{print $2}'); do
            if timeout 3 nslookup google.com "$dns_server" >/dev/null 2>&1; then
                echo "  $dns_server: ✅ Working"
            else
                echo "  $dns_server: ❌ Failed"
            fi
        done
    else
        echo "❌ No /etc/resolv.conf found"
    fi
fi

echo
echo "📊 INTERFACE STATISTICS"
echo "======================="

# Interface traffic statistics
cat /proc/net/dev | awk '
BEGIN {
    printf "%-12s %10s %10s %10s %10s %8s %8s\n", 
           "Interface", "RX Bytes", "RX Packets", "TX Bytes", "TX Packets", "RX Errs", "TX Errs"
    printf "%-12s %10s %10s %10s %10s %8s %8s\n", 
           "=========", "========", "==========", "========", "==========", "======", "======"
}
NR > 2 {
    gsub(/:/, "", $1)
    # Convert bytes to human readable
    rx_bytes = $2
    rx_packets = $3
    rx_errors = $4
    tx_bytes = $10
    tx_packets = $11  
    tx_errors = $12
    
    if (rx_bytes > 1024*1024*1024) rx_display = sprintf("%.1fGB", rx_bytes/1024/1024/1024)
    else if (rx_bytes > 1024*1024) rx_display = sprintf("%.1fMB", rx_bytes/1024/1024)
    else if (rx_bytes > 1024) rx_display = sprintf("%.1fKB", rx_bytes/1024)
    else rx_display = rx_bytes "B"
    
    if (tx_bytes > 1024*1024*1024) tx_display = sprintf("%.1fGB", tx_bytes/1024/1024/1024)
    else if (tx_bytes > 1024*1024) tx_display = sprintf("%.1fMB", tx_bytes/1024/1024)
    else if (tx_bytes > 1024) tx_display = sprintf("%.1fKB", tx_bytes/1024)
    else tx_display = tx_bytes "B"
    
    printf "%-12s %10s %10s %10s %10s %8s %8s\n", 
           $1, rx_display, rx_packets, tx_display, tx_packets, rx_errors, tx_errors
}'

echo
echo "🌍 EXTERNAL CONNECTIVITY"
echo "========================"

# Test external connectivity
echo "Testing external connectivity..."

# Test DNS resolution
if nslookup google.com >/dev/null 2>&1; then
    echo "DNS Resolution: ✅ Working"
else
    echo "DNS Resolution: ❌ Failed"
fi

# Test HTTP connectivity
if timeout 5 curl -s http://www.google.com >/dev/null 2>&1; then
    echo "HTTP Access: ✅ Working"
else
    echo "HTTP Access: ❌ Failed"
fi

# Test HTTPS connectivity
if timeout 5 curl -s https://www.google.com >/dev/null 2>&1; then
    echo "HTTPS Access: ✅ Working"
else
    echo "HTTPS Access: ❌ Failed"
fi

# Get external IP if possible
external_ip=$(timeout 5 curl -s ifconfig.me 2>/dev/null || echo "Unable to determine")
echo "External IP: $external_ip"

echo
echo "🔧 NETWORK TOOLS AVAILABLE"
echo "=========================="

tools=("ping" "traceroute" "nslookup" "dig" "wget" "curl" "ss" "netstat" "iftop" "tcpdump")
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool"
    else
        echo "❌ $tool (not installed)"
    fi
done
```

### net_connections
```bash
#!/bin/bash
# net_connections - Active network connections with process information
set -euo pipefail

echo "🔌 ACTIVE NETWORK CONNECTIONS"
echo "============================="
echo "Generated: $(date)"
echo

# Summary statistics
echo "📊 CONNECTION SUMMARY"
echo "====================="

tcp_connections=$(ss -t | grep -v State | wc -l)
udp_connections=$(ss -u | grep -v State | wc -l)  
listening_tcp=$(ss -tl | grep -v State | wc -l)
listening_udp=$(ss -ul | grep -v State | wc -l)

echo "Active TCP connections: $tcp_connections"
echo "Active UDP connections: $udp_connections"
echo "TCP listening ports: $listening_tcp"
echo "UDP listening ports: $listening_udp"

echo
echo "🎧 LISTENING SERVICES"
echo "===================="
echo "Proto Local Address           Process/PID"
echo "===== ==================== ==============================="

ss -tlnp | grep LISTEN | while IFS= read -r line; do
    proto=$(echo "$line" | awk '{print $1}')
    local_addr=$(echo "$line" | awk '{print $4}')
    process_info=$(echo "$line" | awk '{print $6}' | sed 's/users:((//' | sed 's/))//' | cut -d'"' -f2)
    pid=$(echo "$line" | awk '{print $6}' | grep -o 'pid=[0-9]*' | cut -d'=' -f2 || echo "")
    
    if [ -n "$pid" ]; then
        printf "%-5s %-20s %s (PID: %s)\n" "$proto" "$local_addr" "$process_info" "$pid"
    else
        printf "%-5s %-20s %s\n" "$proto" "$local_addr" "$process_info"
    fi
done

echo
echo "🔗 ESTABLISHED CONNECTIONS"
echo "=========================="
echo "Proto Local Address           Peer Address             State      Process"
echo "===== ==================== ======================= ========== ============"

ss -tnp | grep ESTAB | head -20 | while IFS= read -r line; do
    proto=$(echo "$line" | awk '{print $1}')
    local_addr=$(echo "$line" | awk '{print $4}')
    peer_addr=$(echo "$line" | awk '{print $5}')
    state=$(echo "$line" | awk '{print $2}')
    process_info=$(echo "$line" | awk '{print $6}' | cut -d'"' -f2 | head -c 15)
    
    printf "%-5s %-20s %-23s %-10s %s\n" "$proto" "$local_addr" "$peer_addr" "$state" "$process_info"
done

# Show count if there are more than 20
total_established=$(ss -tnp | grep ESTAB | wc -l)
if [ "$total_established" -gt 20 ]; then
    echo "... and $((total_established - 20)) more established connections"
fi

echo
echo "📈 CONNECTION STATISTICS BY STATE"
echo "=================================="

ss -tan | awk 'NR>1 {print $2}' | sort | uniq -c | sort -nr | head -10 | while read -r count state; do
    case "$state" in
        "LISTEN")
            echo "🎧 Listening: $count"
            ;;
        "ESTAB")
            echo "🔗 Established: $count"
            ;;
        "TIME-WAIT")
            echo "⏳ Time-Wait: $count"
            ;;
        "CLOSE-WAIT")
            echo "⏸️  Close-Wait: $count"
            ;;
        "FIN-WAIT-1"|"FIN-WAIT-2")
            echo "🔚 Fin-Wait: $count"
            ;;
        *)
            echo "❓ $state: $count"
            ;;
    esac
done

echo
echo "🌐 TOP REMOTE HOSTS"
echo "=================="

ss -tnp | grep ESTAB | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -nr | head -10 | while read -r count ip; do
    # Try to resolve hostname
    hostname=$(timeout 2 nslookup "$ip" 2>/dev/null | grep "name =" | awk '{print $4}' | sed 's/\.$//') || hostname=""
    
    if [ -n "$hostname" ]; then
        echo "$ip ($hostname): $count connections"
    else
        echo "$ip: $count connections"
    fi
done

echo
echo "📊 NETWORK USAGE BY PROCESS"
echo "==========================="

# Get network usage by process (requires ss with process info)
echo "Process                  TCP Connections  UDP Sockets"
echo "======================= ================ ============"

ss -tnup | grep -E "(ESTAB|UNCONN)" | awk '{
    if ($6 ~ /users:/) {
        gsub(/.*users:\(\(\"/, "", $6)
        gsub(/\".*/, "", $6)
        if ($1 == "tcp") tcp[$6]++
        else if ($1 == "udp") udp[$6]++
    }
}
END {
    for (proc in tcp) {
        printf "%-23s %-16d %d\n", proc, tcp[proc], udp[proc]+0
    }
    for (proc in udp) {
        if (!(proc in tcp)) {
            printf "%-23s %-16d %d\n", proc, 0, udp[proc]
        }
    }
}' | sort -k2 -nr | head -15

echo
echo "⚠️  POTENTIAL SECURITY CONCERNS"
echo "==============================="

security_issues=0

# Check for unusual connections
foreign_connections=$(ss -tnp | grep ESTAB | awk '{print $5}' | cut -d':' -f1 | grep -v "^127\.\|^192\.168\.\|^10\.\|^172\." | wc -l)
if [ "$foreign_connections" -gt 0 ]; then
    echo "🌍 $foreign_connections external connections detected"
    security_issues=$((security_issues + 1))
fi

# Check for high port usage
high_ports=$(ss -tnp | grep ESTAB | awk '{print $4}' | cut -d':' -f2 | awk '$1 > 60000' | wc -l)
if [ "$high_ports" -gt 100 ]; then
    echo "⚠️  High number of connections using ephemeral ports: $high_ports"
    security_issues=$((security_issues + 1))
fi

# Check for many TIME-WAIT connections
time_wait_count=$(ss -tan | grep TIME-WAIT | wc -l)
if [ "$time_wait_count" -gt 1000 ]; then
    echo "⏳ High number of TIME-WAIT connections: $time_wait_count (possible DoS or high load)"
    security_issues=$((security_issues + 1))
fi

# Check for unusual listening ports
unusual_ports=$(ss -tlnp | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | grep -v -E "^(22|25|53|80|443|993|995|587|143|110|25|465)$" | wc -l)
if [ "$unusual_ports" -gt 10 ]; then
    echo "🔍 Many unusual listening ports: $unusual_ports (review needed)"
    security_issues=$((security_issues + 1))
fi

if [ "$security_issues" -eq 0 ]; then
    echo "✅ No obvious security concerns detected"
fi

echo
echo "💡 NETWORK MONITORING TIPS"
echo "=========================="
echo "• Monitor connections: watch -n 2 'ss -tuln'"
echo "• Real-time traffic: iftop (if installed)"
echo "• Capture packets: tcpdump -i any host <ip>"
echo "• Check firewall: net_firewall"
echo "• Test connectivity: net_ping <host>"
```

### net_ping
```bash
#!/bin/bash
# net_ping - Advanced connectivity testing with analysis
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: net_ping <hostname_or_ip> [count] [size]"
    echo "Examples:"
    echo "  net_ping google.com"
    echo "  net_ping 8.8.8.8 10"
    echo "  net_ping cloudflare.com 5 1024"
    exit 1
fi

TARGET="$1"
COUNT="${2:-10}"
SIZE="${3:-56}"  # Default ping size (excluding headers)

echo "🏓 CONNECTIVITY TEST: $TARGET"
echo "$(printf '=%.0s' {1..50})"
echo "Target: $TARGET"
echo "Count: $COUNT packets"
echo "Size: $SIZE bytes"
echo "Started: $(date)"
echo "$(printf '=%.0s' {1..50})"

# Resolve hostname if needed
echo "🔍 HOSTNAME RESOLUTION"
echo "======================"

if [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # It's an IP address
    echo "Target is IP address: $TARGET"
    
    # Try reverse DNS lookup
    reverse_dns=$(timeout 5 nslookup "$TARGET" 2>/dev/null | grep "name =" | awk '{print $4}' | sed 's/\.$//' || echo "No reverse DNS")
    echo "Reverse DNS: $reverse_dns"
    resolved_ip="$TARGET"
else
    # It's a hostname
    echo "Resolving hostname: $TARGET"
    
    # Multiple DNS resolution methods
    if command -v dig >/dev/null 2>&1; then
        resolved_ip=$(dig +short "$TARGET" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    elif command -v nslookup >/dev/null 2>&1; then
        resolved_ip=$(nslookup "$TARGET" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    else
        resolved_ip=$(getent hosts "$TARGET" | awk '{print $1}' | head -1)
    fi
    
    if [ -n "$resolved_ip" ]; then
        echo "Resolved IP: $resolved_ip"
    else
        echo "❌ Failed to resolve hostname"
        exit 1
    fi
fi

echo
echo "🛣️  ROUTE TO TARGET"
echo "=================="

# Get route to target
route_info=$(ip route get "$resolved_ip" 2>/dev/null || echo "Route not found")
if [ "$route_info" != "Route not found" ]; then
    gateway=$(echo "$route_info" | grep -o 'via [0-9.]*' | awk '{print $2}' || echo "direct")
    interface=$(echo "$route_info" | grep -o 'dev [^ ]*' | awk '{print $2}' || echo "unknown")
    source_ip=$(echo "$route_info" | grep -o 'src [0-9.]*' | awk '{print $2}' || echo "unknown")
    
    echo "Gateway: $gateway"
    echo "Interface: $interface"
    echo "Source IP: $source_ip"
else
    echo "❌ Cannot determine route to target"
fi

echo
echo "🏓 PING RESULTS"
echo "=============="

# Perform ping with detailed output
ping_output=$(ping -c "$COUNT" -s "$SIZE" "$TARGET" 2>&1)
ping_exit_code=$?

if [ $ping_exit_code -eq 0 ]; then
    echo "$ping_output"
    
    echo
    echo "📊 PING ANALYSIS"
    echo "================"
    
    # Extract statistics
    packet_loss=$(echo "$ping_output" | grep "packet loss" | awk '{print $6}' | tr -d '%')
    min_time=$(echo "$ping_output" | grep "min/avg/max" | cut -d'=' -f2 | cut -d'/' -f1)
    avg_time=$(echo "$ping_output" | grep "min/avg/max" | cut -d'=' -f2 | cut -d'/' -f2)
    max_time=$(echo "$ping_output" | grep "min/avg/max" | cut -d'=' -f2 | cut -d'/' -f3)
    stddev=$(echo "$ping_output" | grep "min/avg/max" | cut -d'=' -f2 | cut -d'/' -f4 | cut -d' ' -f1)
    
    echo "📈 Statistics Summary:"
    echo "  Packet Loss: $packet_loss%"
    echo "  Min RTT: ${min_time}ms"
    echo "  Avg RTT: ${avg_time}ms"
    echo "  Max RTT: ${max_time}ms"
    echo "  Std Dev: ${stddev}ms"
    
    # Analyze results
    echo
    echo "🎯 CONNECTIVITY ASSESSMENT"
    echo "=========================="
    
    if [ "${packet_loss%.*}" -eq 0 ]; then
        echo "✅ Connectivity: Excellent (no packet loss)"
    elif [ "${packet_loss%.*}" -lt 5 ]; then
        echo "✅ Connectivity: Good ($packet_loss% loss)"
    elif [ "${packet_loss%.*}" -lt 20 ]; then
        echo "⚠️  Connectivity: Fair ($packet_loss% loss)"
    else
        echo "❌ Connectivity: Poor ($packet_loss% loss)"
    fi
    
    # Latency assessment
    avg_int=$(printf "%.0f" "$avg_time")
    if [ "$avg_int" -lt 50 ]; then
        echo "✅ Latency: Excellent (${avg_time}ms avg)"
    elif [ "$avg_int" -lt 100 ]; then
        echo "✅ Latency: Good (${avg_time}ms avg)"
    elif [ "$avg_int" -lt 200 ]; then
        echo "⚠️  Latency: Fair (${avg_time}ms avg)"
    else
        echo "❌ Latency: Poor (${avg_time}ms avg)"
    fi
    
    # Jitter assessment
    stddev_int=$(printf "%.0f" "$stddev")
    if [ "$stddev_int" -lt 10 ]; then
        echo "✅ Jitter: Low (${stddev}ms std dev)"
    elif [ "$stddev_int" -lt 20 ]; then
        echo "⚠️  Jitter: Moderate (${stddev}ms std dev)"
    else
        echo "❌ Jitter: High (${stddev}ms std dev)"
    fi
    
    echo
    echo "🌍 NETWORK PATH ANALYSIS"
    echo "========================"
    
    # Determine network type based on IP
    if [[ "$resolved_ip" =~ ^10\. ]] || [[ "$resolved_ip" =~ ^192\.168\. ]] || [[ "$resolved_ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        echo "📍 Network Type: Private/Internal"
    elif [[ "$resolved_ip" =~ ^127\. ]]; then
        echo "📍 Network Type: Loopback/Local"
    else
        echo "📍 Network Type: Public/Internet"
        
        # For public IPs, try to get geolocation
        if command -v curl >/dev/null 2>&1; then
            geo_info=$(timeout 5 curl -s "http://ip-api.com/line/$resolved_ip?fields=country,regionName,city,isp" 2>/dev/null || echo "")
            if [ -n "$geo_info" ]; then
                country=$(echo "$geo_info" | sed -n '1p')
                region=$(echo "$geo_info" | sed -n '2p')  
                city=$(echo "$geo_info" | sed -n '3p')
                isp=$(echo "$geo_info" | sed -n '4p')
                echo "🌍 Location: $city, $region, $country"
                echo "🏢 ISP: $isp"
            fi
        fi
    fi
    
else
    echo "❌ PING FAILED"
    echo "=============="
    echo "$ping_output"
    
    echo
    echo "🔍 TROUBLESHOOTING STEPS"
    echo "======================="
    echo "1. Check DNS resolution: nslookup $TARGET"
    echo "2. Check routing: ip route get $TARGET"
    echo "3. Check firewall: net_firewall"
    echo "4. Try traceroute: net_trace $TARGET"
    echo "5. Check interface status: net_status"
fi

echo
echo "💡 ADDITIONAL TESTS"
echo "==================="
echo "• Traceroute: net_trace $TARGET"
echo "• Port check: telnet $TARGET <port>"
echo "• DNS test: net_dns_check"
echo "• Full diagnostics: net_diagnostics"
```

### net_trace
```bash
#!/bin/bash
# net_trace - Traceroute with geographic and performance analysis
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: net_trace <hostname_or_ip> [max_hops]"
    echo "Examples:"
    echo "  net_trace google.com"
    echo "  net_trace 8.8.8.8 15"
    exit 1
fi

TARGET="$1"
MAX_HOPS="${2:-30}"

echo "🛣️  NETWORK ROUTE TRACE: $TARGET"
echo "$(printf '=%.0s' {1..50})"
echo "Target: $TARGET"
echo "Max hops: $MAX_HOPS"
echo "Started: $(date)"
echo "$(printf '=%.0s' {1..50})"

# Choose traceroute command
TRACE_CMD=""
if command -v traceroute >/dev/null 2>&1; then
    TRACE_CMD="traceroute"
elif command -v tracert >/dev/null 2>&1; then
    TRACE_CMD="tracert"
else
    echo "❌ No traceroute command available"
    echo "Install with: sudo apt install traceroute"
    exit 1
fi

echo "🔍 TRACING ROUTE"
echo "==============="

# Run traceroute and capture output
trace_output=$(timeout 60 $TRACE_CMD -m "$MAX_HOPS" "$TARGET" 2>&1)
trace_exit_code=$?

if [ $trace_exit_code -eq 0 ] || [ $trace_exit_code -eq 124 ]; then
    echo "$trace_output"
    
    echo
    echo "📊 ROUTE ANALYSIS"
    echo "================="
    
    # Extract hop information
    hop_count=$(echo "$trace_output" | grep -E '^ *[0-9]+' | wc -l)
    echo "Total hops: $hop_count"
    
    # Analyze latencies
    max_latency=0
    total_latency=0
    hop_count_with_time=0
    
    echo "$trace_output" | grep -E '^ *[0-9]+' | while IFS= read -r line; do
        # Extract latencies from the line (look for ms values)
        latencies=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+' | head -3)
        if [ -n "$latencies" ]; then
            for latency in $latencies; do
                if (( $(echo "$latency > $max_latency" | bc -l 2>/dev/null || echo 0) )); then
                    max_latency=$latency
                fi
                total_latency=$(echo "$total_latency + $latency" | bc -l 2>/dev/null || echo "$total_latency")
                hop_count_with_time=$((hop_count_with_time + 1))
            done
        fi
    done 2>/dev/null
    
    if [ "$hop_count_with_time" -gt 0 ]; then
        avg_latency=$(echo "scale=2; $total_latency / $hop_count_with_time" | bc -l 2>/dev/null || echo "0")
        echo "Average hop latency: ${avg_latency}ms"
        echo "Maximum hop latency: ${max_latency}ms"
    fi
    
    echo
    echo "🌍 GEOGRAPHIC PATH ANALYSIS"
    echo "==========================="
    
    # Extract unique IP addresses from traceroute output
    unique_ips=$(echo "$trace_output" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort | uniq)
    
    if [ -n "$unique_ips" ] && command -v curl >/dev/null 2>&1; then
        echo "Analyzing route geography..."
        echo
        
        hop_num=1
        echo "$trace_output" | grep -E '^ *[0-9]+' | while IFS= read -r line; do
            # Extract IP from this hop
            hop_ip=$(echo "$line" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -1)
            
            if [ -n "$hop_ip" ]; then
                # Get geolocation for public IPs
                if [[ ! "$hop_ip" =~ ^10\. ]] && [[ ! "$hop_ip" =~ ^192\.168\. ]] && [[ ! "$hop_ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && [[ ! "$hop_ip" =~ ^127\. ]]; then
                    geo_info=$(timeout 3 curl -s "http://ip-api.com/line/$hop_ip?fields=country,regionName,city,isp" 2>/dev/null)
                    if [ -n "$geo_info" ] && [ "$geo_info" != "fail" ]; then
                        country=$(echo "$geo_info" | sed -n '1p')
                        city=$(echo "$geo_info" | sed -n '3p')
                        isp=$(echo "$geo_info" | sed -n '4p')
                        printf "Hop %2d (%s): %s, %s - %s\n" "$hop_num" "$hop_ip" "$city" "$country" "$isp"
                    else
                        printf "Hop %2d (%s): Geographic data unavailable\n" "$hop_num" "$hop_ip"
                    fi
                else
                    printf "Hop %2d (%s): Private/Local network\n" "$hop_num" "$hop_ip"
                fi
            else
                printf "Hop %2d: No response (* * *)\n" "$hop_num"
            fi
            
            hop_num=$((hop_num + 1))
            
            # Rate limit API calls
            sleep 0.2
        done
    else
        echo "Geographic analysis unavailable (no curl or no IPs found)"
    fi
    
    echo
    echo "🔍 ROUTE QUALITY ASSESSMENT"
    echo "==========================="
    
    # Count timeouts and failed hops
    timeout_count=$(echo "$trace_output" | grep -c '\* \* \*' || echo 0)
    successful_hops=$((hop_count - timeout_count))
    
    echo "Successful hops: $successful_hops/$hop_count"
    echo "Timeout hops: $timeout_count"
    
    if [ "$timeout_count" -eq 0 ]; then
        echo "✅ Route Quality: Excellent (no timeouts)"
    elif [ "$timeout_count" -lt 3 ]; then
        echo "✅ Route Quality: Good (few timeouts)"
    elif [ "$timeout_count" -lt 6 ]; then
        echo "⚠️  Route Quality: Fair (some timeouts)"
    else
        echo "❌ Route Quality: Poor (many timeouts)"
    fi
    
    # Analyze for common issues
    echo
    echo "🚨 POTENTIAL ISSUES"
    echo "=================="
    
    issues_found=0
    
    # Check for excessive hops
    if [ "$hop_count" -gt 20 ]; then
        echo "⚠️  Excessive hop count ($hop_count) - route may be suboptimal"
        issues_found=$((issues_found + 1))
    fi
    
    # Check for high latency increases
    if [ -n "$max_latency" ] && (( $(echo "$max_latency > 500" | bc -l 2>/dev/null || echo 0) )); then
        echo "⚠️  High latency detected (${max_latency}ms) - possible congestion"
        issues_found=$((issues_found + 1))
    fi
    
    # Check for many consecutive timeouts
    consecutive_timeouts=$(echo "$trace_output" | grep -E '^ *[0-9]+' | grep '\* \* \*' | wc -l)
    if [ "$consecutive_timeouts" -gt 3 ]; then
        echo "⚠️  Multiple consecutive timeouts - possible firewall blocking"
        issues_found=$((issues_found + 1))
    fi
    
    if [ "$issues_found" -eq 0 ]; then
        echo "✅ No obvious routing issues detected"
    fi
    
else
    echo "❌ TRACEROUTE FAILED"
    echo "=================="
    echo "$trace_output"
fi

echo
echo "💡 NETWORK DIAGNOSTICS TIPS"
echo "==========================="
echo "• Test connectivity: net_ping $TARGET"
echo "• Check DNS: net_dns_check"
echo "• Analyze a specific hop: net_ping <hop_ip>"
echo "• Check local routing: ip route get $TARGET"
echo "• Monitor with MTR: mtr $TARGET (if installed)"
```

### net_firewall
```bash
#!/bin/bash
# net_firewall - Comprehensive firewall analysis and status
set -euo pipefail

echo "🛡️  FIREWALL STATUS & CONFIGURATION"
echo "==================================="
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo

# Check UFW status
echo "🔥 UFW (Uncomplicated Firewall)"
echo "==============================="

if command -v ufw >/dev/null 2>&1; then
    ufw_status=$(ufw status verbose 2>/dev/null)
    if echo "$ufw_status" | grep -q "Status: active"; then
        echo "✅ UFW is ACTIVE"
        echo
        echo "$ufw_status"
        
        echo
        echo "📊 UFW Rule Analysis:"
        rule_count=$(ufw status numbered | grep -E '^\[' | wc -l)
        allow_rules=$(ufw status | grep -c "ALLOW" || echo 0)
        deny_rules=$(ufw status | grep -c "DENY" || echo 0)
        
        echo "  Total rules: $rule_count"
        echo "  Allow rules: $allow_rules"
        echo "  Deny rules: $deny_rules"
        
        # Check for overly permissive rules
        anywhere_rules=$(ufw status | grep -c "Anywhere" || echo 0)
        if [ "$anywhere_rules" -gt 5 ]; then
            echo "  ⚠️  Many 'Anywhere' rules: $anywhere_rules (review recommended)"
        else
            echo "  ✅ Rule specificity: Good"
        fi
        
    elif echo "$ufw_status" | grep -q "Status: inactive"; then
        echo "❌ UFW is INACTIVE"
        echo "⚠️  System is not protected by UFW firewall"
    else
        echo "❓ UFW status unknown"
        echo "$ufw_status"
    fi
else
    echo "❌ UFW not installed"
fi

echo
echo "🔧 iptables (Raw Rules)"
echo "======================"

if command -v iptables >/dev/null 2>&1; then
    # Check if we can read iptables (requires root for some info)
    if iptables -L >/dev/null 2>&1; then
        echo "✅ iptables accessible"
        
        echo
        echo "📋 iptables Summary:"
        
        # Count rules in different chains
        input_rules=$(iptables -L INPUT --line-numbers | grep -c '^[0-9]' || echo 0)
        output_rules=$(iptables -L OUTPUT --line-numbers | grep -c '^[0-9]' || echo 0)
        forward_rules=$(iptables -L FORWARD --line-numbers | grep -c '^[0-9]' || echo 0)
        
        echo "  INPUT chain rules: $input_rules"
        echo "  OUTPUT chain rules: $output_rules"
        echo "  FORWARD chain rules: $forward_rules"
        
        # Check default policies
        echo
        echo "📜 Chain Policies:"
        iptables -L | grep "^Chain" | while read -r line; do
            chain=$(echo "$line" | awk '{print $2}')
            policy=$(echo "$line" | grep -o '(policy [^)]*)' | sed 's/(policy //' | sed 's/)//')
            echo "  $chain: $policy"
        done
        
        echo
        echo "📋 iptables Rules (INPUT chain):"
        iptables -L INPUT -n --line-numbers | head -20
        
        # Look for common security rules
        echo
        echo "🔍 Security Analysis:"
        
        # Check for SSH protection
        ssh_rules=$(iptables -L INPUT -n | grep -c ":22 " || echo 0)
        if [ "$ssh_rules" -gt 0 ]; then
            echo "  ✅ SSH rules detected: $ssh_rules"
        else
            echo "  ⚠️  No specific SSH rules found"
        fi
        
        # Check for rate limiting
        rate_limit=$(iptables -L INPUT -n | grep -c "limit:" || echo 0)
        if [ "$rate_limit" -gt 0 ]; then
            echo "  ✅ Rate limiting rules: $rate_limit"
        else
            echo "  ⚠️  No rate limiting detected"
        fi
        
        # Check for DROP/REJECT rules
        drop_rules=$(iptables -L INPUT -n | grep -c "DROP\|REJECT" || echo 0)
        echo "  🚫 DROP/REJECT rules: $drop_rules"
        
    else
        echo "❌ iptables not accessible (may require root privileges)"
        echo "  Try running with sudo for full analysis"
    fi
else
    echo "❌ iptables not available"
fi

echo
echo "🔥 firewalld Status"
echo "=================="

if command -v firewall-cmd >/dev/null 2>&1; then
    if systemctl is-active firewalld >/dev/null 2>&1; then
        echo "✅ firewalld is active"
        
        # Get default zone
        default_zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "unknown")
        echo "Default zone: $default_zone"
        
        # List active zones
        active_zones=$(firewall-cmd --get-active-zones 2>/dev/null || echo "none")
        echo "Active zones:"
        echo "$active_zones" | sed 's/^/  /'
        
        # List services in default zone
        echo
        echo "Services in $default_zone zone:"
        firewall-cmd --list-services --zone="$default_zone" 2>/dev/null | sed 's/^/  /' || echo "  Unable to list services"
        
    else
        echo "❌ firewalld is not active"
    fi
else
    echo "❌ firewalld not installed"
fi

echo
echo "🌐 Network Security Assessment"
echo "=============================="

# Check for open ports vs firewall rules
echo "🔍 Open Ports vs Firewall Protection:"

# Get listening ports
listening_ports=$(ss -tlnp | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | sort -n | uniq)

echo "$listening_ports" | while read -r port; do
    [ -z "$port" ] && continue
    
    protected=false
    
    # Check UFW protection
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "$port"; then
            protected=true
        fi
    fi
    
    # Check iptables protection  
    if command -v iptables >/dev/null 2>&1; then
        if iptables -L INPUT -n 2>/dev/null | grep -q ":$port "; then
            protected=true
        fi
    fi
    
    if [ "$protected" = true ]; then
        echo "  Port $port: ✅ Protected by firewall rules"
    else
        echo "  Port $port: ⚠️  No specific firewall rules found"
    fi
done

echo
echo "🚨 Security Recommendations"
echo "============================"

recommendations=()

# Check if any firewall is active
ufw_active=false
iptables_active=false
firewalld_active=false

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    ufw_active=true
fi

if command -v iptables >/dev/null 2>&1 && [ "$(iptables -L INPUT | wc -l)" -gt 3 ]; then
    iptables_active=true
fi

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
    firewalld_active=true
fi

if [ "$ufw_active" = false ] && [ "$iptables_active" = false ] && [ "$firewalld_active" = false ]; then
    recommendations+=("🚨 CRITICAL: No firewall appears to be active!")
    recommendations+=("Install and configure UFW: sudo apt install ufw && sudo ufw enable")
fi

# Check for common security issues
if command -v ss >/dev/null 2>&1; then
    # Check for risky open ports
    risky_ports=$(ss -tlnp | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | grep -E '^(21|23|25|53|111|135|139|445|512|513|514|2049|3389|5900|6000)$' | wc -l)
    if [ "$risky_ports" -gt 0 ]; then
        recommendations+=("⚠️  $risky_ports high-risk ports are open - review necessity")
    fi
    
    # Check for services binding to all interfaces
    all_interfaces=$(ss -tlnp | grep "0.0.0.0:" | wc -l)
    if [ "$all_interfaces" -gt 5 ]; then
        recommendations+=("⚠️  $all_interfaces services binding to all interfaces - consider restricting")
    fi
fi

# UFW-specific recommendations
if [ "$ufw_active" = true ]; then
    # Check UFW logging
    if ! ufw status verbose | grep -q "Logging: on"; then
        recommendations+=("Enable UFW logging: sudo ufw logging on")
    fi
    
    # Check for default deny policy
    if ! ufw status verbose | grep -q "Default: deny (incoming)"; then
        recommendations+=("Ensure UFW default deny policy: sudo ufw default deny incoming")
    fi
fi

# Display recommendations
if [ ${#recommendations[@]} -gt 0 ]; then
    for rec in "${recommendations[@]}"; do
        echo "$rec"
    done
else
    echo "✅ Firewall configuration appears secure"
fi

echo
echo "💡 Firewall Management Commands"
echo "==============================="
echo "UFW Commands:"
echo "  sudo ufw status                 # Show status"
echo "  sudo ufw allow 22               # Allow SSH"
echo "  sudo ufw deny 80                # Deny HTTP"
echo "  sudo ufw enable                 # Enable firewall"
echo "  sudo ufw reset                  # Reset to defaults"
echo
echo "iptables Commands:"
echo "  sudo iptables -L                # List rules"
echo "  sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # Allow SSH"
echo "  sudo iptables-save              # Save current rules"
echo
echo "Analysis Commands:"
echo "  net_ports                       # Check open ports"
echo "  net_security                    # Full security assessment"
echo "  security_audit                  # Complete security audit"
```

### net_diagnostics
```bash
#!/bin/bash
# net_diagnostics - Complete network health check and diagnostics
set -euo pipefail

echo "🔧 COMPREHENSIVE NETWORK DIAGNOSTICS"
echo "===================================="
echo "Started: $(date)"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo

# Initialize counters for final assessment
ISSUES=0
WARNINGS=0

log_issue() {
    local severity="$1"
    local message="$2"
    
    case "$severity" in
        "ERROR")
            echo "❌ ERROR: $message"
            ISSUES=$((ISSUES + 1))
            ;;
        "WARNING")
            echo "⚠️  WARNING: $message"  
            WARNINGS=$((WARNINGS + 1))
            ;;
        "INFO")
            echo "ℹ️  INFO: $message"
            ;;
        "SUCCESS")
            echo "✅ SUCCESS: $message"
            ;;
    esac
}

echo "📡 INTERFACE STATUS CHECK"
echo "========================="

# Check all network interfaces
interfaces_down=0
interfaces_up=0

ip addr show | grep -E '^[0-9]+:' | while read -r line; do
    interface=$(echo "$line" | awk '{print $2}' | tr -d ':')
    state=$(echo "$line" | grep -o 'state [A-Z]*' | awk '{print $2}')
    
    if [ "$interface" = "lo" ]; then
        continue  # Skip loopback
    fi
    
    case "$state" in
        "UP")
            interfaces_up=$((interfaces_up + 1))
            echo "✅ $interface is UP"
            ;;
        "DOWN")
            interfaces_down=$((interfaces_down + 1))
            echo "⚠️  $interface is DOWN"
            ;;
        *)
            echo "❓ $interface state unknown: $state"
            ;;
    esac
done

echo
echo "🛣️  CONNECTIVITY TESTS"
echo "====================="

# Test local connectivity (gateway)
default_gateway=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -n "$default_gateway" ]; then
    echo "Testing gateway connectivity ($default_gateway)..."
    if timeout 5 ping -c 3 "$default_gateway" >/dev/null 2>&1; then
        log_issue "SUCCESS" "Gateway $default_gateway is reachable"
    else
        log_issue "ERROR" "Cannot reach gateway $default_gateway"
    fi
else
    log_issue "ERROR" "No default gateway configured"
fi

# Test DNS resolution
echo
echo "🔍 DNS RESOLUTION TESTS"
echo "======================="

# Test multiple DNS servers and domains
dns_servers=("8.8.8.8" "1.1.1.1" "9.9.9.9")
test_domains=("google.com" "cloudflare.com" "github.com")

for dns in "${dns_servers[@]}"; do
    echo "Testing DNS server $dns..."
    if timeout 5 nslookup google.com "$dns" >/dev/null 2>&1; then
        log_issue "SUCCESS" "DNS server $dns is working"
    else
        log_issue "WARNING" "DNS server $dns is not responding"
    fi
done

# Test domain resolution
for domain in "${test_domains[@]}"; do
    echo "Testing domain resolution: $domain..."
    if timeout 5 nslookup "$domain" >/dev/null 2>&1; then
        log_issue "SUCCESS" "Domain $domain resolves correctly"
    else
        log_issue "WARNING" "Failed to resolve domain $domain"
    fi
done

echo
echo "🌐 INTERNET CONNECTIVITY"
echo "========================"

# Test HTTP/HTTPS connectivity
echo "Testing HTTP connectivity..."
if timeout 10 curl -s http://httpbin.org/get >/dev/null 2>&1; then
    log_issue "SUCCESS" "HTTP connectivity working"
else
    log_issue "ERROR" "HTTP connectivity failed"
fi

echo "Testing HTTPS connectivity..."  
if timeout 10 curl -s https://httpbin.org/get >/dev/null 2>&1; then
    log_issue "SUCCESS" "HTTPS connectivity working"
else
    log_issue "ERROR" "HTTPS connectivity failed"
fi

# Test external IP detection
external_ip=$(timeout 10 curl -s ifconfig.me 2>/dev/null || echo "")
if [ -n "$external_ip" ]; then
    log_issue "SUCCESS" "External IP detected: $external_ip"
else
    log_issue "WARNING" "Cannot determine external IP"
fi

echo
echo "🔥 FIREWALL STATUS"
echo "=================="

# Check firewall status
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        log_issue "SUCCESS" "UFW firewall is active"
        
        # Check for overly permissive rules
        anywhere_rules=$(ufw status | grep -c "Anywhere" || echo 0)
        if [ "$anywhere_rules" -gt 10 ]; then
            log_issue "WARNING" "Many permissive firewall rules ($anywhere_rules 'Anywhere' rules)"
        fi
    else
        log_issue "WARNING" "UFW firewall is not active"
    fi
else
    log_issue "INFO" "UFW not installed - checking iptables"
    
    if command -v iptables >/dev/null 2>&1; then
        rule_count=$(iptables -L | wc -l)
        if [ "$rule_count" -gt 8 ]; then
            log_issue "INFO" "iptables rules present ($rule_count lines)"
        else
            log_issue "WARNING" "No firewall protection detected"
        fi
    fi
fi

echo
echo "📊 PERFORMANCE ANALYSIS"
echo "======================="

# Check network interface errors
echo "Checking interface error rates..."
cat /proc/net/dev | awk 'NR>2 {
    interface = $1
    gsub(/:/, "", interface)
    rx_errors = $4
    tx_errors = $12
    rx_packets = $3
    tx_packets = $11
    
    if (rx_packets > 0) {
        rx_error_rate = (rx_errors / rx_packets) * 100
        if (rx_error_rate > 1) {
            printf "WARNING: %s has high RX error rate: %.2f%% (%d errors)\n", interface, rx_error_rate, rx_errors
        }
    }
    
    if (tx_packets > 0) {
        tx_error_rate = (tx_errors / tx_packets) * 100  
        if (tx_error_rate > 1) {
            printf "WARNING: %s has high TX error rate: %.2f%% (%d errors)\n", interface, tx_error_rate, tx_errors
        }
    }
}'

# Check for high network utilization
echo
echo "🚦 CONNECTION ANALYSIS"
echo "====================="

# Count connection states
tcp_connections=$(ss -tan | wc -l)
established=$(ss -tan | grep ESTAB | wc -l)
time_wait=$(ss -tan | grep TIME-WAIT | wc -l)
listen_ports=$(ss -tln | grep LISTEN | wc -l)

log_issue "INFO" "TCP connections: $tcp_connections total, $established established"
log_issue "INFO" "Listening ports: $listen_ports"

if [ "$time_wait" -gt 1000 ]; then
    log_issue "WARNING" "High TIME-WAIT connections: $time_wait (possible DoS or high load)"
fi

if [ "$established" -gt 500 ]; then
    log_issue "WARNING" "High number of established connections: $established"
fi

# Check for unusual ports
unusual_ports=$(ss -tln | grep LISTEN | awk '{print $4}' | cut -d':' -f2 | grep -v -E '^(22|25|53|80|443|993|995|587|143|110|25|465|8080|3000|5432|3306|6379|9000)$' | wc -l)
if [ "$unusual_ports" -gt 5 ]; then
    log_issue "WARNING" "Many unusual listening ports: $unusual_ports (review recommended)"
fi

echo
echo "🔒 SECURITY ASSESSMENT"
echo "====================="

# Check for common security issues
if [ -f /var/log/auth.log ]; then
    # Check for failed SSH attempts
    today=$(date '+%b %d')
    failed_ssh=$(grep "Failed password" /var/log/auth.log | grep "$today" | wc -l)
    
    if [ "$failed_ssh" -eq 0 ]; then
        log_issue "SUCCESS" "No failed SSH attempts today"
    elif [ "$failed_ssh" -lt 10 ]; then
        log_issue "INFO" "Few failed SSH attempts today: $failed_ssh"
    elif [ "$failed_ssh" -lt 50 ]; then
        log_issue "WARNING" "Moderate SSH attack activity: $failed_ssh failed attempts"
    else
        log_issue "ERROR" "High SSH attack activity: $failed_ssh failed attempts"
    fi
fi

# Check SSH configuration
if [ -f /etc/ssh/sshd_config ]; then
    root_login=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "yes")
    if [ "$root_login" = "no" ]; then
        log_issue "SUCCESS" "SSH root login disabled"
    else
        log_issue "WARNING" "SSH root login enabled"
    fi
    
    pass_auth=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}' || echo "yes")
    if [ "$pass_auth" = "no" ]; then
        log_issue "SUCCESS" "SSH password authentication disabled"
    else
        log_issue "WARNING" "SSH password authentication enabled"
    fi
fi

echo
echo "📈 BANDWIDTH & LATENCY TESTS"
echo "============================"

# Test latency to common services
latency_servers=("8.8.8.8" "1.1.1.1" "google.com")
total_latency=0
successful_tests=0

for server in "${latency_servers[@]}"; do
    echo "Testing latency to $server..."
    latency=$(timeout 10 ping -c 3 "$server" 2>/dev/null | grep "avg" | cut -d'/' -f5)
    
    if [ -n "$latency" ]; then
        latency_int=$(printf "%.0f" "$latency")
        total_latency=$((total_latency + latency_int))
        successful_tests=$((successful_tests + 1))
        
        if [ "$latency_int" -lt 50 ]; then
            log_issue "SUCCESS" "Good latency to $server: ${latency}ms"
        elif [ "$latency_int" -lt 100 ]; then
            log_issue "INFO" "Acceptable latency to $server: ${latency}ms" 
        else
            log_issue "WARNING" "High latency to $server: ${latency}ms"
        fi
    else
        log_issue "ERROR" "Cannot test latency to $server"
    fi
done

if [ "$successful_tests" -gt 0 ]; then
    avg_latency=$((total_latency / successful_tests))
    log_issue "INFO" "Average latency: ${avg_latency}ms"
fi

echo
echo "🎯 NETWORK DIAGNOSTICS SUMMARY"
echo "=============================="
echo "Diagnostic completed: $(date)"
echo

# Calculate health score
total_checks=$((ISSUES + WARNINGS + 20))  # Approximate number of checks
health_score=$(( (total_checks - ISSUES * 2 - WARNINGS) * 100 / total_checks ))

# Ensure score doesn't go negative
if [ "$health_score" -lt 0 ]; then
    health_score=0
fi

echo "🏥 NETWORK HEALTH SCORE: $health_score/100"

if [ "$health_score" -ge 90 ]; then
    echo "✅ EXCELLENT - Network is healthy and well-configured"
elif [ "$health_score" -ge 75 ]; then
    echo "✅ GOOD - Minor issues that should be addressed"
elif [ "$health_score" -ge 60 ]; then
    echo "⚠️  FAIR - Several issues need attention"
elif [ "$health_score" -ge 40 ]; then
    echo "⚠️  POOR - Significant network problems detected"
else
    echo "❌ CRITICAL - Major network issues require immediate attention"
fi

echo
echo "📊 Issue Summary:"
echo "  Critical Issues: $ISSUES"
echo "  Warnings: $WARNINGS"

if [ "$ISSUES" -gt 0 ] || [ "$WARNINGS" -gt 0 ]; then
    echo
    echo "🔧 RECOMMENDED ACTIONS:"
    
    if [ "$ISSUES" -gt 0 ]; then
        echo "  1. Address critical connectivity issues first"
        echo "  2. Check gateway and DNS configuration"
        echo "  3. Verify firewall settings"
        echo "  4. Review network interface status"
    fi
    
    if [ "$WARNINGS" -gt 0 ]; then
        echo "  • Review security warnings"
        echo "  • Optimize performance issues"  
        echo "  • Consider firewall hardening"
    fi
    
    echo
    echo "🛠️  Additional Diagnostics:"
    echo "  • Run 'net_status' for detailed interface info"
    echo "  • Use 'net_ping <target>' for specific connectivity tests"
    echo "  • Check 'net_firewall' for security configuration"
    echo "  • Monitor with 'net_connections' for active sessions"
fi

# Return exit code based on issues
if [ "$ISSUES" -gt 0 ]; then
    exit 1
elif [ "$WARNINGS" -gt 2 ]; then
    exit 2
else
    exit 0
fi
```

## Installation

Copy this skill to your OpenClaw skills directory:
```bash
cp -r network-manager ~/.openclaw/skills/
```

Or install via ClawHub (when published):
```bash
openclaw skill install network-manager
```

## Dependencies

- Standard Linux networking utilities (ip, ss, ping, etc.)
- Optional: curl for external connectivity tests
- Optional: traceroute for path analysis  
- Optional: dig/nslookup for DNS testing
- Optional: speedtest-cli for bandwidth testing
- Optional: iftop/nethogs for real-time monitoring

Install optional dependencies on Ubuntu:
```bash
sudo apt-get update
sudo apt-get install traceroute curl dnsutils speedtest-cli iftop nethogs
```

## Security Notes

- Network diagnostic commands are read-only by default
- Firewall analysis requires appropriate permissions
- External connectivity tests respect timeouts
- Geographic lookups use public APIs (rate-limited)

## Integration Examples

### Heartbeat Network Monitoring
Add to `HEARTBEAT.md`:
```bash
# Check network health every ~6 hours
if ! net_diagnostics >/dev/null 2>&1; then
    echo "🌐 Network issues detected"
    net_diagnostics | tail -30
fi
```

### Automated Connectivity Testing
```bash
# Test critical services connectivity
critical_services=("8.8.8.8" "github.com" "docker.io")
for service in "${critical_services[@]}"; do
    if ! net_ping "$service" 1 >/dev/null 2>&1; then
        echo "⚠️  Connectivity issue with $service"
        net_ping "$service" 3
    fi
done
```

### Network Performance Monitoring
```bash
# Monitor for high latency or packet loss
avg_latency=$(net_ping 8.8.8.8 10 | grep "avg" | cut -d'/' -f5)
packet_loss=$(net_ping 8.8.8.8 10 | grep "packet loss" | awk '{print $6}' | tr -d '%')

if (( $(echo "$avg_latency > 200" | bc -l 2>/dev/null || echo 0) )); then
    echo "⚠️  High latency detected: ${avg_latency}ms"
fi

if (( $(echo "$packet_loss > 5" | bc -l 2>/dev/null || echo 0) )); then
    echo "⚠️  Packet loss detected: ${packet_loss}%"
fi
```