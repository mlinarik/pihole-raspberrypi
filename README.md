# Pi-hole Installation Scripts for Raspberry Pi

Comprehensive installation and configuration scripts for deploying Pi-hole on Raspberry Pi. Pi-hole is a network-wide DNS-based ad blocker that protects all devices on your network from unwanted content.

## Overview

This repository contains fully automated scripts to:
- Install Pi-hole and all dependencies on Raspberry Pi
- Configure DNS, DHCP, and security settings
- Set up backup/restore functionality
- Manage blocklists and filtering rules
- Optimize system performance

## Contents

- **install.sh** - Main installation script for Pi-hole and dependencies
- **setup.sh** - Post-installation configuration and customization
- **backup.sh** - Backup, restore, and maintenance utilities
- **README.md** - This documentation file

## Prerequisites

### Hardware Requirements
- **Raspberry Pi** (Pi 3B+, Pi 4, or Pi 5 recommended)
- **microSD Card** (16GB or larger, Class 10)
- **Power Supply** (2.5A minimum, 3A+ recommended)
- **Ethernet Connection** (or WiFi on supported models)

### Software Requirements
- **OS**: Raspberry Pi OS Lite (Debian/Raspbian based)
- **Network**: Working internet connection during installation
- **Privileges**: Root/sudo access required

### System Resources
- **Minimum 500MB** free disk space
- **512MB RAM** (1GB+ recommended)
- **Stable power supply** (recommended to avoid corruption)

## Quick Start

### Step 1: Prepare Raspberry Pi

