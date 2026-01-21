# MediaTek MT7925 WiFi Driver Fixes

Critical fixes for the MediaTek MT7925 WiFi driver that resolve kernel panics, mutex deadlocks, and system hangs on Framework Desktop systems and other hardware using this WiFi card.

## Status

**Patches:** 12 patches (v7) for each kernel version - includes Sean Wang's upstream deadlock fix + 11 stability patches.

**DKMS:** v1.3.0 - requires kernel 6.17+ (uses APIs not available in older kernels)

## Quick Start

### Option 1: Apply Patches to Your Kernel (Recommended)

```bash
# Get kernel source matching your version
# Ideally google how to fetch your linux kernel sources for your distro with all the your distro patches and config.

# Or check out vanilla linux kernel
git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git -b v6.18.5
cd linux

# Apply patches (use the folder for your kernel version: 6.17, 6.18, 6.19-rc, nbd168)
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
git checkout mt7925-upstream-v2-6.18  # or -6.19, -6.17, or mt7925-upstream-v2 (nbd168)

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
| 6.18.x | 12 (`kernels/6.18/`) | **Current stable** | Arch, Fedora 42, CachyOS |
| 6.19-rc | 12 (`kernels/6.19-rc/`) | Release candidate | Bleeding edge |
| 6.17.x | 12 (`kernels/6.17/`) | EOL | Fedora 41, older Arch |
| nbd168 | 12 (`kernels/nbd168/`) | **Upstream target** | nbd168/wireless tree |

## Patch Series (v6)

**12 patches** - Sean Wang's upstream deadlock fix as base + 11 stability patches:

| # | Patch | Category |
|---|-------|----------|
| 01 | mt7925: fix potential deadlock in roc_abort_sync | **Critical** (Sean Wang's upstream fix) |
| 02 | mt76: fix list corruption in mt76_wcid_cleanup | Critical (mt76 core) |
| 03 | mt792x: fix NULL pointer and firmware reload issues | Critical (mt792x shared) |
| 04 | mt7921: fix mutex and ROC deadlocks | Critical (mt7921) |
| 05 | mt7925: add comprehensive NULL pointer protection for MLO | Safety (mt7925) |
| 06 | mt7925: add mutex protection in critical paths | Safety (mt7925) |
| 07 | mt7925: add MCU command error handling | Safety (mt7925) |
| 08 | mt7925: add lockdep assertions for mutex verification | Debug (mt7925) |
| 09 | mt7925: fix MLO roaming and ROC setup issues | MLO (mt7925) |
| 10 | mt7925: fix BA session teardown during beacon loss | Critical (mt7925) |
| 11 | mt7925: fix ROC deadlocks and race conditions | Critical (mt7925) |
| 12 | mt7925: fix double wcid initialization race condition | Critical (mt7925) |

**Order:** `Sean's fix → mt76 core → mt792x shared → mt7921 → mt7925`

## Repository Structure

```
mt7925/
├── kernels/                    # Patches organized by kernel version
│   ├── 6.17/                   # 12 patches for v6.17.13
│   ├── 6.18/                   # 12 patches for v6.18.5
│   ├── 6.19-rc/                # 12 patches for v6.19-rc5
│   └── nbd168/                 # 12 patches for nbd168/wireless (upstream)
├── dkms/                       # DKMS package (v1.3.0, requires 6.17+)
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
| `mt7925-upstream-v2` | nbd168/mt76 | **Upstream target** |
| `mt7925-upstream-v2-6.18` | v6.18.5 | Current stable |
| `mt7925-upstream-v2-6.19` | v6.19-rc5 | RC |
| `mt7925-upstream-v2-6.17` | v6.17.13 | EOL |

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

1. **ROC Deadlock** - `cancel_work_sync` called while holding mutex (Sean's fix)
2. **NULL Pointer Dereference** - Kernel panics during reset or state transitions
3. **Mutex Deadlock in Reset/ROC** - System hangs during network switching
4. **Mutex Deadlock in Power Management** - Deadlocks during suspend/resume
5. **Missing Error Handling** - MCU command failures cause inconsistent state
6. **WCID Resource Leak** - WCID table exhaustion on repeated sta add failures
7. **List Corruption** - `sta_poll_list` corruption after device reset
8. **Suspend/Resume Race** - ROC timer firing during quiescing causes hangs
9. **Double WCID Init Race** - wcid reinitialized after RCU publish causes corruption

### Affected Hardware

- Framework Desktop (AMD Ryzen AI Max 300 Series)
- Framework Laptop 13 (AMD Ryzen AI 300 Series) with MT7925
- Any system using MediaTek MT7925 WiFi

### Symptoms

- Kernel panics with NULL pointer dereference in mt7925
- System hangs during WiFi network switching
- Processes stuck in D state (uninterruptible sleep)
- Hangs during suspend/resume cycles

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

Patches prepared for upstream submission to:
- **nbd168/wireless** (Felix Fietkau's staging tree)
- **linux-wireless mailing list**
- **OpenWRT mt76**

Patch 01 (Sean Wang's deadlock fix) is already in the upstream queue.

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
