#!/bin/bash
# MT7925 DKMS Installer
# Installs the patched MT7925 WiFi driver via DKMS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NAME="mt76-mt7925"
PACKAGE_VERSION="1.5.0"
DKMS_SRC="/usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}"

# Session tracking for telemetry (correlate start/end events)
SESSION_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N | sha256sum | head -c 32)
SESSION_START=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Telemetry config file location
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

    # No preference set yet
    return 2
}

# Save telemetry preference
save_telemetry_preference() {
    echo "$1" > "$TELEMETRY_CONFIG" 2>/dev/null || true
}

# Prompt user for telemetry consent (interactive terminals only)
prompt_telemetry_consent() {
    # Skip if environment variable is set
    if [[ -n "${MT7925_TELEMETRY:-}" ]]; then
        return
    fi

    # Skip if preference already saved
    if [[ -f "$TELEMETRY_CONFIG" ]]; then
        return
    fi

    # Only prompt in interactive terminals
    if [[ ! -t 0 ]]; then
        # Non-interactive: default to disabled
        return
    fi

    echo ""
    echo -e "${YELLOW}--- Telemetry ---${NC}"
    echo "Help improve this driver by enabling anonymous telemetry."
    echo ""
    echo "What's collected (fully anonymized):"
    echo "  - Kernel version, distro name, hardware ID"
    echo "  - Install success/failure"
    echo ""
    echo "NOT collected: IP addresses, MAC addresses, hostnames, usernames"
    echo ""
    echo "This helps me find issues people are having and discover new"
    echo "operating systems I should be testing on."
    echo ""

    read -r -p "Enable telemetry? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            save_telemetry_preference 1
            echo "Telemetry enabled. Thank you for helping improve this driver!"
            ;;
        *)
            save_telemetry_preference 0
            echo "Telemetry disabled. You can enable later with: sudo MT7925_TELEMETRY=1 ./install.sh"
            ;;
    esac
    echo ""
}

# Wait for network connectivity (WiFi may take time to reconnect after module reload)
wait_for_network() {
    local max_wait="${1:-30}"
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        # Try to reach PostHog endpoint (or any reliable endpoint)
        if curl -s --max-time 3 -o /dev/null "https://us.i.posthog.com/" 2>/dev/null; then
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
    done
    return 1  # Timeout - network not available
}

# Queue telemetry event for later sending (when network is unavailable)
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

    # Append to queue file (one JSON object per line)
    echo "{\"event\":\"${event}\",\"error_type\":\"${error_type}\",\"kernel\":\"${kernel}\",\"distro\":\"${distro}\",\"hardware\":\"${hw_id}\",\"version\":\"${version}\",\"session_id\":\"${session_id}\",\"duration_seconds\":${duration:-0},\"chip\":\"${chip}\",\"bus_type\":\"${bus_type}\",\"uses_clang\":${uses_clang},\"queued_at\":\"${timestamp}\"}" >> "$TELEMETRY_QUEUE" 2>/dev/null || true
}

# Send queued telemetry events (called at start of install when network is likely available)
send_queued_telemetry() {
    [[ ! -f "$TELEMETRY_QUEUE" ]] && return 0

    # Return early if telemetry is disabled or not configured
    check_telemetry_enabled || return 0

    # Process each queued event
    local failed_events=""

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Extract fields from JSON (simple parsing)
        local event=$(echo "$line" | grep -oP '"event"\s*:\s*"\K[^"]+' || echo "")
        local error_type=$(echo "$line" | grep -oP '"error_type"\s*:\s*"\K[^"]+' || echo "none")
        local kernel=$(echo "$line" | grep -oP '"kernel"\s*:\s*"\K[^"]+' || echo "")
        local distro=$(echo "$line" | grep -oP '"distro"\s*:\s*"\K[^"]+' || echo "")
        local hw_id=$(echo "$line" | grep -oP '"hardware"\s*:\s*"\K[^"]+' || echo "")
        local version=$(echo "$line" | grep -oP '"version"\s*:\s*"\K[^"]+' || echo "")
        local session_id=$(echo "$line" | grep -oP '"session_id"\s*:\s*"\K[^"]+' || echo "")
        local duration=$(echo "$line" | grep -oP '"duration_seconds"\s*:\s*\K[0-9]+' || echo "0")
        local chip=$(echo "$line" | grep -oP '"chip"\s*:\s*"\K[^"]+' || echo "unknown")
        local bus_type=$(echo "$line" | grep -oP '"bus_type"\s*:\s*"\K[^"]+' || echo "unknown")
        local uses_clang=$(echo "$line" | grep -oP '"uses_clang"\s*:\s*\K(true|false)' || echo "false")
        local queued_at=$(echo "$line" | grep -oP '"queued_at"\s*:\s*"\K[^"]+' || echo "")

        # Try to send
        if curl -s --max-time 5 -X POST "https://us.i.posthog.com/capture/" \
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
                    \"version\": \"${version}\",
                    \"error_type\": \"${error_type}\",
                    \"session_id\": \"${session_id}\",
                    \"duration_seconds\": ${duration},
                    \"queued_at\": \"${queued_at}\"
                }
            }" >/dev/null 2>&1; then
            : # Success - don't re-queue
        else
            # Failed - keep in queue
            failed_events="${failed_events}${line}\n"
        fi
    done < "$TELEMETRY_QUEUE"

    # Rewrite queue with only failed events
    if [[ -n "$failed_events" ]]; then
        echo -e "$failed_events" > "$TELEMETRY_QUEUE"
    else
        rm -f "$TELEMETRY_QUEUE" 2>/dev/null || true
    fi
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

