#!/bin/bash

################################################################################
# Pi-hole Update and Maintenance Script
# Update Pi-hole and perform system maintenance
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_FILE="/var/log/pihole-maintenance.log"

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
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  system          Update system packages only
  gravity         Update gravity database (blocklists)
  pihole          Update Pi-hole to latest version
  all             Update everything (system + gravity + Pi-hole)
  cleanup         Clean logs and temporary files
  optimize        Optimize system performance
  verify          Verify all services are running
  help            Show this help message

Options:
  --backup        Create backup before updating (recommended)
  --no-restart    Don't restart services after update
  -y, --yes       Skip confirmation prompts

Examples:
  $0 gravity --backup
  $0 all --backup -y
  $0 system
  $0 cleanup

EOF
}

################################################################################
# System Update
################################################################################

update_system() {
    log_info "Updating system packages..."
    
    apt-get update || {
        log_error "Failed to update package list"
        return 1
    }
    
    # List available updates
    local updates=$(apt-get upgrade -s | grep -c "^Inst" || echo "0")
    
    if [[ $updates -gt 0 ]]; then
        log_info "Found $updates package updates available"
        
        DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || {
            log_error "Failed to upgrade packages"
            return 1
        }
        
        log_success "System packages updated ($updates packages)"
    else
        log_success "System is up to date"
    fi
    
    # Check for packages that need autoremove
    local autoremove_count=$(apt-get autoremove -s | grep -c "^Remv" || echo "0")
    if [[ $autoremove_count -gt 0 ]]; then
        log_info "Cleaning up $autoremove_count unused packages"
        apt-get autoremove -y >/dev/null 2>&1 || true
    fi
}

################################################################################
# Gravity Update
################################################################################

update_gravity() {
    log_info "Updating gravity database..."
    
    if [[ ! -f /usr/local/bin/gravity.sh ]]; then
        log_warn "Gravity update script not found"
        log_info "You can manually update from web interface: Tools → Update Gravity"
        return 1
    fi
    
    if /usr/local/bin/gravity.sh >/dev/null 2>&1; then
        log_success "Gravity database updated"
        
        # Restart services to load new lists
        log_info "Restarting services..."
        systemctl restart pihole-FTL 2>/dev/null || true
        systemctl restart dnsmasq 2>/dev/null || true
        
        log_success "Services restarted"
        return 0
    else
        log_error "Failed to update gravity database"
        return 1
    fi
}

################################################################################
# Pi-hole Update
################################################################################

update_pihole() {
    log_info "Checking for Pi-hole updates..."
    
    if [[ ! -d /opt/pihole ]]; then
        log_error "Pi-hole installation not found"
        return 1
    fi
    
    cd /opt/pihole || {
        log_error "Cannot access Pi-hole directory"
        return 1
    }
    
    # Check for updates
    git fetch origin >/dev/null 2>&1 || {
        log_warn "Cannot fetch from git repository"
        return 1
    }
    
    local current=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local latest=$(git rev-parse origin/master 2>/dev/null || echo "unknown")
    
    if [[ "$current" == "$latest" ]]; then
        log_success "Pi-hole is already at the latest version"
        return 0
    fi
    
    log_warn "New Pi-hole version available"
    log_info "Current: $current"
    log_info "Latest: $latest"
    
    # Pull latest version
    log_info "Pulling latest Pi-hole code..."
    git pull origin master || {
        log_error "Failed to pull latest code"
        return 1
    }
    
    log_success "Pi-hole updated successfully"
    
    # Restart FTL to use updated code
    log_info "Restarting Pi-hole FTL..."
    systemctl restart pihole-FTL 2>/dev/null || log_warn "Failed to restart FTL"
    
    return 0
}

################################################################################
# Backup Before Update
################################################################################

backup_before_update() {
    log_info "Creating backup before update..."
    
    if command -v /usr/local/bin/pihole-backup.sh &>/dev/null; then
        /usr/local/bin/pihole-backup.sh || {
            log_warn "Backup script failed, continuing anyway"
            return 1
        }
        log_success "Backup created"
        return 0
    else
        log_warn "Backup script not found"
        return 1
    fi
}

################################################################################
# Log Cleanup
################################################################################

cleanup_logs() {
    log_info "Cleaning up logs..."
    
    local cleaned=0
    
    # Compress old dnsmasq logs
    if [[ -f /var/log/dnsmasq.log ]]; then
        local size=$(du -h /var/log/dnsmasq.log | cut -f1)
        if [[ $(stat -c%s /var/log/dnsmasq.log) -gt 104857600 ]]; then # 100MB
            log_info "Compressing large dnsmasq log ($size)"
            gzip -f /var/log/dnsmasq.log
            touch /var/log/dnsmasq.log
            ((cleaned++))
        fi
    fi
    
    # Clean FTL logs
    if [[ -d /var/log/pihole ]]; then
        find /var/log/pihole -type f -mtime +30 -delete 2>/dev/null || true
        ((cleaned++))
    fi
    
    # Clean lighttpd logs
    find /var/log/lighttpd -type f -mtime +30 -delete 2>/dev/null || true
    
    log_success "Log cleanup completed"
}

