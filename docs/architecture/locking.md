# Locking Patterns

This document describes the locking mechanisms in the mt76 driver, common deadlock patterns, and the fixes developed to address them.

## Synchronization Primitives

| Primitive | Purpose |
|-----------|---------|
| `dev->mt76.mutex` | Main device mutex protecting hardware state |
| Work queues | Deferred work execution (`ps_work`, `mac_work`, `roc_work`) |
| `MT76_STATE_*` flags | Atomic state bits for lightweight synchronization |
| RCU | Read-Copy-Update for link/station data structures |

## The Main Mutex

### Acquisition Patterns

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

### Critical Rule

!!! danger "Never Nest Mutex Acquisition"
    The most common deadlock pattern is nested mutex acquisition.

**Wrong:**
```c
void outer_function(struct mt792x_dev *dev) {
    mt792x_mutex_acquire(dev);    // Acquire mutex
    inner_function(dev);          // Calls function that also acquires mutex
    mt792x_mutex_release(dev);
}

void inner_function(struct mt792x_dev *dev) {
    mt792x_mutex_acquire(dev);    // DEADLOCK - already held!
    // ...
    mt792x_mutex_release(dev);
}
```

**Correct:**
```c
void outer_function(struct mt792x_dev *dev) {
    mt792x_mutex_acquire(dev);
    __inner_function(dev);        // Use unlocked variant
    mt792x_mutex_release(dev);
}
```

## Deadlock Classification

### Type 1: Recursive Lock (AA Deadlock)

Same thread tries to acquire the same non-recursive lock twice.

**Fix:** Create `_nolock()` or `__` prefixed variants that assume lock is already held.

### Type 2: Lock Ordering Violation (AB-BA Deadlock)

Two threads acquire two locks in opposite order.

```
Thread A:                    Thread B:
  mutex_lock(&lock_A)          mutex_lock(&lock_B)
  mutex_lock(&lock_B) ←WAIT    mutex_lock(&lock_A) ←WAIT
         ↑                            ↑
         +-------- DEADLOCK ----------+
```

**Fix:** Establish consistent lock ordering - always acquire in same order.

### Type 3: Lock + Synchronization Deadlock

Thread holds lock while waiting for another thread/work that needs the same lock.

```
Thread A (holds lock):           Thread B (work):
  mutex_lock(&lock)
  ...
  cancel_work_sync(&work) ←WAIT    mutex_lock(&lock) ←WAIT
         ↑                                ↑
         +---------- DEADLOCK ------------+
```

**Fixes:**

1. Use non-blocking cancel: `cancel_work()` instead of `cancel_work_sync()`
2. Check a flag before acquiring lock, exit early if abort requested
3. Release lock before calling synchronization functions

## Common Deadlock Patterns

### Pattern 1: ps_work vs mac_work

Both works try to cancel each other with `_sync`, causing circular wait.

**Fix (Leon Yen):**
```c
// Use non-blocking cancel
- cancel_delayed_work_sync(&mphy->mac_work);
+ cancel_delayed_work(&mphy->mac_work);
```

### Pattern 2: ROC Work Deadlock

Station removal holds mutex and calls `cancel_work_sync()` on `roc_work`, which needs the mutex.

**Fix (Sean Wang - upstream):**
```c
void mt7925_roc_abort_sync(struct mt792x_dev *dev) {
    if (!test_and_clear_bit(MT76_STATE_ROC, &phy->mt76->state))
        return;
-   cancel_work_sync(&phy->roc_work);
+   cancel_work(&phy->roc_work);  // Non-blocking
}
```

### Pattern 3: Interface Iteration Without Mutex

MCU calls from iteration callbacks without mutex protection.

**Fix:**
```c
void some_function(struct mt792x_dev *dev) {
    mt792x_mutex_acquire(dev);
    ieee80211_iterate_active_interfaces(hw,
        IEEE80211_IFACE_ITER_RESUME_ALL,
        callback_that_calls_mcu, dev);
    mt792x_mutex_release(dev);
}
```

!!! warning "Important"
    The mutex must be at the *caller* level, not inside the callback.

## Functions Requiring Mutex

### MCU Functions

All MCU command functions require the mutex:

- `mt7925_mcu_uni_bss_ps()`
- `mt7925_mcu_sta_update()`
- `mt7925_mcu_add_bss_info()`
- `mt7925_mcu_set_tx()`
- `mt76_connac_mcu_uni_add_dev()`

### Interface Iteration

| Function | Requires Mutex |
|----------|---------------|
| `ieee80211_iterate_active_interfaces()` | At call site if callbacks use MCU |
| `ieee80211_iterate_active_interfaces_atomic()` | No (callbacks can't sleep) |

## Safe Patterns

### Cancel Work Before Acquiring Mutex

```c
int mt76_remain_on_channel(...) {
    // Cancel work BEFORE acquiring mutex
    cancel_delayed_work_sync(&phy->mac_work);

    mutex_lock(&dev->mutex);
    // ... operations
    mutex_unlock(&dev->mutex);
}
```

### Early Exit with Atomic Test-and-Clear

```c
void mt7925_roc_abort_sync(struct mt792x_dev *dev) {
    if (!test_and_clear_bit(MT76_STATE_ROC, &phy->mt76->state))
        return;

    cancel_work(&phy->roc_work);
}
```

### Non-Blocking Cancel in Work Functions

```c
void mt792x_pm_power_save_work(struct work_struct *work) {
    if (!mt792x_mcu_fw_pmctrl(dev)) {
        cancel_delayed_work(&mphy->mac_work);  // Non-blocking
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
int mt7925_mcu_uni_bss_ps(struct mt792x_dev *dev, ...) {
    lockdep_assert_held(&dev->mt76.mutex);
    // ... rest of function
}
```

### Check for Hung Tasks

```bash
# Check for D-state processes
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

| Issue | Fix | Source |
|-------|-----|--------|
| Nested mutex in `roc_complete` | Use `__mt76_set_channel()` | Chad Monroe |
| ps_work/mac_work circular cancel | Use `cancel_delayed_work()` | Leon Yen |
| ROC abort sync deadlock | Use `cancel_work()` + early exit | Sean Wang |
| Interface iteration without mutex | Add mutex at call site | Our patches |
