# MT7925 Driver Lock Audit

## Overview

This document provides a comprehensive audit of mutex usage in the MT7925 WiFi driver,
including all lock acquisition points, work functions, and potential deadlock scenarios.

**Primary Lock:** `dev->mt76.mutex` (accessed via `mt792x_mutex_acquire`/`mt792x_mutex_release`)

---

## Work Functions and Their Lock Requirements

### Work Functions That ACQUIRE the Mutex

| Work Function | File | Line | Lock Acquired |
|---------------|------|------|---------------|
| `mt7925_mac_reset_work` | mac.c | 1311 | `mutex_lock(&dev->mt76.mutex)` in for loop |
| `mt7925_mac_reset_work` | mac.c | 1334 | `mt792x_mutex_acquire(dev)` after reset |
| `mt7925_roc_work` | main.c | 471 | `mt792x_mutex_acquire(phy->dev)` |
| `mt7925_mlo_pm_work` | main.c | 1359 | `mt792x_mutex_acquire(dev)` |
| `mt7925_set_ipv6_ns_work` | mac.c | 1494 | `mt792x_mutex_acquire(dev)` |

### Work Functions That DO NOT Acquire the Mutex

| Work Function | File | Line | Notes |
|---------------|------|------|-------|
| `mt7925_scan_work` | main.c | 1380 | Uses only `spin_lock_bh(&dev->mt76.lock)` |
| `mt7925_coredump_work` | mac.c | 1343 | Coredump processing only |
| `mt7925_init_work` | init.c | 290 | Initialization sequence |
| `mt7925_stats_work` | (inherited) | - | Statistics gathering |

---

## Functions That Call cancel_work_sync

### MT7925-Specific cancel_work_sync Calls

| Function | File:Line | Work Cancelled | Context |
|----------|-----------|----------------|---------|
| `mt7925_roc_abort_sync` | main.c:453 | `roc_work` | Can be called with or without mutex |
| `mt7925_abort_roc` | main.c:485 | `roc_work` | Acquires mutex AFTER cancel |
| `mt7925_mac_reset_work` | mac.c:1306-1308 | `mac_work`, `ps_work`, `wake_work` | Called BEFORE mutex acquired |
| `mt7925_pci_suspend` | pci.c:454-455 | `ps_work`, `wake_work` | Before mutex (our patch wraps roc_abort) |
| `mt7925e_remove` | pci.c:39-45 | `init_work`, `ps_work`, `wake_work`, `reset_work` | Device removal |

### MT792x Core cancel_work_sync Calls

| Function | File:Line | Work Cancelled | Context |
|----------|-----------|----------------|---------|
| `mt792x_stop` | mt792x_core.c:156-160 | `mac_work`, `ps_work`, `wake_work`, `reset_work` | Called WITHOUT mutex |
| `mt792x_unassign_vif_chanctx` | mt792x_core.c:375 | `csa_work` | Called AFTER mutex released |

---

## Mutex Acquisition Points in MT7925

### main.c

