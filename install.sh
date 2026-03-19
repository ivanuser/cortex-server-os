#!/bin/bash
# CortexOS Server Installer v0.1.0
# Transform any Ubuntu Server 22.04+ into CortexOS Server
# 
# This script installs:
# - Node.js runtime via nvm
# - OpenClaw gateway with systemd service
# - Ollama for local AI inference (optional) 
# - Server management skills (Docker, security, monitoring, etc.)
# - Cortex Web UI dashboard on port 8443
# - AI-first infrastructure management
#
# Usage: curl -sSL https://install.cortexos.dev | bash
# Usage: curl -sSL https://install.cortexos.dev | bash -s -- --unattended
# Usage: wget https://install.cortexos.dev/install.sh && chmod +x install.sh && ./install.sh

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

CORTEX_VERSION="0.1.0"
OPENCLAW_VERSION="2026.3.18"
NODE_VERSION="22"
DASHBOARD_PORT=8443
INSTALL_LOG="/var/log/cortexos-install.log"
CONFIG_DIR="/etc/cortexos"
DATA_DIR="/var/lib/cortexos"
LOG_DIR="/var/log/cortex-server"
USER_CORTEX="cortex"
GROUP_CORTEX="cortex"

# Installation flags
UNATTENDED=false
FORCE_INSTALL=false
SKIP_OLLAMA=false
VERBOSE=false

# Requirements
MIN_RAM_GB=2
MIN_DISK_GB=10
MIN_UBUNTU_VERSION="22.04"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==============================================================================
# Utility Functions
# ==============================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "${INSTALL_LOG}" >/dev/null
}

info() {
    echo -e "${BLUE}ℹ${NC} $*" | tee -a "${INSTALL_LOG}"
}

success() {
    echo -e "${GREEN}✅${NC} $*" | tee -a "${INSTALL_LOG}"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $*" | tee -a "${INSTALL_LOG}"
}

error() {
    echo -e "${RED}❌${NC} $*" | tee -a "${INSTALL_LOG}"
}

fatal() {
    error "$*"
    log "FATAL: Installation failed: $*"
    cleanup_on_failure
    exit 1
}

progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    echo -e "${CYAN}[$current/$total]${NC} ($percent%) $message"
}

spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] %s\r" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "    \r"
}

# ==============================================================================
# Cleanup and Error Handling
# ==============================================================================

cleanup_on_failure() {
    warning "Cleaning up after failed installation..."
    
    # Stop services if they were started
    systemctl stop cortex-server || true
    systemctl disable cortex-server || true
    
    # Remove systemd service file
    rm -f /etc/systemd/system/cortex-server.service
    systemctl daemon-reload
    
    # Remove created directories (only if empty)
    rmdir "${CONFIG_DIR}" 2>/dev/null || true
    rmdir "${DATA_DIR}" 2>/dev/null || true
    rmdir "${LOG_DIR}" 2>/dev/null || true
    
    # Remove created user
    userdel -r "${USER_CORTEX}" 2>/dev/null || true
    
    # Close firewall port
    ufw delete allow "${DASHBOARD_PORT}" 2>/dev/null || true
    
    warning "Cleanup completed. Check ${INSTALL_LOG} for details."
}

# Trap errors and cleanup
trap 'fatal "Installation interrupted"' INT TERM
trap 'test $? -eq 0 || fatal "Installation failed at line $LINENO"' EXIT

# ==============================================================================
# Command Line Parsing
# ==============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unattended)
                UNATTENDED=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --skip-ollama)
                SKIP_OLLAMA=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                fatal "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done
}

show_help() {
    cat << EOF
CortexOS Server Installer v${CORTEX_VERSION}

USAGE:
    curl -sSL https://install.cortexos.dev | bash
    curl -sSL https://install.cortexos.dev | bash -s -- [OPTIONS]
    
    wget https://install.cortexos.dev/install.sh && ./install.sh [OPTIONS]

OPTIONS:
    --unattended     Run without interactive prompts
    --force          Force installation even if requirements not met
    --skip-ollama    Skip Ollama installation (cloud AI only)
    --verbose        Enable verbose output
    --help           Show this help message

REQUIREMENTS:
    - Ubuntu 22.04+ or Debian 12+
    - ${MIN_RAM_GB}GB+ RAM
    - ${MIN_DISK_GB}GB+ free disk space
    - Internet connectivity
    - sudo privileges

EXAMPLES:
    # Interactive installation
    curl -sSL https://install.cortexos.dev | bash
    
    # Unattended installation for automation
    curl -sSL https://install.cortexos.dev | bash -s -- --unattended
    
    # Install without local AI (cloud only)
    curl -sSL https://install.cortexos.dev | bash -s -- --skip-ollama

EOF
}

# ==============================================================================
# Header and Introduction
# ==============================================================================

