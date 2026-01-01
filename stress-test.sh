#!/bin/bash
#
# MT7925 WiFi Driver Stress Test
# 
# This script attempts to trigger race conditions and NULL pointer dereferences
# in the mt7925 driver by simulating various roaming and connection scenarios.
#
# WARNING: This may cause kernel panics on unpatched kernels!
#
# Usage: sudo ./stress-test.sh [OPTIONS]
#
# Options:
#   -i, --interface IFACE   WiFi interface (default: auto-detect)
#   -s, --ssid SSID         Target SSID for connection tests
#   -p, --password PASS     WiFi password
#   -d, --duration SECS     Test duration in seconds (default: 300)
#   -t, --test TEST         Run specific test: all|roam|reconnect|suspend|scan
#   -v, --verbose           Verbose output
#   -l, --log FILE          Log file (default: /tmp/mt7925-stress.log)
#   --dry-run               Show what would be done without executing
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Defaults
INTERFACE=""
SSID=""
PASSWORD=""
DURATION=300
TEST_TYPE="all"
VERBOSE=false
LOG_FILE="/tmp/mt7925-stress.log"
DRY_RUN=false
ITERATION=0
ERRORS=0
START_TIME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -s|--ssid)
            SSID="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -t|--test)
            TEST_TYPE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            head -30 "$0" | tail -25
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  color="$GREEN" ;;
        WARN)  color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        DEBUG) color="$BLUE" ;;
        *)     color="$NC" ;;
    esac
    
    echo -e "${color}[$timestamp] [$level]${NC} $msg" | tee -a "$LOG_FILE"
}

debug() {
    if $VERBOSE; then
        log DEBUG "$@"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This script must be run as root"
        exit 1
    fi
}

detect_interface() {
    if [[ -z "$INTERFACE" ]]; then
        # Find mt7925 interface
        INTERFACE=$(ip link show | grep -oP 'wl\w+' | head -1 || true)
        if [[ -z "$INTERFACE" ]]; then
            log ERROR "No WiFi interface found"
            exit 1
        fi
    fi
    
    # Verify it's an mt7925 device
    if ! lspci -k 2>/dev/null | grep -A3 "Network controller" | grep -qi "mt7925\|mediatek"; then
        log WARN "Interface $INTERFACE may not be mt7925 (continuing anyway)"
    fi
    
    log INFO "Using interface: $INTERFACE"
}

check_driver() {
    if ! lsmod | grep -q mt7925; then
        log ERROR "mt7925 driver not loaded"
        exit 1
    fi
    
    local kernel
    kernel=$(uname -r)
    log INFO "Kernel: $kernel"
    
    if [[ "$kernel" == *"mt7925-fix"* ]]; then
        log INFO "Running patched kernel ✓"
    else
        log WARN "Not running patched kernel - expect crashes!"
    fi
}

check_dmesg_errors() {
    local new_errors
    new_errors=$(dmesg | grep -ciE "mt7925.*error|mt76.*null|BUG:|kernel panic" 2>/dev/null || echo "0")
    
    if [[ "$new_errors" -gt 0 ]]; then
        log ERROR "Found $new_errors kernel errors related to mt7925!"
        dmesg | grep -iE "mt7925.*error|mt76.*null|BUG:" | tail -5 >> "$LOG_FILE"
        ((ERRORS++)) || true
    fi
}

get_current_bssid() {
    iw dev "$INTERFACE" link 2>/dev/null | grep -oP 'Connected to \K[0-9a-f:]+' || echo ""
}

