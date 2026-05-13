#!/bin/bash

################################################################################
# Pi-hole Uninstallation Script
# Safely remove Pi-hole and restore system to original state
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_FILE="/var/log/pihole-uninstall.log"

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

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --keep-backup    Keep backup directory after uninstall
  --force          Skip confirmation prompts
  -h, --help       Show this help message

WARNING: This script will remove Pi-hole and its configuration.
If you have important settings, create a backup first:
  sudo ./backup.sh backup

EOF
}

################################################################################
# Backup Functions
################################################################################

create_final_backup() {
    log_info "Creating final backup before uninstallation..."
    
    local backup_dir="/var/backups/pihole"
    mkdir -p "$backup_dir"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/pihole-backup-FINAL-$timestamp.tar.gz"
    
    if tar -czf "$backup_file" \
        --exclude='*.log' \
        /etc/pihole 2>/dev/null; then
        
        log_success "Final backup created: $backup_file"
        log_warn "If you want to restore later, keep this backup file"
        return 0
    else
        log_warn "Could not create final backup, continuing anyway"
        return 1
    fi
}

################################################################################
# Service Cleanup
################################################################################

stop_services() {
    log_info "Stopping services..."
    
    systemctl stop pihole-FTL 2>/dev/null || log_warn "Failed to stop pihole-FTL"
    systemctl stop dnsmasq 2>/dev/null || log_warn "Failed to stop dnsmasq"
    systemctl stop lighttpd 2>/dev/null || log_warn "Failed to stop lighttpd"
    
    log_success "Services stopped"
}

disable_services() {
    log_info "Disabling services..."
    
    systemctl disable pihole-FTL 2>/dev/null || true
    systemctl disable dnsmasq 2>/dev/null || true
    systemctl disable lighttpd 2>/dev/null || true
    
    # Remove custom service files
    rm -f /etc/systemd/system/pihole-FTL.service
    rm -f /etc/systemd/system/pihole-gravity.service
    rm -f /etc/systemd/system/pihole-gravity.timer
    
    systemctl daemon-reload
    
    log_success "Services disabled"
}

################################################################################
# File Cleanup
################################################################################

remove_pihole_files() {
    log_info "Removing Pi-hole files..."
    
    # Remove Pi-hole installation
    if [[ -d /opt/pihole ]]; then
        rm -rf /opt/pihole
        log_success "Removed /opt/pihole"
    fi
    
    # Remove web interface (but keep lighttpd)
    if [[ -d /var/www/html/admin ]]; then
        rm -rf /var/www/html/admin
        log_success "Removed /var/www/html/admin"
    fi
    
    # Remove Pi-hole configuration
    if [[ -d /etc/pihole ]]; then
        log_warn "Backing up configuration to /etc/pihole.bak"
        mv /etc/pihole /etc/pihole.bak 2>/dev/null || true
    fi
    
    # Remove dnsmasq Pi-hole configuration
    rm -f /etc/dnsmasq.d/05-pihole-*.conf
    log_success "Removed Pi-hole configuration files"
}

remove_custom_scripts() {
    log_info "Removing custom scripts..."
    
    rm -f /usr/local/bin/pihole-backup.sh
    rm -f /usr/local/bin/gravity.sh
    
    log_success "Custom scripts removed"
}

################################################################################
# User Cleanup
################################################################################

remove_pihole_user() {
    log_info "Removing Pi-hole user..."
    
    if id pihole &>/dev/null; then
        # Kill any processes owned by pihole user
        pkill -9 -u pihole 2>/dev/null || true
        
        # Remove user
        userdel -r pihole 2>/dev/null || true
        
        log_success "Pi-hole user removed"
    else
        log_warn "Pi-hole user not found"
    fi
}

################################################################################
# Restore Original Configuration
################################################################################

restore_original_dnsmasq() {
    log_info "Restoring original dnsmasq configuration..."
    
    if [[ -f /etc/dnsmasq.conf.backup ]]; then
        mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf
        log_success "Restored original dnsmasq configuration"
    else
        log_warn "Original dnsmasq configuration not found"
    fi
    
    # Remove all dnsmasq.d files we created
    find /etc/dnsmasq.d -name "*pihole*" -delete 2>/dev/null || true
}

################################################################################
# Package Management
################################################################################

