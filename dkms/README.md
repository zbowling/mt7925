# MT7925 DKMS Package

**Version:** 1.5.0

This DKMS package provides a patched MT7925 WiFi driver with fixes for:
- NULL pointer dereferences in MLO (Multi-Link Operation) paths
- Missing mutex protection causing race conditions
- Error handling for MCU commands
- Firmware reload failures
- ROC (Remain On Channel) deadlocks and race conditions
- WCID resource leaks on error paths
- List corruption in WCID cleanup after reset
- Double wcid initialization race condition
- BA session teardown during beacon loss

**New in v1.5.0:**
- **RSSI Monitor**: CQM RSSI threshold notifications via firmware events
- **CSA Support**: Handle AP-initiated channel switches (WiFi 7 MLO)
- **Conditional Debug**: `MT76_DKMS_DEBUG_FEATURES` compile-time flag for verbose logging

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
sudo dkms build mt76-mt7925/1.5.0
sudo dkms install mt76-mt7925/1.5.0

# Remove
sudo dkms remove mt76-mt7925/1.5.0 --all
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

## Debug Logging

The DKMS version includes **significantly more debug logging** than the upstream kernel patchsets. This helps diagnose issues that are difficult to reproduce.

### What's Logged

The driver logs detailed information for:
- **ROC (Remain On Channel):** MCU commands, grants, timeouts, abort operations
- **MLO (Multi-Link Operation):** Link changes, VIF/STA link additions/removals
- **Keys:** Key installation/removal for each link
- **Channel Context:** Frequency assignments and BSS changes
- **Power Management:** Suspend/resume operations
- **Station Management:** Link station add/remove operations

### Collecting Logs for Bug Reports

If you experience issues (disconnects, hangs, timeouts), please collect logs:

**Option 1: Recent kernel messages (quick)**
```bash
# Get last 500 lines of mt7925-related messages
sudo dmesg | grep -E "(mt7925|mt76|wlan)" | tail -500 > mt7925_dmesg.log
```

**Option 2: Full journal since boot (comprehensive)**
```bash
# All kernel messages this boot
journalctl -k -b > kernel_journal.log

# Or filtered to WiFi-related
journalctl -k -b | grep -E "(mt7925|mt76|wlan|wifi)" > wifi_journal.log
```

**Option 3: Live monitoring (for reproducing issues)**
```bash
# Watch logs in real-time while reproducing the issue
sudo dmesg -w | grep -E "(mt7925|mt76|ROC|MLO|KEY|CHANCTX|PM:)"
```

### Filing an Issue

**File issues at: https://github.com/zbowling/mt7925/issues**

When filing an issue, please include:
1. **Log output** from one of the methods above
2. **Kernel version:** `uname -r`
3. **DKMS version:** `dkms status | grep mt76`
4. **Hardware info:** `lspci | grep -i network`
5. **Steps to reproduce** (if known)
6. **What you were doing** when the issue occurred (suspend/resume, roaming, connecting to MLO AP, etc.)

### Log Prefixes Reference

| Prefix | Meaning |
|--------|---------|
| `ROC:` | Remain On Channel operations (scanning, MLO discovery) |
| `MLO:` | Multi-Link Operation link management |
| `KEY:` | Encryption key installation/removal |
| `CHANCTX:` | Channel context (frequency) management |
| `STA:` | Station link management |
| `MGD:` | Managed mode (prepare_tx) operations |
| `PM:` | Power management (suspend/resume) |

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