show_header() {
    clear 2>/dev/null || true
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                    CortexOS Server Installer                 ║
║                                                              ║
║   Transform Ubuntu Server → AI Infrastructure Management     ║
║                          v0.1.0                             ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo
}

show_intro() {
    if [[ "$UNATTENDED" == "true" ]]; then
        info "Starting unattended installation..."
        return
    fi
    
    cat << 'EOF'
This installer will transform your Ubuntu Server into CortexOS Server:

🤖 AI-native infrastructure management
🛡️ Security hardening and monitoring
🐳 Intelligent Docker and Kubernetes support
📊 Real-time system monitoring
🌐 Web dashboard with AI chat interface
⚡ Natural language server administration

The installation process:
1. Check system requirements and compatibility
2. Install Node.js runtime for OpenClaw
3. Install OpenClaw gateway with AI agents
4. Install Ollama for local AI inference (optional)
5. Install server management skills and tools
6. Configure systemd services and security
7. Set up web dashboard with SSL
8. Configure first-run AI setup

EOF

    if [[ "$UNATTENDED" == "false" ]]; then
        echo -n "Continue with installation? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Installation cancelled by user."
            exit 0
        fi
        echo
    fi
}

# ==============================================================================
# System Requirements Check
# ==============================================================================

check_requirements() {
    progress 1 8 "Checking system requirements..."
    
    # Initialize log file
    mkdir -p "$(dirname "$INSTALL_LOG")"
    touch "$INSTALL_LOG"
    log "CortexOS Server installation started"
    log "Version: ${CORTEX_VERSION}, OpenClaw: ${OPENCLAW_VERSION}"
    
    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        if [[ -z "${SUDO_USER:-}" ]]; then
            fatal "Please run this script with sudo, not as root directly"
        fi
        REAL_USER="$SUDO_USER"
    else
        fatal "This script requires sudo privileges"
    fi
    
    log "Running as user: $REAL_USER with sudo privileges"
    
    # Check operating system
    check_os_compatibility
    
    # Check hardware resources
    check_hardware_resources
    
    # Check network connectivity
    check_network_connectivity
    
    # Check existing installations
    check_existing_installation
    
    success "System requirements check passed"
}

check_os_compatibility() {
    info "Checking operating system compatibility..."
    
    if [[ ! -f /etc/os-release ]]; then
        fatal "Cannot determine operating system. /etc/os-release not found."
    fi
    
    source /etc/os-release
    
    case "$ID" in
        ubuntu)
            if ! version_compare "$VERSION_ID" "$MIN_UBUNTU_VERSION"; then
                if [[ "$FORCE_INSTALL" == "true" ]]; then
                    warning "Ubuntu $VERSION_ID detected (minimum: $MIN_UBUNTU_VERSION) - forcing installation"
                else
                    fatal "Ubuntu $MIN_UBUNTU_VERSION or higher required. Found: $VERSION_ID. Use --force to override."
                fi
            fi
            ;;
        debian)
            if [[ "${VERSION_ID%%.*}" -lt 12 ]]; then
                if [[ "$FORCE_INSTALL" == "true" ]]; then
                    warning "Debian $VERSION_ID detected (minimum: 12) - forcing installation"
                else
                    fatal "Debian 12 or higher required. Found: $VERSION_ID. Use --force to override."
                fi
            fi
            ;;
        *)
            if [[ "$FORCE_INSTALL" == "true" ]]; then
                warning "Unsupported OS: $ID $VERSION_ID - forcing installation"
            else
                fatal "Unsupported operating system: $ID $VERSION_ID. Ubuntu 22.04+ or Debian 12+ required."
            fi
            ;;
    esac
    
    log "OS compatibility check passed: $ID $VERSION_ID"
}

version_compare() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

check_hardware_resources() {
    info "Checking hardware resources..."
    
    # Check RAM
    local ram_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $ram_gb -lt $MIN_RAM_GB ]]; then
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            warning "Low memory: ${ram_gb}GB (minimum: ${MIN_RAM_GB}GB) - forcing installation"
        else
            fatal "Insufficient memory: ${ram_gb}GB available, ${MIN_RAM_GB}GB required. Use --force to override."
        fi
    fi
    
    # Check disk space
    local disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $disk_gb -lt $MIN_DISK_GB ]]; then
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            warning "Low disk space: ${disk_gb}GB (minimum: ${MIN_DISK_GB}GB) - forcing installation"
        else
            fatal "Insufficient disk space: ${disk_gb}GB available, ${MIN_DISK_GB}GB required. Use --force to override."
        fi
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt 2 ]]; then
        warning "Only $cpu_cores CPU core available. 2+ cores recommended for optimal performance."
    fi
    
    log "Hardware check passed: ${ram_gb}GB RAM, ${disk_gb}GB disk, ${cpu_cores} CPU cores"
}