| Function | Line | Acquire | Release | Notes |
|----------|------|---------|---------|-------|
| `mt7925_start` | 342 | 342 | 344 | Simple wrap of __mt7925_start |
| `mt7925_add_interface` | 420 | 420 | 434 | VIF addition |
| `mt7925_roc_work` | 471 | 471 | 475 | **WORK FUNCTION** - acquires mutex |
| `mt7925_abort_roc` | 487 | 487 | 490 | After cancel_work_sync |
| `mt7925_set_channel` | 562 | 562 | 565 | Channel change |
| `mt7925_set_key` | 691 | 691 | 708 | Key management |
| `mt7925_config` | 759 | 759 | 763 | Configuration |
| `mt7925_configure_filter` | 773 | 773 | 788 | Filter setup |
| `mt7925_bss_info_changed` | 814 | 814 | 816 | BSS info |
| `mt7925_mac_link_sta_assoc` | 1066 | 1066 | 1091 | STA association |
| `mt7925_set_rts_threshold` | 1263 | 1263 | 1265 | RTS threshold |
| `mt7925_ampdu_action` | 1289 | 1289 | 1327 | AMPDU actions |
| `mt7925_mlo_pm_work` | 1359 | 1359 | 1363 | **WORK FUNCTION** - MLO PM |
| `mt7925_hw_scan` | 1461-1476 | varies | varies | HW scan start |
| `mt7925_cancel_hw_scan` | 1488 | 1488 | 1496 | HW scan cancel |
| `mt7925_sched_scan_start` | 1508-1510 | 1508 | 1510 | Sched scan |
| `mt7925_sched_scan_stop` | 1529 | 1529 | 1538 | Sched scan stop |
| `mt7925_ops_suspend` | 1556 | 1556 | 1564 | Suspend path |
| `mt7925_ops_resume` | 1574 | 1574 | 1585 | Resume path |
| `mt7925_set_rekey_data` | 1596 | 1596 | 1598 | Rekey data |
| `mt7925_flush` | 1616 | 1616 | 1636 | TX flush |
| `mt7925_set_sar_specs` | 1737-1739 | 1737 | 1739 | SAR specs |
| `mt7925_set_antenna` | 1751 | 1751 | 1753 | Antenna config |
| `mt7925_get_tsf` | 1787 | 1787 | 1801 | TSF get |
| `mt7925_set_tsf` | 1814 | 1814 | 1824 | TSF set |
| `mt7925_vif_cfg_changed` | 1858 | 1858 | 1890 | VIF config |
| `mt7925_link_info_changed` | 1902 | 1902 | 1906 | Link info |
| `mt7925_change_sta_links` | 1929-1968 | 1929 | 1968 | STA links |
| `mt7925_change_vif_links` | 1990-2034 | 1990 | 2034 | VIF links |
| `mt7925_assign_vif_chanctx` | 2056-2146 | 2056 | varies | Channel context |
| `mt7925_unassign_vif_chanctx` | 2163 | 2163 | 2174 | Channel context |
| `mt7925_chanctx_pre_switch` | 2190-2211 | 2190 | 2211 | Direct mutex_lock |
| `mt7925_chanctx_post_switch` | 2226-2245 | 2226 | 2245 | Direct mutex_lock |
| `mt7925_mgd_prepare_tx` | 2253 | 2253 | 2255 | Management TX |

### mac.c

| Function | Line | Acquire | Release | Notes |
|----------|------|---------|---------|-------|
| `mt7925_mac_reset_work` | 1311 | 1311 | 1313 | In for loop (10 iterations) |
| `mt7925_mac_reset_work` | 1334 | 1334 | 1340 | Around interface iteration |
| `mt792x_sta_poll` | 1472 | 1472 | 1474 | Station polling |
| `mt7925_set_ipv6_ns_work` | 1494 | 1494 | 1497 | **WORK FUNCTION** - IPv6 NS |

### pci.c

| Function | Line | Acquire | Release | Notes |
|----------|------|---------|---------|-------|
| `mt7925_pci_suspend` (patched) | 457 | 457 | 459 | Wraps roc_abort_sync |
| `mt7925e_resume_notifier` | 584 | 584 | 589 | Resume notification |

---

## Core MT76 Mutex Points (mac80211.c)

### Critical Entry Points

| Function | Line | Acquire | Release | Notes |
|----------|------|---------|---------|-------|
| `mt76_sta_add` | 1573 | 1573 | 1595 | Station addition |
| `mt76_sta_remove` | 1626 | 1626 | 1628 | **Station removal - CRITICAL** |
| `mt76_sta_state` | 1678 | 1678 | 1682 | Station state change |
| `mt76_ampdu_action` | 1958 | 1958 | 1964 | AMPDU action |
| `__mt76_set_channel` | 1115 | 1115 | 1165 | Channel setting |
| `mt76_set_channel` | 1067 | 1067 | 1069 | Channel wrapper |

---

## Deadlock Scenarios

### Deadlock #1: Station Removal → ROC Abort (FIXED in Patch 0022)

**Call Chain:**
```
mt76_sta_state() or ieee80211_sta_work
    └→ mt76_sta_remove()                    [mac80211.c:1626 - ACQUIRES MUTEX]
        └→ __mt76_sta_remove()
            └→ mt7925_mac_sta_remove()      [main.c:1234 - callback]
                └→ mt7925_mac_sta_remove_links()
                    └→ mt7925_mac_link_sta_remove()
                        └→ mt7925_roc_abort_sync()  [main.c:1130]
                            └→ cancel_work_sync(&roc_work)  [main.c:453]
```

**Deadlock Condition:**
- Thread A: `mt76_sta_remove` holds mutex, calls `cancel_work_sync(&roc_work)`
- Thread B: `mt7925_roc_work` is running, blocked at `mt792x_mutex_acquire`
- **DEADLOCK**: Thread A waits for roc_work to complete, roc_work waits for mutex

