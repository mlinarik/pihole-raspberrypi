#!/bin/bash

################################################################################
# Pi-hole Installation Script for Raspberry Pi
# This script automates the installation and configuration of Pi-hole
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="/var/log/pihole-install.log"
PIHOLE_USER="pihole"
PIHOLE_GROUP="pihole"

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
# System Check Functions
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    log_success "Root privileges verified"
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version"
        exit 1
    fi

    source /etc/os-release
    if [[ "$ID" != "debian" && "$ID" != "raspbian" ]]; then
        log_warn "This script is optimized for Debian/Raspbian. Your OS: $ID"
    fi
    log_success "OS: $ID $VERSION_ID"
}

check_disk_space() {
    local required_space=500 # MB
    local available_space=$(df /home | awk 'NR==2 {print int($4/1024)}')
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space. Required: ${required_space}MB, Available: ${available_space}MB"
        exit 1
    fi
    log_success "Disk space check passed (${available_space}MB available)"
}

check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "No internet connection detected"
        exit 1
    fi
    log_success "Internet connection verified"
}

################################################################################
# System Update Functions
################################################################################

update_system() {
    log_info "Updating system packages..."
    apt-get update || log_error "Failed to update package list"
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || log_error "Failed to upgrade packages"
    log_success "System packages updated"
}

install_dependencies() {
    log_info "Installing dependencies..."
    
    local packages=(
        "curl"
        "wget"
        "git"
        "python3"
        "python3-pip"
        "dnsmasq"
        "lighttpd"
        "php-cgi"
        "sqlite3"
        "unzip"
        "telnet"
        "iputils-ping"
        "net-tools"
        "sudo"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            log_info "Installing $package..."
            apt-get install -y "$package" || log_error "Failed to install $package"
        else
            log_info "$package already installed"
        fi
    done
    
    log_success "All dependencies installed"
}

################################################################################
# Pi-hole Installation Functions
################################################################################

clone_pihole_repo() {
    local pihole_dir="/opt/pihole"
    
    if [[ -d "$pihole_dir" ]]; then
        log_warn "Pi-hole directory already exists at $pihole_dir"
        read -p "Do you want to overwrite it? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping repository clone"
            return 0
        fi
        rm -rf "$pihole_dir"
    fi
    
    log_info "Cloning Pi-hole repository..."
    git clone --depth 1 https://github.com/pi-hole/pi-hole.git "$pihole_dir" || {
        log_error "Failed to clone Pi-hole repository"
        exit 1
    }
    log_success "Pi-hole repository cloned"
}

create_pihole_user() {
    if id "$PIHOLE_USER" &>/dev/null; then
        log_warn "User $PIHOLE_USER already exists"
        return 0
    fi
    
    log_info "Creating Pi-hole user..."
    useradd -r -s /usr/sbin/nologin -d /opt/pihole -m "$PIHOLE_USER" || {
        log_error "Failed to create $PIHOLE_USER user"
        exit 1
    }
    log_success "Pi-hole user created"
}

setup_pihole_permissions() {
    log_info "Setting up Pi-hole permissions..."
    
    # Create necessary directories
    mkdir -p /etc/pihole
    mkdir -p /etc/dnsmasq.d
    mkdir -p /var/www/html/admin
    
    # Set ownership
    chown -R "$PIHOLE_USER:$PIHOLE_GROUP" /opt/pihole
    chown -R "$PIHOLE_USER:$PIHOLE_GROUP" /etc/pihole
    chown -R www-data:www-data /var/www/html
    
    # Set permissions
    chmod -R 755 /opt/pihole
    chmod -R 755 /etc/pihole
    
    log_success "Permissions configured"
}

configure_dnsmasq() {
    log_info "Configuring dnsmasq..."
    
    # Backup original configuration
    if [[ -f /etc/dnsmasq.conf ]]; then
        cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
    fi
    
    # Create Pi-hole dnsmasq config
    cat > /etc/dnsmasq.d/05-pihole-default.conf <<'EOF'
# Pi-hole's default dnsmasq config
addn-hosts=/etc/pihole/adlists
localise-queries
no-negcache
cache-size=10000
log-queries
log-facility=/var/log/dnsmasq.log
EOF
    
    log_success "dnsmasq configured"
}

configure_lighttpd() {
    log_info "Configuring Lighttpd..."
    
    # Enable necessary modules
    lighty-enable-mod fastcgi-php 2>/dev/null || true
    
    # Create Pi-hole lighttpd config
    cat > /etc/lighttpd/conf-available/15-pihole-admin.conf <<'EOF'
# Pi-hole admin dashboard configuration
server.modules = (
    "mod_cgi",
    "mod_fastcgi",
    "mod_rewrite",
)

fastcgi.server = (
    ".php" => (
        "localhost" => (
            "socket" => "/run/php/php-cgi.sock",
            "bin-path" => "/usr/bin/php-cgi",
        )
    )
)

url.rewrite-if-not-file = (
    "^/admin/api(/.*)$" => "/admin/api.php$1"
)
EOF
    
    log_success "Lighttpd configured"
}

