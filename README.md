# MediaTek MT7925 WiFi Driver Fixes

This repository contains critical fixes for the MediaTek MT7925 WiFi driver that resolve kernel panics and system deadlocks on Framework Desktop systems and other hardware using this WiFi card.

## ⚠️ Disclaimer

I am not an expert on the MediaTek mt76 driver codebase. These fixes were developed through analysis of kernel panics and deadlock traces on my Framework Desktop, cross-referencing with similar code patterns in other drivers, and from looking at traces reported by other folks on mailing lists suffering the same pain. However, based on the analysis below, these fixes appear sound and follow established patterns used by other wireless drivers in the kernel.

**These bugs have existed since the MT7925 driver was added to the kernel tree (late 2023 / early 2024).** Given that the alternative is kernel panics and system-wide deadlocks requiring hard reboots, these fixes represent a significant improvement.

## 📋 Known Issues

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for ongoing issues that are **partially mitigated** by these patches but likely have root causes in the MediaTek firmware itself, including:
- MCU timeout during MLO roaming
- Performance degradation compared to Intel cards
- Frequent deauthentication cycles

## Repository Structure

```
patches/
├── critical/           # Most important fixes - submitted to LKML
│   ├── 0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch
│   ├── 0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch
│   ├── 0003-wifi-mt76-mt7925-fix-missing-mutex-protection-in-run.patch
│   ├── 0010-wifi-mt76-mt792x-fix-NULL-pointer-dereference-in-TX-path.patch
│   ├── 0011-wifi-mt76-mt7925-add-lockdep-assertions-for-mutex-ve.patch
│   └── 0012-wifi-mt76-mt7925-fix-key-removal-failure-during-MLO-roaming.patch
├── null-checks/        # Additional defensive NULL checks (OpenWrt PR #1030, #1032)
│   ├── 0004-wifi-mt76-mt7925-add-NULL-checks-in-MCU-STA-TLV-functions.patch
│   ├── 0005-wifi-mt76-mt7925-add-NULL-checks-for-link_conf-and-mlink.patch
│   └── 0009-wifi-mt76-mt7925-add-NULL-checks-in-MLO-link-and-chanctx.patch
├── error-handling/     # MCU return value error checking
│   ├── 0006-wifi-mt76-mt7925-add-error-handling-for-AMPDU-MCU-commands.patch
│   ├── 0007-wifi-mt76-mt7925-add-error-handling-for-BSS-info-in-sta_add.patch
│   └── 0008-wifi-mt76-mt7925-add-error-handling-for-BSS-info-in-key-setup.patch
└── mt7921/             # Equivalent fixes for MT7921 (predecessor driver)
    └── 0001-wifi-mt76-mt7921-fix-missing-mutex-protection-in-mul.patch
```

## Problem Description

The MT7925 WiFi driver (mt7925e) has several related bugs that cause system instability:

1. **NULL Pointer Dereference**: Kernel panics occur when the driver attempts to reset after WiFi association failures or during state transitions.

2. **Mutex Deadlock in Reset/ROC Paths**: System-wide hangs occur during WiFi network switching, BSSID roaming, or firmware recovery.

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

The MT7925 driver was derived from MT7921 (previous generation chipset). **The MT7921 driver has identical bugs**:

- `mt7921_roc_abort_sync()` - missing mutex protection ❌
- `mt7921_set_runtime_pm()` - missing mutex protection ❌
- Similar patterns throughout the codebase

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

## Patches

### Critical Patches (patches/critical/)

#### Patch 1: NULL Pointer Dereference Fix

**File**: `0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch`

Adds NULL checks for `bss_conf` in all loops that iterate over `valid_links` and call `mt792x_vif_to_bss_conf()`.

**Functions fixed:**
- `mt7925_vif_connect_iter()` in mac.c
- `mt7925_mlo_pm_iter()` in main.c
- `mt7925_ipv6_addr_change()` in main.c
- `mt7925_vif_cfg_changed()` in main.c

#### Patch 2: Reset and ROC Mutex Fix

**File**: `0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch`

Adds mutex protection around interface iteration in reset and ROC abort paths.