check_network_connectivity() {
    info "Checking network connectivity..."
    
    local test_urls=(
        "https://github.com"
        "https://raw.githubusercontent.com"
        "https://registry.npmjs.org"
    )
    
    for url in "${test_urls[@]}"; do
        if ! curl -s --connect-timeout 10 --max-time 30 "$url" >/dev/null; then
            fatal "Cannot reach $url. Internet connectivity required for installation."
        fi
    done
    
    log "Network connectivity check passed"
}

check_existing_installation() {
    info "Checking for existing installations..."
    
    if systemctl is-active --quiet cortex-server; then
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            warning "CortexOS Server service already running - will reinstall"
        else
            fatal "CortexOS Server appears to be already installed and running. Use --force to reinstall."
        fi
    fi
    
    if [[ -d "$CONFIG_DIR" ]] && [[ "$FORCE_INSTALL" == "false" ]]; then
        fatal "Configuration directory $CONFIG_DIR already exists. Use --force to reinstall."
    fi
    
    log "Existing installation check passed"
}

# ==============================================================================
# Node.js Installation
# ==============================================================================

install_node() {
    progress 2 8 "Installing Node.js runtime..."
    
    # Check if Node.js already installed and compatible
    if command -v node &>/dev/null; then
        local node_version=$(node --version | sed 's/v//')
        local required_major=$(echo "$NODE_VERSION" | cut -d. -f1)
        local current_major=$(echo "$node_version" | cut -d. -f1)
        
        if [[ $current_major -ge $required_major ]]; then
            success "Node.js v$node_version already installed"
            log "Node.js check passed: v$node_version"
            return
        else
            warning "Node.js v$node_version found, but v$NODE_VERSION+ required"
        fi
    fi
    
    info "Installing Node.js v${NODE_VERSION} via nvm..."
    
    # Install nvm for the real user
    local nvm_install_script="/tmp/nvm-install-$$.sh"
    
    if ! curl -o "$nvm_install_script" -s "https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh"; then
        fatal "Failed to download nvm installer"
    fi
    
    # Install nvm as the real user
    sudo -u "$REAL_USER" bash "$nvm_install_script" &>/dev/null || fatal "Failed to install nvm"
    rm -f "$nvm_install_script"
    
    # Set up nvm environment for the real user
    local user_home=$(getent passwd "$REAL_USER" | cut -d: -f6)
    local nvm_dir="$user_home/.nvm"
    
    if [[ ! -d "$nvm_dir" ]]; then
        fatal "nvm installation failed - directory $nvm_dir not found"
    fi
    
    # Install Node.js as the real user
    sudo -u "$REAL_USER" bash -c "
        source '$nvm_dir/nvm.sh'
        nvm install $NODE_VERSION >/dev/null 2>&1
        nvm use $NODE_VERSION >/dev/null 2>&1
        nvm alias default $NODE_VERSION >/dev/null 2>&1
    " || fatal "Failed to install Node.js via nvm"
    
    # Create system-wide node symlinks
    local node_path="$nvm_dir/versions/node/v$(ls $nvm_dir/versions/node/ | grep "^v$NODE_VERSION" | head -1)"
    if [[ ! -d "$node_path" ]]; then
        # Try to find the exact version installed
        node_path="$nvm_dir/versions/node/$(ls $nvm_dir/versions/node/ | head -1)"
    fi
    
    if [[ -d "$node_path" ]]; then
        ln -sf "$node_path/bin/node" /usr/local/bin/node
        ln -sf "$node_path/bin/npm" /usr/local/bin/npm
        ln -sf "$node_path/bin/npx" /usr/local/bin/npx
    else
        fatal "Could not find installed Node.js in $nvm_dir"
    fi
    
    # Verify installation
    if ! node --version >/dev/null 2>&1; then
        fatal "Node.js installation verification failed"
    fi
    
    local installed_version=$(node --version)
    success "Node.js $installed_version installed successfully"
    log "Node.js installation completed: $installed_version"
}

# ==============================================================================
# OpenClaw Installation
# ==============================================================================