get_available_bssids() {
    # Get all BSSIDs for the current SSID
    local ssid="$1"
    iw dev "$INTERFACE" scan 2>/dev/null | \
        awk -v ssid="$ssid" '
            /^BSS / { bssid=$2; sub(/\(.*/, "", bssid) }
            /SSID:/ { if ($2 == ssid) print bssid }
        ' | sort -u
}

# Test 1: Rapid scan cycles
test_scan_stress() {
    log INFO "=== Starting Scan Stress Test ==="
    local count=0
    local end_time=$((SECONDS + DURATION))
    
    while [[ $SECONDS -lt $end_time ]]; do
        ((count++)) || true
        debug "Scan iteration $count"
        
        if ! $DRY_RUN; then
            # Trigger scan
            iw dev "$INTERFACE" scan trigger 2>/dev/null || true
            sleep 0.5
            
            # Abort scan (can trigger race)
            iw dev "$INTERFACE" scan abort 2>/dev/null || true
            sleep 0.2
        fi
        
        check_dmesg_errors
        
        if ((count % 10 == 0)); then
            log INFO "Completed $count scan cycles"
        fi
    done
    
    log INFO "Scan stress test completed: $count iterations"
}

# Test 2: Connect/Disconnect cycles
test_reconnect_stress() {
    log INFO "=== Starting Reconnect Stress Test ==="
    
    if [[ -z "$SSID" ]]; then
        log ERROR "SSID required for reconnect test (-s option)"
        return 1
    fi
    
    local count=0
    local end_time=$((SECONDS + DURATION))
    
    while [[ $SECONDS -lt $end_time ]]; do
        ((count++)) || true
        debug "Reconnect iteration $count"
        
        if ! $DRY_RUN; then
            # Disconnect
            nmcli device disconnect "$INTERFACE" 2>/dev/null || true
            sleep 1
            
            # Quick reconnect (triggers vif_connect_iter)
            if [[ -n "$PASSWORD" ]]; then
                nmcli device wifi connect "$SSID" password "$PASSWORD" ifname "$INTERFACE" 2>/dev/null || true
            else
                nmcli device wifi connect "$SSID" ifname "$INTERFACE" 2>/dev/null || true
            fi
            sleep 2
        fi
        
        check_dmesg_errors
        
        if ((count % 5 == 0)); then
            log INFO "Completed $count reconnect cycles"
        fi
    done
    
    log INFO "Reconnect stress test completed: $count iterations"
}

# Test 3: BSSID roaming
test_roam_stress() {
    log INFO "=== Starting Roam Stress Test ==="
    
    if [[ -z "$SSID" ]]; then
        log ERROR "SSID required for roam test (-s option)"
        return 1
    fi
    
    # First, scan for available BSSIDs
    log INFO "Scanning for available BSSIDs..."
    
    if ! $DRY_RUN; then
        iw dev "$INTERFACE" scan 2>/dev/null || true
        sleep 3
    fi
    
    local bssids
    bssids=$(get_available_bssids "$SSID")
    local bssid_count
    bssid_count=$(echo "$bssids" | grep -c . || echo "0")
    
    if [[ "$bssid_count" -lt 2 ]]; then
        log WARN "Only $bssid_count BSSID(s) found for SSID '$SSID'"
        log WARN "Roaming test works best with multiple APs"
        
        if [[ "$bssid_count" -eq 0 ]]; then
            log ERROR "No BSSIDs found, cannot perform roam test"
            return 1
        fi
    fi
    
    log INFO "Found $bssid_count BSSID(s) for SSID '$SSID':"
    echo "$bssids" | while read -r bssid; do
        log INFO "  - $bssid"
    done
    
    local count=0
    local end_time=$((SECONDS + DURATION))
    
    while [[ $SECONDS -lt $end_time ]]; do
        for bssid in $bssids; do
            ((count++)) || true
            
            local current
            current=$(get_current_bssid)
            
            if [[ "$current" == "$bssid" ]]; then
                debug "Already connected to $bssid, skipping"
                continue
            fi
            
            log INFO "Roaming to BSSID: $bssid"
            
            if ! $DRY_RUN; then
                # Force roam using wpa_supplicant
                wpa_cli -i "$INTERFACE" roam "$bssid" 2>/dev/null || \
                    # Fallback: disconnect and reconnect to specific BSSID
                    nmcli device wifi connect "$SSID" bssid "$bssid" \
                        ${PASSWORD:+password "$PASSWORD"} ifname "$INTERFACE" 2>/dev/null || true
                
                sleep 3
            fi
            
            check_dmesg_errors
            
            if [[ $SECONDS -ge $end_time ]]; then
                break
            fi
        done
        
        if ((count % 5 == 0)); then
            log INFO "Completed $count roam attempts"
        fi
    done
    
    log INFO "Roam stress test completed: $count iterations"
}

# Test 4: Suspend/Resume cycles
test_suspend_stress() {
    log INFO "=== Starting Suspend/Resume Stress Test ==="
    log WARN "This test will suspend your system multiple times!"
    
    local count=0
    local cycles=$((DURATION / 30))  # ~30 seconds per cycle
    
    if [[ $cycles -lt 1 ]]; then
        cycles=1
    fi
    
    log INFO "Will perform $cycles suspend/resume cycles"
    
    for ((i=1; i<=cycles; i++)); do
        ((count++)) || true
        log INFO "Suspend cycle $count/$cycles"
        
        if ! $DRY_RUN; then
            # Check connection before suspend
            local bssid_before
            bssid_before=$(get_current_bssid)
            debug "Connected to $bssid_before before suspend"
            
            # Suspend for 5 seconds
            rtcwake -m mem -s 5 2>/dev/null || \
                systemctl suspend 2>/dev/null || \
                pm-suspend 2>/dev/null || {
                    log ERROR "Failed to suspend system"
                    return 1
                }
            
            # Wait for system to fully resume
            sleep 5
            
            # Check connection after resume
            local bssid_after
            bssid_after=$(get_current_bssid)
            debug "Connected to $bssid_after after resume"
            
            if [[ -z "$bssid_after" ]]; then
                log WARN "Not connected after resume, waiting..."
                sleep 10
            fi
        fi
        
        check_dmesg_errors
    done
    
    log INFO "Suspend stress test completed: $count cycles"
}

# Test 5: Interface up/down cycles
test_interface_stress() {
    log INFO "=== Starting Interface Up/Down Stress Test ==="
    
    local count=0
    local end_time=$((SECONDS + DURATION))
    
    while [[ $SECONDS -lt $end_time ]]; do
        ((count++)) || true
        debug "Interface cycle $count"
        
        if ! $DRY_RUN; then
            # Bring interface down
            ip link set "$INTERFACE" down 2>/dev/null || true
            sleep 0.5
            
            # Bring interface up
            ip link set "$INTERFACE" up 2>/dev/null || true
            sleep 1
            
            # Trigger a scan (exercises driver paths)
            iw dev "$INTERFACE" scan trigger 2>/dev/null || true
            sleep 1
        fi
        
        check_dmesg_errors
        
        if ((count % 10 == 0)); then
            log INFO "Completed $count interface cycles"
        fi
    done
    
    log INFO "Interface stress test completed: $count iterations"
}

# Test 6: Combined stress test
test_combined_stress() {
    log INFO "=== Starting Combined Stress Test ==="
    
    local end_time=$((SECONDS + DURATION))
    local iteration=0
    
    while [[ $SECONDS -lt $end_time ]]; do
        ((iteration++)) || true
        
        # Rotate through different stress operations
        case $((iteration % 4)) in
            0)
                debug "Quick scan"
                if ! $DRY_RUN; then
                    iw dev "$INTERFACE" scan trigger 2>/dev/null || true
                    sleep 0.3
                fi
                ;;
            1)
                debug "Interface toggle"
                if ! $DRY_RUN; then
                    ip link set "$INTERFACE" down 2>/dev/null || true
                    sleep 0.2
                    ip link set "$INTERFACE" up 2>/dev/null || true
                    sleep 0.5
                fi
                ;;
            2)
                if [[ -n "$SSID" ]]; then
                    debug "Quick disconnect"
                    if ! $DRY_RUN; then
                        nmcli device disconnect "$INTERFACE" 2>/dev/null || true
                        sleep 0.5
                    fi
                fi
                ;;
            3)
                if [[ -n "$SSID" ]]; then
                    debug "Quick reconnect"
                    if ! $DRY_RUN; then
                        if [[ -n "$PASSWORD" ]]; then
                            nmcli device wifi connect "$SSID" password "$PASSWORD" ifname "$INTERFACE" 2>/dev/null || true
                        else
                            nmcli device wifi connect "$SSID" ifname "$INTERFACE" 2>/dev/null || true
                        fi
                        sleep 1
                    fi
                fi
                ;;
        esac
        
        check_dmesg_errors
        
        if ((iteration % 20 == 0)); then
            log INFO "Combined stress: $iteration iterations, $ERRORS errors"
        fi
    done
    
    log INFO "Combined stress test completed: $iteration iterations"
}