**Functions/Paths fixed:**
- `mt7925_mac_reset_work()` in mac.c
- PCI suspend path in pci.c (wraps `mt7925_roc_abort_sync()` call)

**Important**: Mutex is added at the *call site* in pci.c rather than inside `roc_abort_sync()` to avoid self-deadlock when called from station remove path (which already holds mutex).

#### Patch 3: Runtime PM and MLO PM Mutex Fix

**File**: `0003-wifi-mt76-mt7925-fix-missing-mutex-protection-in-run.patch`

Fixes two additional code paths missing mutex protection.

**Functions fixed:**
- `mt7925_set_runtime_pm()` in main.c
- `mt7925_mlo_pm_work()` in main.c
- `mt7925_mlo_pm_iter()` in main.c (mutex moved from callback to caller)

#### Patch 10: TX Path NULL Pointer Fix (mt792x_core.c)

**File**: `0010-wifi-mt76-mt792x-fix-NULL-pointer-dereference-in-TX-path.patch`

**CRITICAL**: Fixes NULL pointer dereference in the shared TX path that affects both MT7921 and MT7925.

**What it fixes:**
- `mt792x_tx()` in mt792x_core.c - Check mlink before dereferencing wcid
- Check RCU-dereferenced conf and link_sta before use
- Prevents kernel crash when transmitting during link removal

This race occurs when:
1. A packet is queued for transmission
2. Concurrently, the link is being removed
3. `mt792x_sta_to_link()` returns NULL
4. Kernel crashes on `wcid = &mlink->wcid`

### Additional NULL Checks (patches/null-checks/)

**File**: `0003-wifi-mt76-mt7925-fix-missing-mutex-protection-in-run.patch`

Fixes two additional code paths missing mutex protection.

**Functions fixed:**
- `mt7925_set_runtime_pm()` in main.c
- `mt7925_mlo_pm_work()` in main.c
- `mt7925_mlo_pm_iter()` in main.c (mutex moved from callback to caller)

### Additional NULL Checks (patches/null-checks/)

#### Patch 4: MCU STA TLV NULL Checks

**File**: `0004-wifi-mt76-mt7925-add-NULL-checks-in-MCU-STA-TLV-functions.patch`

Adds NULL pointer checks in MCU station TLV building functions.

**Functions fixed:**
- `mt7925_mcu_sta_phy_tlv()` in mcu.c
- `mt7925_mcu_sta_rate_ctrl_tlv()` in mcu.c

#### Patch 5: Main.c Link NULL Checks

**File**: `0005-wifi-mt76-mt7925-add-NULL-checks-for-link_conf-and-mlink.patch`

Adds comprehensive NULL checks throughout main.c.

**Functions fixed:**
- `mt7925_set_key()` - Check link_conf, mconf, and mlink
- `mt7925_mac_link_sta_add()` - Check link_conf before BSS info update
- `mt7925_mac_link_sta_assoc()` - Check mlink and link_conf
- `mt7925_mac_link_sta_remove()` - Check mlink and link_conf
- `mt7925_change_vif_links()` - Check link_conf before adding BSS

#### Patch 9: MLO Link and Chanctx NULL Checks

**File**: `0009-wifi-mt76-mt7925-add-NULL-checks-in-MLO-link-and-chanctx.patch`

Adds NULL pointer checks in MLO link selection and channel context functions.

**Functions fixed:**
- `mt7925_mac_set_links()` - Check primary and secondary link_conf before band selection
- `mt7925_link_info_changed()` - Check mconf before getting link_conf (prevents chain dereference)
- `mt7925_assign_vif_chanctx()` - Check mconf before use, return -EINVAL if NULL
- `mt7925_unassign_vif_chanctx()` - Check mconf during MLO cleanup

### MCU Error Handling (patches/error-handling/)

#### Patch 6: AMPDU MCU Error Handling

**File**: `0006-wifi-mt76-mt7925-add-error-handling-for-AMPDU-MCU-commands.patch`

Checks return values of AMPDU (block aggregation) MCU commands.

