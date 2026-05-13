#!/bin/bash

################################################################################
# Pi-hole Health Check and Maintenance Script
# Monitor Pi-hole status, performance, and system health
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

status_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

status_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

status_error() {
    echo -e "${RED}✗${NC} $1"
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

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
}

################################################################################
# System Health Checks
################################################################################

check_system_resources() {
    print_section "System Resources"
    
    # Check CPU temperature
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((temp / 1000))
        echo "  CPU Temperature: ${temp}°C" 
        if [[ $temp -gt 80 ]]; then
            status_error "High CPU temperature (>80°C)"
        elif [[ $temp -gt 60 ]]; then
            status_warn "CPU temperature is elevated"
        else
            status_ok "CPU temperature normal"
        fi
    fi
    
    # Check CPU load
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
    echo "  CPU Load Average: $load"
    local cpu_count=$(nproc)
    local load_pct=$(echo "$load * 100 / $cpu_count" | bc)
    if (( $(echo "$load > $cpu_count * 1.5" | bc -l) )); then
        status_error "High CPU load"
    elif (( $(echo "$load > $cpu_count" | bc -l) )); then
        status_warn "CPU load is elevated"
    else
        status_ok "CPU load normal"
    fi
    
    # Check memory
    local mem_info=$(free | grep Mem)
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_pct=$((mem_used * 100 / mem_total))
    echo "  Memory Usage: ${mem_used}MB / ${mem_total}MB (${mem_pct}%)"
    if [[ $mem_pct -gt 90 ]]; then
        status_error "Critical memory usage (>90%)"
    elif [[ $mem_pct -gt 75 ]]; then
        status_warn "Memory usage high (>75%)"
    else
        status_ok "Memory usage normal"
    fi
    
    # Check swap
    local swap_info=$(free | grep Swap)
    local swap_total=$(echo $swap_info | awk '{print $2}')
    local swap_used=$(echo $swap_info | awk '{print $3}')
    if [[ $swap_used -gt 0 ]]; then
        status_warn "Swap is being used (${swap_used}MB/${swap_total}MB)"
    else
        status_ok "No swap usage"
    fi
}

check_disk_space() {
    print_section "Disk Space"
    
    local df_output=$(df -h / | tail -1)
    local total=$(echo $df_output | awk '{print $2}')
    local used=$(echo $df_output | awk '{print $3}')
    local available=$(echo $df_output | awk '{print $4}')
    local percent=$(echo $df_output | awk '{print $5}' | tr -d '%')
    
    echo "  Root Filesystem: $used / $total (${percent}% used)"
    
    if [[ $percent -gt 90 ]]; then
        status_error "Critical disk usage (>90%)"
    elif [[ $percent -gt 75 ]]; then
        status_warn "Disk usage high (>75%)"
    else
        status_ok "Disk space available"
    fi
    
    # Check specific directories
    echo ""
    echo "  Directory Sizes:"
    
    for dir in "/opt/pihole" "/etc/pihole" "/var/log/pihole" "/var/backups/pihole"; do
        if [[ -d "$dir" ]]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "    $dir: $size"
        fi
    done
}

################################################################################
# Service Checks
################################################################################

check_services() {
    print_section "Service Status"
    
    local services=("dnsmasq" "lighttpd" "pihole-FTL")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            status_ok "$service is running"
        else
            status_error "$service is NOT running"
        fi
    done
}

check_dns_functionality() {
    print_section "DNS Functionality"
    
    # Test DNS locally
    if dig +short @127.0.0.1 google.com &>/dev/null; then
        status_ok "Local DNS resolution working"
    else
        status_error "Local DNS resolution failed"
    fi
    
    # Test external DNS
    if dig +short @8.8.8.8 google.com &>/dev/null; then
        status_ok "External DNS (8.8.8.8) reachable"
    else
        status_warn "External DNS (8.8.8.8) not reachable"
    fi
    
    # Check dnsmasq listening
    if netstat -tlnp 2>/dev/null | grep -q "53.*dnsmasq"; then
        status_ok "dnsmasq listening on port 53"
    else
        status_error "dnsmasq not listening on port 53"
    fi
}

check_web_interface() {
    print_section "Web Interface"
    
    # Check Lighttpd listening
    if netstat -tlnp 2>/dev/null | grep -q "80.*lighttpd"; then
        status_ok "Lighttpd listening on port 80"
    else
        status_error "Lighttpd not listening on port 80"
    fi
    
    # Test HTTP connectivity
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/admin/ | grep -q "200\|403"; then
        status_ok "Web interface responding"
    else
        status_warn "Web interface not responding properly"
    fi
    
    echo "  Access at: http://$(get_local_ip)/admin"
}

