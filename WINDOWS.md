# CortexOS Server — Windows Installer Plan

## Overview

Windows installer for CortexOS Server, targeting Windows Server 2019+ and Windows 10/11 Pro with WSL2.

## Two Approaches

### Option A: WSL2-Based (Recommended)
Install CortexOS inside WSL2 Ubuntu, with a Windows wrapper for management.

**Pros:** Reuses the existing Linux installer, full Linux compatibility
**Cons:** Requires WSL2 enabled, slight overhead

```
┌─────────────────────────────────────┐
│         Windows Host                 │
│  ┌──────────────────────────────┐   │
│  │    WSL2 (Ubuntu 24.04)       │   │
│  │  ┌────────────────────────┐  │   │
│  │  │   CortexOS Server      │  │   │
│  │  │   (same Linux install) │  │   │
│  │  └────────────────────────┘  │   │
│  └──────────────────────────────┘   │
│  Windows Service Wrapper             │
│  (starts/stops WSL + gateway)        │
└─────────────────────────────────────┘
```

#### Install Flow
1. Check WSL2 is installed (install if not)
2. Create Ubuntu WSL instance for CortexOS
3. Run Linux installer inside WSL
4. Create Windows scheduled task to auto-start
5. Create Windows shortcuts (dashboard, logs, shell)
6. Configure Windows Firewall rules

#### install.ps1
```powershell
# CortexOS Server Installer for Windows
# Requires: PowerShell 5.1+, Administrator privileges

param(
    [switch]$Unattended,
    [string]$WslDistro = "CortexOS",
    [int]$Port = 18789
)

# Check admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run as Administrator"
    exit 1
}

# Check/install WSL2
$wslInstalled = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
if ($wslInstalled.State -ne "Enabled") {
    Write-Host "Installing WSL2..."
    wsl --install --no-distribution
    Write-Host "Reboot required. Run this installer again after reboot."
    exit 0
}

# Create Ubuntu instance
Write-Host "Creating CortexOS WSL instance..."
wsl --import $WslDistro "$env:ProgramData\CortexOS" "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64-wsl.rootfs.tar.gz"

# Run Linux installer inside WSL
Write-Host "Running CortexOS installer..."
wsl -d $WslDistro -- bash -c "curl -sO https://raw.githubusercontent.com/ivanuser/cortex-server-os/main/install.sh && sudo bash install.sh --unattended"

# Create Windows scheduled task for auto-start
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d $WslDistro -- sudo systemctl start cortex-server"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "CortexOS Server" -Action $action -Trigger $trigger -RunLevel Highest

# Windows Firewall
New-NetFirewallRule -DisplayName "CortexOS Server" -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow

Write-Host ""
Write-Host "CortexOS Server installed!"
Write-Host "Dashboard: http://localhost:$Port"
Write-Host ""
```

### Option B: Native Windows (Future)
Run OpenClaw natively on Windows with Node.js.

**Pros:** No WSL dependency, lighter
**Cons:** Need Windows-specific skills, some Linux tools unavailable

Not planned for v0.1.0.

## Status

- [ ] WSL2 installer (install.ps1)
- [ ] Windows service wrapper
- [ ] Auto-start on boot
- [ ] Firewall configuration
- [ ] Desktop shortcuts
- [ ] Uninstaller
- [ ] Testing on Windows Server 2022
- [ ] Testing on Windows 11 Pro

## Corporate Network Considerations

For RAND/corporate environments:
- RAND PKI certificate chain must be configured in WSL
- See sop.honercloud.com for SSL certificate SOP
- `NODE_EXTRA_CA_CERTS` and `REQUESTS_CA_BUNDLE` env vars
- npm config: `npm config set cafile /etc/ssl/certs/ca-certificates.crt`
