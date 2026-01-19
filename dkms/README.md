# MT7925 DKMS Package

**Version:** 1.1.0

This DKMS package provides a patched MT7925 WiFi driver with fixes for:
- NULL pointer dereferences in MLO (Multi-Link Operation) paths
- Missing mutex protection causing race conditions
- Error handling for MCU commands
- Firmware reload failures
- ROC (Remain On Channel) deadlocks and race conditions
- WCID resource leaks on error paths
- List corruption in WCID cleanup after reset
- ROC timer race during suspend/resume
- ROC rate limiting for MLO authentication failures

## Requirements

- Linux kernel **6.17 or newer** (uses APIs not available in older kernels)
- DKMS installed
- Kernel headers for your running kernel
- Clang + lld (if your kernel was built with clang)

### Installing Requirements

**Arch Linux / CachyOS / Manjaro:**
```bash
sudo pacman -S dkms linux-headers
```

**Ubuntu / Pop!_OS / Debian:**
```bash
sudo apt install dkms linux-headers-$(uname -r)
```

**Fedora:**
```bash
sudo dnf install dkms kernel-devel
```

## Installation

```bash
cd dkms
sudo ./install.sh
```

The installer will:
1. Check for DKMS and kernel headers
2. Remove any existing installation
3. Blacklist stock mt76 modules
4. Install and build the DKMS modules
5. Load the new modules

## Uninstallation

```bash
cd dkms
sudo ./uninstall.sh
```

This will:
1. Remove the DKMS package
2. Remove the blacklist file
3. Restore stock kernel modules

## Manual DKMS Commands

```bash
# Check status
dkms status

# Rebuild for current kernel
sudo dkms build mt76-mt7925/1.1.0
sudo dkms install mt76-mt7925/1.1.0

# Remove
sudo dkms remove mt76-mt7925/1.1.0 --all
```

## Troubleshooting

### WiFi not working after install
Try rebooting. The stock modules may still be cached.

### Build fails
Make sure you have kernel headers installed:
```bash
ls /lib/modules/$(uname -r)/build
```

### Module not loading
Check dmesg for errors:
```bash
sudo dmesg | grep -i mt76
```

### Secure Boot
If you have Secure Boot enabled, you may need to sign the modules or disable Secure Boot.

## Modules Included

| Module | Description |
|--------|-------------|
| mt76.ko | MT76 core driver |
| mt76-connac-lib.ko | Connac chipset library |
| mt792x-lib.ko | MT7921/MT7925 shared library |
| mt7925-common.ko | MT7925 common code |
| mt7925e.ko | MT7925 PCIe driver |

## Source

The source code is pre-patched from the [zbowling/linux-wifi](https://github.com/zbowling/linux-wifi)
fork's `mt7925-fixes-v6.18.5` branch.

Patches are also available separately in the `kernels/` directory for manual application.
