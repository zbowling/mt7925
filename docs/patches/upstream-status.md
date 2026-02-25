# Upstream Status

Progress toward getting these fixes into the mainline Linux kernel.

## Current Status

| Patch | Status | Notes |
|-------|--------|-------|
| 01 - Double wcid init race | :material-email:{ .yellow } Submitted | v7 series |
| 02 - NULL pointer protection | :material-email:{ .yellow } Submitted | v7 series |
| 03 - Mutex protection | :material-email:{ .yellow } Submitted | v7 series |
| 04 - MCU error handling | :material-email:{ .yellow } Submitted | v7 series |
| 05 - Lockdep assertions | :material-email:{ .yellow } Submitted | v7 series |
| 06 - MLO ROC error handling | :material-email:{ .yellow } Submitted | v7 series |
| 07 - MLO ROC error logging  | :material-email:{ .yellow } Submitted | v7 series |

## Submission History

### v7 (Current - January 29, 2026)

- **Date:** January 29, 2026
- **Series:** 7 patches
- **To:** Felix Fietkau (nbd@nbd.name) - MT76 maintainer
- **Cc:** linux-wireless, linux-kernel, MediaTek engineers, Framework
- **Status:** Under review

**Patches:**

1. `wifi: mt76: mt7925: fix double wcid initialization race condition`
2. `wifi: mt76: mt7925: add NULL pointer protection for MLO operations`
3. `wifi: mt76: mt7925: add mutex protection in critical paths`
4. `wifi: mt76: mt7925: add MCU command error handling in ampdu_action`
5. `wifi: mt76: mt7925: add lockdep assertions for mutex verification`
6. `wifi: mt76: mt7925: fix MLO ROC setup error handling`
7. `wifi: mt76: mt7925: add error logging for MLO ROC setup in set_links`

### v6 (January 2026)

- **Date:** January 2026
- **Series:** 12 patches (consolidated from earlier versions)
- **Changes:** Squashed mt7921 patches, added wcid init fix
- **Status:** Superseded by v7

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
