# MT76 Locking Patterns and Deadlock Analysis

This document describes the locking mechanisms in the mt76 driver, common deadlock patterns, and the fixes that have been developed to address them.

## Overview

The mt76 driver uses several synchronization primitives:

1. **`dev->mt76.mutex`** - Main device mutex protecting hardware state
2. **Work queues** - Deferred work execution (`ps_work`, `mac_work`, `roc_work`)
3. **Atomic state bits** - `MT76_STATE_*` flags for lightweight synchronization
4. **RCU** - Read-Copy-Update for link/station data structures

## The Main Mutex: `dev->mt76.mutex`

### Acquisition Patterns

The MT792x drivers use wrapper functions:

```c
// Acquire mutex (with power management wake)
mt792x_mutex_acquire(dev);

// Release mutex
mt792x_mutex_release(dev);
```

These wrappers handle:
- Acquiring `dev->mt76.mutex`
- Waking the device from power save if needed
- Tracking lock ownership for debugging

### Critical Rule: Never Nest Mutex Acquisition

The most common deadlock pattern:

```c
// WRONG - Nested mutex acquisition
void outer_function(struct mt792x_dev *dev) {
    mt792x_mutex_acquire(dev);    // Acquire mutex
    inner_function(dev);           // Calls function that also acquires mutex
    mt792x_mutex_release(dev);
}

void inner_function(struct mt792x_dev *dev) {
    mt792x_mutex_acquire(dev);    // DEADLOCK - already held!
    // ...
    mt792x_mutex_release(dev);
}
```

**Fix:** Use double-underscore variants that assume mutex is already held:

```c
// CORRECT - Use unlocked variant
void outer_function(struct mt792x_dev *dev) {
    mt792x_mutex_acquire(dev);
    __inner_function(dev);         // No mutex acquisition
    mt792x_mutex_release(dev);
}
```

### Real Example: `mt76_set_channel()` vs `__mt76_set_channel()`

From Chad Monroe's fix:

```c
// WRONG - mt76_set_channel() acquires mutex internally
void mt76_roc_complete(struct mt76_phy *phy) {
    // Already holding dev->mutex here...
    mt76_set_channel(phy, &phy->main_chandef, false);  // DEADLOCK
}

// CORRECT - Use unlocked variant
void mt76_roc_complete(struct mt76_phy *phy) {
    __mt76_set_channel(phy, &phy->main_chandef, false);  // OK
}
```

## Work Queue Interactions

### The `cancel_work_sync()` Deadlock

Work queues can cause deadlocks when:
1. Work function A holds mutex, calls `cancel_work_sync()` on work B
2. Work function B is running and waiting for the same mutex

```
Thread 1 (work A):              Thread 2 (work B):
  mutex_lock()                    
  cancel_work_sync(B)  ------>    mutex_lock()  // Waiting
       |                               ^
       +---------- DEADLOCK -----------+
```

### Pattern 1: ps_work vs mac_work Deadlock

**The Bug:**
```c
mt792x_mac_work() -> cancel_delayed_work_sync(&pm->ps_work);
mt792x_pm_power_save_work() -> cancel_delayed_work_sync(&mphy->mac_work);
```

Both works try to cancel each other with `_sync`, causing circular wait.

**The Fix (Leon Yen):**
```c
// Use non-blocking cancel - don't wait for the other work
- cancel_delayed_work_sync(&mphy->mac_work);
+ cancel_delayed_work(&mphy->mac_work);
```

### Pattern 2: ROC Work Deadlock

**The Bug:**
```c
// Station removal path holds mutex
mt7925_mac_link_sta_remove() {
    mt792x_mutex_acquire(dev);        // Holds mutex
    mt7925_roc_abort_sync(dev);       // Calls cancel_work_sync
}

// ROC work needs mutex
mt7925_roc_work() {
    mt792x_mutex_acquire(dev);        // Waits for mutex
    // ...
}
```

**The Fix (Sean Wang):**
```c
void mt7925_roc_abort_sync(struct mt792x_dev *dev) {
    // Early exit if ROC not active
    if (!test_and_clear_bit(MT76_STATE_ROC, &phy->mt76->state))
        return;
    
    // Use non-blocking cancel
-   cancel_work_sync(&phy->roc_work);
+   cancel_work(&phy->roc_work);
    
    // Continue with cleanup...
}
```

### Pattern 3: Interface Iteration Without Mutex

**The Bug:**
```c
void some_function(struct mt792x_dev *dev) {
    // Missing mutex protection!
    ieee80211_iterate_active_interfaces(hw,
        IEEE80211_IFACE_ITER_RESUME_ALL,
        callback_that_calls_mcu, dev);
}

void callback_that_calls_mcu(void *priv, ...) {
    mt7925_mcu_some_command(dev, ...);  // MCU call without mutex!
}
```

