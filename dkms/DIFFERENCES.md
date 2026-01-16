# DKMS Module Differences from Mainline Linux

This document tracks patches and modifications in the DKMS module that differ
from mainline Linux. These are either:
- Patches pending merge in mainline
- Patches from linux-wireless mailing list not yet merged
- Local fixes specific to this DKMS build

## Patches from Mainline Patchsets

The following patches are from our patchsets submitted to linux-wireless:
- See `kernels/nbd168/*.patch` for the full list (21 patches)
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

## Version History

| Date | Change |
|------|--------|
| 2026-01-16 | Added scan suspend skip patch from MediaTek |
| 2026-01-15 | Initial DKMS with 21 patches from patchset |
