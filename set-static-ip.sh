#!/bin/bash

################################################################################
# Set Static IP Configuration on Raspberry Pi
# Configures eth0 to use static IP and reboots
################################################################################

set -euo pipefail

# Configuration
INTERFACE="netplan-eth0"
IP_ADDRESS="10.0.0.2/24"
GATEWAY="10.0.0.1"
DNS_SERVER="10.0.0.1"

echo "Setting static IP configuration..."
echo "Interface: $INTERFACE"
echo "IP Address: $IP_ADDRESS"
echo "Gateway: $GATEWAY"
echo "DNS: $DNS_SERVER"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Apply network configuration
sudo nmcli connection modify "$INTERFACE" \
  ipv4.addresses "$IP_ADDRESS" \
  ipv4.gateway "$GATEWAY" \
  ipv4.dns "$DNS_SERVER" \
  ipv4.method manual

echo "Configuration applied. Bringing connection up..."
sudo nmcli connection up "$INTERFACE"

echo "Verifying network configuration..."
nmcli device show eth0

echo ""
echo "Network configuration complete. Rebooting in 5 seconds..."
sleep 5

sudo reboot