**The Fix (Our Patches):**
```c
void some_function(struct mt792x_dev *dev) {
    mt792x_mutex_acquire(dev);
    ieee80211_iterate_active_interfaces(hw,
        IEEE80211_IFACE_ITER_RESUME_ALL,
        callback_that_calls_mcu, dev);
    mt792x_mutex_release(dev);
}
```

**Important:** The mutex must be at the *caller* level, not inside the callback (which would cause nested acquisition if called multiple times).

## Functions Requiring Mutex

### MCU Functions

All MCU command functions require the mutex to be held:

```c
// These all need mutex protection:
mt7925_mcu_uni_bss_ps()
mt7925_mcu_sta_update()
mt7925_mcu_add_bss_info()
mt7925_mcu_set_tx()
mt76_connac_mcu_uni_add_dev()
// ... and many more
```

**Verification with lockdep:**
```c
int mt7925_mcu_uni_bss_ps(struct mt792x_dev *dev, ...) {
    lockdep_assert_held(&dev->mt76.mutex);  // Debug assertion
    // ... rest of function
}
```

### Interface Iteration Functions

When callbacks make MCU calls, the iteration must be protected:

| Function | Requires Mutex |
|----------|---------------|
| `ieee80211_iterate_active_interfaces()` | At call site if callbacks use MCU |
| `ieee80211_iterate_active_interfaces_atomic()` | No (callbacks can't sleep) |

## Safe Patterns

### Pattern: Cancel Work Before Acquiring Mutex

```c
int mt76_remain_on_channel(...) {
    // Cancel work BEFORE acquiring mutex
    cancel_delayed_work_sync(&phy->mac_work);
    
    mutex_lock(&dev->mutex);
    // ... operations that might conflict with mac_work
    mutex_unlock(&dev->mutex);
}
```

### Pattern: Early Exit with Atomic Test-and-Clear

```c
void mt7925_roc_abort_sync(struct mt792x_dev *dev) {
    // Atomic check + clear - if not set, nothing to do
    if (!test_and_clear_bit(MT76_STATE_ROC, &phy->mt76->state))
        return;
    
    // Now safe to proceed with cleanup
    cancel_work(&phy->roc_work);
    // ...
}
```

### Pattern: Use Non-Blocking Cancel in Work Functions

```c
void mt792x_pm_power_save_work(struct work_struct *work) {
    // ...
    if (!mt792x_mcu_fw_pmctrl(dev)) {
        // Non-blocking: don't wait for mac_work
        cancel_delayed_work(&mphy->mac_work);
        return;
    }
}
```

## Debugging Deadlocks

### Enable Lockdep

Build kernel with:
```
CONFIG_PROVE_LOCKING=y
CONFIG_DEBUG_LOCK_ALLOC=y
CONFIG_LOCKDEP=y
```

### Add Assertions

```c
// Add to functions that require mutex
lockdep_assert_held(&dev->mt76.mutex);
```

### Check for Hung Tasks

```bash
# Check for D-state (uninterruptible sleep) processes
ps aux | awk '$8 ~ /D/'

# Check kernel log for lockdep warnings
dmesg | grep -i deadlock
dmesg | grep -i "held lock"
```

### Common Symptoms

| Symptom | Likely Cause |
|---------|--------------|
| System completely frozen | Deadlock with interrupts disabled |
| Network commands hang | Mutex deadlock in driver |
| D-state processes | Waiting on mutex held by another thread |
| Soft lockup warnings | Work queue deadlock |

## Summary of Fixes

| Issue | Fix | Patch |
|-------|-----|-------|
| Nested mutex in `roc_complete` | Use `__mt76_set_channel()` | Chad Monroe |
| ps_work/mac_work circular cancel | Use `cancel_delayed_work()` | Leon Yen |
| ROC abort sync deadlock | Use `cancel_work()` + early exit | Sean Wang |
| Interface iteration without mutex | Add mutex at call site | Our patches 0002, 0003 |
| Resume path MCU calls | Add mutex protection | Our patch 0016 |

## References

- [LKML: mt7925 roc_abort_sync deadlock fix](https://lore.kernel.org/linux-mediatek/20251216013849.17976-1-sean.wang@kernel.org/)
- [LKML: mt792x ps_work/mac_work deadlock](https://lore.kernel.org/linux-mediatek/20251215122231.3180648-1-leon.yen@mediatek.com/)
- [LKML: mt76 ROC channel deadlock](https://lore.kernel.org/linux-mediatek/3fceebb12dcb672cfae11f993a373b457a35e228.1765198130.git.chad@monroe.io/)
- [Kernel Documentation: Locking](https://www.kernel.org/doc/html/latest/locking/index.html)

