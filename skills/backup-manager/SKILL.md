# backup-manager — Backup & Recovery

Manage backups, snapshots, and disaster recovery for Ubuntu/Debian servers.

## Quick Reference

### Quick Backups
```bash
# Tar backup of directory
sudo tar czf /backup/$(hostname)-$(date +%Y%m%d).tar.gz /etc /home /var/lib

# Backup specific service data
sudo tar czf /backup/cortexos-$(date +%Y%m%d).tar.gz /etc/cortexos /var/lib/cortexos /root/.openclaw

# Backup with exclusions
sudo tar czf /backup/full-$(date +%Y%m%d).tar.gz \
  --exclude='/proc' --exclude='/sys' --exclude='/dev' \
  --exclude='/tmp' --exclude='/run' --exclude='/mnt' \
  --exclude='/backup' /

# Incremental (files changed since last backup)
sudo find / -newer /backup/.last-backup -type f 2>/dev/null | \
  sudo tar czf /backup/incremental-$(date +%Y%m%d).tar.gz -T -
sudo touch /backup/.last-backup
```

### rsync Backups
```bash
# Local backup
sudo rsync -avz --delete /var/lib/cortexos/ /backup/cortexos/

# Remote backup
sudo rsync -avz -e "ssh -p 22" /var/lib/cortexos/ user@backup-server:/backup/cortexos/

# With exclusions
sudo rsync -avz --delete \
  --exclude='*.log' \
  --exclude='*.tmp' \
  --exclude='.cache' \
  /home/ /backup/home/

# Dry run (preview what would change)
sudo rsync -avzn --delete /var/lib/ /backup/var-lib/

# Bandwidth limited
sudo rsync -avz --bwlimit=5000 /data/ remote:/backup/data/
```

### Scheduled Backups (cron)
```bash
# Edit root's crontab
sudo crontab -e

# Daily backup at 2 AM
0 2 * * * tar czf /backup/daily-$(date +\%Y\%m\%d).tar.gz /etc /var/lib/cortexos /root/.openclaw 2>/dev/null

# Weekly full backup Sunday 3 AM
0 3 * * 0 rsync -avz --delete /home/ /backup/weekly-home/ 2>/dev/null

# Monthly backup rotation (keep 30 days)
0 4 * * * find /backup -name "daily-*.tar.gz" -mtime +30 -delete 2>/dev/null

# Backup to remote daily
0 2 * * * rsync -avz -e ssh /var/lib/cortexos/ backup@remote:/backups/cortexos/ 2>/dev/null
```

### Database Backups
```bash
# PostgreSQL
sudo -u postgres pg_dumpall > /backup/postgres-$(date +%Y%m%d).sql
sudo -u postgres pg_dump <dbname> > /backup/<dbname>-$(date +%Y%m%d).sql

# MySQL/MariaDB
sudo mysqldump --all-databases > /backup/mysql-$(date +%Y%m%d).sql
sudo mysqldump <dbname> > /backup/<dbname>-$(date +%Y%m%d).sql

# SQLite
sqlite3 /path/to/db.sqlite ".backup '/backup/db-$(date +%Y%m%d).sqlite'"

# Redis
redis-cli BGSAVE
cp /var/lib/redis/dump.rdb /backup/redis-$(date +%Y%m%d).rdb
```

### LVM Snapshots
```bash
# Create snapshot
sudo lvcreate -L 5G -s -n snap-$(date +%Y%m%d) /dev/<vg>/<lv>

# Mount snapshot (read-only)
sudo mount -o ro /dev/<vg>/snap-$(date +%Y%m%d) /mnt/snapshot

# Backup from snapshot
sudo tar czf /backup/lvm-$(date +%Y%m%d).tar.gz /mnt/snapshot/

# Remove snapshot when done
sudo umount /mnt/snapshot
sudo lvremove -y /dev/<vg>/snap-$(date +%Y%m%d)

# List snapshots
sudo lvs -a | grep snap
```

### Restore
```bash
# Restore from tar
sudo tar xzf /backup/daily-20260319.tar.gz -C /

# Restore specific files
sudo tar xzf /backup/daily-20260319.tar.gz -C / etc/cortexos/config.yaml

# List contents before restoring
tar tzf /backup/daily-20260319.tar.gz | head -30

# Restore from rsync backup
sudo rsync -avz /backup/cortexos/ /var/lib/cortexos/

# Restore PostgreSQL
sudo -u postgres psql < /backup/postgres-20260319.sql

# Restore MySQL
sudo mysql < /backup/mysql-20260319.sql
```

### Backup Verification
```bash
# Test tar integrity
tar tzf /backup/daily-20260319.tar.gz > /dev/null && echo "OK" || echo "CORRUPTED"

# Compare backup to source
diff <(tar tzf /backup/daily-20260319.tar.gz | sort) <(find /etc /home -type f | sort)

# Check backup sizes over time
ls -lhS /backup/*.tar.gz | head -10

# Disk usage of backups
du -sh /backup/
```

### CortexOS Backup Strategy
```bash
# What to backup for CortexOS Server:
# 1. Gateway config
#    /root/.openclaw/openclaw.json
#    /root/.openclaw/agents/
#    /root/.openclaw/audit.db
# 2. CortexOS config
#    /etc/cortexos/
# 3. Skills
#    /var/lib/cortexos/skills/
# 4. Data
#    /var/lib/cortexos/
# 5. Service file
#    /etc/systemd/system/cortex-server.service

# Quick CortexOS backup script
cat > /usr/local/bin/cortexos-backup << 'SCRIPT'
#!/bin/bash
BACKUP_DIR="/backup/cortexos"
DATE=$(date +%Y%m%d-%H%M)
mkdir -p "$BACKUP_DIR"

tar czf "$BACKUP_DIR/cortexos-$DATE.tar.gz" \
  /root/.openclaw \
  /etc/cortexos \
  /var/lib/cortexos \
  /etc/systemd/system/cortex-server.service \
  2>/dev/null

# Keep last 14 days
find "$BACKUP_DIR" -name "cortexos-*.tar.gz" -mtime +14 -delete

echo "Backup: $BACKUP_DIR/cortexos-$DATE.tar.gz ($(du -h "$BACKUP_DIR/cortexos-$DATE.tar.gz" | awk '{print $1}'))"
SCRIPT
chmod +x /usr/local/bin/cortexos-backup
```

## Safety Rules

- **Test restores regularly** — a backup you can't restore is worthless
- **Store backups offsite** — same disk doesn't count as a backup
- **Encrypt sensitive backups** — `tar czf - /data | gpg -c > backup.tar.gz.gpg`
- **Verify backup integrity** after creation
- **Document restore procedures** — you won't remember at 3 AM during an outage
- **3-2-1 rule**: 3 copies, 2 different media, 1 offsite
