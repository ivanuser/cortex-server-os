# storage-manager — Disk & Storage Management

Manage filesystems, partitions, LVM, NFS mounts, and disk health on Ubuntu/Debian.

## Quick Reference

### Disk Overview
```bash
# Filesystem usage
df -hT

# Block devices and partitions
lsblk -f

# Disk info (serial, model, size)
lsblk -o NAME,SIZE,MODEL,SERIAL,ROTA,TYPE

# Partition table
sudo fdisk -l

# Mount points
mount | grep -v "tmpfs\|cgroup\|proc\|sys"
```

### Space Analysis
```bash
# Largest directories from root
sudo du -sh /* 2>/dev/null | sort -rh | head -15

# Largest files on system
sudo find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -20

# Directory size breakdown
sudo du -sh /var/* 2>/dev/null | sort -rh | head -10

# Inode usage (can fill up with many small files)
df -i

# Deleted but open files (holding space)
sudo lsof +L1 2>/dev/null | head -20
```

### Cleanup
```bash
# Journal logs (can be huge)
journalctl --disk-usage
sudo journalctl --vacuum-time=7d
sudo journalctl --vacuum-size=500M

# Apt cache
sudo apt clean
sudo apt autoremove -y

# Old kernels
dpkg --list 'linux-image-*' | grep '^ii' | awk '{print $2}'
sudo apt autoremove --purge -y

# Temp files
sudo find /tmp -type f -atime +7 -delete 2>/dev/null
sudo find /var/tmp -type f -atime +30 -delete 2>/dev/null

# Docker (if installed)
docker system prune -af 2>/dev/null
docker volume prune -f 2>/dev/null

# Snap revisions
snap list --all | awk '/disabled/{print $1, $3}' | while read name rev; do sudo snap remove "$name" --revision="$rev"; done
```

### LVM Management
```bash
# Physical volumes
sudo pvs
sudo pvdisplay

# Volume groups
sudo vgs
sudo vgdisplay

# Logical volumes
sudo lvs
sudo lvdisplay

# Extend logical volume
sudo lvextend -L +10G /dev/<vg>/<lv>
sudo resize2fs /dev/<vg>/<lv>    # ext4
sudo xfs_growfs /dev/<vg>/<lv>   # xfs

# Create new LV
sudo lvcreate -L 20G -n <name> <vg>
sudo mkfs.ext4 /dev/<vg>/<name>
```

### NFS
```bash
# Show NFS mounts
mount | grep nfs

# Mount NFS share
sudo mount -t nfs <server>:<export> /mnt/<name>

# Persistent NFS mount (/etc/fstab)
echo "<server>:<export> /mnt/<name> nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# NFS exports (if this is a server)
cat /etc/exports
sudo exportfs -v

# NFS stats
nfsstat -c  # client
nfsstat -s  # server
```

### SMART Disk Health
```bash
# Install smartmontools
sudo apt install -y smartmontools

# Disk health summary
sudo smartctl -H /dev/sda

# Full SMART data
sudo smartctl -a /dev/sda

# Short self-test
sudo smartctl -t short /dev/sda

# Check all disks
for disk in $(lsblk -dno NAME | grep -E 'sd|nvme'); do
  echo "=== /dev/$disk ==="
  sudo smartctl -H /dev/$disk 2>/dev/null | grep -E "result|Status"
done
```

### Partition Management
```bash
# Interactive partitioning
sudo fdisk /dev/<disk>

# Non-interactive (create partition)
echo -e "n\np\n\n\n\nw" | sudo fdisk /dev/<disk>

# Format partition
sudo mkfs.ext4 /dev/<partition>
sudo mkfs.xfs /dev/<partition>

# Mount
sudo mkdir -p /mnt/<name>
sudo mount /dev/<partition> /mnt/<name>

# Add to fstab (persistent)
echo "UUID=$(blkid -s UUID -o value /dev/<partition>) /mnt/<name> ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

### Swap Management
```bash
# Current swap
swapon --show
free -h | grep Swap

# Create swap file
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Adjust swappiness (lower = prefer RAM)
cat /proc/sys/vm/swappiness
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Safety Rules

- **Always backup before partition changes**
- **Never resize a mounted root partition** — use live USB
- **Check SMART before trusting old disks**
- **Test fstab changes** with `sudo mount -a` before rebooting
- **Use UUID in fstab**, not /dev/sdX (device names can change)
- **Leave 10-15% free** on ext4 filesystems for reserved blocks