install_openclaw() {
    progress 3 8 "Installing OpenClaw gateway..."
    
    info "Installing OpenClaw v${OPENCLAW_VERSION}..."
    
    # Create cortex user and group
    if ! getent group "$GROUP_CORTEX" >/dev/null; then
        groupadd --system "$GROUP_CORTEX"
        log "Created group: $GROUP_CORTEX"
    fi
    
    if ! getent passwd "$USER_CORTEX" >/dev/null; then
        useradd --system --gid "$GROUP_CORTEX" --home-dir "$DATA_DIR" \
                --shell /bin/bash --comment "CortexOS Server" "$USER_CORTEX"
        log "Created user: $USER_CORTEX"
    fi
    
    # Create directories
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
    chown "$USER_CORTEX:$GROUP_CORTEX" "$DATA_DIR" "$LOG_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 750 "$DATA_DIR" "$LOG_DIR"
    
    # Install OpenClaw globally
    # Source nvm for current user AND check common install locations
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    
    # Also check if the invoking user has nvm (sudo preserves SUDO_USER)
    if ! command -v npm &>/dev/null && [ -n "$SUDO_USER" ]; then
        local user_home=$(eval echo ~$SUDO_USER)
        export NVM_DIR="$user_home/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    fi
    
    # Verify npm is available
    if ! command -v npm &>/dev/null; then
        fatal "npm not found in PATH. Node.js may not be properly installed."
    fi
    
    info "Using npm at: $(which npm) ($(npm --version))"
    log "npm path: $(which npm), version: $(npm --version)"
    
    # Clean stale module directory if exists (prevents ENOTEMPTY on reinstall)
    local npm_prefix="$(npm prefix -g)"
    rm -rf "${npm_prefix}/lib/node_modules/.openclaw-cortex-"* 2>/dev/null || true
    rm -rf "${npm_prefix}/lib/node_modules/openclaw-cortex" 2>/dev/null || true
    
    # Always show npm output so we can debug failures
    info "Running: npm install -g openclaw-cortex@${OPENCLAW_VERSION}"
    npm install -g "openclaw-cortex@${OPENCLAW_VERSION}" 2>&1 | tee -a "$INSTALL_LOG" || fatal "Failed to install OpenClaw"
    
    # Verify OpenClaw installation — find the binary wherever npm put it
    local openclaw_bin=""
    for candidate in \
        "$(npm prefix -g)/bin/openclaw" \
        "$(npm prefix -g)/bin/cortex" \
        "/usr/local/bin/openclaw" \
        "/usr/local/bin/cortex" \
        "$NVM_DIR/versions/node/$(node --version)/bin/openclaw" \
        "$NVM_DIR/versions/node/$(node --version)/bin/cortex"; do
        if [ -x "$candidate" ] 2>/dev/null; then
            openclaw_bin="$candidate"
            break
        fi
    done
    
    if [ -z "$openclaw_bin" ]; then
        warn "Binary not found in PATH, searching..."
        openclaw_bin=$(find / -name "openclaw" -type f -executable 2>/dev/null | head -1)
        [ -z "$openclaw_bin" ] && openclaw_bin=$(find / -name "cortex" -type f -executable -not -path "*/cortex-server*" 2>/dev/null | head -1)
    fi
    
    if [ -z "$openclaw_bin" ]; then
        fatal "OpenClaw installation verification failed — binary not found"
    fi
    
    # Ensure it's in PATH by symlinking
    if ! command -v openclaw &>/dev/null && ! command -v cortex &>/dev/null; then
        ln -sf "$openclaw_bin" /usr/local/bin/openclaw 2>/dev/null || true
        info "Symlinked $openclaw_bin → /usr/local/bin/openclaw"
    fi
    
    local openclaw_version=$("$openclaw_bin" --version 2>/dev/null | head -1 || echo "unknown")
    success "OpenClaw installed successfully: $openclaw_version"
    log "OpenClaw installation completed: $openclaw_version"
}

# ==============================================================================
# Ollama Installation (Optional Local AI)
# ==============================================================================

install_ollama() {
    if [[ "$SKIP_OLLAMA" == "true" ]]; then
        progress 4 8 "Skipping Ollama installation (--skip-ollama)"
        info "Ollama installation skipped - cloud AI providers will be used"
        return
    fi
    
    progress 4 8 "Installing Ollama for local AI inference..."
    
    # Check if Ollama already installed
    if command -v ollama &>/dev/null; then
        success "Ollama already installed: $(ollama --version 2>/dev/null || echo 'unknown version')"
        log "Ollama already installed"
        return
    fi
    
    # Prompt user for Ollama installation in interactive mode
    if [[ "$UNATTENDED" == "false" ]]; then
        echo -n "Install Ollama for local AI inference? [Y/n]: "
        read -r response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            info "Skipping Ollama installation - cloud AI providers will be used"
            return
        fi
        echo
    fi
    
    info "Installing Ollama..."
    
    # Download and install Ollama
    local ollama_install_script="/tmp/ollama-install-$$.sh"
    
    if ! curl -o "$ollama_install_script" -sfL "https://ollama.com/install.sh"; then
        warning "Failed to download Ollama installer - continuing without local AI"
        log "Ollama download failed - continuing installation"
        return
    fi
    
    if bash "$ollama_install_script" 2>&1 | tee -a "$INSTALL_LOG"; then
        rm -f "$ollama_install_script"
        
        # Start Ollama service
        systemctl enable ollama 2>/dev/null || true
        systemctl start ollama 2>/dev/null || true
        
        # Wait for Ollama to start
        local wait_count=0
        while ! curl -s http://localhost:11434/api/version >/dev/null && [[ $wait_count -lt 30 ]]; do
            sleep 1
            ((wait_count++))
        done
        
        if curl -s http://localhost:11434/api/version >/dev/null; then
            success "Ollama installed and running"
            log "Ollama installation completed"
            
            # Download a default model if unattended
            if [[ "$UNATTENDED" == "true" ]]; then
                info "Downloading default AI model (llama3.1:8b)..."
                ollama pull llama3.1:8b &>/dev/null &
                local pull_pid=$!
                spinner $pull_pid "Downloading AI model"
                wait $pull_pid && success "Default AI model downloaded" || warning "Failed to download default model"
            fi
        else
            warning "Ollama installed but not responding - continuing without local AI"
        fi
    else
        warning "Ollama installation failed - continuing without local AI"
        log "Ollama installation failed - continuing"
        rm -f "$ollama_install_script"
    fi
}

