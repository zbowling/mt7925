# Patch List

Detailed description of the 7 patches in the v7 stability series submitted to the nbd168 upstream tree.

## Patch 01: Fix Double WCID Initialization Race

**File:** `0001-wifi-mt76-mt7925-fix-double-wcid-initialization-race.patch`

Removes duplicate `mt76_wcid_init()` call in `mt7925_mac_link_sta_add` that occurs after the wcid is already published via `rcu_assign_pointer()`.

**Root cause:**
The wcid is correctly initialized at line 873 after allocation. However, a second `mt76_wcid_init()` call at line 885 reinitializes the wcid after it has been published to RCU readers, which can cause:

- List head corruption (`tx_list`, `poll_list`) if concurrent code is already using the wcid
- RCU readers accessing partially reinitialized structures

**Symptoms:**
- Kernel oops with list corruption messages
- WiFi stops working after disconnect/reconnect
- System hangs during roaming

---

## Patch 02: Add NULL Pointer Protection for MLO

**File:** `0002-wifi-mt76-mt7925-add-NULL-pointer-protection-for-MLO.patch`

Adds NULL pointer checks for functions that return pointers to link-related structures throughout the mt7925 driver.

**Functions protected:**

- `mt792x_vif_to_bss_conf()`: Returns link BSS configuration
- `mt792x_vif_to_link()`: Returns driver link state
- `mt792x_sta_to_link()`: Returns station link state

**Why needed:**
During MLO state transitions, these functions can return NULL when link configuration is not synchronized. Without checks, NULL pointer dereferences cause kernel panics.

**Symptoms:**
- Kernel panic during MLO link changes
- NULL dereference in `mt7925_mcu_add_bss_info`
- Crashes during WiFi 7 MLO operations

---

## Patch 03: Add Mutex Protection in Critical Paths

**File:** `0003-wifi-mt76-mt7925-add-mutex-protection-in-critical-pa.patch`

Adds proper mutex protection for mt7925 driver operations that access hardware state without proper synchronization.

**Fixes:**

1. **mac.c: `mt7925_mac_reset_work()`**
   - Wrap `ieee80211_iterate_active_interfaces()` with `mt792x_mutex`
   - The `vif_connect_iter` callback accesses hardware state

2. **main.c: `mt7925_set_runtime_pm()`**
   - Add mutex protection around `ieee80211_iterate_active_interfaces()`
   - Runtime PM can race with other operations

**Symptoms:**
- System instability during power management
- Race conditions during recovery operations
- Deadlocks or data corruption

---

## Patch 04: Add MCU Command Error Handling in AMPDU Actions

**File:** `0004-wifi-mt76-mt7925-add-MCU-command-error-handling-in-a.patch`

Adds proper error handling for MCU command return values that were previously being ignored in `mt7925_ampdu_action()`.

**Changes:**

- Check `mt7925_mcu_uni_tx_ba()` return value
- Check `mt7925_mcu_uni_rx_ba()` return value
- Return error to mac80211 on failure

**Special case for `IEEE80211_AMPDU_TX_STOP_CONT`:**
The `ieee80211_stop_tx_ba_cb_irqsafe()` callback is kept unconditional because during beacon loss, the MCU command may fail but mac80211 MUST be notified to complete the BA session teardown. Otherwise the state machine gets stuck and triggers WARN in `__ieee80211_stop_tx_ba_session()`.

**Symptoms:**
- "Aggregation stop is not requested!" warnings
- BA session stuck in bad state
- Connection issues after brief signal loss

---

## Patch 05: Add Lockdep Assertions for Mutex Verification

**File:** `0005-wifi-mt76-mt7925-add-lockdep-assertions-for-mutex-ve.patch`

Adds `lockdep_assert_held()` calls to critical MCU functions to help catch mutex violations during development and debugging.

**Functions with new assertions:**

- `mt7925_mcu_add_bss_info()`: Core BSS configuration MCU command
- `mt7925_mcu_sta_update()`: Station record update MCU command
- `mt7925_mcu_uni_bss_ps()`: Power save state MCU command

**Additional fix:**
Fixes a potential NULL pointer issue in `mt7925_mcu_sta_update()` by initializing `mlink` to NULL and checking it before use.

!!! note
    This patch is primarily for debugging. Assertions trigger runtime warnings if locks are not held correctly.

---

## Patch 06: Fix MLO ROC Setup Error Handling

**File:** `0006-wifi-mt76-mt7925-fix-MLO-ROC-setup-error-handling.patch`

Replaces noisy `WARN_ON_ONCE` checks with silent returns in `mt7925_mcu_set_mlo_roc()`.

**Changes:**

- Replace `WARN_ON_ONCE(!link_conf)` with silent `if (!link_conf)` check
- Replace `WARN_ON_ONCE(!links[i].chan)` with silent check
- Add explicit `mconf` NULL check before use
- Use `-ENOLINK` error code to indicate link not ready
- Replace `continue` with `return` to fail fast on invalid links

**Why needed:**
During MLO setup, links may not be fully configured when ROC is requested. The `WARN_ON_ONCE` statements were triggering unnecessary kernel warnings during normal operation.

The `-ENOLINK` error code properly indicates that the link is not yet ready for ROC, allowing upper layers to retry later without generating spurious kernel warnings.

---

## Patch 07: Add Error Logging for MLO ROC Setup in set_links

**File:** `0007-wifi-mt76-mt7925-add-error-logging-for-MLO-ROC-setup.patch`

Adds error logging in `mt7925_mac_set_links()` when `mt7925_set_mlo_roc()` fails.

**Why needed:**
The `mt7925_mac_set_links()` function is a void callback that previously ignored error returns from `mt7925_set_mlo_roc()`. After patch 06 changes the ROC setup to return `-ENOLINK` instead of `WARN_ON_ONCE`, errors would be silently dropped.

**Changes:**

- Check return value of `mt7925_set_mlo_roc()`
- Log non-ENOLINK errors as warnings via `dev_warn()`
- ENOLINK errors are expected during link transitions and are not logged

This complements patch 06 by ensuring ROC setup failures are visible in logs for debugging, while avoiding noise for expected transient conditions.

---

## DKMS-Only Features

The DKMS package includes additional features not in the upstream patch series:

### RSSI Monitor Support

- MCU command `MCU_UNI_CMD_RSSI_MONITOR` for configuring thresholds
- Event handler for `MCU_UNI_EVENT_RSSI_MONITOR` unsolicited events
- Integration with mac80211 `ieee80211_cqm_rssi_notify()` API

### CSA (Channel Switch Announcement) Support

- `pre_channel_switch` validation
- `channel_switch` timer-based work scheduling
- `channel_switch_rx_beacon` for beacon count updates
- `switch_vif_chanctx` for channel context transitions

### Conditional Debug Features

Controlled by `MT76_DKMS_DEBUG_FEATURES` compile-time flag:

- ROC abort state (`MT76_STATE_ROC_ABORT`) for async abort handling
- ROC rate limiting/backoff mechanism
- Verbose `dev_info()` logging throughout driver

---

## Applying Individual Patches

To apply a specific patch:

```bash
cd /path/to/kernel/source
git apply /path/to/mt7925/kernels/nbd168/0001-*.patch
```

To apply all patches:

```bash
git am /path/to/mt7925/kernels/nbd168/*.patch
```
