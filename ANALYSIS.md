# MT7925 Driver Deep Analysis

This document contains a comprehensive analysis of potential bugs and issues in the MT7925 WiFi driver, comparing patterns with the mature MT7615 driver and other wireless drivers.

## Summary of Issues Found

### 🔴 Critical Issues (Already Fixed in Our Patches)

1. **NULL Pointer Dereference in VIF Iteration** (Patch 0001) ✅ FIXED
2. **Missing Mutex in Reset/ROC Paths** (Patch 0002) ✅ FIXED
3. **Missing Mutex in PM Paths** (Patch 0003) ✅ FIXED

### 🟠 High Priority Issues (Fixed in Additional Patches)

#### 1. Missing NULL Checks in mcu.c - ✅ FIXED (Patch 0004)

**Location**: `mt7925/mcu.c` lines 1774 and 1852

Two functions dereference `link_conf` without NULL checks:

```c
// Line 1774 - mt7925_mcu_sta_phy_tlv()
link_conf = mt792x_vif_to_bss_conf(vif, link_sta->link_id);
mconf = mt792x_vif_to_link(mvif, link_sta->link_id);
chandef = mconf->mt76.ctx ? &mconf->mt76.ctx->def :
                            &link_conf->chanreq.oper;  // DEREFERENCE WITHOUT CHECK

// Line 1852 - mt7925_mcu_sta_rate_ctrl_tlv()
link_conf = mt792x_vif_to_bss_conf(vif, link_sta->link_id);
mconf = mt792x_vif_to_link(mvif, link_sta->link_id);
chandef = mconf->mt76.ctx ? &mconf->mt76.ctx->def :
                            &link_conf->chanreq.oper;  // SAME ISSUE
band = chandef->chan->band;  // DOUBLE DEREFERENCE
```

**Impact**: Kernel panic if `link_conf` is NULL during MLO operations
**Risk**: HIGH - These are called during station add/update operations

#### 2. Missing NULL Checks in main.c - ✅ FIXED (Patches 0005, 0009)

**Location**: `mt7925/main.c` multiple locations

| Line | Function | Status |
|------|----------|--------|
| 603 | `mt7925_set_key()` | ✅ Fixed (0005) |
| 891 | `mt7925_mac_link_sta_add()` | ✅ Fixed (0005) |
| 999 | `mt7925_mac_set_links()` | ✅ Fixed (0009) |
| 1009 | `mt7925_mac_set_links()` | ✅ Fixed (0009) |
| 1041 | `mt7925_mac_link_sta_assoc()` | ✅ Fixed (0005) |
| 1043 | `mt7925_mac_link_sta_assoc()` | ✅ Fixed (0005) |
| 1109 | `mt7925_mac_link_sta_remove()` | ✅ Fixed (0005) |
| 1910 | `mt7925_link_info_changed()` | ✅ Fixed (0009) |
| 2032 | `mt7925_change_vif_links()` | ✅ Fixed (0005) |
| 2114 | `mt7925_assign_vif_chanctx()` | ✅ Fixed (0009) |

#### 3. Unchecked MCU Return Values - ✅ PARTIALLY FIXED (Patches 0006-0008)

**Location**: Throughout `mt7925/main.c`

Many MCU calls ignore return values, which could leave the driver in an inconsistent state:

```c
// Examples of unchecked MCU calls:
mt7925_mcu_abort_roc(phy, &mvif->bss_conf, phy->roc_token_id);  // Line 453
mt7925_mcu_set_sniffer(dev, vif, monitor);  // Line 737
mt7925_mcu_set_deep_sleep(dev, pm->ds_enable);  // Lines 741, 760
mt7925_mcu_set_rxfilter(dev, flags, 0, 0);  // Line 810
mt7925_mcu_add_bss_info(...);  // Multiple locations
mt7925_mcu_sta_update(...);  // Lines 1060, 1104
mt7925_mcu_uni_bss_ps(dev, bss_conf);  // Line 1310
mt7925_mcu_set_rts_thresh(&dev->phy, val);  // Line 1230
```

**Impact**: Failed MCU commands may not be detected, causing silent failures
**Risk**: MEDIUM - Most of these are not critical path but could cause issues

Fixed in patches 0006-0008:
- ✅ AMPDU rx_ba/tx_ba return values (0006)
- ✅ BSS info in sta_add (0007)
- ✅ BSS info in key setup (0008)