# ==============================================================================
# Skills Installation
# ==============================================================================

install_skills() {
    progress 5 8 "Installing server management skills..."
    
    info "Installing CortexOS Server skills..."
    
    # Create skills directory
    local skills_dir="$DATA_DIR/skills"
    mkdir -p "$skills_dir"
    chown "$USER_CORTEX:$GROUP_CORTEX" "$skills_dir"
    
    # Skills to install
    local skills=(
        "systemd-manager"
        "docker-manager"
        "security-hardening"
        "network-manager"
        "storage-manager"
        "monitoring"
        "package-manager"
        "user-manager"
        "firewall-manager"
        "backup-manager"
    )
    
    # Install skills from repo if available, otherwise download from GitHub
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_skills_dir="$script_dir/skills"
    
    for skill in "${skills[@]}"; do
        local skill_dir="$skills_dir/$skill"
        mkdir -p "$skill_dir"
        
        if [ -f "$repo_skills_dir/$skill/SKILL.md" ]; then
            # Copy from local repo
            cp "$repo_skills_dir/$skill/SKILL.md" "$skill_dir/SKILL.md"
        else
            # Download from GitHub
            local url="https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/skills/$skill/SKILL.md"
            curl -sfL "$url" -o "$skill_dir/SKILL.md" 2>/dev/null || {
                # Fallback: create minimal placeholder
                echo "# $skill" > "$skill_dir/SKILL.md"
                echo "" >> "$skill_dir/SKILL.md"
                echo "Server management skill. See cortex-server-os repo for full documentation." >> "$skill_dir/SKILL.md"
            }
        fi
        
        chown -R "$USER_CORTEX:$GROUP_CORTEX" "$skill_dir"
        success "  ✅ ${skill}"
    done
    
    # Symlink skills into gateway's skill directory so the AI can find them
    mkdir -p /root/.openclaw
    ln -sfn "$skills_dir" /root/.openclaw/skills
    log "Skills symlinked to /root/.openclaw/skills"
    
    log "Server management skills installed: ${#skills[@]} skills"
}

# ==============================================================================
# Gateway Configuration
# ==============================================================================

