#!/bin/bash
# MT7925 DKMS Installer
# Installs the patched MT7925 WiFi driver via DKMS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NAME="mt76-mt7925"
PACKAGE_VERSION="1.4.0"
DKMS_SRC="/usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}"

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
        exit 1
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
        exit 1
    fi

    if [[ ! -d "/lib/modules/$(uname -r)/build" ]]; then
        log_error "Kernel headers not found for $(uname -r). Please install them:"
        echo "  Arch/Manjaro: sudo pacman -S linux-headers"
        echo "  Ubuntu/Debian: sudo apt install linux-headers-$(uname -r)"
        echo "  Fedora: sudo dnf install kernel-devel"
        exit 1
    fi

    # Check if kernel was built with clang (CONFIG_CC_IS_CLANG=y)
    if grep -q "CONFIG_CC_IS_CLANG=y" "/lib/modules/$(uname -r)/build/.config" 2>/dev/null; then
        log_info "Detected clang-built kernel (CONFIG_CC_IS_CLANG=y)"
        if ! command -v clang &> /dev/null; then
            log_error "Kernel was built with clang but clang is not installed"
            echo "  Arch/Manjaro: sudo pacman -S clang lld"
            echo "  Ubuntu/Debian: sudo apt install clang lld"
            echo "  Fedora: sudo dnf install clang lld"
            exit 1
        fi
        if ! command -v ld.lld &> /dev/null; then
            log_error "Kernel was built with clang but lld (LLVM linker) is not installed"
            echo "  Arch/Manjaro: sudo pacman -S lld"
            echo "  Ubuntu/Debian: sudo apt install lld"
            echo "  Fedora: sudo dnf install lld"
            exit 1
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
    ip link show | grep -E "wlan|wlp" || echo "No WiFi interfaces found (may need reboot)"
}

main() {
    echo "========================================"
    echo "MT7925 DKMS Installer"
    echo "========================================"
    echo ""

    check_root
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
}

main "$@"
