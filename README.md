# MediaTek MT7925 WiFi Driver Fixes

This repository contains two critical fixes for the MediaTek MT7925 WiFi driver that resolve kernel panics and system deadlocks on Framework Desktop systems and other hardware using this WiFi card.

## Problem Description

The MT7925 WiFi driver (mt7925e) has two related bugs that cause system instability:

1. **NULL Pointer Dereference**: Kernel panics occur when the driver attempts to reset after WiFi association failures or during state transitions. The driver tries to access `bss_conf->vif->type` when `bss_conf` is NULL.

2. **Mutex Deadlock**: System-wide hangs occur during WiFi network switching, BSSID roaming, or firmware recovery. Network commands (like `ip`) hang indefinitely, processes get stuck in uninterruptible sleep (D state), and the system becomes completely unresponsive requiring a force reboot.

### Affected Hardware

- Framework Desktop (AMD Ryzen AI Max 300 Series)
- Framework Laptop 13 (AMD Ryzen AI 300 Series) with MT7925 (RZ717) WiFi card
- Any system using MediaTek MT7925 WiFi hardware

### Symptoms

- Kernel panics with NULL pointer dereference in `mt76_connac_mcu_uni_add_dev()`
- System hangs during WiFi network switching or roaming
- Network commands (`ip`, `ifconfig`, etc.) hang indefinitely
- Processes stuck in uninterruptible sleep (D state)
- NetworkManager, wpa_supplicant, and other network services timeout
- System becomes completely unresponsive, requiring force reboot
- Deadlock occurs every 5 minutes when adapter tries to hop to a better BSSID

## Patches

### Patch 1: NULL Pointer Dereference Fix

**File**: `0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch`

This patch adds NULL checks for `bss_conf` in all loops that iterate over `valid_links` and call `mt792x_vif_to_bss_conf()`. This prevents kernel panics when the link configuration in mac80211 is not yet set up even though the driver's `valid_links` bitmap has the link marked as valid.

**What it fixes:**
- Kernel panics during WiFi reset/recovery
- NULL pointer dereference in `mt76_connac_mcu_uni_add_dev()`
- Crashes during hardware reset or state transitions

### Patch 2: Mutex Deadlock Fix

**File**: `0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch`

This patch adds mutex protection around interface iteration in two critical functions:
- `mt7925_mac_reset_work()`: Called during firmware recovery after MCU timeouts
- `mt7925_roc_abort_sync()`: Called during suspend/resume and when aborting Remain On Channel operations

Both functions iterate over active interfaces and call MCU functions that require the device mutex to be held, but the mutex was not acquired before the iteration, causing deadlocks.

**What it fixes:**
- System hangs during WiFi network switching
- Deadlocks during BSSID roaming/hopping
- Network stack becoming unresponsive
- Processes stuck waiting on mutex locks

## Related Issues

- [Framework Community Forum Discussion](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
- [Ubuntu Launchpad Bug #2137291](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)
- [Linux Kernel Mailing List Thread](https://lore.kernel.org/all/CAA5_Hq7vNOy9oCGkkgyukq2OP=a5yL_3ZKBdmNtBXS+zp6byiQ@mail.gmail.com/T/#u)
- [OpenWrt mt76 Issue #1027](https://github.com/openwrt/mt76/issues/1027)

## How to Apply These Patches

### Prerequisites

- Linux kernel source code (version 6.12+ or 6.17+)
- Basic build tools (`build-essential` on Debian/Ubuntu)
- Kernel headers matching your running kernel (for module builds)

### Method 1: Apply to Full Kernel Source Tree

If you have the full kernel source tree:

```bash
# Navigate to your kernel source directory
cd /path/to/linux-kernel-source

# Apply both patches
git apply /path/to/mt7925/0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch
git apply /path/to/mt7925/0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch

# Build the kernel or just the mt7925 module
# For full kernel build:
make -j$(nproc)

# Or build just the mt7925 module:
make -j$(nproc) M=drivers/net/wireless/mediatek/mt76/mt7925
```

### Method 2: Apply to Ubuntu/Debian Kernel Package Source

For Ubuntu/Debian users who want to rebuild the kernel package:

```bash
# Install kernel build dependencies
sudo apt-get install build-essential fakeroot kernel-package libncurses5-dev

# Get kernel source (example for Ubuntu 25.10)
apt-get source linux-image-$(uname -r)

# Navigate to source directory
cd linux-*/

# Apply patches
patch -p1 < /path/to/mt7925/0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch
patch -p1 < /path/to/mt7925/0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch

# Build kernel package
fakeroot debian/rules binary-headers binary-generic
```

### Method 3: Build and Load Module Only (Quick Test)

For a quick test without rebuilding the entire kernel:

```bash
# Install kernel headers
sudo apt-get install linux-headers-$(uname -r)

# Get kernel source (minimal, just for headers)
apt-get source linux-image-$(uname -r)
cd linux-*/

# Apply patches to the mt7925 driver
patch -p1 < /path/to/mt7925/0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch
patch -p1 < /path/to/mt7925/0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch

# Build just the mt7925 modules
cd drivers/net/wireless/mediatek/mt76/mt7925
make -C /lib/modules/$(uname -r)/build M=$(pwd) modules

# Unload old modules
sudo modprobe -r mt7925e mt7925_common

# Load new modules
sudo insmod mt7925-common.ko
sudo insmod mt7925e.ko

# Verify modules are loaded
lsmod | grep mt7925
```

**Note**: Module-only builds require the kernel source to match your running kernel version exactly. If versions don't match, you'll need to rebuild the full kernel.

## Verification

After applying the patches and loading the modules, verify the fixes are active:

```bash
# Check module version
modinfo mt7925_common | grep srcversion

# Monitor kernel logs for errors
dmesg | grep -i mt7925

# Test WiFi connectivity
# Try switching between networks or disconnecting/reconnecting
# The system should no longer hang or panic
```

## Status

- ✅ Patch 1 (NULL pointer fix) - Submitted to Linux kernel mailing list
- ✅ Patch 2 (Mutex deadlock fix) - Submitted to Linux kernel mailing list
- ⏳ Awaiting upstream merge

These patches have been tested on:
- Framework Desktop (AMD Ryzen AI Max 300 Series)
- Ubuntu 25.10 (kernel 6.17.0-8)

## Contributing

If you encounter issues or have improvements, please help me out by:
1. Testing the patches on your system
2. Report results in the [Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
3. Update the [Ubuntu Launchpad bug](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291) with your findings

## License

These patches are provided under the same license as the Linux kernel (GPL v2).