configure_gateway() {
    progress 6 8 "Configuring OpenClaw gateway..."
    
    info "Configuring CortexOS Server gateway..."
    
    # Generate secure gateway token
    local gateway_token=$(openssl rand -hex 32)
    
    # Create main configuration file
    cat > "$CONFIG_DIR/config.yaml" << EOF
# CortexOS Server Configuration
# Generated on $(date)

version: "${CORTEX_VERSION}"
mode: "server"

# Gateway configuration
gateway:
  port: 18789
  host: "127.0.0.1"
  token: "${gateway_token}"
  ssl: false

# Dashboard configuration
dashboard:
  enabled: true
  port: ${DASHBOARD_PORT}
  ssl: true
  auth: true

# AI configuration
ai:
  provider: "auto"  # auto-detect ollama or use cloud
  models:
    chat: "llama3.1:8b"
    embedding: "nomic-embed-text"
  
# Server role configuration  
role:
  template: "general"
  capabilities:
    - "system_management"
    - "container_orchestration"
    - "security_monitoring"
    - "backup_management"
    - "performance_optimization"

# Security configuration
security:
  audit_logging: true
  behavioral_monitoring: true
  auto_hardening: true
  compliance_checking: true

# Logging configuration
logging:
  level: "info"
  file: "${LOG_DIR}/cortex-server.log"
  max_size: "100MB"
  max_files: 10
EOF
    
    # Set secure permissions
    chmod 640 "$CONFIG_DIR/config.yaml"
    chown root:"$GROUP_CORTEX" "$CONFIG_DIR/config.yaml"
    
    # Create OpenClaw gateway config (this is what the gateway actually reads)
    mkdir -p /root/.openclaw
    
    # Determine allowed origins for the Control UI
    local allowed_origins='"http://localhost:18789", "http://127.0.0.1:18789"'
    local external_url=""
    
    if [[ "$UNATTENDED" == "false" ]]; then
        echo ""
        echo -n "Will this server be accessible from outside the local network? (e.g. via Cloudflare tunnel, reverse proxy) [y/N]: "
        read -r external_access
        if [[ "$external_access" =~ ^[Yy] ]]; then
            echo -n "Enter the external URL (e.g. https://myserver.example.com): "
            read -r external_url
            if [[ -n "$external_url" ]]; then
                # Strip trailing slash
                external_url="${external_url%/}"
                allowed_origins="${allowed_origins}, \"${external_url}\""
                info "External access configured for: ${external_url}"
                log "External origin added: ${external_url}"
            fi
        fi
    fi
    
    # Ask for AI provider configuration
    local api_key=""
    local api_provider="anthropic"
    local auth_method=""
    
    if [[ "$UNATTENDED" == "false" ]]; then
        echo ""
        echo "CortexOS needs an AI provider to power the server management agent."
        echo ""
        echo "Supported providers:"
        echo "  1) Anthropic (Claude) — recommended"
        echo "  2) OpenAI (GPT)"
        echo "  3) Google (Gemini)"
        echo "  4) Skip — configure later"
        echo ""
        echo -n "Choose provider [1]: "
        read -r provider_choice
        case "$provider_choice" in
            2) api_provider="openai" ;;
            3) api_provider="google" ;;
            4) api_provider="skip" ;;
            *) api_provider="anthropic" ;;
        esac
        
        if [[ "$api_provider" == "anthropic" ]]; then
            echo ""
            echo "Anthropic auth options:"
            echo "  1) Setup token (Claude subscription — recommended)"
            echo "     Run 'claude setup-token' on any machine, paste the token here"
            echo "  2) API key (from console.anthropic.com)"
            echo "  3) Skip — configure after install"
            echo ""
            echo -n "Choose auth method [1]: "
            read -r auth_choice
            case "$auth_choice" in
                2) auth_method="apikey" ;;
                3) auth_method="skip" ;;
                *) auth_method="setup-token" ;;
            esac
            
            if [[ "$auth_method" == "setup-token" ]]; then
                echo ""
                echo "Paste your setup token (from 'claude setup-token'):"
                read -rs api_key
                echo ""
            elif [[ "$auth_method" == "apikey" ]]; then
                echo -n "Enter your Anthropic API key (sk-ant-...): "
                read -rs api_key
                echo ""
            fi
        elif [[ "$api_provider" != "skip" ]]; then
            echo -n "Enter your ${api_provider} API key: "
            read -rs api_key
            echo ""
        fi
        
        if [[ -n "$api_key" ]]; then
            info "Auth configured for ${api_provider}"
            log "AI provider configured: ${api_provider} (${auth_method:-apikey})"
        elif [[ "$api_provider" != "skip" && "$auth_method" != "skip" ]]; then
            info "No key provided — configure after install with: openclaw models auth setup-token --provider ${api_provider}"
        fi
    fi
    
    cat > /root/.openclaw/openclaw.json << OCEOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "auth": {
      "token": "${gateway_token}"
    },
    "controlUi": {
      "allowedOrigins": [${allowed_origins}],
      "allowInsecureAuth": true,
      "root": "/var/lib/cortexos/dashboard"
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-20250514"
      }
    }
  },
  "ui": {
    "assistant": {
      "name": "CortexOS Server"
    }
  }
}
OCEOF
    chmod 600 /root/.openclaw/openclaw.json
    # Tighten state directory permissions
    chmod 700 /root/.openclaw 2>/dev/null || true
    log "OpenClaw gateway config created at /root/.openclaw/openclaw.json"
    
    # Configure AI provider auth
    if [[ -n "$api_key" && "$api_provider" != "skip" ]]; then
        if [[ "$api_provider" == "anthropic" && "$auth_method" == "setup-token" ]]; then
            # Use openclaw CLI to paste the setup token (must run as root with correct HOME)
            info "Configuring Anthropic via setup token..."
            HOME=/root echo "$api_key" | HOME=/root /usr/local/bin/openclaw models auth paste-token --provider anthropic 2>&1 | tee -a "$INSTALL_LOG" || {
                warning "Setup token paste failed — configure manually after install:"
                info "  sudo -i openclaw models auth setup-token --provider anthropic"
            }
        elif [[ "$api_provider" == "anthropic" && "$auth_method" == "apikey" ]]; then
            # Direct API key
            mkdir -p /root/.openclaw/agents/main/agent
            cat > /root/.openclaw/agents/main/agent/auth-profiles.json << AUTHEOF
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "provider": "anthropic",
      "apiKey": "${api_key}"
    }
  }
}
AUTHEOF
            chmod 600 /root/.openclaw/agents/main/agent/auth-profiles.json
        else
            # OpenAI / Google — direct API key
            mkdir -p /root/.openclaw/agents/main/agent
            cat > /root/.openclaw/agents/main/agent/auth-profiles.json << AUTHEOF
{
  "version": 1,
  "profiles": {
    "${api_provider}:default": {
      "provider": "${api_provider}",
      "apiKey": "${api_key}"
    }
  }
}
AUTHEOF
            chmod 600 /root/.openclaw/agents/main/agent/auth-profiles.json
        fi
        log "Auth configured for provider: ${api_provider} (${auth_method:-apikey})"
    fi
    
    # Display connection info
    if [[ -n "$external_url" ]]; then
        info "Control UI accessible at: ${external_url}"
    fi
    
    # Create systemd service file
    cat > /etc/systemd/system/cortex-server.service << EOF
