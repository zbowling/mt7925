# MediaTek MT7925 WiFi Driver Fixes

This repository contains critical fixes for the MediaTek MT7925 WiFi driver that resolve kernel panics and system deadlocks on Framework Desktop systems and other hardware using this WiFi card.

## ⚠️ Disclaimer

I am not an expert on the MediaTek mt76 driver codebase. These fixes were developed through analysis of kernel panics and deadlock traces on my Framework Desktop, cross-referencing with similar code patterns in other drivers, and from looking at traces reported by other folks on mailing lists suffering the same pain. However, based on the analysis below, these fixes appear sound and follow established patterns used by other wireless drivers in the kernel.

**These bugs have existed since the MT7925 driver was added to the kernel tree (late 2023 / early 2024).** Given that the alternative is kernel panics and system-wide deadlocks requiring hard reboots, these fixes represent a significant improvement.

## Repository Structure

```
├── linux-6.19-rc4/     # ⭐ LATEST - All 18 patches for kernel 6.19-rc4
│   ├── 0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch
│   ├── 0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch
│   ├── ...
│   └── 0018-wifi-mt76-mt7921-fix-missing-mutex-protection-in-mul.patch
├── patches/            # Original patches for 6.18.x and 6.17.x
│   ├── mt7925/         # MT7925 specific fixes
│   └── mt7921/         # MT7921 specific fixes
├── nbd168-patches/     # Patches for nbd168.git (the official Linux Wireless Development fork)
├── stress-test.sh      # WiFi stress testing script
└── monitor.sh          # Driver monitoring script
```

## Quick Start (Kernel 6.19-rc4)

```bash
# Clone the kernel and this repo
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux
git checkout v6.19-rc4

# Apply all patches
git am /path/to/mt7925/linux-6.19-rc4/*.patch

# Configure and build (with ccache for faster rebuilds)
cp /boot/config-$(uname -r) .config
make olddefconfig
make CC="ccache gcc" -j$(nproc)
make CC="ccache gcc" modules -j$(nproc)

# Install
sudo make modules_install
sudo make install
sudo update-initramfs -c -k 6.19.0-rc4-mt7925-fix+
sudo update-grub
```

## Problem Description

The MT7925 WiFi driver (mt7925e) has several related bugs that cause system instability:

1. **NULL Pointer Dereference**: Kernel panics occur when the driver attempts to reset after WiFi association failures or during state transitions.

2. **Mutex Deadlock in Reset/ROC Paths**: System-wide hangs occur during WiFi network switching, BSSID roaming, or firmware recovery.

3. **Mutex Deadlock in Power Management Paths**: Additional deadlocks occur when runtime PM settings change or during MLO (Multi-Link Operation) power save state transitions.

4. **Missing Error Handling**: MCU command failures are silently ignored, leading to inconsistent driver/firmware state.

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

## Patch Summary (18 patches for 6.19-rc4)

| # | Patch | Category | Description |
|---|-------|----------|-------------|
| 01 | `0001-...-vif.patch` | Critical | NULL pointer dereference fix in vif iteration |
| 02 | `0002-...-res.patch` | Critical | Missing mutex in reset and ROC abort |
| 03 | `0003-...-run.patch` | Critical | Missing mutex in runtime PM and MLO PM |
| 04 | `0004-...-func.patch` | NULL Checks | NULL checks in MCU STA TLV functions |
| 05 | `0005-...-and-m.patch` | NULL Checks | NULL checks for link_conf and mlink |
| 06 | `0006-...-co.patch` | Error Handling | Error handling for AMPDU MCU commands |
| 07 | `0007-...-MCU.patch` | Error Handling | Error handling for BSS info in sta_add |
| 08 | `0008-...-in-.patch` | Error Handling | Error handling for BSS info in key setup |
| 09 | `0009-...-cha.patch` | NULL Checks | NULL checks in MLO link and chanctx |
| 10 | `0010-...-TX-.patch` | Critical | NULL pointer fix in TX path (mt792x) |
| 11 | `0011-...-ve.patch` | Debug | Lockdep assertions for mutex verification |
| 12 | `0012-...-MLO-.patch` | MLO Fix | Key removal failure during MLO roaming |
| 13 | `0013-...-setup.patch` | MLO Fix | Kernel warning in MLO ROC setup |
| 14 | `0014-...-pointe.patch` | NULL Checks | NULL checks for MLO link pointers in MCU |
| 15 | `0015-...-after-p.patch` | Recovery | Firmware reload after failed load (mt792x) |
| 16 | `0016-...-path.patch` | Mutex | Mutex protection in resume path |
| 17 | `0017-...-i.patch` | NULL Checks | NULL checks in sta_add and conf_tx |
| 18 | `0018-...-mul.patch` | MT7921 | Missing mutex in MT7921 (same bugs) |