# Opt-in telemetry using PostHog
# API key is write-only (safe to embed in public code)
send_telemetry() {
    local event="$1"
    local error_type="${2:-none}"
    local wait_for_net="${3:-false}"

    # Return early if telemetry is disabled or not configured
    check_telemetry_enabled || return 0

    # Collect safe system info
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
            # Network not available - queue for later
            queue_telemetry "$event" "$error_type" "$kernel" "$distro" "$hw_id" "$PACKAGE_VERSION" "$SESSION_ID" "$duration" "$chip" "$bus_type" "$uses_clang"
            return 0
        fi
    fi

    # PostHog capture API (write-only key, safe to embed)
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
        # Failed to send - queue for later
        queue_telemetry "$event" "$error_type" "$kernel" "$distro" "$hw_id" "$PACKAGE_VERSION" "$SESSION_ID" "$duration" "$chip" "$bus_type" "$uses_clang"
    fi
}

# Error handler for telemetry
handle_error() {
    local error_type="${1:-unknown}"
    send_telemetry "install_failure" "$error_type"
    exit 1
}

# Trap for unexpected failures (e.g., DKMS build errors)
trap 'send_telemetry "install_failure" "build_failed"' ERR

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
        # Don't send telemetry for root check - not an installation failure
        exit 1
    fi
}

check_kernel_version() {
    log_info "Checking kernel version..."

    KVER=$(uname -r)
    # Extract major.minor version
    MAJOR=$(echo "$KVER" | cut -d. -f1)
    MINOR=$(echo "$KVER" | cut -d. -f2)

    if [[ "$MAJOR" -lt 6 ]] || [[ "$MAJOR" -eq 6 && "$MINOR" -lt 17 ]]; then
        log_error "Kernel $KVER is too old. This DKMS package requires kernel 6.17+"
        log_error "The mt76 source uses APIs not available in older kernels."
        log_error "Options:"
        echo "  1. Upgrade to a newer kernel (6.17+)"
        echo "  2. Apply patches directly to your kernel source"
        echo "     See kernels/ directory for version-specific patches"
        handle_error "kernel_too_old"
    fi

    log_info "Kernel version $KVER is supported"
}

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v dkms &> /dev/null; then
        log_error "DKMS is not installed. Please install it first:"
        echo "  Arch/Manjaro: sudo pacman -S dkms"
        echo "  Ubuntu/Debian: sudo apt install dkms"
        echo "  Fedora: sudo dnf install dkms"
        handle_error "dkms_missing"
    fi

    if [[ ! -d "/lib/modules/$(uname -r)/build" ]]; then
        log_error "Kernel headers not found for $(uname -r). Please install them:"
        echo "  Arch/Manjaro: sudo pacman -S linux-headers"
        echo "  Ubuntu/Debian: sudo apt install linux-headers-$(uname -r)"
        echo "  Fedora: sudo dnf install kernel-devel"
        handle_error "headers_missing"
    fi

    # Check if kernel was built with clang (CONFIG_CC_IS_CLANG=y)
    if grep -q "CONFIG_CC_IS_CLANG=y" "/lib/modules/$(uname -r)/build/.config" 2>/dev/null; then
        log_info "Detected clang-built kernel (CONFIG_CC_IS_CLANG=y)"
        if ! command -v clang &> /dev/null; then
            log_error "Kernel was built with clang but clang is not installed"
            echo "  Arch/Manjaro: sudo pacman -S clang lld"
            echo "  Ubuntu/Debian: sudo apt install clang lld"
            echo "  Fedora: sudo dnf install clang lld"
            handle_error "clang_missing"
        fi
        if ! command -v ld.lld &> /dev/null; then
            log_error "Kernel was built with clang but lld (LLVM linker) is not installed"
            echo "  Arch/Manjaro: sudo pacman -S lld"
            echo "  Ubuntu/Debian: sudo apt install lld"
            echo "  Fedora: sudo dnf install lld"
            handle_error "lld_missing"
        fi
        log_info "LLVM toolchain (clang + lld) found - Makefile will auto-detect"
    fi

    # Check for firmware files
    FW_DIR="/lib/firmware/mediatek"
    if [[ ! -d "$FW_DIR/mt7925" ]] && [[ ! -f "$FW_DIR/mt7925_firmware.bin" ]]; then
        log_warn "MT7925 firmware not found in $FW_DIR"
        log_warn "Install linux-firmware package if WiFi doesn't work after installation"
    fi

    log_info "Dependencies satisfied"
}

