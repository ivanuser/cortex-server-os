# user-manager — User & Group Management

Manage system users, groups, SSH keys, sudo access, and authentication.

## Quick Reference

### User Operations
```bash
# List all users (human accounts, UID >= 1000)
awk -F: '$3 >= 1000 && $3 < 65534 {print $1, "UID="$3, "HOME="$6, "SHELL="$7}' /etc/passwd

# List all users including system
cat /etc/passwd | column -t -s:

# Current logged-in users
who
w

# Last logins
last -10

# Failed login attempts
sudo lastb -10 2>/dev/null

# User details
id <username>
finger <username> 2>/dev/null || getent passwd <username>
```

### Create & Modify Users
```bash
# Create user with home directory
sudo useradd -m -s /bin/bash <username>
sudo passwd <username>

# Create user (one command)
sudo adduser <username>

# Delete user (keep home)
sudo userdel <username>

# Delete user + home directory
sudo userdel -r <username>

# Modify user
sudo usermod -aG <group> <username>   # Add to group
sudo usermod -s /bin/bash <username>   # Change shell
sudo usermod -d /new/home <username>   # Change home
sudo usermod -l <newname> <oldname>    # Rename
sudo usermod -L <username>             # Lock account
sudo usermod -U <username>             # Unlock account

# Set password expiry
sudo chage -M 90 <username>            # Max 90 days
sudo chage -l <username>               # Show policy
```

### Group Management
```bash
# List groups
cat /etc/group | column -t -s:

# User's groups
groups <username>

# Create group
sudo groupadd <groupname>

# Delete group
sudo groupdel <groupname>

# Add user to group
sudo usermod -aG <group> <username>

# Remove user from group
sudo gpasswd -d <username> <group>

# List group members
getent group <groupname>
```

### Sudo Configuration
```bash
# Check who has sudo
grep -E '^[^#].*ALL=' /etc/sudoers
cat /etc/sudoers.d/* 2>/dev/null

# Add sudo access (preferred method — use sudoers.d)
echo "<username> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/<username>
sudo chmod 440 /etc/sudoers.d/<username>

# Add sudo with password required
echo "<username> ALL=(ALL) ALL" | sudo tee /etc/sudoers.d/<username>
sudo chmod 440 /etc/sudoers.d/<username>

# Validate sudoers (ALWAYS do this)
sudo visudo -cf /etc/sudoers.d/<username>

# Edit sudoers safely
sudo visudo
```

### SSH Key Management
```bash
# Generate SSH key for user
sudo -u <username> ssh-keygen -t ed25519 -C "<username>@$(hostname)"

# Add authorized key
sudo -u <username> mkdir -p ~<username>/.ssh
echo "<public-key>" | sudo -u <username> tee -a ~<username>/.ssh/authorized_keys
sudo chmod 700 ~<username>/.ssh
sudo chmod 600 ~<username>/.ssh/authorized_keys

# List authorized keys
cat ~<username>/.ssh/authorized_keys

# Remove specific key
# Edit ~/.ssh/authorized_keys and remove the line
```

### Password Policy
```bash
# Check PAM password policy
cat /etc/pam.d/common-password

# Install password quality checker
sudo apt install -y libpam-pwquality

# Set password policy
sudo tee /etc/security/pwquality.conf << 'EOF'
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
enforce_for_root
EOF

# Check password aging for user
sudo chage -l <username>

# Force password change on next login
sudo chage -d 0 <username>
```

### Audit
```bash
# Recent sudo usage
sudo grep sudo /var/log/auth.log | tail -20

# Failed SSH attempts by user
sudo grep "Failed password" /var/log/auth.log | awk '{print $9}' | sort | uniq -c | sort -rn

# Users with no password set
sudo awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow

# Users with UID 0 (should only be root)
awk -F: '$3 == 0 {print $1}' /etc/passwd

# Active sessions
loginctl list-sessions
```

## Safety Rules

- **Always validate sudoers** with `visudo -cf` before applying
- **Never edit /etc/sudoers directly** — use /etc/sudoers.d/ files
- **Don't delete users without checking** what they own: `find / -user <username> 2>/dev/null`
- **Lock accounts** (`usermod -L`) instead of deleting when in doubt
- **SSH keys > passwords** for remote access
- **Audit UID 0 accounts** — only root should have UID 0