## Background & Analysis

### The Root Cause: Missing Mutex Protection

All patches address variations of the same anti-pattern:

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

### Same Bugs Exist in MT7921

The MT7925 driver was derived from MT7921 (previous generation chipset). **The MT7921 driver has identical bugs** (fixed by patch 18).

### The Older MT7615 Driver Does It Correctly

The MT7615 driver (for much older MediaTek hardware) has **proper mutex protection**:

```c
// mt7615/main.c - roc_work has mutex protection
mt7615_mutex_acquire(phy->dev);
ieee80211_iterate_active_interfaces(phy->mt76->hw,
                                    IEEE80211_IFACE_ITER_RESUME_ALL,
                                    mt7615_roc_iter, phy);
mt7615_mutex_release(phy->dev);
```

### Consistent with Other Wireless Drivers

This mutex pattern is consistent with how other major wireless drivers handle `ieee80211_iterate_active_interfaces`:

- **Intel iwlwifi**: Uses `lockdep_assert_held(&mvm->mutex)` to verify the driver mutex is held
- **Atheros (ath9k/10k/11k/12k)**: Only uses the `_atomic` variant where callbacks don't need to sleep
- **TI wlcore**: Explicitly documents mutex requirements in comments

The mac80211 subsystem's `ieee80211_iterate_active_interfaces()` only protects the **interface list** with its internal mutex. It does **not** protect driver state.

## How to Apply These Patches

### Method 1: Apply to Kernel 6.19-rc4 (Recommended)

```bash
cd /path/to/linux-kernel-source
git checkout v6.19-rc4

# Apply all 18 patches
git am /path/to/mt7925/linux-6.19-rc4/*.patch

# Build with ccache for faster rebuilds
make CC="ccache gcc" -j$(nproc)
make CC="ccache gcc" modules -j$(nproc)
```

### Method 2: Build Module Only (Quick Test)

```bash
# Install kernel headers
sudo apt-get install linux-headers-$(uname -r)

# Get kernel source
apt-get source linux-image-$(uname -r)
cd linux-*/

# Apply patches (adjust paths for your kernel version)
for patch in /path/to/mt7925/linux-6.19-rc4/*.patch; do
    patch -p1 < "$patch" || echo "Patch may need manual adjustment: $patch"
done

# Build just the mt76 modules
make CC="ccache gcc" -j$(nproc) M=drivers/net/wireless/mediatek/mt76

# Unload old modules
sudo modprobe -r mt7925e mt7925_common mt792x_lib mt76_connac_lib mt76

# Load new modules
cd drivers/net/wireless/mediatek/mt76
sudo insmod mt76.ko
sudo insmod mt76-connac-lib.ko
sudo insmod mt792x-lib.ko
sudo insmod mt7925/mt7925-common.ko
sudo insmod mt7925/mt7925e.ko
```

### Using ccache for Faster Builds

Install and enable ccache:

