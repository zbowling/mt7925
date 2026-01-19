# MT7925 Patch Differences Between Kernel Versions

This document explains how the MT76/MT7925 driver differs between kernel versions and how our patches are adapted for each.

## Overview

The MT7925 WiFi 7 driver is part of the mt76 driver family in the Linux kernel. As the kernel evolves, the driver code changes, requiring patches to be adapted for each version.

## Supported Kernel Versions

| Version | Tag | Patches | Status |
|---------|-----|---------|--------|
| 6.17.x | v6.17.13 | 25 patches | EOL but still used (Fedora 41, older Arch) |
| 6.18.x | v6.18.5 | 26 patches | **Current stable** - Arch, Fedora 42 |
| 6.19-rcX | v6.19-rc5 | 27 patches | Release candidate - bleeding edge |
| nbd168 | wireless-next | 26 patches | OpenWRT staging tree |

## Key Differences Between Versions

### 6.17.x vs 6.18.x

1. **MLO Chanctx Functions** (patch 0009 on 6.18)
   - 6.17 lacks some MLO chanctx code that was added in 6.18
   - The `mt7925_mlo_add_chanctx` and related functions were refactored
   - **Result**: 6.17 missing 1 patch

2. **Error Handling Consolidation** (patch 0024 on 6.18)
   - 6.18 has a consolidated error handling cleanup patch
   - 6.17 doesn't need this patch (different code structure)
   - **Result**: 6.17 missing 1 patch

3. **MT7921 Mutex Patches**
   - 6.17: Two separate patches (0016 + 0018)
   - 6.18: Combined into one patch (0018)
   - **Result**: 6.17 has 1 extra patch

**Net difference**: 6.17 has 25 patches, 6.18 has 26 patches (-2 +1 = -1)

### 6.18.x vs 6.19-rc

1. **MT7921 Mutex Patches**
   - 6.18: Combined into one patch (0018)
   - 6.19-rc: Two separate patches (0015 + 0019)
   - **Result**: 6.19-rc has 1 extra patch

2. **Regulatory Domain Update Function**
   - 6.18 uses: `mt7925_regd_update(dev)`
   - 6.19-rc uses: `mt7925_mcu_regd_update(dev, mdev->alpha2, dev->country_ie_env)`
   - The function was renamed and now takes additional parameters
   - **Impact**: Resume path mutex patch differs in implementation

3. **Reset Work Function**
   - 6.18: `mt7925_regd_update(&dev->phy, "00")`
   - 6.19-rc: `mt7925_regd_change(&dev->phy, "00")`
   - Function renamed from `_update` to `_change`

4. **Patch Ordering**
   - Due to different code structure, patches are numbered differently
   - Same fixes, different application order

**Net difference**: 6.18 has 26 patches, 6.19-rc has 27 patches (+1)

## Patch Categories

### NULL Pointer Checks
These patches add defensive NULL checks before dereferencing pointers, particularly for MLO (Multi-Link Operation) link structures:

- `mt792x_sta_to_link()` - Station to link conversion
- `mt792x_vif_to_link()` - VIF to link conversion
- `msta->deflink` - Default link pointer
- `link_conf` - Link configuration

**Applies uniformly** across all kernel versions with minor line number adjustments.

### Mutex Protection
These patches add `mt792x_mutex_acquire()/release()` around `ieee80211_iterate_*` calls:

| Location | 6.17 | 6.18 | 6.19-rc |
|----------|------|------|---------|
| mac.c reset work | Patch 17 | Patch 02 | Patch 16 |
| main.c runtime PM | Patch 02 | Patch 03 | Patch 17 |
| pci.c resume path | Patch 14 | Patch 16 | Patch 18 |
| mt7921 ROC/PM | Patch 16 | Patch 18 | Patch 15 |

### Error Handling
These patches add proper error checking for MCU command responses:

- AMPDU MCU commands
- BSS info MCU commands
- Key setup operations

**Applies uniformly** with context adjustments.

### Lockdep Assertions
Debug assertions to verify mutex is held when expected. Uniform across versions.

### ROC (Remain On Channel) Fixes
Critical fixes for ROC state machine issues:

- **ROC Timer Race During Suspend** (patch 22/23): Cancels ROC timer and work in `mt7925_suspend()` before mac80211 finishes quiescing, preventing warnings and inconsistent state on resume.

- **Deadlock in STA Removal ROC Abort** (patch 21/22): Fixes potential deadlock in `mt7925_sta_remove_links()` where `mt7925_abort_roc()` was called without proper mutex handling.

- **ROC Rate Limiting** (patch 23/24): Adds exponential backoff rate limiting for ROC commands to prevent MCU overload during rapid reconnection cycles (especially MLO authentication failures).

