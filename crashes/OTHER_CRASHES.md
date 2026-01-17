# MT7925 Crash Log

## 2026-01-15 21:18 - Hard Lockup

**Conditions:**
- Connected to tri-band MLO (2.4 + 5 + 6 GHz simultaneously)
- Just switched connection profiles between networks
- Testing 6GHz connectivity

**Symptoms:**
- Complete system freeze (hard lockup)
- No kernel panic logged
- Required hard reboot

**Possible causes:**
- MLO link switching on 6GHz
- Driver state machine issue with tri-band MLO
- 6GHz regulatory/channel switching

**Last logs before crash:**
```
Jan 15 21:18:06 - Chrome crash report directory error (unrelated)
```

No WiFi-related errors logged before crash.

See also: [docs/6ghz-mlo-workaround.md](docs/6ghz-mlo-workaround.md)

---

## 2026-01-16 - Hung Task Deadlock (Station Removal Path)

**Report:** ARitz-Cracker via GitHub

**Conditions:**
- Framework Laptop 16 with AMD Ryzen AI 9 HX 370
- NixOS with kernel 6.18.5
- Moving physically away from AP (signal loss triggers roaming)

**Symptoms:**
- Hung task timeout after 122 seconds
- Multiple processes blocked in uninterruptible sleep (D state)
- NetworkManager, wpa_supplicant, iwconfig, ip commands all stuck
- System requires hard reboot

**Kernel Log:**
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

**Root Cause Analysis:**

This is a **NEW deadlock bug** different from what patch 0002 fixes.

The deadlock occurs in the station removal path:

```
mt76_sta_remove() [mac80211.c:1626]
    └→ mutex_lock(&dev->mutex)  <-- ACQUIRES MUTEX
    └→ __mt76_sta_remove()
        └→ mt7925_mac_sta_remove()
            └→ mt7925_mac_sta_remove_links()
                └→ mt7925_mac_link_sta_remove() [main.c]
                    └→ mt7925_roc_abort_sync() [main.c:1130]
                        └→ cancel_work_sync(&roc_work) [main.c:453]
                            └→ WAITS for roc_work to complete
```

Meanwhile, if `roc_work` is running:
```
mt7925_roc_work() [main.c:461]
    └→ mt792x_mutex_acquire() [main.c:471]  <-- BLOCKED on same mutex
```

**Result:** Thread A holds mutex and waits for roc_work via cancel_work_sync.
Thread B (roc_work) waits for mutex. **Classic AB-BA deadlock.**

**Trigger:** Roaming events (moving away from AP, BSSID changes)

**Status:** UNPATCHED - Requires new fix

**Proposed Fix Options:**

1. **Move roc_abort_sync before mutex:** Don't call `mt7925_roc_abort_sync()`
   from within `mt7925_mac_link_sta_remove()` since caller already holds mutex.
   Move it to a location before `mt76_sta_remove()` acquires mutex.

2. **Use cancel_work (non-sync):** Replace `cancel_work_sync()` with
   `cancel_work()` and set a flag for roc_work to check.

3. **Make roc_work check for abort before mutex:** Add check in `roc_work`
   to bail out early if station removal is in progress.

**See Also:**
- [docs/lock-audit.md](docs/lock-audit.md) - Full lock audit
- Patches 0018/0019 for mt7921 address similar issues
