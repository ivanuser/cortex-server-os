# package-manager — Package & Update Management

Manage system packages, security updates, and software installation on Ubuntu/Debian.

## Quick Reference

### Check Updates
```bash
# Update package lists
sudo apt update

# List available upgrades
apt list --upgradable 2>/dev/null

# Count pending updates
apt list --upgradable 2>/dev/null | grep -c upgradable

# Security updates only
apt list --upgradable 2>/dev/null | grep -i security

# Check if reboot required
[ -f /var/run/reboot-required ] && echo "REBOOT REQUIRED" || echo "No reboot needed"
cat /var/run/reboot-required.pkgs 2>/dev/null
```

### Install & Remove
```bash
# Install package
sudo apt install -y <package>

# Install specific version
sudo apt install <package>=<version>

# Remove package (keep config)
sudo apt remove <package>

# Remove package + config
sudo apt purge <package>

# Remove unused dependencies
sudo apt autoremove -y

# Search for packages
apt search <keyword>

# Show package info
apt show <package>

# Check if package is installed
dpkg -l | grep <package>
```

### System Upgrade
```bash
# Safe upgrade (won't remove packages)
sudo apt upgrade -y

# Full upgrade (may remove packages if needed)
sudo apt full-upgrade -y

# Distribution upgrade
sudo do-release-upgrade

# Unattended security upgrades
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Package History
```bash
# Recent installs/upgrades
grep -E "install|upgrade" /var/log/dpkg.log | tail -20

# All manually installed packages
apt-mark showmanual

# Package install date
stat /var/lib/dpkg/info/<package>.list 2>/dev/null

# Hold a package (prevent upgrades)
sudo apt-mark hold <package>

# Unhold a package
sudo apt-mark unhold <package>

# Show held packages
apt-mark showhold
```

### Cleanup
```bash
# Clean package cache
sudo apt clean

# Remove old package files
sudo apt autoclean

# Remove unused dependencies
sudo apt autoremove -y

# Cache size
du -sh /var/cache/apt/archives/

# Remove old kernels (keep current + 1 previous)
sudo apt autoremove --purge -y
```

### Snap & Flatpak
```bash
# Snap packages
snap list
sudo snap refresh          # Update all snaps
sudo snap install <pkg>
sudo snap remove <pkg>

# Flatpak (if installed)
flatpak list
flatpak update
flatpak install <pkg>
flatpak uninstall <pkg>
```

### Repository Management
```bash
# List repos
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/

# Add PPA
sudo add-apt-repository ppa:<user>/<ppa>

# Remove PPA
sudo add-apt-repository --remove ppa:<user>/<ppa>

# Add GPG key + repo
curl -fsSL <key-url> | sudo gpg --dearmor -o /etc/apt/keyrings/<name>.gpg
echo "deb [signed-by=/etc/apt/keyrings/<name>.gpg] <repo-url> <dist> <component>" | sudo tee /etc/apt/sources.list.d/<name>.list
```

### Unattended Upgrades Config
```bash
# Check status
systemctl status unattended-upgrades

# Config files
cat /etc/apt/apt.conf.d/50unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades

# Enable automatic security updates
sudo tee /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# Test run (dry-run)
sudo unattended-upgrade --dry-run --debug
```

## Safety Rules

- **Always `apt update` before `apt install`** — stale package lists cause dependency errors
- **Check what will be removed** before running `apt autoremove`
- **Hold critical packages** if you need specific versions
- **Test upgrades on staging** before production servers
- **Check reboot-required** after kernel/security updates
- **Never run `do-release-upgrade` without a backup plan**
