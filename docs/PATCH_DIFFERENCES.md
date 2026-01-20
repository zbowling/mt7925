# MT7925 Patch Differences Between Kernel Versions

This document explains how the MT76/MT7925 driver differs between kernel versions and how our patches are adapted for each.

## Overview

The MT7925 WiFi 7 driver is part of the mt76 driver family in the Linux kernel. As the kernel evolves, the driver code changes, requiring patches to be adapted for each version.

## Patch Series (v2 - Reorganized)

Our patch series has been reorganized from 27 individual fixes into **11 cleaner, logically-grouped patches** for easier upstream review.

### Patch List

| # | Patch Title | Subsystem | Description |
|---|-------------|-----------|-------------|
| 01 | fix list corruption in mt76_wcid_cleanup | mt76 core | Fixes sta_poll_list corruption after reset |
| 02 | fix NULL pointer and firmware reload issues | mt792x shared | NULL checks in TX path + firmware reload fix |
| 03 | add mutex protection in critical paths | mt7921 | Mutex fixes for reset/ROC/PM paths |
| 04 | fix deadlock in sta removal and suspend ROC abort | mt7921 | Async ROC abort for deadlock prevention |
| 05 | add comprehensive NULL pointer protection for MLO | mt7925 | NULL checks for link structures in MLO |
| 06 | add mutex protection in critical paths | mt7925 | Mutex fixes for reset/ROC/PM/resume paths |
| 07 | add MCU command error handling | mt7925 | Error checking for AMPDU/BSS MCU commands |
| 08 | add lockdep assertions for mutex verification | mt7925 | Debug assertions for mutex verification |
| 09 | fix MLO roaming and ROC setup issues | mt7925 | Key removal fix + ROC setup warning fix |
| 10 | fix BA session teardown during beacon loss | mt7925 | Race condition fix in BA teardown |
| 11 | fix ROC deadlocks and race conditions | mt7925 | Comprehensive ROC state machine fixes |

### Patch Order

Patches are ordered by subsystem dependency:
```
mt76 core → mt792x shared → mt7921 → mt7925
```

This ensures each patch builds on prior changes and can be applied incrementally.

## Supported Kernel Versions

| Version | Tag | Patches | Status |
|---------|-----|---------|--------|
| 6.17.x | v6.17.13 | 11 patches | EOL but still used (Fedora 41, older Arch) |
| 6.18.x | v6.18.5 | 11 patches | **Current stable** - Arch, Fedora 42 |
| 6.19-rcX | v6.19-rc5 | 11 patches | Release candidate - bleeding edge |
| nbd168 | wireless-next | 11 patches | OpenWRT staging tree (upstream target) |

## Key Differences Between Versions

### Function Renames

The primary difference between kernel versions is function naming:

| Function | 6.17.x / 6.18.x | 6.19-rc / nbd168 |
|----------|-----------------|------------------|
| Regulatory update | `mt7925_regd_update(dev)` | `mt7925_mcu_regd_update(dev, alpha2, env)` |
| Link selection | `mt7925_mac_select_links(mdev, vif)` | `mt76_select_links(vif, 2)` |

### Affected Patches

**Patch 06** (mt7925 mutex protection) differs between versions:
- 6.17/6.18: Uses `mt7925_regd_update(dev)` in pci.c resume path
- 6.19/nbd168: Uses `mt7925_mcu_regd_update(dev, mdev->alpha2, dev->country_ie_env)`

**Patch 05** (NULL pointer protection) differs in 6.17:
- 6.17: Uses `mt7925_mac_select_links(mdev, vif)` in `mt7925_mac_set_links()`
- 6.18+: Uses `mt76_select_links(vif, 2)`

### All Other Patches

All other patches apply uniformly across kernel versions with only minor context adjustments (line numbers, surrounding code).

## Patch Categories

### Critical Fixes (Patches 01, 02, 04, 10, 11)

These fix crashes and deadlocks:

- **01**: List corruption causing crashes after device reset
- **02**: NULL pointer dereference in TX path during MLO transitions
- **04**: Deadlock when ROC abort called while holding mutex
- **10**: Race condition between BA teardown and beacon loss
- **11**: Multiple ROC state machine issues causing hangs

### Safety Improvements (Patches 03, 05, 06, 07)

These add defensive checks and proper synchronization:

- **03/06**: Mutex protection around `ieee80211_iterate_*` calls
- **05**: NULL checks before dereferencing MLO link pointers
- **07**: Error checking for MCU command return values

### Debug/Maintenance (Patches 08, 09)

- **08**: Lockdep assertions (only active with CONFIG_LOCKDEP)
- **09**: MLO roaming edge cases and warning fixes

## Files Modified

### mt76 Core
| File | Patch | Change |
|------|-------|--------|
| `mac80211.c` | 01 | Remove from sta_poll_list in wcid_cleanup |

### mt792x Shared (MT7921 + MT7925)
| File | Patch | Change |
|------|-------|--------|
| `mt792x_core.c` | 02 | NULL checks in TX, firmware reload fix |
| `mt792x.h` | 02, 11 | ROC rate limiting structures, abort flag |

### MT7921
| File | Patch | Change |
|------|-------|--------|
| `mt7921/main.c` | 03, 04 | Mutex protection, async ROC abort |
| `mt7921/mac.c` | 03 | Mutex in reset work |
| `mt7921/pci.c` | 03, 04 | Remove incorrect mutex wrappers |
| `mt7921/sdio.c` | 04 | Remove incorrect mutex wrappers |

### MT7925
| File | Patch | Change |
|------|-------|--------|
| `mt7925/main.c` | 05-11 | NULL checks, mutex, error handling, ROC fixes |
| `mt7925/mac.c` | 05, 06 | NULL checks, mutex in reset/assoc |
| `mt7925/mcu.c` | 05, 08, 09 | NULL checks, lockdep, ROC setup |
| `mt7925/pci.c` | 06 | Mutex in resume path |
| `mt76.h` | 11 | MT76_STATE_ROC_ABORT flag |

## How to Port Patches to New Kernel Versions

When a new kernel is released:

1. **Start from the closest version** (usually nbd168 for upstream):
   ```bash
   cd linux-wifi
   git checkout -B mt7925-upstream-v2-NEW nbd168/mt76  # or vX.Y.Z
   ```

2. **Cherry-pick from the nbd168 branch**:
   ```bash
   git cherry-pick mt7925-upstream-v2~10..mt7925-upstream-v2
   ```

3. **Resolve any conflicts**:
   - Check function names (regulatory, link selection)
   - Use kernel version's naming convention
   - Keep the logic/fix identical

4. **Export patches**:
   ```bash
   git format-patch vX.Y.Z..HEAD -o ../mt7925/kernels/X.Y/
   ```

5. **Update this document** with any new differences found.

## Upstream Submission

The reorganized 11-patch series is designed for upstream submission to:

1. **nbd168/wireless** (Felix Fietkau's staging tree) - Primary target
2. **linux-wireless mailing list** - For mainline inclusion
3. **OpenWRT mt76** - Community driver repository

## See Also

- [zbowling/linux-wifi](https://github.com/zbowling/linux-wifi) - Fork with pre-applied patches
- [mt76 upstream](https://github.com/openwrt/mt76) - OpenWRT/nbd168 mt76 repository
- [LKML archives](https://lkml.org) - Linux kernel mailing list for patch discussions
