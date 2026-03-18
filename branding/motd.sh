#!/bin/bash

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Display ASCII banner in cyan
echo -e "${CYAN}"
cat << 'EOF'
   ██████╗ ██████╗ ██████╗ ████████╗███████╗██╗  ██╗
  ██╔════╝██╔═══██╗██╔══██╗╚══██╔══╝██╔════╝╚██╗██╔╝
  ██║     ██║   ██║██████╔╝   ██║   █████╗   ╚███╔╝ 
  ██║     ██║   ██║██╔══██╗   ██║   ██╔══╝   ██╔██╗ 
  ╚██████╗╚██████╔╝██║  ██║   ██║   ███████╗██╔╝ ██╗
   ╚═════╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
              ╔═══════════════════╗
              ║   O P E N C L A W ║
              ╚═══════════════════╝
                 AI-Native Server OS
EOF
echo -e "${NC}"

# System information
echo -e "${BOLD}System Information:${NC}"
echo -e "Hostname: ${YELLOW}$(hostname)${NC}"
echo -e "IP Address: ${YELLOW}$(hostname -I | awk '{print $1}')${NC}"
echo -e "Uptime: ${YELLOW}$(uptime -p)${NC}"
echo -e "Load Average: ${YELLOW}$(uptime | awk -F'load average:' '{print $2}')${NC}"

# Memory usage
MEM_TOTAL=$(free -m | awk 'NR==2{printf "%.0f", $2}')
MEM_USED=$(free -m | awk 'NR==2{printf "%.0f", $3}')
MEM_PERCENT=$(free -m | awk 'NR==2{printf "%.0f", $3*100/$2}')
echo -e "Memory Usage: ${YELLOW}${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PERCENT}%)${NC}"

# Disk usage (root filesystem)
DISK_INFO=$(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
echo -e "Disk Usage: ${YELLOW}${DISK_INFO}${NC}"

echo ""

# OpenClaw status
if pgrep -f "openclaw" > /dev/null 2>&1; then
    echo -e "OpenClaw Status: ${GREEN}Online${NC}"
    
    # Try to get the dashboard URL from config
    OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
    if [[ -f "$OPENCLAW_CONFIG" ]]; then
        DASHBOARD_URL=$(grep -o '"publicUrl":"[^"]*' "$OPENCLAW_CONFIG" 2>/dev/null | cut -d'"' -f4)
        if [[ -n "$DASHBOARD_URL" ]]; then
            echo -e "Dashboard: ${YELLOW}${DASHBOARD_URL}${NC}"
        fi
    fi
else
    echo -e "OpenClaw Status: ${RED}Offline${NC}"
fi

echo ""
echo -e "${BOLD}💬 Chat with your AI:${NC} ${CYAN}openclaw chat${NC}"
echo ""