1. Download and flash [Raspberry Pi OS Lite](https://www.raspberrypi.com/software/) to your microSD card
2. Enable SSH (optional but recommended)
   - Create an empty file named `ssh` in the boot partition
3. Boot the Raspberry Pi and connect to network
4. Obtain the IP address: `hostname -I`

### Step 2: Download Installation Scripts

```bash
# SSH into your Raspberry Pi
ssh pi@<raspberry-pi-ip>

# Clone or download the scripts
git clone https://github.com/yourusername/pihole-raspberrypi.git
cd pihole-raspberrypi

# Make scripts executable
chmod +x install.sh setup.sh backup.sh
```

### Step 3: Run Installation

```bash
# Update system first
sudo apt-get update && sudo apt-get upgrade -y

# Run the main installation script
sudo ./install.sh

# Wait for completion (takes 10-15 minutes)
```

### Step 4: Configure Pi-hole

```bash
# Run setup script
sudo ./setup.sh
```

### Step 5: Access Web Interface

1. Open a browser on any computer on your network
2. Navigate to: `http://<raspberry-pi-ip>/admin`
3. Log in with the admin password (displayed after setup)
4. Configure your router's DNS to point to Pi-hole's IP address

## Script Details

### install.sh - Main Installation

**What it does:**
- Checks system requirements (root, disk space, internet)
- Updates system packages
- Installs dependencies (DNS, web server, Python)
- Clones Pi-hole repository
- Configures dnsmasq (DNS server)
- Configures Lighttpd (web server)
- Sets up systemd services
- Initializes databases and users

**Usage:**
```bash
sudo ./install.sh
```

**Output:**
- Installation logs saved to `/var/log/pihole-install.log`
- Pi-hole installed to `/opt/pihole`
- Configuration stored in `/etc/pihole`
- Web interface at `/var/www/html/admin`

**Logging:**
All output is logged to `/var/log/pihole-install.log`. You can monitor during installation:
```bash
tail -f /var/log/pihole-install.log
```

### setup.sh - Configuration

**What it configures:**
- Adlist management (blocklists configuration)
- Whitelist/Blacklist setup
- Upstream DNS servers (Cloudflare, Quad9, etc.)
- Query logging settings
- DHCP server template (optional)
- Security settings
- System optimizations
- Daily backup scheduling
- Web UI customization

**Usage:**
```bash
sudo ./setup.sh
```

**Configuration Files Created:**
- `/etc/pihole/adlists.conf` - Blocklist sources
- `/etc/pihole/whitelist.txt` - Always-allow domains
- `/etc/pihole/blacklist.txt` - Always-block domains
- `/etc/pihole/regex.txt` - Regex filtering patterns
- `/etc/pihole/upstream.conf` - Upstream DNS configuration
- `/etc/pihole/logging.conf` - Logging settings
- `/etc/pihole/security.conf` - Security parameters

### backup.sh - Backup and Restore

**Features:**
- Create full configuration backups
- Restore from previous backups
- List available backups with details
- Delete specific backups or purge all
- Export backups to external storage
- View backup contents
- Automatic cleanup of old backups
- Pre-restore safety backups

**Usage:**

```bash
# Create a backup
sudo ./backup.sh backup

# List all backups
sudo ./backup.sh list

# Restore from backup
sudo ./backup.sh restore pihole-backup-20240115_143022.tar.gz

# Delete specific backup
sudo ./backup.sh delete pihole-backup-20240115_143022.tar.gz

# Export backup
sudo ./backup.sh export pihole-backup-latest.tar.gz /mnt/external/

# Show backup contents
sudo ./backup.sh info pihole-backup-latest.tar.gz

# Clean up old backups (keeps last 7)
sudo ./backup.sh cleanup 7

# Delete all backups
sudo ./backup.sh purge
```

**Backup Location:** `/var/backups/pihole/`

**Automatic Backups:** Daily backups scheduled at 2:00 AM via cron

## Network Configuration

### Option 1: Router-Wide (Recommended)

1. Access your router's admin interface
2. Go to **DHCP Settings** or **DNS Settings**
3. Set DNS servers to your Raspberry Pi's IP address:
   - Primary DNS: `<your-pi-ip>`
   - Secondary DNS: `<your-pi-ip>` (optional)
4. Save and restart router (if required)
5. All devices will now use Pi-hole's DNS

### Option 2: Per-Device Configuration

Configure each device individually to use Pi-hole as DNS:

**Windows:**
1. Settings → Network & Internet → Change adapter options
2. Right-click your connection → Properties
3. Double-click IPv4 Properties
4. Select "Use the following DNS server addresses"
5. Enter Pi-hole IP in "Preferred DNS server"

**macOS:**
1. System Preferences → Network
2. Select your connection → Advanced → DNS
3. Click + and add Pi-hole IP

**Linux:**
```bash
# Edit /etc/netplan/01-netcfg.yaml
nameservers:
  addresses: [<pi-hole-ip>]
```

**Android:**
1. Settings → WiFi → Long-press your network → Modify
2. Show advanced options → DNS 1: Enter Pi-hole IP

**iOS:**
1. Settings → WiFi → Select your network
2. Configure DNS → Manual
3. Add Pi-hole IP address

## Common Tasks

### Add Custom Blocklist

1. Access web interface: `http://<pi-ip>/admin`
2. Go to **Adlists** section
3. Enter blocklist URL
4. Click **Add**
5. Update gravity database

Example blocklists:
```
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
```

### Whitelist/Blacklist Domains

**Via Web Interface:**
1. Go to **Whitelist** or **Blacklist**
2. Enter domain names
3. Click **Add**

**Via Command Line:**
```bash
# Add to whitelist
echo "trusted-domain.com" | sudo tee -a /etc/pihole/whitelist.txt

# Add to blacklist
echo "blocked-domain.com" | sudo tee -a /etc/pihole/blacklist.txt

# Apply changes
sudo systemctl restart pihole-FTL
```

### Change Upstream DNS

Edit `/etc/pihole/upstream.conf`:

```bash
sudo nano /etc/pihole/upstream.conf
```

Available options:
```bash
# Cloudflare (default)
server=1.1.1.1
server=1.0.0.1

# Quad9
server=9.9.9.9
server=149.112.112.112

# OpenDNS
server=208.67.222.222
server=208.67.220.220

# Google DNS
server=8.8.8.8
server=8.8.4.4
```

After changes: `sudo systemctl restart dnsmasq`

### Enable DHCP Server

If you want Pi-hole to handle DHCP (requires disabling on router first):

1. Edit `/etc/pihole/dnsmasq-dhcp.conf`
2. Uncomment DHCP lines
3. Configure IP range and options
4. Restart dnsmasq: `sudo systemctl restart dnsmasq`

### View Query Logs

```bash
# Real-time logs
sudo tail -f /var/log/dnsmasq.log

# Web interface (recommended)
# Navigate to http://<pi-ip>/admin/logs.php
```

### Restart Services

```bash
# Restart DNS service
sudo systemctl restart dnsmasq

# Restart web interface
sudo systemctl restart lighttpd

# Restart Pi-hole FTL
sudo systemctl restart pihole-FTL

# Restart all services
sudo systemctl restart dnsmasq lighttpd pihole-FTL
```

### Check Service Status

```bash
# Check all services
sudo systemctl status dnsmasq
sudo systemctl status lighttpd
sudo systemctl status pihole-FTL

# Or use this command to check all at once
sudo systemctl status dnsmasq lighttpd pihole-FTL --no-pager
```

### View Statistics

```bash
# Blocked queries count
sudo sqlite3 /etc/pihole/gravity.db \
  "SELECT COUNT(*) FROM queries WHERE status=1;"

# Total queries
sudo sqlite3 /etc/pihole/gravity.db \
  "SELECT COUNT(*) FROM queries;"

# Top blocked domains
sudo sqlite3 /etc/pihole/gravity.db \
  "SELECT domain, COUNT(*) FROM queries \
   WHERE status=1 GROUP BY domain \
   ORDER BY COUNT(*) DESC LIMIT 10;"
```

## Maintenance

### Regular Backups

Automatic backups run daily at 2:00 AM. Manual backup:
```bash
sudo /usr/local/bin/pihole-backup.sh
```

Backups are kept in `/var/backups/pihole/` (last 7 by default).

### Update Gravity Database

```bash
# Update blocklists
sudo /usr/local/bin/gravity.sh

# Or via web interface: Tools → Update Gravity
```

### Monitor Disk Usage

```bash
# Check disk space
df -h

# Check Pi-hole directory size
du -sh /opt/pihole /etc/pihole /var/log/pihole
```

### Clean Logs

```bash
# Archive old logs
sudo gzip /var/log/dnsmasq.log*

# Rotate logs (configure in /etc/logrotate.d/)
sudo logrotate -f /etc/logrotate.d/dnsmasq
```

## Troubleshooting

### DNS Not Resolving

```bash
# Test DNS locally
dig @127.0.0.1 google.com

# Check dnsmasq is running
sudo systemctl status dnsmasq

# Check for errors
sudo systemctl status dnsmasq -l

# Restart service
sudo systemctl restart dnsmasq
```

### Web Interface Not Accessible

```bash
# Check Lighttpd status
sudo systemctl status lighttpd

# Check if port 80 is listening
sudo netstat -tlnp | grep :80

# Restart web server
sudo systemctl restart lighttpd

# Check error logs
sudo tail -f /var/log/lighttpd/error.log
```

### High CPU Usage

```bash
# Monitor processes
top -b -n 1 | head -20

# Check if queries are backing up
sudo sqlite3 /etc/pihole/gravity.db \
  "SELECT COUNT(*) FROM queries;"

# Restart FTL
sudo systemctl restart pihole-FTL
```

### Disk Full

```bash
# Find large files
sudo du -sh /* | sort -rh | head -10

# Clean old logs
sudo rm -f /var/log/pihole/*.old
sudo rm -f /var/log/dnsmasq.log*

# Clean backup directory
sudo /usr/local/bin/backup.sh cleanup 3
```

### Installation Failed

```bash
# Check installation log
tail -100 /var/log/pihole-install.log

# Free disk space
sudo apt-get autoremove -y
df -h

# Retry installation
sudo ./install.sh
```

## Advanced Configuration

### Custom Regex Filters

Edit `/etc/pihole/regex.txt`:

```bash
# Block all tracking domains
^tracker\.
^analytics\.
^ad[sz]?\.

# Allow specific subdomains
^exception\.tracking\.

# Block by TLD pattern
^.*\.ads\.com$
```

### Privacy Levels

Configure in `/etc/pihole/pihole-FTL.conf`:
```bash
PRIVACYLEVEL=0  # Show all queries (default)
PRIVACYLEVEL=1  # Hide domains
PRIVACYLEVEL=2  # Hide domains and clients
PRIVACYLEVEL=3  # Anonymous mode
```

### Rate Limiting

Configure in `/etc/pihole/security.conf`:
```bash
RATE_LIMIT=1000/60  # 1000 queries per 60 seconds
```

### Conditional Forwarding

For local network domain resolution, edit `/etc/dnsmasq.d/05-pihole-default.conf`:
```bash
# Forward local queries to router
server=/local/192.168.1.1
```

## Performance Tuning

### Cache Size Optimization

Edit `/etc/dnsmasq.d/05-pihole-performance.conf`:
```bash
cache-size=10000      # Increase for more caching
min-cache-ttl=60      # Minimum time to cache
max-cache-ttl=86400   # Maximum time to cache
neg-cache-ttl=3600    # Time to cache negative responses
```

### File Descriptor Limits

Already configured by setup.sh in `/etc/security/limits.conf`:
```bash
pihole soft nofile 999999
pihole hard nofile 999999
```

### Memory Optimization

Monitor FTL memory usage:
```bash
ps aux | grep pihole-FTL
free -h
```

## Security Considerations

### Change Admin Password

```bash
# Via web interface: Settings → Web Interface → Password

# Or via command line:
pihole -a -p <new-password>
```

### Enable HTTPS

```bash
# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/lighttpd/server.key \
  -out /etc/lighttpd/server.crt

# Configure Lighttpd for HTTPS
sudo nano /etc/lighttpd/lighttpd.conf
```

### Enable Firewall

```bash
# Install UFW
sudo apt-get install ufw

# Enable basic rules
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 53/tcp      # DNS
sudo ufw allow 53/udp      # DNS
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw enable
```

### Regular Updates

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Update gravity database
sudo /usr/local/bin/gravity.sh
```

## Uninstallation

To remove Pi-hole:

```bash
# Stop services
sudo systemctl stop pihole-FTL dnsmasq lighttpd

# Disable services
sudo systemctl disable pihole-FTL dnsmasq lighttpd

# Remove directories
sudo rm -rf /opt/pihole
sudo rm -rf /etc/pihole

# Remove user
sudo userdel -r pihole

# Reinstall original dnsmasq
sudo apt-get install --reinstall dnsmasq
```

## Support and Resources

- **Pi-hole Official**: https://pi-hole.net/
- **GitHub Repository**: https://github.com/pi-hole/pi-hole
- **Community Forum**: https://discourse.pi-hole.net/
- **Reddit**: https://www.reddit.com/r/pihole/
- **Documentation**: https://docs.pi-hole.net/

## License

These scripts are provided as-is for educational and personal use.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests to improve these scripts.

## Changelog

### Version 1.0
- Initial release
- Full installation automation
- Configuration management
- Backup and restore functionality
- Comprehensive documentation

## Notes

- Installation typically takes 10-15 minutes
- First boot after installation may be slower as services initialize
- Automatic backups require cron daemon to be running
- Gravity database updates recommended weekly for fresh blocklists
- Monitor disk usage regularly as query logs can grow quickly

## FAQ

**Q: How much disk space does Pi-hole use?**
A: Approximately 500MB for installation. Query logs grow based on network activity.

**Q: Can I use Pi-hole on Wi-Fi only?**
A: Yes, though Ethernet is recommended for stability.

**Q: How many devices can Pi-hole protect?**
A: Theoretically unlimited, though performance depends on Raspberry Pi model and network load.

**Q: What happens if Pi-hole goes offline?**
A: Devices using Pi-hole as DNS may experience connectivity issues. Configure fallback DNS on router.

**Q: Can I block specific sites?**
A: Yes, via whitelist/blacklist or regex patterns in the web interface.

**Q: How do I check if Pi-hole is working?**
A: Access the dashboard at `http://<pi-ip>/admin` to view statistics and blocked queries.

---

For more information and updates, visit the [Pi-hole project](https://pi-hole.net/).
