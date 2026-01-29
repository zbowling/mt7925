# Patch Overview

This project provides stability patches for the MediaTek MT7925/MT7921 WiFi drivers that fix critical bugs causing kernel panics, deadlocks, and system hangs.

## Upstream Patch Series (v7)

The v7 series consists of 6 focused patches submitted to the nbd168 upstream tree:

| # | Patch | Issue Fixed |
|---|-------|-------------|
| 01 | Fix double wcid initialization race | Race condition in station add |
| 02 | Add NULL pointer protection for MLO | NULL derefs in link transitions |
| 03 | Add mutex protection in critical paths | Race conditions in PM/recovery |
| 04 | Add MCU command error handling | AMPDU BA session issues |
| 05 | Add lockdep assertions | Debug assertions for mutex |
| 06 | Fix MLO ROC setup error handling | WARN_ON_ONCE spam in MLO |

## DKMS Package Features

The DKMS package includes additional features beyond the upstream patches:

| Feature | Description |
|---------|-------------|
| **RSSI Monitor** | CQM RSSI threshold notifications via firmware events |
| **CSA Support** | Handle AP-initiated channel switches (WiFi 7 MLO) |
| **Debug Features** | Optional verbose logging (compile-time flag) |

## Supported Kernel Versions

Patches are maintained for multiple kernel versions:

| Kernel | Patch Directory | Status |
|--------|-----------------|--------|
| 6.17.x | `kernels/6.17/` | :material-check: Stable |
| 6.18.x | `kernels/6.18/` | :material-check: Stable |
| 6.19-rc | `kernels/6.19-rc/` | :material-check: Stable |
| nbd168 | `kernels/nbd168/` | :material-check: v7 series (6 patches) |

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
