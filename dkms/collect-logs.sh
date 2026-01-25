#!/bin/bash
# MT7925 Debug Log Collector
# Collects all relevant logs for bug reports

OUTPUT_FILE="mt7925-debug-$(date +%Y%m%d-%H%M%S).txt"

echo "MT7925 Debug Log Collection"
echo "==========================="
echo ""
echo "Collecting system information..."

{
    echo "# MT7925 Debug Report"
    echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""

    echo "## System Information"
    echo '```'
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Distro: $(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep ^PRETTY_NAME | cut -d'"' -f2)"
    echo '```'
    echo ""

    echo "## Hardware"
    echo '```'
    lspci -nnk | grep -A3 -i "network\|wifi\|wireless" 2>/dev/null || echo "No PCI WiFi found"
    echo '```'
    echo ""

    echo "## DKMS Status"
    echo '```'
    dkms status 2>/dev/null || echo "DKMS not installed"
    echo '```'
    echo ""

    echo "## Loaded Modules"
    echo '```'
    lsmod | grep -E "mt76|mt792|mt7925" || echo "No mt76 modules loaded"
    echo '```'
    echo ""

    echo "## Module Info"
    echo '```'
    modinfo mt7925e 2>/dev/null | head -20 || echo "mt7925e module not found"
    echo '```'
    echo ""

    echo "## WiFi Interfaces"
    echo '```'
    ip link show 2>/dev/null | grep -E "wlan|wlp" || echo "No WiFi interfaces"
    iw dev 2>/dev/null || echo "iw not available"
    echo '```'
    echo ""

    echo "## Kernel Messages (mt76 related, last 200 lines)"
    echo '```'
    dmesg 2>/dev/null | grep -iE "mt76|mt792|mt7925|mt7921|wlan|wifi" | tail -200 || \
    journalctl -k -b 2>/dev/null | grep -iE "mt76|mt792|mt7925|mt7921|wlan|wifi" | tail -200 || \
    echo "Cannot read kernel logs (try with sudo)"
    echo '```'
    echo ""

    echo "## Recent Errors"
    echo '```'
    dmesg 2>/dev/null | grep -iE "error|fail|null|bug|oops|panic" | grep -iE "mt76|mt792|wifi|wlan" | tail -50 || echo "No errors found"
    echo '```'
    echo ""

    echo "## Firmware Files"
    echo '```'
    ls -la /lib/firmware/mediatek/mt7925* /lib/firmware/mediatek/mt7921* 2>/dev/null || echo "No MT7925/MT7921 firmware found"
    echo '```'

} > "$OUTPUT_FILE"

echo ""
echo "Done! Log saved to: $OUTPUT_FILE"
echo ""
echo "To report an issue:"
echo "1. Go to: https://github.com/zbowling/mt7925/issues/new"
echo "2. Copy the contents of $OUTPUT_FILE into the issue"
echo ""
echo "--- Preview (first 50 lines) ---"
head -50 "$OUTPUT_FILE"
echo "..."
echo "--- End Preview ---"
