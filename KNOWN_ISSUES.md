# Known Issues - MT7925 WiFi Driver

This document tracks ongoing issues with the MediaTek MT7925 WiFi driver that are **partially mitigated** by the patches in this repository but likely have root causes in the firmware itself.

## Issue #1: MCU Timeout During MLO Roaming

**Status:** 🟡 Partially Mitigated  
**Severity:** Medium  
**First Observed:** 2026-01-01  
**Firmware:** WM Build 20250721232943  

### Summary

During WiFi 7 MLO (Multi-Link Operation) roaming attempts, the MT7925 firmware can become unresponsive, causing MCU command timeouts. The driver now recovers gracefully (thanks to our patches), but the underlying firmware issue remains.

### Symptoms

- MCU message timeouts in dmesg:
  ```
  mt7925e 0000:c0:00.0: Message 00020002 (seq 12) timeout
  mt7925e 0000:c0:00.0: Message 00020003 (seq 13) timeout
  mt7925e 0000:c0:00.0: Message 00020002 (seq 14) timeout
  ```
- Firmware reset/reload occurs automatically
- Brief WiFi disconnection (~30 seconds)
- Successful reconnection after recovery

### Trigger Conditions

1. WiFi 7 AP with MLO enabled (multiple bands: 2.4GHz + 5GHz + 6GHz)
2. MT7925 client with MLO active on multiple links
3. Roaming triggered between BSSIDs (signal-based or manual)
4. Particularly common when switching to/from 6GHz band

### Root Cause Analysis

The roaming failure cascade involves multiple issues:

#### 1. MLO Group Key Removal Returns -EINVAL

```
wlp192s0: failed to remove key (1, ff:ff:ff:ff:ff:ff) from hardware (-22)
wlp192s0: failed to remove key (4, ff:ff:ff:ff:ff:ff) from hardware (-22)
```

The driver returns `-EINVAL` when removing broadcast/multicast keys during MLO roaming. This suggests the key removal path doesn't properly handle MLO link IDs.

**wpa_supplicant reports:**
```
nl80211: kernel reports: link ID must for MLO group key
```

#### 2. BSS Fetch Failure

```
nl80211: kernel reports: Error fetching BSS for link
wlp192s0: SME: Association request to the driver failed
```

During MLO roaming, the driver fails to provide BSS information for the target link, causing association to fail.

#### 3. Firmware State Machine Corruption

After the failed roaming sequence, firmware enters an unresponsive state:
- Multiple MCU commands timeout (6+ second delays each)
- Firmware stops processing command queue
- Only recovery is firmware reset

### Timeline Example

```
00:51:21 - Roaming triggered (6GHz target)
00:51:21 - MLO group key errors (3x)
00:51:21 - Key removal failed (-22)
00:51:22 - Authentication OK, Association FAILED
00:51:25 - AP requests comeback delay (SAE anti-clogging)
00:51:26 - Association timed out
00:51:29 - MCU timeout begins (firmware hung)
00:51:44 - Firmware reset triggered
00:51:51 - Reconnected to different BSSID
00:51:54 - Fully online
```

### Mitigation Status

| Issue | Driver Fix | Firmware Fix Needed |
|-------|-----------|---------------------|
| Key removal -EINVAL | ✅ Patch 0012 | ❌ No (driver bug) |
| BSS fetch failure | 🟡 NULL checks help | ✅ Yes |
| MCU timeout recovery | ✅ Patches prevent crash | ✅ Root cause in FW |
| Firmware hang | ✅ Auto-recovery works | ✅ Shouldn't happen |

### New Fix: Patch 0012

**File:** `patches/critical/0012-wifi-mt76-mt7925-fix-key-removal-failure-during-MLO-.patch`

The key removal `-EINVAL` error was a **driver bug**, not a firmware issue. During MLO roaming:
1. Link teardown cleans up driver state
2. mac80211 requests group key removal
3. `mt792x_vif_to_bss_conf()` returns NULL (link already gone)
4. Driver returned `-EINVAL` instead of success

The fix: Return success (0) when removing a key if the link is already torn down - the key is effectively removed with the link.

### What Our Patches Do

Without our patches, this sequence would cause:
- **Kernel panic** from NULL pointer dereference in VIF iteration
- **System deadlock** from missing mutex in reset path
- **Hard reboot required**

With our patches:
- Driver handles failures gracefully
- Firmware reset completes successfully  
- Automatic reconnection works
- Total downtime: ~30 seconds

### Recommended Actions

**For Users:**
- Apply patches from this repository
- Use kernel 6.18+ with patches
- Consider disabling 6GHz if roaming issues are frequent

**For MediaTek/Upstream:**
1. Fix MLO group key handling in driver (`mt7925_set_key()`)
2. Investigate firmware state machine for roaming failures
3. Add proper BSS info caching for MLO links
4. Review MCU command queueing during rapid state transitions

### Related Links

- [OpenWrt Issue #1036](https://github.com/openwrt/mt76/issues/1036)
- [OpenWrt PR #1037](https://github.com/openwrt/mt76/pull/1037) - Fix for key removal failure
- [LKML Patches](https://lore.kernel.org/linux-wireless/?q=mt7925+zbowling)
- [Framework Community Thread](https://community.frame.work/t/issues-with-mediatek-mt7925-rz717-wi-fi-card/75815)

---

## Issue #2: Performance Degradation vs Intel Cards

**Status:** 🔴 Unmitigated (Firmware/Hardware)  
**Severity:** Medium  

### Summary

Users report significantly lower throughput compared to Intel WiFi cards in identical conditions.

### Observed Performance

| Card | 5GHz Throughput | Notes |
|------|-----------------|-------|
| Intel 8265 | 184-192 Mbit/s | No MIMO |
| MT7925 | 18-26 Mbit/s | With MIMO |

Source: [Framework Community benchmarks](https://community.frame.work/t/issues-with-mediatek-mt7925-rz717-wi-fi-card/75815/24)

### Possible Causes

- Firmware power management too aggressive
- Driver rate control issues
- Antenna configuration
- MIMO not functioning correctly

### Workarounds

None known. Some users have replaced the MT7925 with Intel AX210.

---

## Issue #3: Frequent Deauthentication/Reauthentication Cycles

**Status:** 🟡 Partially Mitigated  
**Severity:** Low-Medium  

### Summary

The driver frequently disconnects and reconnects, especially in the first 1-2 hours after boot.

### Symptoms

```
wlan0: deauthenticating from XX:XX:XX:XX:XX:XX by local choice (Reason: 3=DEAUTH_LEAVING)
wlan0: authenticate with XX:XX:XX:XX:XX:XX
wlan0: authenticated
wlan0: associated
```

This cycle repeats every few minutes.

### Possible Causes

- Aggressive roaming decisions
- Power management state transitions
- Regulatory domain changes triggering reconnection

### Workarounds

- Set regulatory domain explicitly in `/etc/conf.d/wireless-regdom`
- Disable power management: `iw dev wlan0 set power_save off`

---

## Reporting New Issues

If you encounter issues with the MT7925 driver:

1. Capture `dmesg` output around the incident
2. Note your kernel version and firmware version
3. Check if our patches are applied
4. Open an issue in this repository with the above information

---

*Last updated: 2026-01-01*

