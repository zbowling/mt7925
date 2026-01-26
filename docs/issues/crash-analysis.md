# Crash Analysis

Detailed analysis of specific crashes and deadlocks encountered with the MT7925 driver.

## Hard Lockup - Tri-band MLO Switch

**Date:** January 2026

| | |
|---|---|
| **Type** | Hard Lockup |
| **Status** | Under Investigation |
| **Requires** | Hard Reboot |

### Conditions

- Connected to tri-band MLO (2.4 + 5 + 6 GHz simultaneously)
- Just switched connection profiles between networks
- Testing 6GHz connectivity

### Symptoms

- Complete system freeze (hard lockup)
- No kernel panic logged
- Required hard reboot

### Possible Causes

- MLO link switching on 6GHz
- Driver state machine issue with tri-band MLO
- 6GHz regulatory/channel switching

### Notes

No WiFi-related errors logged before crash, making this difficult to diagnose.

!!! info "6GHz Workaround"
    See [6GHz MLO Workaround](../architecture/mlo.md#6ghz-considerations) for tips on reducing 6GHz-related issues.

---

## Hung Task Deadlock - Station Removal Path

**Date:** January 2026
**Report:** GitHub community

| | |
|---|---|
| **Type** | Mutex Deadlock |
| **Status** | :material-alert-circle:{ .red } Requires New Fix |
| **Trigger** | Roaming (moving away from AP) |

### Environment

- Framework Laptop 16 with AMD Ryzen AI 9 HX 370
- NixOS with kernel 6.18.5
- Moving physically away from AP (signal loss triggers roaming)

### Symptoms

- Hung task timeout after 122 seconds
- Multiple processes blocked in uninterruptible sleep (D state)
- NetworkManager, wpa_supplicant, iwconfig, ip commands all stuck
- System requires hard reboot

### Kernel Log

```
INFO: task kworker/u128:0:48737 blocked for more than 122 seconds.
Workqueue: mt76 mt7925_mac_reset_work [mt7925_common]
Call Trace:
 __schedule+0x426/0x12c0
 schedule+0x27/0xf0
 schedule_preempt_disabled+0x15/0x30
 __mutex_lock.constprop.0+0x3d0/0x6d0
 mt7925_mac_reset_work+0x85/0x170 [mt7925_common]
```

### Root Cause Analysis

This is a **NEW deadlock bug** different from what existing patches fix.

The deadlock occurs in the station removal path:

```
mt76_sta_remove() [mac80211.c:1626]
    +-- mutex_lock(&dev->mutex)  <-- ACQUIRES MUTEX
    +-- __mt76_sta_remove()
        +-- mt7925_mac_sta_remove()
            +-- mt7925_mac_sta_remove_links()
                +-- mt7925_mac_link_sta_remove() [main.c]
                    +-- mt7925_roc_abort_sync() [main.c:1130]
                        +-- cancel_work_sync(&roc_work)
                            +-- WAITS for roc_work to complete
```

Meanwhile, if `roc_work` is running:

```
mt7925_roc_work() [main.c:461]
    +-- mt792x_mutex_acquire() [main.c:471]  <-- BLOCKED on same mutex
```

**Result:** Classic AB-BA deadlock.

- Thread A holds mutex and waits for roc_work via `cancel_work_sync`
- Thread B (roc_work) waits for mutex

### Proposed Fixes

#### Option 1: Move roc_abort_sync Before Mutex

Don't call `mt7925_roc_abort_sync()` from within `mt7925_mac_link_sta_remove()` since caller already holds mutex. Move it to a location before `mt76_sta_remove()` acquires mutex.

#### Option 2: Use Non-blocking Cancel

Replace `cancel_work_sync()` with `cancel_work()` and set a flag for roc_work to check.

#### Option 3: Early Abort Check

Add check in `roc_work` to bail out early if station removal is in progress.

### Related

- [Locking Documentation](../architecture/locking.md) - Full lock audit
- Patches 0018/0019 for mt7921 address similar issues

---

## Common Crash Patterns

### Pattern 1: NULL Pointer in VIF Iteration

**Symptom:** Kernel panic with NULL dereference in `ieee80211_iterate_active_interfaces`

**Cause:** VIF pointer becomes NULL during iteration

**Fix:** Patch 0005 adds NULL checks for MLO operations

### Pattern 2: Mutex Deadlock in Suspend

**Symptom:** System hangs during suspend/resume

**Cause:** Mutex lock ordering violation

**Fix:** Patch 0004 fixes mutex handling in suspend path

### Pattern 3: List Corruption in wcid Cleanup

**Symptom:** `list_del corruption` kernel warning

**Cause:** Race condition in wcid cleanup

**Fix:** Patch 0002 adds proper list handling

---

## Collecting Crash Information

When you experience a crash, collect the following:

### Before Crash (if possible)

```bash
# Save recent dmesg
dmesg > ~/dmesg-before.log

# Check module info
lsmod | grep mt > ~/modules.log
modinfo mt7925e >> ~/modules.log
```

### After Reboot

```bash
# Check previous boot logs (if journald configured)
journalctl -b -1 | grep -i mt76 > ~/crash-log.txt
journalctl -b -1 | grep -i "Call Trace" -A 50 >> ~/crash-log.txt

# Or check /var/log/kern.log
sudo grep -i mt76 /var/log/kern.log.1
```

### Report Format

When filing an issue, include:

1. **Kernel version:** `uname -r`
2. **DKMS version:** `dkms status | grep mt76`
3. **Firmware version:** `dmesg | grep -i "firmware version"`
4. **Crash log:** Output from above commands
5. **Trigger:** What were you doing when it crashed?