print_summary() {
    local elapsed=$((SECONDS - START_TIME))
    
    echo ""
    log INFO "=========================================="
    log INFO "          STRESS TEST SUMMARY"
    log INFO "=========================================="
    log INFO "Kernel: $(uname -r)"
    log INFO "Interface: $INTERFACE"
    log INFO "Duration: ${elapsed}s"
    log INFO "Total errors detected: $ERRORS"
    log INFO "Log file: $LOG_FILE"
    
    if [[ $ERRORS -gt 0 ]]; then
        log ERROR "⚠️  Errors were detected during testing!"
        log INFO "Check dmesg and $LOG_FILE for details"
    else
        log INFO "✅ No errors detected"
    fi
    
    echo ""
}

cleanup() {
    log INFO "Cleaning up..."
    
    # Ensure interface is up
    ip link set "$INTERFACE" up 2>/dev/null || true
    
    # Reconnect if we have credentials
    if [[ -n "$SSID" ]]; then
        if [[ -n "$PASSWORD" ]]; then
            nmcli device wifi connect "$SSID" password "$PASSWORD" ifname "$INTERFACE" 2>/dev/null || true
        else
            nmcli device wifi connect "$SSID" ifname "$INTERFACE" 2>/dev/null || true
        fi
    fi
    
    print_summary
}

main() {
    START_TIME=$SECONDS
    
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        MT7925 WiFi Driver Stress Test                        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Initialize log file
    echo "=== MT7925 Stress Test Started at $(date) ===" > "$LOG_FILE"
    
    if ! $DRY_RUN; then
        check_root
    fi
    
    detect_interface
    check_driver
    
    trap cleanup EXIT
    
    log INFO "Test type: $TEST_TYPE"
    log INFO "Duration: ${DURATION}s"
    log INFO "SSID: ${SSID:-<not set>}"
    
    if $DRY_RUN; then
        log WARN "DRY RUN MODE - no actual operations will be performed"
    fi
    
    echo ""
    
    case $TEST_TYPE in
        scan)
            test_scan_stress
            ;;
        reconnect)
            test_reconnect_stress
            ;;
        roam)
            test_roam_stress
            ;;
        suspend)
            test_suspend_stress
            ;;
        interface)
            test_interface_stress
            ;;
        combined)
            test_combined_stress
            ;;
        all)
            log INFO "Running all stress tests..."
            DURATION=$((DURATION / 5))
            test_scan_stress
            test_interface_stress
            test_reconnect_stress
            test_roam_stress
            test_combined_stress
            ;;
        *)
            log ERROR "Unknown test type: $TEST_TYPE"
            log INFO "Available: scan, reconnect, roam, suspend, interface, combined, all"
            exit 1
            ;;
    esac
}

main "$@"

