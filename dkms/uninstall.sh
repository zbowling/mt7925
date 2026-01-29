#!/bin/bash
# MT7925 DKMS Uninstaller
# Removes the patched MT7925 WiFi driver and restores stock modules

set -e

PACKAGE_NAME="mt76-mt7925"
PACKAGE_VERSION="1.5.0"

# Session tracking for telemetry (correlate start/end events)
SESSION_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N | sha256sum | head -c 32)
SESSION_START=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Telemetry config (shared with install.sh)
TELEMETRY_CONFIG="/etc/mt7925-telemetry.conf"
TELEMETRY_QUEUE="/var/lib/mt7925-telemetry-queue"

# Check if telemetry is enabled (opt-in)
check_telemetry_enabled() {
    # Environment variable override takes precedence
    if [[ -n "${MT7925_TELEMETRY:-}" ]]; then
        [[ "${MT7925_TELEMETRY}" == "1" ]] && return 0
        return 1
    fi

    # Check saved preference
    if [[ -f "$TELEMETRY_CONFIG" ]]; then
        local saved=$(cat "$TELEMETRY_CONFIG" 2>/dev/null)
        [[ "$saved" == "1" ]] && return 0
        return 1
    fi

    # No preference set - default to disabled
    return 1
}

# Wait for network connectivity (WiFi may take time to reconnect after module reload)
wait_for_network() {
    local max_wait="${1:-30}"
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        if curl -s --max-time 3 -o /dev/null "https://us.i.posthog.com/" 2>/dev/null; then
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
    done
    return 1
}

# Detect hardware details for telemetry
detect_hardware_info() {
    # Detect chip and bus type
    # PCIe devices (most common)
    if lspci -nn 2>/dev/null | grep -qi "14c3:7925"; then
        echo "mt7925:pcie"
    elif lspci -nn 2>/dev/null | grep -qi "14c3:7921"; then
        echo "mt7921:pcie"
    # USB devices
    elif lsusb 2>/dev/null | grep -qi "0e8d:7961"; then
        echo "mt7921:usb"
    # SDIO devices (check /sys/bus/sdio)
    elif [[ -d /sys/bus/sdio/devices ]] && ls /sys/bus/sdio/devices/*/modalias 2>/dev/null | xargs grep -l "sdio:c00v037Ad7901" >/dev/null 2>&1; then
        echo "mt7921:sdio"
    else
        echo "unknown:unknown"
    fi
}

# Detect if kernel uses clang
detect_uses_clang() {
    if grep -q "CONFIG_CC_IS_CLANG=y" "/lib/modules/$(uname -r)/build/.config" 2>/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

# Queue telemetry event for later sending
queue_telemetry() {
    local event="$1"
    local error_type="$2"
    local kernel="$3"
    local distro="$4"
    local hw_id="$5"
    local version="$6"
    local session_id="$7"
    local duration="$8"
    local chip="${9:-unknown}"
    local bus_type="${10:-unknown}"
    local uses_clang="${11:-false}"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    echo "{\"event\":\"${event}\",\"error_type\":\"${error_type}\",\"kernel\":\"${kernel}\",\"distro\":\"${distro}\",\"hardware\":\"${hw_id}\",\"version\":\"${version}\",\"session_id\":\"${session_id}\",\"duration_seconds\":${duration:-0},\"chip\":\"${chip}\",\"bus_type\":\"${bus_type}\",\"uses_clang\":${uses_clang},\"queued_at\":\"${timestamp}\"}" >> "$TELEMETRY_QUEUE" 2>/dev/null || true
}

# Send telemetry using PostHog (write-only API key, safe to embed)
send_telemetry() {
    local event="$1"
    local error_type="${2:-none}"
    local wait_for_net="${3:-false}"

    check_telemetry_enabled || return 0

    local kernel=$(uname -r)
    local distro=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "unknown")
    local hw_id=$(lspci -nn 2>/dev/null | grep -i "7925\|7921" | grep -oP '\[14c3:[0-9a-f]+\]' | head -1 || echo "unknown")

    # Detect hardware details
    local hw_info=$(detect_hardware_info)
    local chip=$(echo "$hw_info" | cut -d: -f1)
    local bus_type=$(echo "$hw_info" | cut -d: -f2)
    local uses_clang=$(detect_uses_clang)

    # Calculate duration since session start
    local duration=$(($(date +%s) - SESSION_START))

    # If requested, wait for network (useful after WiFi module replacement)
    if [[ "$wait_for_net" == "true" ]]; then
        if ! wait_for_network 30; then
            queue_telemetry "$event" "$error_type" "$kernel" "$distro" "$hw_id" "$PACKAGE_VERSION" "$SESSION_ID" "$duration" "$chip" "$bus_type" "$uses_clang"
            return 0
        fi
    fi

    # Try to send, queue on failure
    if ! curl -s --max-time 5 -X POST "https://us.i.posthog.com/capture/" \
        -H "Content-Type: application/json" \
        -d "{
            \"api_key\": \"phc_NYTw1UQKJXKsgZUT16cn0OTbKoOMJEkUSbGwzMnNh0g\",
            \"event\": \"${event}\",
            \"distinct_id\": \"anonymous\",
            \"properties\": {
                \"kernel\": \"${kernel}\",
                \"distro\": \"${distro}\",
                \"hardware\": \"${hw_id}\",
                \"chip\": \"${chip}\",
                \"bus_type\": \"${bus_type}\",
                \"uses_clang\": ${uses_clang},
                \"version\": \"${PACKAGE_VERSION}\",
                \"error_type\": \"${error_type}\",
                \"session_id\": \"${SESSION_ID}\",
                \"duration_seconds\": ${duration}
            }
        }" >/dev/null 2>&1; then
        queue_telemetry "$event" "$error_type" "$kernel" "$distro" "$hw_id" "$PACKAGE_VERSION" "$SESSION_ID" "$duration" "$chip" "$bus_type" "$uses_clang"
    fi
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

unload_modules() {
    log_info "Unloading DKMS mt76 modules..."

    # Unload in dependency order (leaf modules first)
    # Note: kernel modules use underscores internally
    for mod in mt7925e mt7925_common \
               mt7921e mt7921s mt7921u mt7921_common \
               mt792x_usb mt76_usb mt76_sdio \
               mt792x_lib mt76_connac_lib mt76; do
        if lsmod | grep -q "^${mod//-/_}"; then
            rmmod "${mod//-/_}" 2>/dev/null || true
        fi
    done
}

remove_dkms() {
    # Find all installed versions and remove them
    local versions
    versions=$(dkms status | grep "^${PACKAGE_NAME}/" | sed 's/.*\///; s/[,:].*//; s/ .*//' | sort -u)

    if [[ -n "$versions" ]]; then
        for version in $versions; do
            log_info "Removing ${PACKAGE_NAME}/${version} from DKMS..."
            dkms remove "${PACKAGE_NAME}/${version}" --all || true
        done
    else
        log_info "DKMS package not found, skipping..."
    fi

    # Remove all source directories for any version
    for src_dir in /usr/src/${PACKAGE_NAME}-*; do
        if [[ -d "$src_dir" ]]; then
            log_info "Removing source directory ${src_dir}..."
            rm -rf "$src_dir"
        fi
    done
}

