#!/bin/bash
# MT7925 DKMS Uninstaller
# Removes the patched MT7925 WiFi driver and restores stock modules

set -e

PACKAGE_NAME="mt76-mt7925"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
    for mod in mt7925e mt7925_common mt7925-common \
               mt7921e mt7921s mt7921u mt7921_common mt7921-common \
               mt792x_lib mt792x-lib \
               mt76_connac_lib mt76-connac-lib mt76; do
        if lsmod | grep -q "^${mod//-/_}"; then
            rmmod "${mod//-/_}" 2>/dev/null || true
        fi
    done
}

remove_dkms() {
    # Find all installed versions and remove them
    local versions
    versions=$(dkms status | grep "${PACKAGE_NAME}" | sed 's/.*\///; s/,.*//' | sort -u)

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
}

restore_stock_modules() {
    log_info "Regenerating module dependencies..."
    depmod -a

    log_info "Loading stock modules..."

    # Try to load stock modules (kernel will auto-load the right one for the hardware)
    modprobe mt76 2>/dev/null || log_warn "Could not load mt76 (may not be available)"
    modprobe mt76_connac_lib 2>/dev/null || true
    modprobe mt792x_lib 2>/dev/null || true

    # Try mt7925 first (newer chip), then mt7921
    modprobe mt7925e 2>/dev/null || modprobe mt7921e 2>/dev/null || \
        log_warn "Could not load WiFi driver (may need reboot)"
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

main() {
    echo "========================================"
    echo "MT7925 DKMS Uninstaller"
    echo "========================================"
    echo ""

    check_root
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
}

main "$@"