uninstall_packages() {
    log_info "Removing Pi-hole specific packages..."
    
    # We keep most packages as they may be needed for other things
    # Only remove lighttpd if user confirms (not done by default)
    
    log_warn "Package removal skipped to avoid breaking other services"
    log_info "Installed packages kept: curl wget git python3 dnsmasq lighttpd"
    
    return 0
}

################################################################################
# Cron Job Cleanup
################################################################################

remove_cron_jobs() {
    log_info "Removing cron jobs..."
    
    # Remove Pi-hole backup cron job
    crontab -l 2>/dev/null | grep -v "pihole-backup" | crontab - 2>/dev/null || true
    
    log_success "Cron jobs removed"
}

################################################################################
# Verify Cleanup
################################################################################

verify_uninstall() {
    log_info "Verifying uninstallation..."
    
    local errors=0
    
    if [[ -d /opt/pihole ]]; then
        log_error "Pi-hole directory still exists"
        ((errors++))
    fi
    
    if id pihole &>/dev/null; then
        log_error "Pi-hole user still exists"
        ((errors++))
    fi
    
    if [[ -d /var/www/html/admin ]]; then
        log_error "Pi-hole web interface still exists"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "Uninstallation verified"
        return 0
    else
        log_warn "Some Pi-hole files may remain"
        return 1
    fi
}

################################################################################
# Restoration Instructions
################################################################################

print_restoration_info() {
    log_info "Pi-hole has been uninstalled"
    echo ""
    echo "Post-Uninstallation Steps:"
    echo ""
    echo "1. Update router/device DNS settings back to your ISP or preferred DNS"
    echo "   (IMPORTANT: Otherwise devices will not be able to resolve DNS)"
    echo ""
    echo "2. If you need to reinstall:"
    echo "   - Run: sudo ./install.sh"
    echo "   - Or restore from backup: sudo ./backup.sh restore <backup-file>"
    echo ""
    echo "3. If you have performance issues, try:"
    echo "   - Reinstall dnsmasq: sudo apt-get install --reinstall dnsmasq"
    echo "   - Restart networking: sudo systemctl restart networking"
    echo ""
    echo "Backed up configuration: /etc/pihole.bak"
    echo "Installation log: $LOG_FILE"
    echo "Previous backups: /var/backups/pihole/"
    echo ""
}

################################################################################
# Main Uninstallation
################################################################################

main() {
    local keep_backup=false
    local force=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-backup)
                keep_backup=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    check_root
    
    # Confirmation prompt
    if [[ $force == false ]]; then
        echo -e "${RED}"
        echo "⚠️  WARNING: This will uninstall Pi-hole completely!"
        echo -e "${NC}"
        echo "This will:"
        echo "  • Stop all Pi-hole services"
        echo "  • Remove Pi-hole installation files"
        echo "  • Delete Pi-hole configuration"
        echo "  • Remove the pihole system user"
        echo "  • Restore original dnsmasq configuration"
        echo ""
        echo "Your network may lose DNS resolution until you update DNS settings!"
        echo ""
        read -p "Are you sure you want to uninstall Pi-hole? (yes/NO): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Uninstallation cancelled"
            exit 0
        fi
    fi
    
    log_info "Starting Pi-hole uninstallation..."
    echo ""
    
    # Create final backup
    create_final_backup
    echo ""
    
    # Stop services
    stop_services
    echo ""
    
    # Disable services
    disable_services
    echo ""
    
    # Remove files
    remove_pihole_files
    echo ""
    
    # Remove scripts
    remove_custom_scripts
    echo ""
    
    # Remove user
    remove_pihole_user
    echo ""
    
    # Restore original config
    restore_original_dnsmasq
    echo ""
    
    # Remove cron jobs
    remove_cron_jobs
    echo ""
    
    # Verify
    verify_uninstall
    echo ""
    
    # Cleanup backups if requested
    if [[ $keep_backup == false ]]; then
        read -p "Delete backup directory? (yes/NO): " -r
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            if [[ -d /var/backups/pihole ]]; then
                rm -rf /var/backups/pihole
                log_success "Backup directory deleted"
            fi
        fi
    fi
    
    echo ""
    log_success "Uninstallation completed successfully!"
    print_restoration_info
}

# Run main function
main "$@"