- **ROC Work Deadlock** (patch 24/25): Moves `cancel_work_sync(&phy->roc_work)` from inside `mt7925_set_roc()` to callers BEFORE mutex acquisition, preventing deadlock when roc_work is waiting for the mutex.

### Resource Leak Fixes
- **WCID Table Leak** (patch 24/25): Adds proper error cleanup path in `mt7925_mac_link_sta_add()` that clears the wcid pointer and frees the allocated index on failure, preventing WCID table exhaustion.

- **List Corruption in WCID Cleanup** (patch 20): Fixes `mt76_wcid_cleanup()` to remove entries from `sta_poll_list` before reset, preventing list corruption when `mt76_wcid_add_poll()` later tries to add the entry back.

### BA Session Handling
- **BA Session Teardown During Beacon Loss** (patch 21): Fixes race condition between BA session teardown and beacon loss handling that could cause system hangs.

## How to Port Patches to New Kernel Versions

When a new kernel is released:

1. **Sparse checkout the kernel source**:
   ```bash
   git clone --depth 1 --filter=blob:none --sparse \
     https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
     -b vX.Y.Z linux-src
   cd linux-src
   git sparse-checkout set drivers/net/wireless/mediatek/mt76
   ```

2. **Apply patches from closest version**:
   ```bash
   # Try 6.18 patches first for stable releases
   git am ../kernels/6.18/*.patch
   ```

3. **Fix any conflicts**:
   - Check function names - MediaTek renames functions between releases
   - Check line numbers - code moves around
   - Use `git apply --reject` to see what fails

4. **Common issues**:
   - Function renamed → grep for similar names
   - Context mismatch → read the actual file and apply fix manually
   - File moved → check git log for renames

5. **Export clean patches**:
   ```bash
   git format-patch vX.Y.Z..HEAD -o ../kernels/X.Y/
   ```

6. **Validate**:
   ```bash
   ./scripts/validate-patches.sh X.Y
   ```

## File Reference

### Primary Files Modified

| File | Purpose |
|------|---------|
| `mt7925/main.c` | Main driver callbacks, runtime PM, interface iteration |
| `mt7925/mac.c` | MAC layer, reset handling, TX path |
| `mt7925/mcu.c` | MCU command handling, firmware communication |
| `mt7925/pci.c` | PCIe bus interface, suspend/resume |
| `mt792x_core.c` | Shared MT7921/MT7925 code |
| `mt7921/main.c` | MT7921 driver (affected by shared mutex fixes) |
| `mt7921/mac.c` | MT7921 MAC layer |

### Key Functions Patched

| Function | File | Fix Type |
|----------|------|----------|
| `mt7925_mac_reset_work` | mac.c | Mutex protection |
| `mt7925_set_runtime_pm` | main.c | Mutex protection |
| `mt7925_mlo_pm_work` | main.c | Mutex protection |
| `_mt7925_pci_resume` | pci.c | Mutex protection |
| `mt7925_mac_link_sta_add` | main.c | NULL checks, WCID leak fix |
| `mt7925_conf_tx` | main.c | NULL checks |
| `mt76_connac_mcu_sta_tlv` | mcu.c | NULL checks |
| `mt7925_set_roc` | main.c | Deadlock fix, rate limiting |
| `mt7925_set_mlo_roc` | main.c | Deadlock fix, rate limiting |
| `mt7925_remain_on_channel` | main.c | Deadlock fix |
| `mt7925_mgd_prepare_tx` | main.c | Deadlock fix |
| `mt7925_change_vif_links` | main.c | Deadlock fix |
| `mt7925_suspend` | main.c | ROC timer race fix |
| `mt7925_sta_remove_links` | main.c | ROC abort deadlock |
| `mt76_wcid_cleanup` | mac80211.c | List corruption fix |
| Various MLO functions | main.c, mcu.c | NULL checks |

## Testing

After porting patches:

1. **Apply test**: `git apply --check *.patch`
2. **Build test**: Compile the module against target kernel
3. **Load test**: Load module and check dmesg for warnings
4. **Functional test**: Connect to WiFi, check stability

## Upstream Status

These patches address issues found in production use. Some have been submitted to LKML (Linux Kernel Mailing List). Check the individual patch files for upstream submission status in their commit messages.

## See Also

- [zbowling/linux-wifi](https://github.com/zbowling/linux-wifi) - Fork with pre-applied patches
- [mt76 upstream](https://github.com/openwrt/mt76) - OpenWRT/nbd168 mt76 repository
- [LKML archives](https://lkml.org) - Linux kernel mailing list for patch discussions
