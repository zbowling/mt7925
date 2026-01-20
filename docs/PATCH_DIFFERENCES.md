# MT7925 Patch Differences Between Kernel Versions

This document explains how the MT76/MT7925 driver differs between kernel versions and how our patches are adapted for each.

## Overview

The MT7925 WiFi 7 driver is part of the mt76 driver family in the Linux kernel. As the kernel evolves, the driver code changes, requiring patches to be adapted for each version.

## Patch Series (v6 - With Sean Wang's Deadlock Fix)

Our patch series consists of **12 patches** - Sean Wang's upstream deadlock fix as the base, followed by 11 stability/safety patches.

### Patch List

| # | Patch Title | Subsystem | Description |
|---|-------------|-----------|-------------|
| 01 | fix potential deadlock in mt7925_roc_abort_sync | mt7925 | Sean Wang's fix: cancel_work() instead of cancel_work_sync() |
| 02 | fix list corruption in mt76_wcid_cleanup | mt76 core | Fixes sta_poll_list corruption after reset |
| 03 | fix NULL pointer and firmware reload issues | mt792x shared | NULL checks in TX path + firmware reload fix |
| 04 | add mutex protection in critical paths | mt7921 | Mutex fixes for reset/ROC/PM paths |
| 05 | fix deadlock in sta removal and suspend ROC abort | mt7921 | Async ROC abort for deadlock prevention |
| 06 | add comprehensive NULL pointer protection for MLO | mt7925 | NULL checks for link structures in MLO |
| 07 | add mutex protection in critical paths | mt7925 | Mutex fixes for reset/ROC/PM/resume paths |
| 08 | add MCU command error handling | mt7925 | Error checking for AMPDU/BSS MCU commands |
| 09 | add lockdep assertions for mutex verification | mt7925 | Debug assertions for mutex verification |
| 10 | fix MLO roaming and ROC setup issues | mt7925 | Key removal fix + ROC setup warning fix |
| 11 | fix BA session teardown during beacon loss | mt7925 | Race condition fix in BA teardown |
| 12 | fix ROC deadlocks and race conditions | mt7925 | Comprehensive ROC state machine fixes |

### Patch Order

Patches are ordered by subsystem dependency:
```
Sean's fix (base) → mt76 core → mt792x shared → mt7921 → mt7925
```

This ensures each patch builds on prior changes and can be applied incrementally.

## Supported Kernel Versions

| Version | Tag | Patches | Status |
|---------|-----|---------|--------|
| 6.17.x | v6.17.13 | 12 patches | EOL but still used (Fedora 41, older Arch) |
| 6.18.x | v6.18.5 | 12 patches | **Current stable** - Arch, Fedora 42 |
| 6.19-rcX | v6.19-rc5 | 12 patches | Release candidate - bleeding edge |
| nbd168 | wireless-next | 12 patches | OpenWRT staging tree (upstream target) |

## Key Differences Between Versions

### Function Renames

The primary difference between kernel versions is function naming:

| Function | 6.17.x / 6.18.x | 6.19-rc / nbd168 |
|----------|-----------------|------------------|
| Regulatory update | `mt7925_regd_update(dev)` | `mt7925_mcu_regd_update(dev, alpha2, env)` |
| Regulatory reset | `mt7925_regd_update(dev)` | `mt7925_regd_change(&dev->phy, "00")` |
| Link selection | `mt7925_mac_select_links(mdev, vif)` | `mt76_select_links(vif, 2)` |

### Affected Patches

**Patch 06** (NULL pointer protection for MLO) differs in link selection:
- 6.17/6.18: Uses `mt7925_mac_select_links(mdev, vif)` in `mt7925_mac_set_links()`
- 6.19/nbd168: Uses `mt76_select_links(vif, 2)`

**Patch 07** (mt7925 mutex protection) differs in regulatory functions:
- 6.17/6.18: Uses `mt7925_regd_update(dev)` in pci.c resume and mac.c reset
- 6.19/nbd168: Uses `mt7925_mcu_regd_update(dev, mdev->alpha2, dev->country_ie_env)` and `mt7925_regd_change(&dev->phy, "00")`

