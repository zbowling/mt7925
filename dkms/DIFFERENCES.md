# DKMS Module Differences from Mainline Linux

This document tracks patches and modifications in the DKMS module that differ
from mainline Linux. These are either:
- Patches pending merge in mainline
- Patches from linux-wireless mailing list not yet merged
- Local fixes specific to this DKMS build

## Patches from Mainline Patchsets

The following patches are from our patchsets submitted to linux-wireless:
- See `kernels/nbd168/*.patch` for the full list (22 patches)
- These fix NULL pointer dereferences, mutex issues, MLO bugs, etc.
- Tracking: Submitted as v4 patchset to linux-wireless mailing list

## Additional Patches (DKMS Only)

These patches are applied to the DKMS module but NOT included in the mainline
patchsets. They are either pending review, from other authors, or experimental.

### 1. Skip scan during suspend (2026-01-12)

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

### 2. Fix deadlock in sta removal ROC abort path (2026-01-16)

**Source:** Local fix based on user crash reports

**Author:** Zac Bowling <zbowling@gmail.com>

**Status:** Patch 0022 - pending submission to linux-wireless

**Files:** `mt76.h`, `mt7925/main.c`

**Description:**
Fixes a mutex deadlock that occurs during station removal when ROC (Remain On
Channel) work is pending. The deadlock happens when cancel_work_sync() is
called while holding the device mutex, and the work function needs the same
mutex.

This manifests as hung tasks (122+ second timeouts), system freezes during
roaming, and processes stuck in uninterruptible sleep.

**Root cause:**
```
Thread A (sta_remove):          Thread B (roc_work):
mutex_lock(&dev->mutex)
  -> cancel_work_sync(roc_work)   -> mt792x_mutex_acquire()
     WAITS for work                   BLOCKED on mutex
        DEADLOCK
```

**Fix approach:**
- Add MT76_STATE_ROC_ABORT atomic flag
- Create mt7925_roc_abort_async() that sets flag without blocking
- Modify roc_work to check abort flag BEFORE acquiring mutex
- Use async abort in sta_remove path

**Why in patchset:**
This is a significant deadlock fix that affects users during normal operation
(roaming). Added to patch 0022 for upstream submission.

---

## Version History

| Date | Change |
|------|--------|
| 2026-01-16 | Added patch 0022: deadlock fix in sta removal ROC abort |
| 2026-01-16 | Added scan suspend skip patch from MediaTek |
| 2026-01-15 | Initial DKMS with 21 patches from patchset |