```bash
# Install ccache
sudo apt install ccache

# Add to your shell rc file (~/.bashrc or ~/.zshrc)
export PATH="/usr/lib/ccache:$PATH"

# Build kernel with ccache
make CC="ccache gcc" -j$(nproc)

# Check ccache stats
ccache -s
```

## Verification

```bash
# Check module version (srcversion will be different from stock)
modinfo mt7925_common | grep srcversion

# Monitor kernel logs for errors
dmesg | grep -i mt7925

# Test WiFi connectivity
# Try switching between networks or disconnecting/reconnecting
# The system should no longer hang or panic
```

## Status

| Patch | Description | Status / Reference |
|-------|-------------|-------------------|
| 0001 | NULL pointer dereference fix | ✅ Submitted to LKML / [OpenWrt PR #1029](https://github.com/openwrt/mt76/pull/1029) |
| 0002 | Reset/ROC mutex fix          | ✅ Submitted to LKML / [OpenWrt PR #1029](https://github.com/openwrt/mt76/pull/1029) |
| 0003 | Runtime PM/MLO PM mutex fix  | ✅ Submitted to LKML / [OpenWrt PR #1029](https://github.com/openwrt/mt76/pull/1029) |
| 0004 | MCU STA TLV NULL checks      | ✅ [OpenWrt PR #1030](https://github.com/openwrt/mt76/pull/1030) |
| 0005 | Main.c link NULL checks      | ✅ [OpenWrt PR #1030](https://github.com/openwrt/mt76/pull/1030) |
| 0006 | AMPDU MCU error handling     | ✅ [OpenWrt PR #1031](https://github.com/openwrt/mt76/pull/1031) |
| 0007 | Station add BSS info error handling | ✅ [OpenWrt PR #1031](https://github.com/openwrt/mt76/pull/1031) |
| 0008 | Key setup BSS info error handling | ✅ [OpenWrt PR #1031](https://github.com/openwrt/mt76/pull/1031) |
| 0009 | MLO link/chanctx NULL checks | ✅ [OpenWrt PR #1032](https://github.com/openwrt/mt76/pull/1032) |
| 0010 | TX path NULL pointer fix (mt792x) | ✅ [OpenWrt PR #1033](https://github.com/openwrt/mt76/pull/1033) |
| 0011 | Lockdep assertions           | ✅ Submitted to LKML |
| 0012 | MLO roaming key removal fix  | ✅ Submitted to LKML |
| 0013 | MLO ROC setup warning fix    | ✅ Submitted to LKML |
| 0014 | MCU MLO link NULL checks     | ✅ Submitted to LKML |
| 0015 | Firmware reload fix (mt792x) | ✅ Submitted to LKML |
| 0016 | Resume path mutex fix        | ✅ Submitted to LKML |
| 0017 | sta_add/conf_tx NULL checks  | ✅ Submitted to LKML |
| 0018 | MT7921 mutex fixes           | ✅ Submitted to LKML |

## Tested Kernels

| Kernel | Status | Notes |
|--------|--------|-------|
| 6.18.2 (custom build) | ✅ Working | Stable with all patches |
| 6.19-rc4 | ✅ Building | 18 patches applied cleanly |
| 6.17.0 (Ubuntu) | ✅ Working | Tested with earlier patch set |

## Related Issues

- [Framework Community Forum Discussion](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
- [Ubuntu Launchpad Bug #2137291](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)
- [Linux Kernel Mailing List Thread](https://lore.kernel.org/all/CAA5_Hq7vNOy9oCGkkgyukq2OP=a5yL_3ZKBdmNtBXS+zp6byiQ@mail.gmail.com/T/#u)
- [OpenWrt mt76 Issue #1027](https://github.com/openwrt/mt76/issues/1027)

## Contributing

If you encounter issues or have improvements, please help by:
1. Testing the patches on your system
2. Reporting results in the [Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
3. Updating the [Ubuntu Launchpad bug](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291) with your findings

## License

These patches are provided under the same license as the Linux kernel (GPL v2).