cleanup_legacy_files() {
    # Remove obsolete blacklist file from old versions
    # (We no longer use blacklisting - depmod priority handles module selection)
    if [[ -f /etc/modprobe.d/mt76-dkms-blacklist.conf ]]; then
        log_info "Removing obsolete blacklist file..."
        rm -f /etc/modprobe.d/mt76-dkms-blacklist.conf
    fi

    # Remove telemetry config and queue files
    if [[ -f "$TELEMETRY_CONFIG" ]]; then
        log_info "Removing telemetry config..."
        rm -f "$TELEMETRY_CONFIG"
    fi
    if [[ -f "$TELEMETRY_QUEUE" ]]; then
        log_info "Removing telemetry queue..."
        rm -f "$TELEMETRY_QUEUE"
    fi
}

restore_stock_modules() {
    log_info "Regenerating module dependencies..."
    depmod -a

    log_info "Loading stock modules..."

    # Try to load stock modules (kernel will auto-load the right one for the hardware)
    modprobe mt76 2>/dev/null || log_warn "Could not load mt76 (may not be available)"
    modprobe mt76_connac_lib 2>/dev/null || true
    modprobe mt792x_lib 2>/dev/null || true

    # Try to load WiFi driver and confirm it bound to hardware via sysfs
    # modprobe succeeds even without hardware, so check driver binding
    if modprobe mt7925e 2>/dev/null && compgen -G "/sys/bus/pci/drivers/mt7925e/*:*" > /dev/null; then
        log_info "Loaded mt7925e (PCIe)"
    elif modprobe mt7921e 2>/dev/null && compgen -G "/sys/bus/pci/drivers/mt7921e/*:*" > /dev/null; then
        log_info "Loaded mt7921e (PCIe)"
    elif modprobe mt7921u 2>/dev/null && compgen -G "/sys/bus/usb/drivers/mt7921u/*:*" > /dev/null; then
        log_info "Loaded mt7921u (USB)"
    elif modprobe mt7921s 2>/dev/null && compgen -G "/sys/bus/sdio/drivers/mt7921s/*:*" > /dev/null; then
        log_info "Loaded mt7921s (SDIO)"
    else
        log_warn "Could not load WiFi driver (may need reboot)"
    fi
}

verify_removal() {
    log_info "Verifying removal..."

    echo ""
    echo "DKMS Status:"
    dkms status | grep "${PACKAGE_NAME}" || echo "Package removed from DKMS"

    echo ""
    echo "Loaded modules:"
    lsmod | grep -E "mt76|mt792|mt7921|mt7925" || echo "No mt76 modules loaded"
}

# Trap for unexpected failures
trap 'send_telemetry "uninstall_failure" "unexpected_error"' ERR

main() {
    echo "========================================"
    echo "MT7925 DKMS Uninstaller"
    echo "========================================"
    echo ""

    check_root

    # Send uninstall_started event (network is up, before we touch modules)
    send_telemetry "uninstall_started"

    unload_modules
    remove_dkms
    cleanup_legacy_files
    restore_stock_modules
    verify_removal

    echo ""
    echo "========================================"
    log_info "Uninstallation complete!"
    echo "========================================"
    echo ""
    echo "The DKMS package has been removed."
    echo "Stock kernel modules should now be active."
    echo ""
    echo "If WiFi doesn't work, try rebooting to fully"
    echo "restore the stock modules."

    # Send uninstall telemetry (wait for network - stock WiFi may take time to reconnect)
    send_telemetry "uninstall_success" "none" "true"
}

main "$@"