################################################################################
# Statistics
################################################################################

show_statistics() {
    print_section "Pi-hole Statistics"
    
    if [[ ! -f /etc/pihole/gravity.db ]]; then
        log_warn "Gravity database not found"
        return 1
    fi
    
    # Total queries
    local total_queries=$(sqlite3 /etc/pihole/gravity.db \
        "SELECT COUNT(*) FROM queries;" 2>/dev/null || echo "0")
    echo "  Total Queries: $total_queries"
    
    # Blocked queries
    local blocked_queries=$(sqlite3 /etc/pihole/gravity.db \
        "SELECT COUNT(*) FROM queries WHERE status=1;" 2>/dev/null || echo "0")
    echo "  Blocked Queries: $blocked_queries"
    
    if [[ $total_queries -gt 0 ]]; then
        local block_pct=$((blocked_queries * 100 / total_queries))
        echo "  Block Rate: ${block_pct}%"
    fi
    
    # Top blocked domains
    echo ""
    echo "  Top 5 Blocked Domains:"
    sqlite3 /etc/pihole/gravity.db \
        "SELECT domain, COUNT(*) as count FROM queries \
         WHERE status=1 GROUP BY domain ORDER BY count DESC LIMIT 5;" 2>/dev/null | \
        while read -r line; do
            local domain=$(echo "$line" | cut -d'|' -f1)
            local count=$(echo "$line" | cut -d'|' -f2)
            echo "    • $domain: $count"
        done
    
    # Top queried domains
    echo ""
    echo "  Top 5 Queried Domains:"
    sqlite3 /etc/pihole/gravity.db \
        "SELECT domain, COUNT(*) as count FROM queries \
         GROUP BY domain ORDER BY count DESC LIMIT 5;" 2>/dev/null | \
        while read -r line; do
            local domain=$(echo "$line" | cut -d'|' -f1)
            local count=$(echo "$line" | cut -d'|' -f2)
            echo "    • $domain: $count"
        done
    
    # Gravity database stats
    local adlist_count=$(sqlite3 /etc/pihole/gravity.db \
        "SELECT COUNT(*) FROM adlist;" 2>/dev/null || echo "0")
    echo ""
    echo "  Active Adlists: $adlist_count"
}

################################################################################
# Network Information
################################################################################

show_network_info() {
    print_section "Network Information"
    
    local ip=$(get_local_ip)
    echo "  Pi-hole IP Address: $ip"
    
    # Get gateway
    local gateway=$(ip route | grep default | awk '{print $3}')
    echo "  Gateway: $gateway"
    
    # Get DNS servers
    echo "  Configured DNS Servers:"
    if [[ -f /etc/pihole/upstream.conf ]]; then
        grep "^server=" /etc/pihole/upstream.conf | head -3 | sed 's/server=/    • /'
    fi
    
    # Network interfaces
    echo ""
    echo "  Network Interfaces:"
    ip link show | grep "^[0-9]" | awk '{print $2}' | while read -r iface; do
        iface=${iface%:}
        local addr=$(ip addr show "$iface" | grep "inet " | awk '{print $2}')
        if [[ -n "$addr" ]]; then
            echo "    • $iface: $addr"
        fi
    done
}

################################################################################
# Log Analysis
################################################################################

analyze_logs() {
    print_section "Log Analysis"
    
    if [[ -f /var/log/dnsmasq.log ]]; then
        local lines=$(wc -l < /var/log/dnsmasq.log)
        echo "  dnsmasq log size: $(du -h /var/log/dnsmasq.log | cut -f1) ($lines lines)"
        
        # Recent errors
        local errors=$(grep -i "error" /var/log/dnsmasq.log | wc -l)
        if [[ $errors -gt 0 ]]; then
            status_warn "$errors errors in recent logs"
        else
            status_ok "No errors in recent logs"
        fi
    fi
    
    if [[ -f /var/log/lighttpd/error.log ]]; then
        local size=$(du -h /var/log/lighttpd/error.log | cut -f1)
        echo "  Lighttpd error log: $size"
    fi
}

################################################################################
# Recommendations
################################################################################

