# MediaTek MT7925 WiFi Driver Fixes

Critical fixes for the MediaTek MT7925 WiFi driver that resolve kernel panics, mutex deadlocks, and system hangs on Framework Desktop systems and other hardware using this WiFi card.

## Status

**Patches:** 24-26 patches (depending on kernel version) tested and submitted to LKML for upstream inclusion.

**DKMS:** v1.1.0 - requires kernel 6.17+ (uses APIs not available in older kernels)

## Quick Start

### Option 1: Apply Patches to Your Kernel (Recommended)

```bash
# Get kernel source matching your version
# Ideally google how to fetch your linux kernel sources for your distro with all the your distro patches and config.


# Or check out vanilla linux kernel
git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git -b v6.18.5
cd linux

# Apply patches (use the folder for your kenrel version, 6.17/6.18/6.19-rc, etc)
git am /path/to/mt7925/kernels/6.18/*.patch

# Build and install
make olddefconfig
make -j$(nproc)
sudo make modules_install install
```

### Option 2: Use Pre-Patched Kernel

```bash
git clone https://github.com/zbowling/linux-wifi.git
cd linux-wifi
git checkout mt7925-fixes-v6.18.5  # or v6.19-rc5, v6.17.13

make olddefconfig
make -j$(nproc)
sudo make modules_install install
```

### Option 3: DKMS Package (Beta - Kernel 6.17+ Only)

> **Warning:** The DKMS package requires kernel 6.17 or newer. It will NOT build on older kernels like Ubuntu 24.04's 6.8 kernel due to missing kernel APIs.

```bash
cd dkms
sudo ./install.sh
```

## Supported Kernel Versions

| Version | Patches | Status | Notes |
|---------|---------|--------|-------|
| 6.18.x | 25 (`kernels/6.18/`) | **Current stable** | Arch, Fedora 42, CachyOS |
| 6.19-rc | 26 (`kernels/6.19-rc/`) | Release candidate | Bleeding edge |
| 6.17.x | 24 (`kernels/6.17/`) | EOL | Fedora 41, older Arch |
| nbd168 | 25 (`kernels/nbd168/`) | Upstream staging | nbd168/wireless tree |

## Repository Structure

```
mt7925/
├── kernels/                    # Patches organized by kernel version
│   ├── 6.17/                   # 24 patches for v6.17.13
│   ├── 6.18/                   # 25 patches for v6.18.5
│   ├── 6.19-rc/                # 26 patches for v6.19-rc5
│   └── nbd168/                 # 25 patches for nbd168/wireless
├── dkms/                       # DKMS package (v1.1.0, requires 6.17+)
│   ├── install.sh              # Installer (auto-detects clang)
│   ├── uninstall.sh            # Clean removal
│   ├── dkms.conf               # DKMS configuration
│   └── src/                    # Pre-patched mt76 source
├── crashes/                    # Crash logs for debugging
├── docs/                       # Documentation for mt76 drivers
│   ├── ARCHITECTURE.md         # Driver architecture overview
│   ├── LOCKING.md              # Locking and mutex patterns
│   └── PATCH_DIFFERENCES.md    # Version differences
└── scripts/
    └── validate-patches.sh     # Local patch validation
```

## Pre-Patched Kernel Fork

**Repository:** https://github.com/zbowling/linux-wifi

| Branch | Base | Status |
|--------|------|--------|
| `mt7925-fixes-v6.18.5` | v6.18.5 | **Primary** |
| `mt7925-fixes-v6.19-rc5` | v6.19-rc5 | RC |
| `mt7925-fixes-v6.17.13` | v6.17.13 | EOL |
| `mt7925-fixes-nbd168` | nbd168/mt76 | Staging |

Base tags are pushed for easy comparison: `git diff v6.18.5..mt7925-fixes-v6.18.5`

## DKMS Installation (Beta)

### Requirements