[Unit]
Description=CortexOS Server Infrastructure Agent
Documentation=https://docs.cortexos.dev
After=network.target
Wants=network.target
Requires=network.target

[Service]
Type=simple
WorkingDirectory=${DATA_DIR}
Environment=NODE_ENV=production
Environment=HOME=/root
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/local/bin/openclaw gateway run --bind lan
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
Restart=always
RestartSec=10s
TimeoutStopSec=30s

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable cortex-server
    
    log "Gateway configuration completed"
    log "Generated secure token: ${gateway_token:0:8}..."
}

# ==============================================================================
# Dashboard Setup
# ==============================================================================

setup_dashboard() {
    progress 7 8 "Setting up web dashboard..."
    
    info "Configuring web dashboard on port ${DASHBOARD_PORT}..."
    
    # Deploy dashboard files
    local dashboard_dir="/var/lib/cortexos/dashboard"
    mkdir -p "$dashboard_dir"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -f "$script_dir/dashboard/index.html" ]; then
        cp "$script_dir/dashboard/"* "$dashboard_dir/" 2>/dev/null || true
        log "Dashboard files deployed from repo"
    else
        # Download from GitHub
        curl -sfL "https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/dashboard/index.html" \
            -o "$dashboard_dir/index.html" 2>/dev/null || warning "Failed to download dashboard"
        curl -sfL "https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/dashboard/logo.png" \
            -o "$dashboard_dir/logo.png" 2>/dev/null || true
        log "Dashboard files downloaded from GitHub"
    fi
    
    # Verify dashboard deployed
    if [ -f "$dashboard_dir/index.html" ]; then
        success "Dashboard deployed to $dashboard_dir"
    else
        warning "Dashboard files not found — web UI will not be available"
    fi
    
    # Configure firewall for dashboard port
    if command -v ufw &>/dev/null; then
        ufw allow "$DASHBOARD_PORT/tcp" comment "CortexOS Server Dashboard" 2>/dev/null || true
        log "Firewall configured for port $DASHBOARD_PORT"
    fi
    
    # TODO: In production, install and configure Cortex Web UI
    # For now, create placeholder configuration
    
    # Create SSL directory
    local ssl_dir="$CONFIG_DIR/ssl"
    mkdir -p "$ssl_dir"
    chown root:"$GROUP_CORTEX" "$ssl_dir"
    chmod 750 "$ssl_dir"
    
    # Generate self-signed certificate for initial setup
    local cert_file="$ssl_dir/cortex-server.crt"
    local key_file="$ssl_dir/cortex-server.key"
    
    if [[ ! -f "$cert_file" ]]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$key_file" \
            -out "$cert_file" \
            -subj "/C=US/ST=Local/L=Local/O=CortexOS Server/OU=IT/CN=$(hostname)" \
            2>/dev/null || warning "Failed to generate SSL certificate"
        
        chmod 640 "$cert_file" "$key_file"
        chown root:"$GROUP_CORTEX" "$cert_file" "$key_file"
        log "Generated self-signed SSL certificate"
    fi
    
    success "Web dashboard configuration completed"
    log "Dashboard will be available at: https://$(hostname -I | awk '{print $1}'):${DASHBOARD_PORT}"
}

# ==============================================================================
# First Run Setup
# ==============================================================================

