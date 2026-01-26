# Upstream Status

Progress toward getting these fixes into the mainline Linux kernel.

## Current Status

| Patch | Status | Notes |
|-------|--------|-------|
| 01 - ROC abort deadlock | :material-check-circle:{ .green } Merged | Sean Wang's upstream fix |
| 02-12 - Stability series | :material-clock:{ .yellow } Submitted | v7 series under review |

## Submission History

### v7 (Current)

- **Date:** January 2026
- **Series:** 12 patches
- **Status:** Under review on linux-wireless mailing list

### v6

- **Date:** January 2026
- **Changes:** Squashed mt7921 patches, added wcid init fix

### Previous Versions

Earlier versions (v1-v5) were iterative improvements based on reviewer feedback.

## Mailing List Threads

- [linux-wireless patch series](https://lore.kernel.org/linux-wireless/) - Search for "mt7925 stability"

## How to Help

### Testing

Test the patches on your hardware and report results:

1. Install using DKMS or patches
2. Use WiFi normally for a few days
3. Report any issues on [GitHub](https://github.com/zbowling/mt7925/issues)

### Review

If you're familiar with the mt76 driver, review the patches:

1. Check the patch series on linux-wireless
2. Test on your hardware
3. Reply with `Tested-by:` or `Reviewed-by:`

## Related Upstream Work

- [MediaTek MT76 driver](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/net/wireless/mediatek/mt76)
- [nbd168's wireless tree](https://git.kernel.org/pub/scm/linux/kernel/git/netdev/net-next.git/) - MT76 maintainer tree

## Timeline

| Milestone | Target | Status |
|-----------|--------|--------|
| v7 submission | January 2026 | :material-check: Done |
| Review feedback | February 2026 | :material-clock: Pending |
| Merge to net-next | TBD | :material-clock: Pending |
| Mainline kernel | 6.20+ | :material-clock: Pending |