- **Kernel 6.17 or newer** (won't build on older kernels)
- DKMS installed
- Kernel headers for your running kernel
- Clang + lld (if your kernel was built with clang)

### Install

```bash
cd dkms
sudo ./install.sh
```

The installer:
1. Checks dependencies and kernel version
2. Auto-detects clang-built kernels (uses `CC=clang LD=ld.lld LLVM=1`)
3. Blacklists stock mt76 modules
4. Builds 5 modules via DKMS: mt76, mt76-connac-lib, mt792x-lib, mt7925-common, mt7925e
5. Loads the new modules

### Verify

```bash
dkms status                    # Check DKMS status
lsmod | grep mt7925            # Verify modules loaded
modinfo mt7925e                # Check module info
```

### Uninstall

```bash
cd dkms
sudo ./uninstall.sh
```

## Problem Description

The MT7925 WiFi driver has several critical bugs:

1. **NULL Pointer Dereference** - Kernel panics during reset or state transitions
2. **Mutex Deadlock in Reset/ROC** - System hangs during network switching
3. **Mutex Deadlock in Power Management** - Deadlocks during suspend/resume
4. **Missing Error Handling** - MCU command failures cause inconsistent state
5. **ROC Work Deadlock** - `cancel_work_sync` called while holding mutex
6. **WCID Resource Leak** - WCID table exhaustion on repeated sta add failures
7. **List Corruption** - `sta_poll_list` corruption after device reset
8. **Suspend/Resume Race** - ROC timer firing during quiescing causes hangs

### Affected Hardware

- Framework Desktop (AMD Ryzen AI Max 300 Series)
- Framework Laptop 13 (AMD Ryzen AI 300 Series) with MT7925
- Any system using MediaTek MT7925 WiFi

### Symptoms

- Kernel panics with NULL pointer dereference in mt7925
- System hangs during WiFi network switching
- Processes stuck in D state (uninterruptible sleep)
- Hangs during suspend/resume cycles

## Patches (24-26 per kernel)

| # | Patch | Category |
|---|-------|----------|
| 01 | fix-NULL-pointer-dereference-in-vif | Critical |
| 02-03 | fix-missing-mutex-protection | Critical |
| 04-05 | add-NULL-checks-in-MCU-STA-TLV | NULL Checks |
| 06-08 | add-error-handling-for-MCU | Error Handling |
| 09 | add-NULL-checks-in-MLO-link | MLO |
| 10 | fix-NULL-pointer-dereference-in-TX | Critical (mt792x) |
| 11 | add-lockdep-assertions | Debug |
| 12-13 | fix-MLO-roaming-issues | MLO |
| 14-17 | add-NULL-checks-and-mutex | Safety |
| 18 | mt7921-fix-missing-mutex | MT7921 |
| 19 | mt7921-fix-mutex-deadlocks | MT7921 |
| 20 | fix-list-corruption-in-wcid-cleanup | Critical (mt76 core) |
| 21 | fix-BA-session-teardown-beacon-loss | Critical |
| 22 | fix-deadlock-in-sta-removal-ROC-abort | Critical |
| 23 | fix-ROC-timer-race-during-suspend | Critical |
| 24 | add-ROC-rate-limiting-MLO-auth-failures | Stability |
| 25 | fix-deadlock-and-WCID-leak-bugs | Critical |

## Building with Clang

If your kernel was built with clang (Arch, CachyOS, etc.):

```bash
# Manual build
make CC=clang LD=ld.lld LLVM=1 -j$(nproc) M=drivers/net/wireless/mediatek/mt76

# DKMS auto-detects CONFIG_CC_IS_CLANG=y and uses clang automatically
```

## CI Status

- **Patch validation**: Tests all patches apply cleanly to each kernel version
- **DKMS validation**: Syntax and structure checks
- **DKMS build**: Tests builds on Ubuntu 25.10, Fedora 42, Arch Linux

## Upstream Status

All patches submitted to LKML for upstream inclusion. Also submitted to [OpenWrt mt76](https://github.com/openwrt/mt76).

## Related Issues

- [Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
- [Ubuntu Bug #2137291](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)
- [LKML Thread](https://lore.kernel.org/all/CAA5_Hq7vNOy9oCGkkgyukq2OP=a5yL_3ZKBdmNtBXS+zp6byiQ@mail.gmail.com/T/#u)

## Contributing

1. Test patches on your system
2. Report results in the [Framework Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
3. Update the [Ubuntu bug](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)

## License

BSD-2-Clause-Clear AND GPL-2.0-only (dual licensed, same as mt76 driver)