################################################################################
# Temporary File Cleanup
################################################################################

cleanup_tempfiles() {
    log_info "Cleaning temporary files..."
    
    # Clean package cache
    apt-get clean >/dev/null 2>&1 || true
    
    # Clean partial downloads
    apt-get autoclean >/dev/null 2>&1 || true
    
    # Clean systemd journal (keep 2 weeks)
    journalctl --vacuum=weeks=2 >/dev/null 2>&1 || true
    
    log_success "Temporary files cleaned"
}

################################################################################
# Disk Space Optimization
################################################################################

optimize_system() {
    log_info "Optimizing system..."
    
    # Update locate database if it exists
    if command -v updatedb &>/dev/null; then
        log_info "Updating file database..."
        updatedb >/dev/null 2>&1 || true
    fi
    
    # Optimize dnsmasq performance
    log_info "Optimizing dnsmasq cache..."
    
    # Already configured by setup script, just verify
    if grep -q "cache-size=10000" /etc/dnsmasq.d/05-pihole-performance.conf 2>/dev/null; then
        log_success "dnsmasq cache optimization verified"
    fi
    
    log_success "System optimization completed"
}

################################################################################
# Service Verification
################################################################################

verify_services() {
    log_info "Verifying services..."
    
    local failed=0
    
    for service in "dnsmasq" "lighttpd" "pihole-FTL"; do
        if systemctl is-active --quiet "$service"; then
            log_success "$service is running"
        else
            log_error "$service is NOT running"
            ((failed++))
        fi
    done
    
    # Test DNS
    if dig +short @127.0.0.1 google.com >/dev/null 2>&1; then
        log_success "DNS resolution working"
    else
        log_error "DNS resolution failed"
        ((failed++))
    fi
    
    if [[ $failed -eq 0 ]]; then
        log_success "All services verified"
        return 0
    else
        log_error "Some services are not working properly"
        return 1
    fi
}

################################################################################
# Restart Services
################################################################################

restart_services() {
    log_info "Restarting services..."
    
    systemctl restart dnsmasq || log_warn "Failed to restart dnsmasq"
    sleep 1
    systemctl restart lighttpd || log_warn "Failed to restart lighttpd"
    sleep 1
    systemctl restart pihole-FTL || log_warn "Failed to restart pihole-FTL"
    
    sleep 2
    
    log_success "Services restarted"
}

################################################################################
# Health Report
################################################################################

print_health_report() {
    log_info "Generating health report..."
    echo ""
    
    # Disk space
    local disk=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
    echo "Disk Usage: ${disk}%"
    
    # Memory
    local mem=$(free | grep Mem | awk '{printf("%.0f", $3/$2*100)}')
    echo "Memory Usage: ${mem}%"
    
    # Uptime
    echo "Uptime: $(uptime -p)"
    
    # Service status
    for service in "dnsmasq" "lighttpd" "pihole-FTL"; do
        local status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
        echo "  $service: $status"
    done
    
    echo ""
}

################################################################################
# Main Functions
################################################################################

main() {
    local command="${1:-help}"
    local backup_first=false
    local no_restart=false
    local skip_confirm=false
    
    # Parse options
    shift 2>/dev/null || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backup)
                backup_first=true
                shift
                ;;
            --no-restart)
                no_restart=true
                shift
                ;;
            -y|--yes)
                skip_confirm=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    check_root
    
    # Confirmation for non-help commands
    if [[ $command != "help" && $command != "verify" ]] && [[ $skip_confirm == false ]]; then
        echo "This will update Pi-hole and system packages."
        echo "Your DNS service may be briefly unavailable."
        read -p "Continue? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Update cancelled"
            exit 0
        fi
    fi
    
    # Create backup if requested
    if [[ $backup_first == true ]]; then
        backup_before_update
        echo ""
    fi
    
    case "$command" in
        system)
            update_system
            ;;
        gravity)
            update_gravity
            ;;
        pihole)
            update_pihole
            ;;
        all)
            update_system
            echo ""
            update_gravity
            echo ""
            update_pihole
            ;;
        cleanup)
            cleanup_logs
            cleanup_tempfiles
            ;;
        optimize)
            optimize_system
            ;;
        verify)
            verify_services
            print_health_report
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
    
    # Restart services if not disabled
    if [[ $no_restart == false ]] && [[ $command != "help" ]] && [[ $command != "verify" ]] && [[ $command != "cleanup" ]]; then
        echo ""
        restart_services
    fi
    
    # Final verification
    if [[ $command != "help" ]]; then
        echo ""
        verify_services
        print_health_report
    fi
    
    log_success "Maintenance completed!"
}

# Run main function
main "$@"
