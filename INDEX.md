# Pi-hole Installation Scripts - File Index

Complete collection of automated installation and management scripts for Pi-hole on Raspberry Pi.

## Quick Navigation

- **First Time Users**: Start with [QUICKSTART.md](QUICKSTART.md) (5-minute guide)
- **Full Documentation**: See [README.md](README.md) (comprehensive reference)
- **Already Installed?**: Jump to [Already Installed Section](#already-installed)

---

## Script Files

### Installation & Setup

#### [install.sh](install.sh) 
**Main installation script** - Run this first to install Pi-hole

- ✅ Checks system requirements (root, disk space, internet)
- ✅ Updates system packages
- ✅ Installs all dependencies
- ✅ Clones Pi-hole repository
- ✅ Configures DNS, web server, and services
- ✅ Sets up database and permissions
- ✅ Logs all output to `/var/log/pihole-install.log`

**Usage:**
```bash
sudo ./install.sh
```

**Runtime:** ~10-15 minutes  
**Requirements:** Root access, internet connection, 500MB disk space

---

#### [setup.sh](setup.sh)
**Configuration script** - Run this after install.sh to configure Pi-hole

- ✅ Creates configuration templates for blocklists
- ✅ Sets up whitelist/blacklist files
- ✅ Configures upstream DNS servers
- ✅ Enables query logging
- ✅ Sets up DHCP template
- ✅ Applies security hardening
- ✅ Schedules automatic daily backups

**Usage:**
```bash
sudo ./setup.sh
```

**Runtime:** ~2 minutes  
**Creates:** Configuration files in `/etc/pihole/`

---

### Maintenance & Operations

#### [backup.sh](backup.sh)
**Backup and restore utility** - Manage Pi-hole configuration backups

**Features:**
- Create full backups of Pi-hole configuration
- Restore from previous backups
- List all available backups
- Delete specific or all backups
- Export backups to external storage
- View backup contents
- Automatic cleanup of old backups

**Usage Examples:**
```bash
sudo ./backup.sh backup                                    # Create backup
sudo ./backup.sh list                                      # List backups
sudo ./backup.sh restore pihole-backup-20240115_143022.tar.gz  # Restore
sudo ./backup.sh export pihole-backup-latest.tar.gz /mnt/external/  # Export
sudo ./backup.sh delete pihole-backup-20240115_143022.tar.gz  # Delete
sudo ./backup.sh cleanup 7                                 # Keep last 7 backups
```

**Backup Location:** `/var/backups/pihole/`  
**Automatic Backups:** Daily at 2:00 AM

---

#### [health-check.sh](health-check.sh)
**System health and status monitor** - Check Pi-hole and system health

**Available Checks:**
- System resources (CPU, memory, temperature)
- Disk space usage
- Service status (DNS, web server, FTL)
- DNS functionality tests
- Web interface status
- Network information
- Query statistics
- Log analysis
- Performance metrics
- Maintenance recommendations

**Usage Examples:**
```bash
sudo ./health-check.sh status              # Quick overview
sudo ./health-check.sh full                # Complete report
sudo ./health-check.sh resources           # System resources only
sudo ./health-check.sh services            # Service status only
sudo ./health-check.sh dns                 # DNS functionality
sudo ./health-check.sh stats               # Query statistics
```

**Output:** Formatted status report with color indicators

---

#### [update.sh](update.sh)
**Update and maintenance script** - Keep Pi-hole and system current

**Available Commands:**
- `system` - Update only system packages
- `gravity` - Update gravity database (blocklists)
- `pihole` - Update Pi-hole to latest version
- `all` - Update everything
- `cleanup` - Clean logs and temp files
- `optimize` - Optimize system performance
- `verify` - Verify all services running

**Usage Examples:**
```bash
sudo ./update.sh all --backup -y            # Update everything with backup
sudo ./update.sh gravity                    # Update blocklists only
sudo ./update.sh system                     # System packages only
sudo ./update.sh cleanup                    # Clean logs and temp files
sudo ./update.sh verify                     # Check service status
```

**Features:**
- Create pre-update backups
- Update gravity blocklists
- Update system packages
- Clean logs and temporary files
- Optimize performance
- Verify services after update

---

#### [uninstall.sh](uninstall.sh)
**Uninstallation script** - Cleanly remove Pi-hole

**Does:**
- ✅ Creates final backup before removal
- ✅ Stops all services
- ✅ Removes Pi-hole files and configuration
- ✅ Removes Pi-hole system user
- ✅ Restores original dnsmasq configuration
- ✅ Removes cron jobs
- ✅ Cleans up systemd services

**Usage:**
```bash
sudo ./uninstall.sh                 # Interactive removal
sudo ./uninstall.sh --force         # Skip confirmations
sudo ./uninstall.sh --keep-backup   # Keep backup directory
```

**Safety:** Creates final backup and asks for confirmation before removal

---

## Documentation Files

### [QUICKSTART.md](QUICKSTART.md)
**5-minute getting started guide** - For first-time users

Contents:
- Quick installation steps
- Network configuration options
- First verification steps
- Basic customizations
- Troubleshooting quick fixes
- Device-specific DNS setup

**Read Time:** 5-10 minutes  
**Best For:** New users wanting fast setup

---

### [README.md](README.md)
**Complete documentation** - Comprehensive reference guide

Contents:
- Detailed installation instructions
- Network configuration (router and per-device)
- Common tasks and operations
- Advanced configuration
- Performance tuning
- Security considerations
- Troubleshooting section
- FAQ

**Read Time:** 30-45 minutes  
**Best For:** Reference and in-depth learning

---

### [INDEX.md](INDEX.md)
**This file** - Script index and quick reference

---

## Installation Order

### First-Time Installation

**Step 1: Download Scripts**
```bash
git clone https://github.com/yourusername/pihole-raspberrypi.git
cd pihole-raspberrypi
chmod +x *.sh
```

**Step 2: Run Installation**
```bash
sudo ./install.sh
```
*(Configures system and installs Pi-hole)*

**Step 3: Configure Pi-hole**
```bash
sudo ./setup.sh
```
*(Creates templates and schedules backups)*

**Step 4: Verify Installation**
```bash
sudo ./health-check.sh full
```
*(Check that everything is working)*

**Step 5: Access Web Interface**
- Open browser: `http://<your-pi-ip>/admin`
- Configure your router's DNS or individual devices

---

## Already Installed?

If Pi-hole is already running:

### Regular Maintenance
```bash
# Check health daily
sudo ./health-check.sh status

# Update blocklists weekly
sudo ./update.sh gravity

# Create monthly backups
sudo ./backup.sh backup

# Full system update
sudo ./update.sh all --backup -y
```

### Troubleshooting
```bash
# Full diagnostic report
sudo ./health-check.sh full

# Check DNS
sudo ./health-check.sh dns

# Verify services
sudo ./update.sh verify
```

### Backup/Restore
```bash
# Create backup
sudo ./backup.sh backup

# List backups
sudo ./backup.sh list

# Restore from backup
sudo ./backup.sh restore <backup-file>
```

### Updates
```bash
# Update system only
sudo ./update.sh system

# Update Pi-hole only
sudo ./update.sh pihole

# Update everything
sudo ./update.sh all --backup
```

---

## File Permissions

All scripts should be executable:
```bash
chmod +x install.sh setup.sh backup.sh health-check.sh update.sh uninstall.sh
```

---

## System Requirements

- **Hardware**: Raspberry Pi 3B+ or newer
- **OS**: Raspberry Pi OS Lite (Debian/Raspbian)
- **Disk**: 500MB minimum free space
- **RAM**: 512MB minimum (1GB+ recommended)
- **Network**: Ethernet connection (WiFi supported)
- **Privileges**: Root/sudo access required

---

## Log Files

All scripts create detailed logs:

| Script | Log File |
|--------|----------|
| install.sh | `/var/log/pihole-install.log` |
| setup.sh | `/var/log/pihole-setup.log` |
| backup.sh | `/var/log/pihole-backup.log` |
| health-check.sh | Console output only |
| update.sh | `/var/log/pihole-maintenance.log` |
| uninstall.sh | `/var/log/pihole-uninstall.log` |

View logs:
```bash
sudo tail -f /var/log/pihole-*.log
```

---

## Configuration Files

After installation, these files are created:

```
/etc/pihole/
├── adlists.conf           # Blocklist sources
├── whitelist.txt          # Always-allow domains
├── blacklist.txt          # Always-block domains
├── regex.txt              # Regex filtering patterns
├── upstream.conf          # Upstream DNS servers
├── logging.conf           # Logging settings
├── security.conf          # Security parameters
├── dnsmasq-dhcp.conf      # DHCP template
├── gravity.db             # Gravity database
└── adm_pass               # Admin password
```

---

## Service Management

```bash
# Start/stop individual services
sudo systemctl start dnsmasq              # DNS service
sudo systemctl start lighttpd             # Web server
sudo systemctl start pihole-FTL           # Pi-hole FTL daemon

# Check status
sudo systemctl status dnsmasq

# Restart all services
sudo systemctl restart dnsmasq lighttpd pihole-FTL

# Enable on boot
sudo systemctl enable dnsmasq
```

---

## Common Commands Reference

```bash
# Installation
sudo ./install.sh

# Post-installation setup
sudo ./setup.sh

# Daily health check
sudo ./health-check.sh status

# Create backup
sudo ./backup.sh backup

# Update everything
sudo ./update.sh all --backup

# Remove Pi-hole
sudo ./uninstall.sh

# View all logs
sudo tail -50 /var/log/pihole-install.log
```

---

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| DNS not working | `sudo systemctl restart dnsmasq` |
| Web interface down | `sudo systemctl restart lighttpd` |
| High CPU usage | `sudo systemctl restart pihole-FTL` |
| Out of disk space | `sudo ./update.sh cleanup` |
| Blocklists not updating | `sudo ./update.sh gravity` |
| Forgot admin password | Check `/etc/pihole/adm_pass` |

Full troubleshooting: See [README.md](README.md#troubleshooting)

---

## Support & Resources

- **Official Website**: https://pi-hole.net/
- **GitHub Repository**: https://github.com/pi-hole/pi-hole
- **Community Forum**: https://discourse.pi-hole.net/
- **Documentation**: https://docs.pi-hole.net/

---

## Version Information

- **Script Version**: 1.0
- **Last Updated**: 2024
- **Tested On**: Raspberry Pi 3B+, 4, and 5
- **OS**: Raspberry Pi OS Lite (Bullseye, Bookworm)

---

## License

These scripts are provided as-is for educational and personal use.

---

## Next Steps

1. **New User?** → Start with [QUICKSTART.md](QUICKSTART.md)
2. **Need Details?** → Read [README.md](README.md)
3. **Ready to Install?** → Run `sudo ./install.sh`
4. **Already Installed?** → Run `sudo ./health-check.sh status`

---

*For the latest updates and more information, visit the [Pi-hole project](https://pi-hole.net/)*