**Functions fixed:**
- `mt7925_ampdu_action()` - Check `mt7925_mcu_uni_rx_ba()` and `mt7925_mcu_uni_tx_ba()` return values

**What it fixes:**
- Silent failures in block aggregation setup/teardown
- Inconsistent state between driver and firmware for aggregation

#### Patch 7: Station Add BSS Info Error Handling

**File**: `0007-wifi-mt76-mt7925-add-error-handling-for-BSS-info-in-sta_add.patch`

Checks return value of BSS info MCU command during station add.

**Functions fixed:**
- `mt7925_mac_link_sta_add()` - Check `mt7925_mcu_add_bss_info()` return value

**What it fixes:**
- Prevents station add from continuing if BSS info update fails
- Avoids inconsistent state where station exists without proper BSS config

#### Patch 8: Key Setup BSS Info Error Handling

**File**: `0008-wifi-mt76-mt7925-add-error-handling-for-BSS-info-in-key-setup.patch`

Checks return value of BSS info MCU command during cipher setup.

**Functions fixed:**
- `mt7925_set_key_link()` - Check `mt7925_mcu_add_bss_info()` when setting cipher

**What it fixes:**
- Prevents key programming if BSS cipher configuration fails
- Ensures encryption is properly configured before keys are programmed

## How to Apply These Patches

### Method 1: Apply to Full Kernel Source Tree

```bash
cd /path/to/linux-kernel-source

# Apply critical patches
git apply /path/to/mt7925/patches/critical/*.patch

# Optionally apply additional null-checks
git apply /path/to/mt7925/patches/null-checks/*.patch

# Build just the mt76 modules
make -j$(nproc) M=drivers/net/wireless/mediatek/mt76
```

### Method 2: Build and Load Module Only (Quick Test)

```bash
# Install kernel headers
sudo apt-get install linux-headers-$(uname -r)

# Get kernel source
apt-get source linux-image-$(uname -r)
cd linux-*/

# Apply patches
for patch in /path/to/mt7925/patches/critical/*.patch; do
    patch -p1 < "$patch"
done

# Build just the mt76 modules
make -j$(nproc) M=drivers/net/wireless/mediatek/mt76

# Unload old modules
sudo modprobe -r mt7925e mt7925_common

# Load new modules
sudo insmod drivers/net/wireless/mediatek/mt76/mt7925/mt7925-common.ko
sudo insmod drivers/net/wireless/mediatek/mt76/mt7925/mt7925e.ko

# Verify modules are loaded
lsmod | grep mt7925
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

## Stress Testing

This repository includes scripts to help validate the fixes by triggering the race conditions that cause crashes on unpatched kernels.

### Quick Start

```bash
# Monitor kernel logs in real-time (run in separate terminal)
sudo ./monitor.sh

# Run all stress tests (5 minutes total)
sudo ./stress-test.sh -s "YourSSID" -p "YourPassword" -d 300