first_run_setup() {
    progress 8 8 "Configuring first-run AI setup..."
    
    info "Starting CortexOS Server service..."
    
    # Start the service
    if systemctl start cortex-server; then
        success "CortexOS Server service started"
        log "Service started successfully"
    else
        warning "Failed to start CortexOS Server service - check logs"
        log "Service start failed"
    fi
    
    # Wait for service to be ready
    local wait_count=0
    while ! systemctl is-active --quiet cortex-server && [[ $wait_count -lt 30 ]]; do
        sleep 1
        ((wait_count++))
    done
    
    if systemctl is-active --quiet cortex-server; then
        success "CortexOS Server is running"
        log "Service health check passed"
    else
        warning "Service may not be fully ready - check status with: systemctl status cortex-server"
    fi
    
    # Install MOTD (login banner)
    cat > /etc/motd << 'MOTDEOF'

   ██████╗ ██████╗ ██████╗ ████████╗███████╗██╗  ██╗ ██████╗ ███████╗
  ██╔════╝██╔═══██╗██╔══██╗╚══██╔══╝██╔════╝╚██╗██╔╝██╔═══██╗██╔════╝
  ██║     ██║   ██║██████╔╝   ██║   █████╗   ╚███╔╝ ██║   ██║███████╗
  ██║     ██║   ██║██╔══██╗   ██║   ██╔══╝   ██╔██╗ ██║   ██║╚════██║
  ╚██████╗╚██████╔╝██║  ██║   ██║   ███████╗██╔╝ ██╗╚██████╔╝███████║
   ╚═════╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
                        S E R V E R

  🤖 AI-Powered Infrastructure Management
  
  Quick commands:
    openclaw chat         Talk to your AI sysadmin
    systemctl status cortex-server   Service status
    journalctl -u cortex-server -f   Live logs

MOTDEOF
    # Disable default Ubuntu MOTD scripts that clutter the login
    chmod -x /etc/update-motd.d/* 2>/dev/null || true
    log "MOTD banner installed"
    
    # Install CortexOS workspace files (SOUL, BOOTSTRAP, IDENTITY, etc.)
    local workspace_dir="/root/.openclaw/workspace"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_workspace="$script_dir/workspace"
    
    if [ -d "$repo_workspace" ]; then
        for wfile in SOUL.md BOOTSTRAP.md IDENTITY.md USER.md TOOLS.md AGENTS.md HEARTBEAT.md; do
            if [ -f "$repo_workspace/$wfile" ]; then
                cp "$repo_workspace/$wfile" "$workspace_dir/$wfile" 2>/dev/null || true
            fi
        done
        log "CortexOS workspace files installed"
    fi
    
    # Create first-run flag
    touch "$DATA_DIR/.first-run"
    chown "$USER_CORTEX:$GROUP_CORTEX" "$DATA_DIR/.first-run"
    
    log "First-run setup completed"
}

# ==============================================================================
# Installation Summary
# ==============================================================================

show_installation_summary() {
    local server_ip=$(hostname -I | awk '{print $1}' | head -1)
    local gateway_token=$(python3 -c "import json; print(json.load(open('/root/.openclaw/openclaw.json'))['gateway']['auth']['token'])" 2>/dev/null || echo "see /root/.openclaw/openclaw.json")
    
    clear 2>/dev/null || true
    cat << EOF
╔══════════════════════════════════════════════════════════════╗
║                   🎉 Installation Complete!                  ║
╚══════════════════════════════════════════════════════════════╝

🤖 CortexOS Server v${CORTEX_VERSION} is now running!

📊 SYSTEM STATUS:
   Service Status: $(systemctl is-active cortex-server)
   Gateway:        ws://${server_ip}:18789
   Access Token:   ${gateway_token}
   Web Dashboard:  https://${server_ip}:${DASHBOARD_PORT}
   Configuration:  ${CONFIG_DIR}/config.yaml
   Data Directory: ${DATA_DIR}
   Log Files:      ${LOG_DIR}/

🚀 QUICK START:
   1. SSH to this server and start chatting with your AI
   2. Open the web dashboard for visual management
   3. Try: "systemctl status cortex-server" to check service
   4. Try: "openclaw chat" for direct AI conversation

💡 FIRST COMMANDS TO TRY:
   • "Show me system health"
   • "Set up Docker for container hosting"
   • "Configure automatic security updates"
   • "Set up backup for important data"

📚 DOCUMENTATION:
   Configuration: ${CONFIG_DIR}/config.yaml
   Installation log: ${INSTALL_LOG}
   Service logs: journalctl -u cortex-server
   
🔧 MANAGEMENT:
   Start:   sudo systemctl start cortex-server
   Stop:    sudo systemctl stop cortex-server  
   Status:  sudo systemctl status cortex-server
   Logs:    sudo journalctl -u cortex-server -f

EOF

    if [[ "$UNATTENDED" == "false" ]]; then
        echo "Press Enter to continue..."
        read -r
    fi
    
    success "Welcome to CortexOS Server! 🌟"
    log "Installation completed successfully"
}

# ==============================================================================
# Main Installation Flow
# ==============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show header and introduction
    show_header
    show_intro
    
    # Installation steps
    check_requirements
    install_node
    install_openclaw
    install_ollama
    install_skills
    configure_gateway
    setup_dashboard
    first_run_setup
    
    # Show completion summary
    show_installation_summary
    
    # Disable error trap for normal exit
    trap - EXIT
}

# ==============================================================================
# Script Execution
# ==============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi