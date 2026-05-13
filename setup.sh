#!/bin/bash

################################################################################
# Pi-hole Setup and Configuration Script
# Configure Pi-hole after installation
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONFIG_DIR="/etc/pihole"
LOG_FILE="/var/log/pihole-setup.log"

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

################################################################################
# Utility Functions
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

get_local_ip() {
    hostname -I | awk '{print $1}'
}

################################################################################
# Adlist Management
################################################################################

configure_adlists() {
    log_info "Configuring ad block lists..."
    
    cat > "$CONFIG_DIR/adlists.conf" <<'EOF'
# Pi-hole Adlist Configuration
# These are common blocklists for ad and malware blocking

# StevenBlack's Hosts List
# https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

# Disconnect.me Lists
# https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
# https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt

# Malware Domains
# https://mirror1.malwaredomains.com/files/justdomains

# Peter Lowe's Ad/Malware List
# https://pgl.yoyo.org/adservers/serverlist.php?hostformat=dnsmasq&showintro=0&mimetype=plaintext

# Add your custom blocklists below:
EOF
    
    log_success "Adlists configuration created"
}

################################################################################
# Whitelist/Blacklist Management
################################################################################

setup_lists() {
    log_info "Setting up whitelist and blacklist..."
    
    # Create whitelist file
    cat > "$CONFIG_DIR/whitelist.txt" <<'EOF'
# Whitelist entries (domains to always allow)
# One per line
EOF
    
    # Create blacklist file
    cat > "$CONFIG_DIR/blacklist.txt" <<'EOF'
# Blacklist entries (domains to always block)
# One per line
EOF
    
    # Create regex filter file
    cat > "$CONFIG_DIR/regex.txt" <<'EOF'
# Regex patterns for blocking
# One per line
# Example: ^adserver\.
EOF
    
    chown pihole:pihole "$CONFIG_DIR"/whitelist.txt
    chown pihole:pihole "$CONFIG_DIR"/blacklist.txt
    chown pihole:pihole "$CONFIG_DIR"/regex.txt
    
    chmod 644 "$CONFIG_DIR"/*.txt
    
    log_success "Lists configured"
}

################################################################################
# Upstream DNS Configuration
################################################################################

configure_upstream_dns() {
    log_info "Configuring upstream DNS servers..."
    
    cat > "$CONFIG_DIR/upstream.conf" <<'EOF'
# Upstream DNS Servers Configuration
# Pi-hole will forward unblocked queries to these servers

# Cloudflare
server=1.1.1.1
server=1.0.0.1

# Uncomment to use Quad9 instead:
# server=9.9.9.9
# server=149.112.112.112

# Uncomment to use OpenDNS:
# server=208.67.222.222
# server=208.67.220.220

# Uncomment to use Google DNS:
# server=8.8.8.8
# server=8.8.4.4
EOF
    
    log_success "Upstream DNS configuration created"
}

################################################################################
# Query Logging Configuration
################################################################################

configure_logging() {
    log_info "Configuring query logging..."
    
    cat > "$CONFIG_DIR/logging.conf" <<'EOF'
# Query Logging Configuration

# Log all queries (0 = disabled, 1 = enabled)
QUERY_LOGGING=1

# Log destination
LOGPATH="/var/log/pihole"

# Pihole-FTL configuration
PRIVACYLEVEL=0
# 0 = show all queries
# 1 = hide domains
# 2 = hide domains and clients
# 3 = anonymous mode
EOF
    
    # Create log directory
    mkdir -p /var/log/pihole
    chown pihole:pihole /var/log/pihole
    
    log_success "Logging configured"
}

################################################################################
# DHCP Configuration (Optional)
################################################################################

setup_dhcp() {
    log_info "Setting up DHCP configuration (optional)..."
    
    local ip=$(get_local_ip)
    local subnet="${ip%.*}.0"
    
    cat > "$CONFIG_DIR/dnsmasq-dhcp.conf" <<EOF
# DHCP Configuration for Pi-hole
# Uncomment to enable DHCP server

# dhcp-range=${subnet}.50,${subnet}.150,12h
# dhcp-option=option:router,${ip}
# dhcp-option=option:dns-server,${ip}

# For static IP assignments:
# dhcp-host=AA:BB:CC:DD:EE:FF,hostname,${subnet}.100
EOF
    
    log_success "DHCP template created at $CONFIG_DIR/dnsmasq-dhcp.conf"
    log_warn "DHCP is disabled by default. To enable, uncomment the lines in $CONFIG_DIR/dnsmasq-dhcp.conf and restart dnsmasq"
}

################################################################################
# Security Configuration
################################################################################

configure_security() {
    log_info "Configuring security settings..."
    
    cat > "$CONFIG_DIR/security.conf" <<'EOF'
# Pi-hole Security Configuration

# Rate limiting
RATE_LIMIT=1000/60

# Restrict query logging
QUERY_TYPES="A,AAAA,CNAME,MX,NS,PTR,SOA,SRV,TXT"

# DNS rebind protection
DNS_REBIND_PROTECTION=1

# Local records
LOCAL_ADDN_DOMAIN=local
EOF
    
    # Set restrictive permissions on config directory
    chmod 750 "$CONFIG_DIR"
    
    log_success "Security configuration applied"
}

################################################################################
# Backup Configuration
################################################################################

create_backup_script() {
    log_info "Creating backup script..."
    
    cat > /usr/local/bin/pihole-backup.sh <<'EOF'
#!/bin/bash
# Pi-hole Backup Script

BACKUP_DIR="/var/backups/pihole"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/pihole-backup-$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating Pi-hole backup: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" \
    /etc/pihole \
    /etc/dnsmasq.d \
    /var/www/html/admin

if [ $? -eq 0 ]; then
    echo "Backup created successfully"
    
    # Keep only last 7 backups
    cd "$BACKUP_DIR"
    ls -t pihole-backup-*.tar.gz | tail -n +8 | xargs -r rm
else
    echo "Backup failed"
    exit 1
fi
EOF
    
    chmod 755 /usr/local/bin/pihole-backup.sh
    
    # Create a cron job for daily backups
    if ! crontab -l 2>/dev/null | grep -q pihole-backup; then
        (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/pihole-backup.sh") | crontab -
        log_success "Daily backup cron job scheduled (2:00 AM)"
    fi
    
    log_success "Backup script created"
}

################################################################################
# System Optimization
################################################################################

optimize_system() {
    log_info "Optimizing system for Pi-hole..."
    
    # Increase file descriptors
    if ! grep -q "pihole soft nofile" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf <<EOF
pihole soft nofile 999999
pihole hard nofile 999999
EOF
    fi
    
    # Optimize dnsmasq cache
    cat >> /etc/dnsmasq.d/05-pihole-performance.conf <<'EOF'
# Performance optimizations
cache-size=10000
min-cache-ttl=60
max-cache-ttl=86400
neg-cache-ttl=3600
EOF
    
    log_success "System optimizations applied"
}

################################################################################
# Web Interface Customization
################################################################################

customize_webui() {
    log_info "Setting up web UI customization..."
    
    cat > "$CONFIG_DIR/webui.conf" <<'EOF'
# Web UI Configuration

# Dashboard refresh interval (seconds)
DASHBOARD_REFRESH=10

# Rows per page in tables
ROWS_PER_PAGE=10

# Enable/disable features
ALLOW_STATISTICS=1
ALLOW_QUERY_LOG=1
EOF
    
    log_success "Web UI configuration created"
}

################################################################################
# Display Configuration Summary
################################################################################

print_summary() {
    local ip=$(get_local_ip)
    
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}Configuration Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo "Pi-hole Setup Information:"
    echo "  Web Interface: http://$ip/admin"
    echo "  DNS Server IP: $ip"
    echo "  Config Directory: $CONFIG_DIR"
    echo "  Log File: $LOG_FILE"
    echo ""
    echo "Next Steps:"
    echo "  1. Access the web interface and log in"
    echo "  2. Configure your router's DHCP/DNS settings to point to $ip"
    echo "  3. Or configure individual devices to use $ip as DNS"
    echo "  4. Review adlists in $CONFIG_DIR/adlists.conf"
    echo "  5. Add custom whitelist/blacklist entries if needed"
    echo ""
    echo "Configuration Files:"
    echo "  - Adlists: $CONFIG_DIR/adlists.conf"
    echo "  - Whitelist: $CONFIG_DIR/whitelist.txt"
    echo "  - Blacklist: $CONFIG_DIR/blacklist.txt"
    echo "  - Regex: $CONFIG_DIR/regex.txt"
    echo "  - Upstream DNS: $CONFIG_DIR/upstream.conf"
    echo "  - Logging: $CONFIG_DIR/logging.conf"
    echo "  - Security: $CONFIG_DIR/security.conf"
    echo "  - DHCP (template): $CONFIG_DIR/dnsmasq-dhcp.conf"
    echo ""
    echo "Useful Commands:"
    echo "  systemctl restart pihole-FTL    # Restart Pi-hole FTL"
    echo "  systemctl restart dnsmasq       # Restart DNS"
    echo "  systemctl restart lighttpd      # Restart web server"
    echo "  pihole-backup.sh                # Manual backup"
    echo ""
}

################################################################################
# Main Setup Flow
################################################################################

main() {
    log_info "Starting Pi-hole setup configuration..."
    
    check_root
    
    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"
    
    # Run all configuration steps
    configure_adlists
    setup_lists
    configure_upstream_dns
    configure_logging
    setup_dhcp
    configure_security
    create_backup_script
    optimize_system
    customize_webui
    
    # Restart services to apply changes
    log_info "Restarting services to apply changes..."
    systemctl restart dnsmasq 2>/dev/null || log_warn "Failed to restart dnsmasq"
    systemctl restart lighttpd 2>/dev/null || log_warn "Failed to restart lighttpd"
    
    log_success "Configuration completed successfully!"
    print_summary
}

# Run main function
main "$@"
