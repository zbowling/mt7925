# Patch List

Detailed description of all 12 patches in the stability series.

## Patch 01: Fix Deadlock in ROC Abort

**File:** `0001-wifi-mt76-mt7925-fix-potential-deadlock-in-roc-abort.patch`

Fixes a potential deadlock when aborting remain-on-channel operations. The `mt7925_abort_roc` function could deadlock when called while holding certain locks.

**Author:** Sean Wang (upstream)

---

## Patch 02: Fix List Corruption in wcid Cleanup

**File:** `0002-wifi-mt76-fix-list-corruption-in-mt76_wcid_cleanup.patch`

Fixes list corruption that could occur during wcid (wireless connection ID) cleanup, leading to kernel oops or memory corruption.

**Symptoms:**
- Kernel oops with list corruption messages
- WiFi stops working after disconnect/reconnect

---

## Patch 03: Fix NULL Pointer in Rate Control

**File:** `0003-wifi-mt76-mt792x-fix-null-pointer-in-sta_link_rc_work.patch`

Adds NULL pointer checks in `mt792x_sta_link_rc_work` to prevent crashes when rate control work is scheduled for a station that has been removed.

**Symptoms:**
- Kernel panic on disconnect
- NULL pointer dereference in rate control

---

## Patch 04: Fix Mutex Deadlock in Suspend

**File:** `0004-wifi-mt76-mt7921-fix-mutex-deadlock-in-suspend.patch`

Fixes deadlock in the suspend/resume path when mutex operations overlap with other driver operations.

**Symptoms:**
- System hang during suspend
- Deadlock warnings in dmesg

---

## Patch 05: Add NULL Checks for MLO

**File:** `0005-wifi-mt76-mt7925-add-null-checks-for-mlo.patch`

Comprehensive NULL pointer protection for Multi-Link Operation (MLO) code paths.

**Symptoms:**
- Crashes when using WiFi 7 MLO features
- NULL dereference in link handling

---

## Patch 06: Add Mutex Protection

**File:** `0006-wifi-mt76-add-mutex-protection-in-critical-paths.patch`

Adds missing mutex protection in critical paths to prevent race conditions.

**Affected areas:**
- Station management
- Link state transitions
- MCU command handling

---

## Patch 07: Add MCU Error Handling

**File:** `0007-wifi-mt76-add-mcu-command-error-handling.patch`

Improves error handling for MCU (Microcontroller Unit) commands to gracefully handle timeouts and failures.

**Symptoms:**
- MCU command timeouts
- Driver hangs waiting for firmware response

---

## Patch 08: Add Lockdep Assertions

**File:** `0008-wifi-mt76-add-lockdep-assertions.patch`

Adds lockdep assertions to verify mutex requirements are met, helping catch locking bugs during development.

!!! note
    This patch is primarily for debugging. It adds assertions that verify locks are held correctly.

---

## Patch 09: Fix MLO Roaming and ROC

**File:** `0009-wifi-mt76-mt7925-fix-mlo-roaming-and-roc-setup.patch`

Fixes issues with MLO roaming and remain-on-channel setup that could cause connection failures.

**Symptoms:**
- Failed roaming between APs
- ROC operations failing

---

## Patch 10: Fix BA Session Teardown

**File:** `0010-wifi-mt76-mt7925-fix-ba-session-teardown-beacon-loss.patch`

Fixes Block Acknowledgment (BA) session teardown during beacon loss, preventing state machine corruption.

**Symptoms:**
- Connection issues after brief signal loss
- BA session stuck in bad state

---

## Patch 11: Fix ROC Deadlocks and Races

**File:** `0011-wifi-mt76-mt7925-fix-roc-deadlocks-and-races.patch`

Comprehensive fixes for remain-on-channel deadlocks and race conditions.

**Symptoms:**
- System hangs during scanning
- Deadlock in ROC operations

---

## Patch 12: Fix Double wcid Initialization

**File:** `0012-wifi-mt76-mt7925-fix-double-wcid-init.patch`

Fixes a race condition where wcid could be initialized twice, causing list corruption.

**Symptoms:**
- Kernel oops on connect
- List corruption messages

---

## Applying Individual Patches

To apply a specific patch:

```bash
cd /path/to/kernel/source
git apply /path/to/mt7925/kernels/6.18/0001-*.patch
```

To apply all patches:

```bash
git am /path/to/mt7925/kernels/6.18/*.patch
```