### All Other Patches

All other patches (01-05, 08-12) apply uniformly across kernel versions with only minor context adjustments (line numbers, surrounding code).

## Patch Categories

### Critical Fixes (Patches 01, 02, 03, 05, 11, 12)

These fix crashes and deadlocks:

- **01**: Sean's fix preventing deadlock in ROC abort (cancel_work vs cancel_work_sync)
- **02**: List corruption causing crashes after device reset
- **03**: NULL pointer dereference in TX path during MLO transitions
- **05**: Deadlock when ROC abort called while holding mutex
- **11**: Race condition between BA teardown and beacon loss
- **12**: Multiple ROC state machine issues causing hangs

### Safety Improvements (Patches 04, 06, 07, 08)

These add defensive checks and proper synchronization:

- **04/07**: Mutex protection around `ieee80211_iterate_*` calls
- **06**: NULL checks before dereferencing MLO link pointers
- **08**: Error checking for MCU command return values

### Debug/Maintenance (Patches 09, 10)

- **09**: Lockdep assertions (only active with CONFIG_LOCKDEP)
- **10**: MLO roaming edge cases and warning fixes

## Files Modified

### mt76 Core
| File | Patch | Change |
|------|-------|--------|
| `mac80211.c` | 02 | Remove from sta_poll_list in wcid_cleanup |
| `mt76.h` | 12 | MT76_STATE_ROC_ABORT flag |

### mt792x Shared (MT7921 + MT7925)
| File | Patch | Change |
|------|-------|--------|
| `mt792x_core.c` | 03 | NULL checks in TX, firmware reload fix |
| `mt792x.h` | 03, 12 | ROC rate limiting structures, abort flag |

### MT7921
| File | Patch | Change |
|------|-------|--------|
| `mt7921/main.c` | 04, 05 | Mutex protection, async ROC abort |
| `mt7921/mac.c` | 04 | Mutex in reset work |
| `mt7921/pci.c` | 04, 05 | Remove incorrect mutex wrappers |
| `mt7921/sdio.c` | 05 | Remove incorrect mutex wrappers |

### MT7925
| File | Patch | Change |
|------|-------|--------|
| `mt7925/main.c` | 01, 06-12 | ROC fix, NULL checks, mutex, error handling |
| `mt7925/mac.c` | 06, 07 | NULL checks, mutex in reset/assoc |
| `mt7925/mcu.c` | 06, 09, 10 | NULL checks, lockdep, ROC setup |
| `mt7925/pci.c` | 07 | Mutex in resume path |

## How to Port Patches to New Kernel Versions

When a new kernel is released:

1. **Start from the closest version** (usually nbd168 for upstream):
   ```bash
   cd linux-wifi
   git checkout -B mt7925-upstream-v2-NEW nbd168/mt76  # or vX.Y.Z
   ```

2. **Cherry-pick Sean's fix first** (if not in upstream):
   ```bash
   git cherry-pick mt7925-upstream-v2~11  # Sean's fix commit
   ```

3. **Cherry-pick the remaining 11 patches**:
   ```bash
   git cherry-pick mt7925-upstream-v2~10..mt7925-upstream-v2
   ```

4. **Resolve any conflicts**:
   - Check function names (regulatory, link selection)
   - Use kernel version's naming convention
   - Keep the logic/fix identical

5. **Export patches**:
   ```bash
   git format-patch vX.Y.Z..HEAD -o ../mt7925/kernels/X.Y/
   ```

6. **Update this document** with any new differences found.

## Upstream Submission

The 12-patch series is designed for upstream submission to:

1. **nbd168/wireless** (Felix Fietkau's staging tree) - Primary target
2. **linux-wireless mailing list** - For mainline inclusion
3. **OpenWRT mt76** - Community driver repository

Patch 01 (Sean Wang's fix) is already in the upstream queue.

## See Also

- [zbowling/linux-wifi](https://github.com/zbowling/linux-wifi) - Fork with pre-applied patches
- [mt76 upstream](https://github.com/openwrt/mt76) - OpenWRT/nbd168 mt76 repository
- [LKML archives](https://lkml.org) - Linux kernel mailing list for patch discussions