Remaining unchecked (lower priority - mostly in callbacks):
- `mt7925_mcu_set_sniffer()` - monitor mode setup
- `mt7925_mcu_set_deep_sleep()` - PM callback
- `mt7925_mcu_set_beacon_filter()` - PM callback
- `mt7925_mcu_set_rxfilter()` - config callback

### 🟡 Medium Priority Issues

#### 4. Missing `mconf` NULL Checks - ✅ MOSTLY FIXED (Patches 0005, 0009)

Most locations are now fixed. Remaining are in callback iterators where errors can't be propagated.

#### 5. Potential Race in SKB Freeing

**Location**: `mt7925/main.c` line 1100

```c
mt7925_roc_abort_sync(dev);
mt76_connac_free_pending_tx_skbs(&dev->pm, &mlink->wcid);
```

The `roc_abort_sync` and `free_pending_tx_skbs` calls happen outside mutex in the station remove path. If another thread is submitting packets, this could race.

#### 6. Inconsistent Error Handling in Link Setup

**Location**: `mt7925/main.c` around line 948

When `devm_kzalloc` fails for mlink, the function breaks but doesn't clean up previously allocated links in the loop.

### 🟢 Low Priority Issues

#### 7. Missing Debug Assertions

The mature MT7615 driver uses `lockdep_assert_held()` in various places to verify mutex is held. MT7925 doesn't have these assertions, making debugging harder.

#### 8. Timer Deletion Pattern

The driver uses `del_timer_sync()` but MT7615 uses `timer_delete_sync()` (same function, different name). This is just a style inconsistency.

## Comparison with MT7615 (Mature Driver)

| Pattern | MT7615 | MT7925 | Issue |
|---------|--------|--------|-------|
| Mutex around iterate | ✅ Correct | ✅ Fixed | Was missing |
| NULL checks on bss_conf | ✅ Present | ❌ Missing | Many locations |
| MCU error handling | ✅ Checked | ❌ Ignored | Silent failures |
| lockdep assertions | ✅ Present | ❌ Missing | Debug only |

## Comparison with MT7921 (Predecessor)

MT7921 has the **same bugs** as MT7925 - they were copied when MT7925 was forked:

- Missing mutex in `mt7921_roc_abort_sync()` ❌
- Missing mutex in `mt7921_set_runtime_pm()` ❌
- Missing NULL checks throughout ❌

This suggests the bugs were inherited and never audited.

## Patches Created

| Patch | Description | Status |
|-------|-------------|--------|
| 0001 | NULL pointer fix in VIF iteration | ✅ Submitted to LKML |
| 0002 | Mutex fix in reset/ROC | ✅ Submitted to LKML |
| 0003 | Mutex fix in PM paths | ✅ Submitted to LKML |
| 0004 | NULL checks in MCU TLV functions | ✅ OpenWrt PR #1030 |
| 0005 | NULL checks in main.c | ✅ OpenWrt PR #1030 |
| 0006 | AMPDU MCU error handling | ✅ OpenWrt PR #1031 |
| 0007 | BSS info sta_add error handling | ✅ OpenWrt PR #1031 |
| 0008 | BSS info key setup error handling | ✅ OpenWrt PR #1031 |
| 0009 | MLO link/chanctx NULL checks | ✅ OpenWrt PR #1032 |

## Testing Recommendations

To trigger these bugs:
1. **MLO Operations**: Connect to WiFi 7 AP with MLO, then disconnect/reconnect rapidly
2. **Roaming**: Move between access points (triggers link state changes)
3. **Suspend/Resume**: Suspend and resume with WiFi connected
4. **Channel Switching**: Use `iw dev wlan0 set channel` to change channels
5. **Power Management**: Toggle power save on/off rapidly

## Conclusion

The MT7925 driver had significant code quality issues stemming from:
1. ~~Insufficient NULL pointer checking~~ → **FIXED** (Patches 0001, 0004, 0005, 0009)
2. ~~Missing mutex protection~~ → **FIXED** (Patches 0002, 0003)
3. ~~Ignored return values~~ → **PARTIALLY FIXED** (Patches 0006-0008)
4. Inherited bugs from MT7921 → Still present in MT7921, needs separate patch series

These issues existed since the driver was added to the kernel in late 2023/early 2024. 
The patches in this repository fix all critical issues (deadlocks and panics) and most 
medium-priority issues.

### Remaining Work

1. **MT7921 backport**: Same bugs exist in MT7921, needs equivalent fixes
2. **Remaining MCU error checks**: Lower-priority callbacks still ignore return values
3. **SKB freeing race**: Potential race condition in station remove (needs investigation)
4. **lockdep assertions**: Add debug assertions for mutex verification

