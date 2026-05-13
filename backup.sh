#!/bin/bash

################################################################################
# Pi-hole Backup and Restore Script
# Backup Pi-hole configuration or restore from backup
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BACKUP_DIR="${BACKUP_DIR:-/var/backups/pihole}"
LOG_FILE="/var/log/pihole-backup.log"

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
  backup                Create a backup of Pi-hole configuration
  restore <file>        Restore Pi-hole configuration from backup
  list                  List all available backups
  delete <file>         Delete a specific backup
  purge                 Delete all backups
  export <file>         Export backup to external location
  help                  Show this help message

Options:
  -d, --dir <path>      Custom backup directory (default: $BACKUP_DIR)
  -e, --exclude <dir>   Exclude directory from backup
  -v, --verbose         Verbose output

Examples:
  $0 backup
  $0 restore pihole-backup-20240115_143022.tar.gz
  $0 list
  $0 export pihole-backup-latest.tar.gz /mnt/external/

EOF
}

################################################################################
# Backup Functions
################################################################################

create_backup() {
    log_info "Creating Pi-hole backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/pihole-backup-$timestamp.tar.gz"
    
    # Items to backup
    local backup_items=(
        "/etc/pihole"
        "/etc/dnsmasq.d"
        "/var/www/html/admin"
        "/etc/lighttpd"
    )
    
    log_info "Backing up to: $backup_file"
    
    # Create backup
    if tar -czf "$backup_file" \
        --exclude='*.log' \
        --exclude='*.tmp' \
        --exclude='.git' \
        "${backup_items[@]}" 2>/dev/null; then
        
        local size=$(du -h "$backup_file" | cut -f1)
        log_success "Backup created successfully ($size)"
        
        # Create symlink to latest backup
        ln -sf "$backup_file" "$BACKUP_DIR/pihole-backup-latest.tar.gz"
        
        echo "$backup_file"
        return 0
    else
        log_error "Backup creation failed"
        return 1
    fi
}

restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_warn "This will overwrite your current Pi-hole configuration"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY == "yes" ]]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    log_info "Restoring backup: $backup_file"
    
    # Stop services
    log_info "Stopping services..."
    systemctl stop pihole-FTL 2>/dev/null || true
    systemctl stop dnsmasq 2>/dev/null || true
    systemctl stop lighttpd 2>/dev/null || true
    
    # Create pre-restore backup
    log_info "Creating pre-restore backup..."
    create_backup > /dev/null
    
    # Extract backup
    if tar -xzf "$backup_file" -C / 2>/dev/null; then
        log_success "Backup extracted"
        
        # Set permissions
        chown -R pihole:pihole /etc/pihole 2>/dev/null || true
        chown -R www-data:www-data /var/www/html/admin 2>/dev/null || true
        
        # Restart services
        log_info "Restarting services..."
        systemctl start dnsmasq 2>/dev/null || true
        systemctl start lighttpd 2>/dev/null || true
        sleep 2
        systemctl start pihole-FTL 2>/dev/null || true
        
        log_success "Restore completed successfully"
        return 0
    else
        log_error "Failed to extract backup"
        
        # Try to restart services anyway
        systemctl start dnsmasq 2>/dev/null || true
        systemctl start lighttpd 2>/dev/null || true
        systemctl start pihole-FTL 2>/dev/null || true
        
        return 1
    fi
}

list_backups() {
    log_info "Available backups:"
    echo ""
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_warn "No backup directory found"
        return 0
    fi
    
    local count=0
    while IFS= read -r file; do
        local size=$(du -h "$file" | cut -f1)
        local date=$(stat -c %y "$file" | cut -d' ' -f1,2)
        echo "  $(basename "$file") [$size] - Modified: $date"
        ((count++))
    done < <(find "$BACKUP_DIR" -name "pihole-backup-*.tar.gz" -type f | sort -r)
    
    if [[ $count -eq 0 ]]; then
        log_warn "No backups found"
    else
        echo ""
        log_success "Total backups: $count"
    fi
}

delete_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    read -p "Delete backup $(basename "$backup_file")? (yes/no): " -r
    if [[ ! $REPLY == "yes" ]]; then
        log_info "Deletion cancelled"
        return 0
    fi
    
    if rm "$backup_file"; then
        log_success "Backup deleted: $(basename "$backup_file")"
        return 0
    else
        log_error "Failed to delete backup"
        return 1
    fi
}

purge_backups() {
    log_warn "This will delete ALL backups"
    read -p "Are you sure? (yes/no): " -r
    if [[ ! $REPLY == "yes" ]]; then
        log_info "Purge cancelled"
        return 0
    fi
    
    if [[ -d "$BACKUP_DIR" ]]; then
        local count=$(find "$BACKUP_DIR" -name "pihole-backup-*.tar.gz" -type f | wc -l)
        rm -rf "$BACKUP_DIR"/pihole-backup-*.tar.gz
        log_success "Deleted $count backups"
    else
        log_warn "No backup directory found"
    fi
}

export_backup() {
    local backup_file="$1"
    local export_path="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    if [[ ! -d "$export_path" ]]; then
        log_error "Export path does not exist: $export_path"
        return 1
    fi
    
    local filename=$(basename "$backup_file")
    log_info "Exporting backup to: $export_path/$filename"
    
    if cp "$backup_file" "$export_path/$filename"; then
        log_success "Backup exported successfully"
        return 0
    else
        log_error "Failed to export backup"
        return 1
    fi
}

################################################################################
# Maintenance Functions
################################################################################

cleanup_old_backups() {
    local max_backups="${1:-7}"
    
    log_info "Cleaning up old backups (keeping last $max_backups)..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        return 0
    fi
    
    local count=$(find "$BACKUP_DIR" -name "pihole-backup-*.tar.gz" -type f | wc -l)
    if [[ $count -gt $max_backups ]]; then
        find "$BACKUP_DIR" -name "pihole-backup-*.tar.gz" -type f | sort -r | tail -n +$((max_backups + 1)) | xargs rm -f
        log_success "Cleaned up $((count - max_backups)) old backups"
    fi
}

show_backup_info() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    echo ""
    echo "Backup Information:"
    echo "  File: $(basename "$backup_file")"
    echo "  Size: $(du -h "$backup_file" | cut -f1)"
    echo "  Created: $(stat -c %y "$backup_file" | cut -d' ' -f1,2)"
    echo "  Contents:"
    tar -tzf "$backup_file" | head -20 | sed 's/^/    /'
    echo ""
}

################################################################################
# Main Functions
################################################################################

main() {
    local command="${1:-help}"
    
    check_root
    
    case "$command" in
        backup)
            create_backup
            ;;
        restore)
            if [[ $# -lt 2 ]]; then
                log_error "Restore requires a backup file argument"
                show_usage
                exit 1
            fi
            restore_backup "$2"
            ;;
        list)
            list_backups
            ;;
        delete)
            if [[ $# -lt 2 ]]; then
                log_error "Delete requires a backup file argument"
                show_usage
                exit 1
            fi
            delete_backup "$2"
            ;;
        purge)
            purge_backups
            ;;
        export)
            if [[ $# -lt 3 ]]; then
                log_error "Export requires backup file and destination path"
                show_usage
                exit 1
            fi
            export_backup "$2" "$3"
            ;;
        cleanup)
            cleanup_old_backups "${2:-7}"
            ;;
        info)
            if [[ $# -lt 2 ]]; then
                log_error "Info requires a backup file argument"
                show_usage
                exit 1
            fi
            show_backup_info "$2"
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
}

# Run main function
main "$@"
