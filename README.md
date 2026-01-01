# MediaTek MT7925 WiFi Driver Fixes

This repository contains three critical fixes for the MediaTek MT7925 WiFi driver that resolve kernel panics and system deadlocks on Framework Desktop systems and other hardware using this WiFi card.

## Problem Description

The MT7925 WiFi driver (mt7925e) has several related bugs that cause system instability:

1. **NULL Pointer Dereference**: Kernel panics occur when the driver attempts to reset after WiFi association failures or during state transitions. The driver tries to access `bss_conf->vif->type` when `bss_conf` is NULL.

2. **Mutex Deadlock in Reset/ROC Paths**: System-wide hangs occur during WiFi network switching, BSSID roaming, or firmware recovery. The reset work and ROC abort functions iterate over active interfaces and call MCU functions without proper mutex protection.

3. **Mutex Deadlock in Power Management Paths**: Additional deadlocks occur when runtime PM settings change or during MLO (Multi-Link Operation) power save state transitions.

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
- Hangs during suspend/resume cycles
- Deadlocks when power management settings change

## Patches

### Patch 1: NULL Pointer Dereference Fix

**File**: `0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch`

This patch adds NULL checks for `bss_conf` in all loops that iterate over `valid_links` and call `mt792x_vif_to_bss_conf()`. This prevents kernel panics when the link configuration in mac80211 is not yet set up even though the driver's `valid_links` bitmap has the link marked as valid.

**Functions fixed:**
- `mt7925_vif_connect_iter()` in mac.c
- `mt7925_change_vif_links()` in main.c
- `mt7925_mac_sta_assoc()` in main.c
- `mt7925_mac_sta_remove_links()` in main.c

**What it fixes:**
- Kernel panics during WiFi reset/recovery
- NULL pointer dereference in `mt76_connac_mcu_uni_add_dev()`
- Crashes during hardware reset or state transitions

### Patch 2: Reset and ROC Mutex Fix

**File**: `0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch`

This patch adds mutex protection around interface iteration in two critical functions that are called during firmware recovery and ROC (Remain On Channel) operations.

**Functions fixed:**
- `mt7925_mac_reset_work()` in mac.c - Called during firmware recovery after MCU timeouts
- `mt7925_roc_abort_sync()` in main.c - Called during suspend/resume and when aborting ROC operations

**What it fixes:**
- System hangs during WiFi network switching
- Deadlocks during BSSID roaming/hopping
- Network stack becoming unresponsive
- Processes stuck waiting on mutex locks
- Hangs during suspend/resume

### Patch 3: Runtime PM and MLO PM Mutex Fix

**File**: `0003-wifi-mt76-mt7925-fix-missing-mutex-protection-in-runtime-PM.patch`

This patch fixes two additional code paths that iterate over active interfaces and call MCU functions without proper mutex protection.

**Functions fixed:**
- `mt7925_set_runtime_pm()` in main.c - Called when runtime PM settings change
- `mt7925_mlo_pm_work()` in main.c - Workqueue function for MLO power management
- `mt7925_mlo_pm_iter()` in main.c - Mutex moved from callback to caller for consistency

**What it fixes:**
- Deadlocks when power management settings are changed while WiFi is active
- Race conditions during MLO power save state transitions
- Inconsistent mutex patterns in the driver

## Bug Analysis

All three patches address the same underlying anti-pattern in the driver:

```c
// DANGEROUS - Missing mutex protection
void some_function(...) {
    ieee80211_iterate_active_interfaces(hw,
        IEEE80211_IFACE_ITER_RESUME_ALL,
        callback_that_calls_mcu_functions, dev);
}

// CORRECT - With mutex protection
void some_function(...) {
    mt792x_mutex_acquire(dev);
    ieee80211_iterate_active_interfaces(hw,
        IEEE80211_IFACE_ITER_RESUME_ALL,
        callback_that_calls_mcu_functions, dev);
    mt792x_mutex_release(dev);
}
```

When interface iteration callbacks invoke MCU functions, the device mutex must be held to prevent race conditions and deadlocks.

**Note**: Similar bugs exist in the MT7921 driver (`mt7921_set_runtime_pm`, `mt7921_mac_reset_work`, `mt7921_roc_abort_sync`) and should be fixed in a separate patch series.

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

# Apply all three patches in order
git apply /path/to/mt7925/0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch
git apply /path/to/mt7925/0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch
git apply /path/to/mt7925/0003-wifi-mt76-mt7925-fix-missing-mutex-protection-in-runtime-PM.patch