install_pihole_web() {
    log_info "Installing Pi-hole web interface..."
    
    local pihole_dir="/opt/pihole"
    local admin_src="$pihole_dir/AdminLTE"
    local admin_dest="/var/www/html/admin"
    
    if [[ -d "$admin_src" ]]; then
        cp -r "$admin_src"/* "$admin_dest/" 2>/dev/null || true
        chown -R www-data:www-data "$admin_dest"
        chmod -R 755 "$admin_dest"
    fi
    
    log_success "Web interface installed"
}

################################################################################
# Service Configuration Functions
################################################################################

setup_services() {
    log_info "Setting up services..."
    
    # Create pihole-FTL service
    cat > /etc/systemd/system/pihole-FTL.service <<'EOF'
[Unit]
Description=Pi-hole FTL
After=network.target dnsmasq.service

[Service]
Type=simple
User=pihole
Group=pihole
ExecStart=/usr/bin/pihole-FTL /etc/pihole/pihole-FTL.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Create gravity update service
    cat > /etc/systemd/system/pihole-gravity.timer <<'EOF'
[Unit]
Description=Pi-hole gravity update timer
Requires=pihole-gravity.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF
    
    cat > /etc/systemd/system/pihole-gravity.service <<'EOF'
[Unit]
Description=Pi-hole gravity update
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gravity.sh
EOF
    
    systemctl daemon-reload
    log_success "Services configured"
}

enable_services() {
    log_info "Enabling and starting services..."
    
    # Enable services
    systemctl enable dnsmasq 2>/dev/null || true
    systemctl enable lighttpd 2>/dev/null || true
    
    # Start/restart services
    systemctl restart dnsmasq || log_warn "Failed to restart dnsmasq"
    systemctl restart lighttpd || log_warn "Failed to restart lighttpd"
    
    log_success "Services enabled and started"
}

################################################################################
# Configuration Functions
################################################################################

configure_dns() {
    log_info "Configuring DNS settings..."
    
    # Set up gravity database
    mkdir -p /etc/pihole
    
    # Create initial adlists file
    cat > /etc/pihole/adlists.default <<'EOF'
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://mirror1.malwaredomains.com/files/justdomains
https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
https://pgl.yoyo.org/adservers/serverlist.php?hostformat=dnsmasq&showintro=0&mimetype=plaintext
EOF
    
    log_success "DNS configuration completed"
}

create_admin_user() {
    log_info "Setting up admin interface..."
    
    # Create admin password file if it doesn't exist
    local admin_pass_file="/etc/pihole/adm_pass"
    
    if [[ ! -f "$admin_pass_file" ]]; then
        # Generate a random password
        local admin_pass=$(openssl rand -base64 12)
        echo "$admin_pass" > "$admin_pass_file"
        chmod 600 "$admin_pass_file"
        log_success "Admin password created: $admin_pass (saved to $admin_pass_file)"
    fi
}

################################################################################
# Firewall Configuration
################################################################################

configure_firewall() {
    log_info "Configuring firewall rules..."
    
    if command -v ufw &> /dev/null; then
        # Allow DNS
        ufw allow 53/tcp 2>/dev/null || true
        ufw allow 53/udp 2>/dev/null || true
        
        # Allow HTTP/HTTPS
        ufw allow 80/tcp 2>/dev/null || true
        ufw allow 443/tcp 2>/dev/null || true
        
        # Allow SSH
        ufw allow 22/tcp 2>/dev/null || true
        
        log_success "Firewall rules configured"
    else
        log_warn "UFW not installed, skipping firewall configuration"
    fi
}

################################################################################
# Post-Installation Functions
################################################################################

verify_installation() {
    log_info "Verifying installation..."
    
    local errors=0
    
    # Check if DNS is responding
    if dig +short @127.0.0.1 google.com | grep -q "^[0-9]"; then
        log_success "DNS resolution working"
    else
        log_warn "DNS resolution not responding yet (this may be normal during startup)"
        ((errors++))
    fi
    
    # Check Lighttpd
    if systemctl is-active --quiet lighttpd; then
        log_success "Lighttpd is running"
    else
        log_warn "Lighttpd is not running"
        ((errors++))
    fi
    
    # Check dnsmasq
    if systemctl is-active --quiet dnsmasq; then
        log_success "dnsmasq is running"
    else
        log_warn "dnsmasq is not running"
        ((errors++))
    fi
    
    return $errors
}

print_summary() {
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}Pi-hole Installation Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Access the web interface: http://$(hostname -I | awk '{print $1}')/admin"
    echo "2. Configure your router's DNS to point to this Pi's IP address"
    echo "3. Check the admin dashboard at: http://$(hostname -I | awk '{print $1}')/admin/"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    log_info "Starting Pi-hole installation..."
    log_info "Logging to: $LOG_FILE"
    
    check_root
    check_os
    check_disk_space
    check_internet
    
    log_info "Step 1: System preparation"
    update_system
    install_dependencies
    
    log_info "Step 2: Pi-hole installation"
    clone_pihole_repo
    create_pihole_user
    setup_pihole_permissions
    
    log_info "Step 3: Service configuration"
    configure_dnsmasq
    configure_lighttpd
    install_pihole_web
    setup_services
    
    log_info "Step 4: Network configuration"
    configure_dns
    configure_firewall
    create_admin_user
    
    log_info "Step 5: Starting services"
    enable_services
    
    log_info "Step 6: Verification"
    verify_installation
    
    print_summary
    log_success "Installation completed successfully!"
}

# Run main function
main "$@"