remove_existing() {
    # Remove all installed versions (not just current)
    local versions
    versions=$(dkms status | grep "^${PACKAGE_NAME}/" | sed 's/.*\///; s/[,:].*//; s/ .*//' | sort -u)

    if [[ -n "$versions" ]]; then
        for version in $versions; do
            log_info "Removing ${PACKAGE_NAME}/${version} from DKMS..."
            dkms remove "${PACKAGE_NAME}/${version}" --all 2>/dev/null || true
        done
    fi

    # Remove all source directories for any version
    for src_dir in /usr/src/${PACKAGE_NAME}-*; do
        if [[ -d "$src_dir" ]]; then
            log_info "Removing source directory ${src_dir}..."
            rm -rf "$src_dir"
        fi
    done
}

unload_modules() {
    log_info "Unloading existing mt76 modules..."

    # Unload in reverse dependency order (leaf modules first)
    # Include MT7921 modules since they share mt792x-lib
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

setup_module_priority() {
    # DKMS modules are installed to /updates/dkms/ which has higher priority
    # than stock modules in /kernel/ according to depmod search order.
    # No blacklist needed - depmod priority handles it automatically.
    #
    # Search order (from /lib/depmod.d/search.conf):
    #   updates > extramodules > built-in
    #
    log_info "DKMS modules installed to /updates/dkms/ (higher priority than stock)"

    # Remove old blacklist if it exists (from previous versions)
    # Blacklisting was wrong - it blocks ALL modules with that name including DKMS ones
    if [[ -f /etc/modprobe.d/mt76-dkms-blacklist.conf ]]; then
        log_info "Removing obsolete blacklist file..."
        rm -f /etc/modprobe.d/mt76-dkms-blacklist.conf
    fi
}

install_dkms() {
    log_info "Installing DKMS source to ${DKMS_SRC}..."

    mkdir -p "$DKMS_SRC"
    cp -r "$SCRIPT_DIR/src" "$DKMS_SRC/"
    cp "$SCRIPT_DIR/dkms.conf" "$DKMS_SRC/"

    log_info "Adding to DKMS..."
    dkms add "${PACKAGE_NAME}/${PACKAGE_VERSION}"

    log_info "Building modules for kernel $(uname -r)..."
    dkms build "${PACKAGE_NAME}/${PACKAGE_VERSION}"

    log_info "Installing modules..."
    dkms install "${PACKAGE_NAME}/${PACKAGE_VERSION}"
}

load_modules() {
    log_info "Loading new modules..."

    # Load core modules
    modprobe mt76
    modprobe mt76-connac-lib
    modprobe mt792x-lib

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
        log_warn "No WiFi hardware detected (driver will load on next boot/plug)"
    fi

    log_info "Modules loaded successfully"
}

verify_installation() {
    log_info "Verifying installation..."

    echo ""
    echo "DKMS Status:"
    dkms status | grep "${PACKAGE_NAME}" || true

    echo ""
    echo "Loaded modules:"
    lsmod | grep -E "mt76|mt792|mt7925" || echo "No mt76 modules loaded"

    echo ""
    echo "WiFi interfaces:"
    # Interface may take a few seconds to initialize after module load
    sleep 2
    ip link show | grep -E "wlan|wlp" || echo "No WiFi interfaces found yet (wait a few seconds or replug device)"
}

main() {
    echo "========================================"
    echo "MT7925 DKMS Installer"
    echo "========================================"
    echo ""

    check_root

    # Prompt for telemetry consent (after root check so we can save preference)
    prompt_telemetry_consent

    # Send any queued telemetry from previous installs (network should be up now)
    send_queued_telemetry

    # Send install_started event (network is up, before we touch modules)
    send_telemetry "install_started"

    check_kernel_version
    check_dependencies
    remove_existing
    unload_modules
    setup_module_priority
    install_dkms
    load_modules
    verify_installation

    echo ""
    echo "========================================"
    log_info "Installation complete!"
    echo "========================================"
    echo ""
    echo "The patched MT7925 driver is now installed via DKMS."
    echo "It will be automatically rebuilt when you update your kernel."
    echo ""
    echo "If WiFi doesn't work, try rebooting."
    echo "To check status: dkms status"
    echo "To uninstall: sudo ./uninstall.sh"

    # Send success telemetry (wait for network - WiFi may take time to reconnect)
    send_telemetry "install_success" "none" "true"
}

main "$@"
