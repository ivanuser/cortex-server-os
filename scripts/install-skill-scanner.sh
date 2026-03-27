#!/bin/bash
# Install cisco-ai-skill-scanner on CortexOS agents
set -e

LOG=/var/lib/cortexos/dashboard/skill-scan.log
mkdir -p /var/lib/cortexos/dashboard

echo "=== CortexOS Skill Scanner Install ===" | tee $LOG
date | tee -a $LOG

# Install python3-pip if missing
if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null 2>&1; then
    echo "Installing python3-pip..." | tee -a $LOG
    apt-get install -y python3-pip 2>&1 | grep -E "install|already|error" | tee -a $LOG
fi

# Install skill-scanner
echo "Installing cisco-ai-skill-scanner..." | tee -a $LOG
pip3 install cisco-ai-skill-scanner -q 2>&1 | tail -5 | tee -a $LOG || \
python3 -m pip install cisco-ai-skill-scanner -q --break-system-packages 2>&1 | tail -5 | tee -a $LOG

# Find skill-scanner binary
SCANNER=""
for path in $(which skill-scanner 2>/dev/null) /usr/local/bin/skill-scanner ~/.local/bin/skill-scanner; do
    [ -f "$path" ] && SCANNER="$path" && break
done

if [ -z "$SCANNER" ]; then
    # Try via python -m
    python3 -c "import skill_scanner" 2>/dev/null && SCANNER="python3 -m skill_scanner"
fi

if [ -z "$SCANNER" ]; then
    echo "ERROR: skill-scanner not found after install" | tee -a $LOG
    echo '{"error":"skill-scanner installation failed","results":[]}' > /var/lib/cortexos/dashboard/skill-scan.json
    echo "SCAN_COMPLETE" | tee -a $LOG
    exit 1
fi

echo "Found scanner: $SCANNER" | tee -a $LOG
echo "Running scan on /var/lib/cortexos/skills ..." | tee -a $LOG

FLAGS="${SCAN_FLAGS:-}"
$SCANNER scan-all /var/lib/cortexos/skills --recursive --lenient $FLAGS \
    --format json --output /var/lib/cortexos/dashboard/skill-scan.json 2>&1 | tee -a $LOG

echo "SCAN_COMPLETE" | tee -a $LOG
