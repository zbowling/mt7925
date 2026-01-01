#!/bin/bash
#
# MT7925 Driver Monitor
#
# Monitors kernel logs in real-time for mt7925 driver issues.
# Useful to run alongside the stress test.
#
# Usage: sudo ./monitor.sh
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        MT7925 Driver Monitor                                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Show current status
echo -e "${GREEN}Current Kernel:${NC} $(uname -r)"
echo -e "${GREEN}Driver Version:${NC} $(modinfo mt7925e 2>/dev/null | grep -E "^version:" | awk '{print $2}' || echo 'unknown')"
echo ""

# Find WiFi interface
IFACE=$(ip link show | grep -oP 'wl\w+' | head -1 || echo "none")
echo -e "${GREEN}WiFi Interface:${NC} $IFACE"

if [[ "$IFACE" != "none" ]]; then
    CONN=$(iw dev "$IFACE" link 2>/dev/null | head -1 || echo "Not connected")
    echo -e "${GREEN}Connection:${NC} $CONN"
fi

echo ""
echo -e "${YELLOW}Monitoring kernel logs for mt7925 events...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""
echo "─────────────────────────────────────────────────────────────────"

# Follow dmesg for mt7925 related messages
dmesg -wH 2>/dev/null | while IFS= read -r line; do
    if echo "$line" | grep -qiE "mt7925|mt76|mt792x|wlan|wifi"; then
        # Color based on severity
        if echo "$line" | grep -qiE "error|fail|bug|null|panic|oops"; then
            echo -e "${RED}$line${NC}"
        elif echo "$line" | grep -qiE "warn"; then
            echo -e "${YELLOW}$line${NC}"
        else
            echo -e "${GREEN}$line${NC}"
        fi
    fi
done