# Run specific test types
sudo ./stress-test.sh -s "YourSSID" -p "YourPassword" -t roam -d 60
sudo ./stress-test.sh -s "YourSSID" -p "YourPassword" -t reconnect -d 60
sudo ./stress-test.sh -t scan -d 60  # No credentials needed for scan test
```

### Available Tests

| Test | Description | Triggers |
|------|-------------|----------|
| `scan` | Rapid WiFi scan start/abort cycles | Race conditions in scan state machine |
| `reconnect` | Connect/disconnect cycles | `vif_connect_iter()` NULL dereference |
| `roam` | Force BSSID roaming (needs multiple APs) | MLO link state transitions |
| `suspend` | Suspend/resume cycles | PM path races |
| `interface` | Interface up/down cycles | Driver initialization races |
| `combined` | Mix of all operations | Multiple race conditions |
| `all` | Run all tests sequentially | Comprehensive coverage |

### Test Options

```
-i, --interface IFACE   WiFi interface (default: auto-detect)
-s, --ssid SSID         Target SSID for connection tests
-p, --password PASS     WiFi password
-d, --duration SECS     Test duration in seconds (default: 300)
-t, --test TEST         Test type: all|roam|reconnect|suspend|scan|interface|combined
-v, --verbose           Verbose output
-l, --log FILE          Log file (default: /tmp/mt7925-stress.log)
--dry-run               Show what would be done without executing
```

### Expected Results

- **Unpatched kernel**: Expect kernel panics within minutes, especially during roam and reconnect tests
- **Patched kernel**: All tests should complete without kernel errors

### Interpreting Results

The stress test monitors `dmesg` for errors. Check the log file for:
```bash
cat /tmp/mt7925-stress.log | grep -i error
```

If you see NULL pointer dereferences or BUG messages, the driver needs patching.

## Status

All patches have been submitted upstream to the [OpenWrt mt76 repository](https://github.com/openwrt/mt76).

### MT7925 Patches

| Patch | Description | Status |
|-------|-------------|--------|
| 0001 | NULL pointer dereference fix | ✅ Submitted to LKML and [OpenWrt PR #1029](https://github.com/openwrt/mt76/pull/1029) |
| 0002 | Reset/ROC mutex fix | ✅ Submitted to LKML and [OpenWrt PR #1029](https://github.com/openwrt/mt76/pull/1029) |
| 0003 | Runtime PM/MLO PM mutex fix | ✅ Submitted to LKML and [OpenWrt PR #1029](https://github.com/openwrt/mt76/pull/1029) |
| 0004 | MCU STA TLV NULL checks | ✅ Submitted to LKML and [OpenWrt PR #1030](https://github.com/openwrt/mt76/pull/1030) |
| 0005 | Main.c link NULL checks | ✅ Submitted to LKML and [OpenWrt PR #1030](https://github.com/openwrt/mt76/pull/1030) |
| 0006 | AMPDU MCU error handling | ✅ Submitted to LKML and [OpenWrt PR #1031](https://github.com/openwrt/mt76/pull/1031) |
| 0007 | Station add BSS info error handling | ✅ Submitted to LKML and [OpenWrt PR #1031](https://github.com/openwrt/mt76/pull/1031) |
| 0008 | Key setup BSS info error handling | ✅ Submitted to LKML and [OpenWrt PR #1031](https://github.com/openwrt/mt76/pull/1031) |
| 0009 | MLO link/chanctx NULL checks | ✅ Submitted to LKML and [OpenWrt PR #1032](https://github.com/openwrt/mt76/pull/1032) |
| 0010 | TX path NULL pointer fix (mt792x) | ✅ Submitted to LKML and [OpenWrt PR #1033](https://github.com/openwrt/mt76/pull/1033) |
| 0011 | lockdep assertions for debugging | ✅ Submitted to LKML and [OpenWrt PR #1035](https://github.com/openwrt/mt76/pull/1035) |
| 0012 | Key removal failure during MLO roaming | ✅ [OpenWrt PR #1037](https://github.com/openwrt/mt76/pull/1037) |

### MT7921 Patches

The MT7921 driver (predecessor to MT7925) has the same mutex bugs. These were inherited when MT7925 was forked.

| Patch | Description | Status |
|-------|-------------|--------|
| 0001 | Missing mutex protection in multiple paths | ✅ [OpenWrt PR #1034](https://github.com/openwrt/mt76/pull/1034) |

## Related Issues

- [Framework Community Forum Discussion](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
- [Ubuntu Launchpad Bug #2137291](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)
- [Linux Kernel Mailing List Thread](https://lore.kernel.org/all/CAA5_Hq7vNOy9oCGkkgyukq2OP=a5yL_3ZKBdmNtBXS+zp6byiQ@mail.gmail.com/T/#u)
- [OpenWrt mt76 Issue #1027](https://github.com/openwrt/mt76/issues/1027)
- [OpenWrt mt76 Issue #1036](https://github.com/openwrt/mt76/issues/1036) - MLO roaming firmware hang (partially mitigated)

## Contributing

If you encounter issues or have improvements, please help by:
1. Testing the patches on your system
2. Reporting results in the [Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
3. Updating the [Ubuntu Launchpad bug](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291) with your findings

## License

These patches are provided under the same license as the Linux kernel (GPL v2) and BSD 3-Clause.
