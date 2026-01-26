# Patch Overview

This project provides 12 stability patches for the MediaTek MT7925/MT7921 WiFi drivers that fix critical bugs causing kernel panics, deadlocks, and system hangs.

## Patch Series Summary

| # | Patch | Issue Fixed |
|---|-------|-------------|
| 01 | Fix deadlock in `mt7925_abort_roc` | ROC abort deadlock |
| 02 | Fix list corruption in `mt76_wcid_cleanup` | wcid list corruption |
| 03 | Fix NULL pointer in `mt792x_sta_link_rc_work` | NULL deref in RC work |
| 04 | Fix mutex deadlock in suspend/resume | Suspend deadlock |
| 05 | Add NULL checks for MLO operations | MLO NULL derefs |
| 06 | Add mutex protection in critical paths | Race conditions |
| 07 | Add MCU command error handling | MCU timeout handling |
| 08 | Add lockdep assertions | Debug assertions |
| 09 | Fix MLO roaming and ROC setup | MLO roaming issues |
| 10 | Fix BA session teardown | Beacon loss handling |
| 11 | Fix ROC deadlocks and races | ROC stability |
| 12 | Fix double wcid initialization | Race condition |

## Supported Kernel Versions

Patches are maintained for multiple kernel versions:

| Kernel | Patch Directory | Status |
|--------|-----------------|--------|
| 6.17.x | `kernels/6.17/` | :material-check: Stable |
| 6.18.x | `kernels/6.18/` | :material-check: Stable |
| 6.19-rc | `kernels/6.19-rc/` | :material-check: Stable |
| nbd168 | `kernels/nbd168/` | :material-check: Upstream tree |

## Applying Patches Manually

If you prefer to patch your kernel source instead of using DKMS:

```bash
# Get kernel source
git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git -b v6.18.5
cd linux

# Apply patches (choose your kernel version)
git am /path/to/mt7925/kernels/6.18/*.patch

# Build
make olddefconfig
make -j$(nproc)
sudo make modules_install install
```

## Pre-Patched Kernel Fork

For convenience, a pre-patched kernel is available:

```bash
git clone https://github.com/zbowling/linux-wifi.git
cd linux-wifi
git checkout mt7925-upstream-v2-6.18  # or -6.19, -6.17
```

## Next Steps

- [Patch List](patch-list.md) - Detailed description of each patch
- [Upstream Status](upstream-status.md) - Progress toward mainline inclusion