**Race Window:** The deadlock occurs if `roc_work` has passed its
`test_and_clear_bit(MT76_STATE_ROC, ...)` check (line 468) but hasn't yet
acquired the mutex (line 471). In this window, the ROC bit is already cleared
so `roc_abort_sync` can't signal early termination, and `cancel_work_sync`
will wait for `roc_work` which is blocked on the mutex.

```c
// mt7925_roc_work (main.c:461)
void mt7925_roc_work(struct work_struct *work) {
    ...
    if (!test_and_clear_bit(MT76_STATE_ROC, ...))  // Line 468 - clears bit
        return;
    // <-- RACE WINDOW: bit cleared, mutex not held -->
    mt792x_mutex_acquire(phy->dev);               // Line 471 - BLOCKS HERE
    ...
}
```

**Trigger:** Roaming events (moving away from AP, BSSID changes, signal loss)

**Status:** FIXED in Patch 0022

**Fix Applied (Patch 0022):**
Uses Option 3 (async abort with flag) - the most correct fix:

1. Added `MT76_STATE_ROC_ABORT` flag to `mt76.h`
2. Created `mt7925_roc_abort_async()` that sets abort flag without blocking
3. Modified `mt7925_roc_work()` to check abort flag BEFORE acquiring mutex
4. Replaced sync call in `mt7925_mac_link_sta_remove()` with async version

The key insight: roc_work checks the abort flag before trying to acquire the
mutex. If abort is requested, it cleans up and exits without blocking. This
breaks the deadlock chain while ensuring proper ROC cleanup.

**Note:** The same bug exists in mt7921 driver. A similar fix should be
applied there.

---

### Deadlock #2: Reset Work → Interface Iteration (PATCHED in 0002)

**Call Chain (before patch):**
```
mt7925_mac_reset_work()                     [mac.c:1294]
    └→ mutex_lock(&dev->mt76.mutex)         [mac.c:1311 - loop]
    └→ mutex_unlock(&dev->mt76.mutex)       [mac.c:1313]
    └→ ieee80211_iterate_active_interfaces  [mac.c:1334 - NO MUTEX]
        └→ mt7925_vif_connect_iter()        [callback needs mutex!]
```

**Fix (patch 0002):** Added `mt792x_mutex_acquire`/`release` around line 1334-1340

---

### Deadlock #3: Suspend → ROC Abort (PATCHED in 0002)

**Call Chain (before patch):**
```
mt7925_pci_suspend()                        [pci.c]
    └→ cancel_work_sync(&pm->wake_work)
    └→ mt7925_roc_abort_sync()              [NO MUTEX - but ROC needs mutex]
```

**Fix (patch 0002):** Wrapped `mt7925_roc_abort_sync` with mutex acquire/release in pci.c:457-459

---

## Rules for Safe Lock Usage

### Rule 1: Never call cancel_work_sync while holding mutex if work acquires mutex
```c
// BAD - Deadlock risk!
mutex_lock(&dev->mutex);
cancel_work_sync(&work);  // If work needs mutex, DEADLOCK
mutex_unlock(&dev->mutex);

// GOOD - Release mutex first
cancel_work_sync(&work);  // Safe - no mutex held
mutex_lock(&dev->mutex);
// ... do work ...
mutex_unlock(&dev->mutex);
```

### Rule 2: Work functions should check if they should abort before acquiring mutex
```c
void my_work_function(struct work_struct *work)
{
    // Check early exit conditions BEFORE mutex
    if (should_abort)
        return;

    mt792x_mutex_acquire(dev);
    // ... do work ...
    mt792x_mutex_release(dev);
}
```

### Rule 3: Callbacks from mac80211 iteration may need mutex
When using `ieee80211_iterate_active_interfaces()`, the callback typically
needs the mutex to call MCU functions. Ensure mutex is held before calling.

---

## Version History

| Date | Change |
|------|--------|
| 2026-01-16 | Fixed deadlock #1 with patch 0022 (async abort) |
| 2026-01-16 | Identified new deadlock #1 (sta_remove → roc_abort) |
| 2026-01-16 | Initial lock audit document |

## See Also

- `kernels/nbd168/0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch`
- `kernels/nbd168/0022-wifi-mt76-mt7925-fix-deadlock-in-sta-removal-ROC-abo.patch`
- `CRASHES.md` - Crash logs
- `DIFFERENCES.md` - DKMS-specific patches
