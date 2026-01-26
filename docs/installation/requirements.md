# Requirements

## System Requirements

### Kernel Version

!!! warning "Minimum Kernel: 6.17"
    The DKMS package requires kernel 6.17 or newer. For older kernels, use the [patch method](../patches/index.md) instead.

| Kernel | DKMS Support | Notes |
|--------|--------------|-------|
| 6.19-rc | :material-check: Yes | Release candidate |
| 6.18.x | :material-check: Yes | Recommended |
| 6.17.x | :material-check: Yes | Minimum supported |
| 6.8 - 6.16 | :material-close: No | Use kernel patches |
| < 6.8 | :material-close: No | Not supported |

### Dependencies

The following packages are required:

=== "Arch Linux"

    ```bash
    # Installed automatically by the AUR package
    sudo pacman -S dkms linux-headers linux-firmware

    # For clang-built kernels (CachyOS, etc.)
    sudo pacman -S clang lld
    ```

=== "Debian/Ubuntu"

    ```bash
    # Core dependencies
    sudo apt install dkms linux-headers-$(uname -r) linux-firmware

    # For clang-built kernels
    sudo apt install clang lld
    ```

=== "Fedora/RHEL"

    ```bash
    # Core dependencies
    sudo dnf install dkms kernel-devel linux-firmware

    # For clang-built kernels
    sudo dnf install clang lld
    ```

### Clang-Built Kernels

Some distributions (like CachyOS) build their kernels with Clang instead of GCC. DKMS modules must be built with the same compiler.

To check if your kernel uses Clang:

```bash
grep CONFIG_CC_IS_CLANG /lib/modules/$(uname -r)/build/.config
```

If it shows `CONFIG_CC_IS_CLANG=y`, install `clang` and `lld`. The DKMS build system auto-detects this.

## Hardware Requirements

### Supported Chipsets

| Chipset | Interface | WiFi Standard | Status |
|---------|-----------|---------------|--------|
| MT7925 | PCIe | WiFi 7 (802.11be) | :material-check: Full support |
| MT7921 | PCIe | WiFi 6E (802.11ax) | :material-check: Full support |
| MT7921 | USB | WiFi 6E (802.11ax) | :material-check: Full support |
| MT7921 | SDIO | WiFi 6E (802.11ax) | :material-check: Full support |

### Identifying Your Hardware

```bash
# Check for PCIe devices
lspci -nn | grep -i "14c3:7925\|14c3:7921"

# Check for USB devices
lsusb | grep -i "0e8d:7961"
```

Example output for MT7925:
```text
03:00.0 Network controller [0280]: MEDIATEK Corp. MT7925 Wi-Fi 7 (802.11be) PCI Express [14c3:7925]
```

## Firmware

The driver requires firmware files from `linux-firmware`:

| Chipset | Firmware Files |
|---------|----------------|
| MT7925 | `/lib/firmware/mediatek/mt7925/WIFI_*` |
| MT7921 | `/lib/firmware/mediatek/WIFI_*_MT7921*` |

Verify firmware is installed:

```bash
ls /lib/firmware/mediatek/mt7925/ 2>/dev/null || echo "MT7925 firmware not found"
ls /lib/firmware/mediatek/WIFI_*MT7921* 2>/dev/null || echo "MT7921 firmware not found"
```

!!! tip "Update linux-firmware"
    If firmware files are missing, update your `linux-firmware` package to the latest version.

## Secure Boot

If Secure Boot is enabled, DKMS modules must be signed with a Machine Owner Key (MOK).

### Check Secure Boot Status

```bash
mokutil --sb-state
```

### Configure MOK for DKMS

Most distributions configure this automatically. If you see signature errors:

1. Generate a MOK key pair (if not exists)
2. Enroll the key with `mokutil --import`
3. Reboot and complete enrollment
4. Rebuild DKMS modules

See your distribution's documentation for specific instructions.
