# Pi-hole Quick Start Guide

This guide will get you up and running with Pi-hole on your Raspberry Pi in less than 30 minutes.

## 5-Minute Installation

### 1. Prepare Your Raspberry Pi

```bash
# SSH into your Pi (or open a terminal if you have HDMI connected)
ssh pi@<your-pi-ip>

# Update system (takes ~5 minutes)
sudo apt-get update && sudo apt-get upgrade -y
```

### 2. Download and Run Installation

```bash
# Clone the installation scripts
git clone https://github.com/yourusername/pihole-raspberrypi.git
cd pihole-raspberrypi

# Make scripts executable
chmod +x *.sh

# Run installation (takes ~10-15 minutes)
sudo ./install.sh
```

### 3. Configure Pi-hole

```bash
# Run setup script (takes ~2 minutes)
sudo ./setup.sh
```

### 4. Access Web Interface

Open a web browser and go to:
```
http://<your-pi-ip>/admin
```

## Immediate Next Steps

### Configure Your Network (Pick One)

**Option A: Router Configuration (Recommended)**
1. Access your router's admin panel (usually 192.168.1.1)
2. Find DNS settings (might be under "DHCP" or "Network")
3. Set DNS to your Pi's IP address
4. Save and restart router

**Option B: Individual Device Configuration**
- [Windows DNS Setup](#windows)
- [macOS DNS Setup](#macos)
- [Android DNS Setup](#android)

### First Commands to Try

```bash
# Check installation status
sudo ./health-check.sh status

# View full system status
sudo ./health-check.sh full

# Create a backup
sudo ./backup.sh backup

# View DNS statistics
dig @<your-pi-ip> google.com
```

## Verify It's Working

After configuring DNS, test from your computer:

```bash
# On your computer (not the Pi)
nslookup google.com <your-pi-ip>

# Should return a DNS response (not from 8.8.8.8)
```

Check the web dashboard - you should see queries arriving.

## Common First Customizations

### Add More Blocklists

Edit `/etc/pihole/adlists.conf`:
```bash
sudo nano /etc/pihole/adlists.conf
```

Popular lists to add:
```
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://mirror1.malwaredomains.com/files/justdomains
https://pgl.yoyo.org/adservers/serverlist.php?hostformat=dnsmasq&showintro=0&mimetype=plaintext
```

### Change DNS Provider

Edit `/etc/pihole/upstream.conf` and uncomment a different provider:

```bash
sudo nano /etc/pihole/upstream.conf
```

Popular options:
- **Cloudflare** (default, fastest for most)
- **Quad9** (security-focused)
- **OpenDNS** (parental controls available)

Restart DNS:
```bash
sudo systemctl restart dnsmasq
```

### Enable DHCP

If you want Pi-hole to handle DHCP (advanced):

```bash
sudo nano /etc/pihole/dnsmasq-dhcp.conf
```

Uncomment the DHCP lines and customize for your network, then:
```bash
sudo systemctl restart dnsmasq
```

## Troubleshooting Quick Fixes

### "DNS is not resolving"
```bash
# Check if DNS is running
sudo systemctl status dnsmasq

# Restart it
sudo systemctl restart dnsmasq

# Test locally
dig @127.0.0.1 google.com
```

### "Web interface not accessible"
```bash
# Check if web server is running
sudo systemctl status lighttpd

# Restart it
sudo systemctl restart lighttpd

# Test
curl http://127.0.0.1/admin
```

### "High CPU or Memory Usage"
```bash
# Check what's using resources
top

# View FTL stats
sudo ./health-check.sh resources

# Restart all services
sudo systemctl restart dnsmasq lighttpd pihole-FTL
```

### "Installation failed"
```bash
# Check error log
tail -50 /var/log/pihole-install.log

# Free up disk space if needed
sudo apt-get autoremove -y

# Retry
sudo ./install.sh
```

## Maintenance Routine

### Daily
- Check dashboard for blocked queries
- Monitor any DNS issues

### Weekly
- View statistics
- Update gravity database:
  ```bash
  sudo /usr/local/bin/gravity.sh
  ```

### Monthly
- Verify backups exist:
  ```bash
  sudo ./backup.sh list
  ```
- Check disk space:
  ```bash
  df -h
  ```
- Review logs for issues

## Device-Specific DNS Configuration

### Windows
1. Settings → Network & Internet → Change adapter options
2. Right-click your connection → Properties
3. Select IPv4 Properties
4. Select "Use these DNS server addresses"
5. Primary: `<pi-hole-ip>`
6. Click OK

### macOS
1. System Preferences → Network
2. Select your connection → Advanced
3. DNS tab
4. Click + and add `<pi-hole-ip>`
5. Click OK

### Android
1. Settings → WiFi → Long-press your network
2. Select "Modify"
3. Show advanced options
4. DNS 1: `<pi-hole-ip>`
5. Save

### iOS
1. Settings → WiFi
2. Select your network → Configure DNS
3. Change to "Manual"
4. Add `<pi-hole-ip>`

### Linux
Edit `/etc/netplan/01-netcfg.yaml`:
```yaml
network:
  version: 2
  ethernets:
    eth0:
      nameservers:
        addresses: [<pi-hole-ip>]
```

Then apply:
```bash
sudo netplan apply
```

## Available Scripts

- **install.sh** - Full installation (run once)
- **setup.sh** - Configure Pi-hole after installation
- **backup.sh** - Backup and restore functionality
- **health-check.sh** - Monitor system health
- **README.md** - Full documentation
- **QUICKSTART.md** - This file

## Getting Help

1. Check the full README.md for detailed documentation
2. Run `sudo ./health-check.sh full` for diagnostics
3. Check logs: `tail -f /var/log/pihole-install.log`
4. Visit [Pi-hole Forums](https://discourse.pi-hole.net/)

## Next Steps

After basic setup is working:

1. **Add custom blocklists** - Fine-tune what you block
2. **Create whitelist/blacklist** - Override rules for specific domains
3. **Enable HTTPS** - Secure your admin panel
4. **Set up backups** - Already configured (runs daily at 2 AM)
5. **Monitor statistics** - Use the dashboard to track blocked ads
6. **Configure conditional forwarding** - For local network domain resolution

## Tips for Success

- **Network-wide DNS** works best - set in router
- **Keep it powered** - Consider UPS or setup alerts
- **Monitor regularly** - Use `sudo ./health-check.sh` to check health
- **Update system** - Run `sudo apt-get upgrade -y` monthly
- **Backup configuration** - Done automatically, verify with `sudo ./backup.sh list`

## Performance Expectations

- **DNS Blocking**: 99%+ effective
- **Query Speed**: Adds <5ms latency
- **False Positives**: Less than 1% (easily whitelisted)
- **CPU Usage**: <10% on Pi 4
- **Memory Usage**: ~100-200MB on Raspberry Pi

## Default Credentials

- **Admin URL**: `http://<your-pi-ip>/admin`
- **Username**: Not required (IP-based access)
- **API Token**: Generate in Settings → API

## Common Questions

**Q: When will I see blocked ads?**
A: Immediately after devices are configured to use Pi-hole's DNS.

**Q: Does it affect streaming services?**
A: Only if you block those domains. Most streaming works fine.

**Q: Can I access from outside my network?**
A: Not recommended, but possible with VPN or SSH tunnel.

**Q: How do I uninstall?**
A: See README.md "Uninstallation" section.

---

Ready? Start with Step 1 above and you'll have Pi-hole running in 30 minutes!