show_recommendations() {
    print_section "Recommendations"
    
    local recommendations=0
    
    # Check backups
    if [[ ! -d /var/backups/pihole ]] || [[ -z "$(find /var/backups/pihole -name '*.tar.gz' -type f -newermt '1 day ago' 2>/dev/null)" ]]; then
        log_warn "No recent backup found. Run: sudo ./backup.sh backup"
        ((recommendations++))
    fi
    
    # Check gravity updates
    if [[ -f /etc/pihole/gravity.db ]]; then
        local db_age=$(find /etc/pihole/gravity.db -mtime +7 2>/dev/null)
        if [[ -n "$db_age" ]]; then
            log_warn "Gravity database is older than 7 days. Run: sudo /usr/local/bin/gravity.sh"
            ((recommendations++))
        fi
    fi
    
    # Check log rotation
    local log_size=$(du -sh /var/log/pihole 2>/dev/null | cut -f1 | tr -d 'M')
    if [[ $log_size -gt 500 ]]; then
        log_warn "Pihole logs are large (>500MB). Consider cleaning old logs."
        ((recommendations++))
    fi
    
    if [[ $recommendations -eq 0 ]]; then
        status_ok "No recommendations at this time"
    fi
}

################################################################################
# Performance Report
################################################################################

show_performance_report() {
    print_section "Performance Report"
    
    local uptime=$(uptime -p)
    echo "  System Uptime: $uptime"
    
    local boot_time=$(systemctl show -p ActiveEnterTimestampMonotonic --value | xargs -I {} expr {} / 1000000000)
    echo "  Boot Time: $(date -d @$boot_time +%Y-%m-%d\ %H:%M:%S)"
    
    # Service runtimes
    for service in "dnsmasq" "lighttpd"; do
        local active_time=$(systemctl show -p ActiveEnterTimestamp "$service" --value)
        echo "  $service started: $active_time"
    done
}

################################################################################
# Main Report
################################################################################

generate_full_report() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║          Pi-hole Health Check & Status Report                 ║
║                                                                ║
EOF
    echo "║  Generated: $(date '+%Y-%m-%d %H:%M:%S')                          ║"
    echo "║  Hostname: $(hostname | cut -c1-50)$(printf '%*s' $((50-${#HOSTNAME})) | tr ' ' ' ')║"
    cat << 'EOF'
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_system_resources
    check_disk_space
    check_services
    check_dns_functionality
    check_web_interface
    show_network_info
    analyze_logs
    show_statistics
    show_performance_report
    show_recommendations
    
    print_section "Report Complete"
    echo ""
}

################################################################################
# Quick Status
################################################################################

show_quick_status() {
    echo -e "${BLUE}Pi-hole Status$(NC)"
    echo ""
    
    # Services
    for service in "dnsmasq" "lighttpd" "pihole-FTL"; do
        if systemctl is-active --quiet "$service"; then
            echo -e "  ${GREEN}✓${NC} $service"
        else
            echo -e "  ${RED}✗${NC} $service"
        fi
    done
    
    # System resources
    local mem_pct=$(free | grep Mem | awk '{printf("%.0f", $3/$2*100)}')
    local disk_pct=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
    
    echo ""
    echo "  Memory: ${mem_pct}%  Disk: ${disk_pct}%"
    echo "  IP: $(get_local_ip)"
    echo "  URL: http://$(get_local_ip)/admin"
}

################################################################################
# Main Function
################################################################################

show_usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
  status          Quick status overview
  full            Generate full health report
  resources       Check system resources
  disk            Check disk space
  services        Check service status
  dns             Check DNS functionality
  web             Check web interface
  network         Show network information
  logs            Analyze logs
  stats           Show Pi-hole statistics
  recommendations Show maintenance recommendations
  help            Show this help message

Examples:
  $0 status
  $0 full
  $0 resources

EOF
}

main() {
    local command="${1:-status}"
    
    check_root
    
    case "$command" in
        status|quick)
            show_quick_status
            ;;
        full|report)
            generate_full_report
            ;;
        resources)
            check_system_resources
            ;;
        disk)
            check_disk_space
            ;;
        services)
            check_services
            ;;
        dns)
            check_dns_functionality
            ;;
        web)
            check_web_interface
            ;;
        network)
            show_network_info
            ;;
        logs)
            analyze_logs
            ;;
        stats)
            show_statistics
            ;;
        recommendations|recommend)
            show_recommendations
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
    
    echo ""
}

# Run main function
main "$@"