# Build the kernel or just the mt76 modules
# For full kernel build:
make -j$(nproc)

# Or build just the mt76 modules:
make -j$(nproc) M=drivers/net/wireless/mediatek/mt76
```

### Method 2: Apply to Ubuntu/Debian Kernel Package Source

For Ubuntu/Debian users who want to rebuild the kernel package:

```bash
# Install kernel build dependencies
sudo apt-get install build-essential fakeroot libncurses5-dev libssl-dev

# Get kernel source (example for Ubuntu)
apt-get source linux-image-$(uname -r)

# Navigate to source directory
cd linux-*/

# Apply all patches
patch -p1 < /path/to/mt7925/0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch
patch -p1 < /path/to/mt7925/0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch
patch -p1 < /path/to/mt7925/0003-wifi-mt76-mt7925-fix-missing-mutex-protection-in-runtime-PM.patch

# Build kernel package
fakeroot debian/rules binary-headers binary-generic
```

### Method 3: Build and Load Module Only (Quick Test)

For a quick test without rebuilding the entire kernel:

```bash
# Install kernel headers
sudo apt-get install linux-headers-$(uname -r)

# Get kernel source
apt-get source linux-image-$(uname -r)
cd linux-*/

# Apply all patches
patch -p1 < /path/to/mt7925/0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch
patch -p1 < /path/to/mt7925/0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch
patch -p1 < /path/to/mt7925/0003-wifi-mt76-mt7925-fix-missing-mutex-protection-in-runtime-PM.patch

# Build just the mt76 modules (including mt7925)
make -j$(nproc) M=drivers/net/wireless/mediatek/mt76

# Unload old modules
sudo modprobe -r mt7925e mt7925_common

# Load new modules
sudo insmod drivers/net/wireless/mediatek/mt76/mt7925/mt7925-common.ko
sudo insmod drivers/net/wireless/mediatek/mt76/mt7925/mt7925e.ko

# Verify modules are loaded
lsmod | grep mt7925
```

**Note**: Module-only builds require the kernel source to match your running kernel version exactly. If versions don't match, you'll need to rebuild the full kernel.

### Method 4: Using DKMS (Recommended for Long-term Use)

For a more permanent solution that survives kernel updates:

```bash
# Install DKMS
sudo apt-get install dkms

# Create DKMS module directory
sudo mkdir -p /usr/src/mt7925-patched-1.0

# Copy the patched source files
sudo cp -r drivers/net/wireless/mediatek/mt76/* /usr/src/mt7925-patched-1.0/

# Create dkms.conf
sudo tee /usr/src/mt7925-patched-1.0/dkms.conf << 'EOF'
PACKAGE_NAME="mt7925-patched"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="mt7925e"
BUILT_MODULE_NAME[1]="mt7925-common"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_LOCATION[1]="/updates"
AUTOINSTALL="yes"
EOF

# Register and build with DKMS
sudo dkms add -m mt7925-patched -v 1.0
sudo dkms build -m mt7925-patched -v 1.0
sudo dkms install -m mt7925-patched -v 1.0
```

## Verification

After applying the patches and loading the modules, verify the fixes are active:

```bash
# Check module version (srcversion will be different from stock)
modinfo mt7925_common | grep srcversion

# Monitor kernel logs for errors
dmesg | grep -i mt7925

# Test WiFi connectivity
# Try switching between networks or disconnecting/reconnecting
# The system should no longer hang or panic

# Test BSSID roaming (if you have multiple access points)
# Previously this would cause deadlocks every ~5 minutes
```

## Status

| Patch | Description | Status |
|-------|-------------|--------|
| 0001 | NULL pointer dereference fix | ✅ Submitted to LKML |
| 0002 | Reset/ROC mutex fix | ✅ Submitted to LKML |
| 0003 | Runtime PM/MLO PM mutex fix | ✅ Ready for submission |

These patches have been tested on:
- Framework Desktop (AMD Ryzen AI Max 300 Series)
- Ubuntu 25.10 (kernel 6.17.0-8-generic)
- Linux 6.19-rc3 (mainline)

## Contributing

If you encounter issues or have improvements, please help by:
1. Testing the patches on your system
2. Reporting results in the [Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
3. Updating the [Ubuntu Launchpad bug](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291) with your findings

## License

These patches are provided under the same license as the Linux kernel (GPL v2).
