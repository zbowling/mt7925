# DKMS Module Differences from Mainline Linux

This document tracks patches and modifications in the DKMS module that differ
from mainline Linux. These are either:
- Patches pending merge in mainline (submitted to nbd168 as v7 series)
- Additional features from linux-wireless/nbd168 not yet in stable kernels
- DKMS-specific debug features

## Upstream Patch Series (v7)

The following 6 patches have been submitted to nbd168 (Felix Fietkau) for upstream:

| # | Patch | Status |
|---|-------|--------|
| 1 | Fix double wcid initialization race condition | Submitted |
| 2 | Add NULL pointer protection for MLO operations | Submitted |
| 3 | Add mutex protection in critical paths | Submitted |
| 4 | Add MCU command error handling in AMPDU actions | Submitted |
| 5 | Add lockdep assertions for mutex verification | Submitted |
| 6 | Fix MLO ROC setup error handling | Submitted |

See `kernels/nbd168/*.patch` for the full patch files.

## Additional Features (DKMS Only)

These features are in the DKMS module but NOT in the upstream patch series.
They are from the nbd168 development tree or are DKMS-specific enhancements.

### 1. RSSI Monitor Support (from nbd168)

**Source:** nbd168/wireless development tree

**Status:** In DKMS, tracking upstream

**Files:** `mt7925/mcu.c`, `mt7925/mcu.h`, `mt7925/mt7925.h`

**Description:**
CQM RSSI threshold notifications via firmware events. When signal strength
crosses configured thresholds, the driver notifies mac80211.

**Features:**
- MCU command `MCU_UNI_CMD_RSSI_MONITOR` for configuring thresholds
- Event handler for `MCU_UNI_EVENT_RSSI_MONITOR` unsolicited events
- Integration with mac80211 `ieee80211_cqm_rssi_notify()` API
- Automatic enable when chip has `MT792x_CHIP_CAP_RSSI_NOTIFY_EVT_EN`

---

### 2. CSA (Channel Switch Announcement) Support (from nbd168)

**Source:** nbd168/wireless development tree

**Status:** In DKMS, tracking upstream

**Files:** `mt7925/main.c`

**Description:**
Handle AP-initiated channel switches for WiFi 7 MLO scenarios.

**Features:**
- `pre_channel_switch` validation for supported scenarios
- `channel_switch` timer-based CSA work scheduling
- `channel_switch_rx_beacon` for beacon count updates
- `abort_channel_switch` for CSA cancellation
- `switch_vif_chanctx` for channel context transitions
- Extended channel switching capability advertised in STA mode

---

### 3. Skip scan during suspend (from MediaTek)

**Source:** https://lore.kernel.org/linux-mediatek/20260112114007.2115873-1-leon.yen@mediatek.com/

**Author:** Michael Lo <michael.lo@mediatek.com> (via Leon Yen)

**Status:** Pending merge in mainline

**File:** `mt7925/main.c`

**Description:**
Prevents command timeout issues when upper-layer processes trigger unexpected
scans while the system is in suspend mode.

**Change:**
```c
void mt7925_scan_work(struct work_struct *work)
{
    struct mt792x_phy *phy;
+   struct mt792x_dev *dev;
+   struct mt76_connac_pm *pm;

    phy = (struct mt792x_phy *)container_of(work, struct mt792x_phy,
                                            scan_work.work);

+   /* Skip scan during suspend to prevent command timeouts */
+   dev = phy->dev;
+   pm = &dev->pm;
+   if (pm->suspended)
+       return;

    while (true) {
        // ... rest of function
    }
}
```

**Why not in patchset:**
This patch is authored by MediaTek engineers and is already submitted to the
mailing list. We include it in DKMS for immediate benefit while waiting for
mainline merge.

---

### 4. Conditional Debug Features (DKMS-specific)

**Source:** Local DKMS enhancements

**Status:** DKMS-only (not for upstream)

**Files:** `compat.h`, `mt76.h`, `mt792x.h`, `mt7925/main.c`, `mt7921/main.c`

**Description:**
Controlled by `MT76_DKMS_DEBUG_FEATURES` compile-time flag in `compat.h`.

**Features when enabled:**
- `MT76_STATE_ROC_ABORT` atomic flag for async ROC abort handling
- ROC rate limiting/backoff mechanism to prevent MCU overload
- Verbose `dev_info()` logging for ROC, MLO, key management, and channel context

**To disable:**
```bash
# Build without debug features (matches upstream behavior)
make EXTRA_CFLAGS="-DMT76_DKMS_DEBUG_FEATURES=0"
```

**Why not in patchset:**
These are debugging aids for users experiencing issues. Upstream prefers
minimal logging, but for out-of-tree builds we want maximum visibility.

---

## How to Add New Patches

When adding patches to DKMS that aren't in the mainline patchsets:

1. Apply the patch to the relevant file in `dkms/src/`
2. Document it in this file with:
   - Source URL (mailing list link)
   - Author
   - Status (pending, experimental, local-only)
   - Description of the change
   - Why it's not in the patchset
3. Do NOT add it to `kernels/*/` directories (those are for mainline submission)

---

## Version History

| Date | Change |
|------|--------|
| 2026-01-29 | v1.5.0: Added RSSI monitor, CSA support, conditional debug features |
| 2026-01-29 | Consolidated upstream patches from 12 to 6 for v7 submission |
| 2026-01-16 | Added patch 0022: deadlock fix in sta removal ROC abort |
| 2026-01-16 | Added scan suspend skip patch from MediaTek |
| 2026-01-15 | Initial DKMS with 21 patches from patchset |
