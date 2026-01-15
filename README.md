# MediaTek MT7925 WiFi Driver Fixes

This repository contains critical fixes for the MediaTek MT7925 WiFi driver that resolve kernel panics and system deadlocks on Framework Desktop systems and other hardware using this WiFi card.

## Quick Start

### Option 1: Use Pre-Patched Kernel Fork (Easiest)

Clone our pre-patched Linux kernel fork:

```bash
git clone https://github.com/zbowling/linux-wifi.git
cd linux-wifi

# Choose your kernel version
git checkout mt7925-fixes-v6.18.5   # Current stable
# or: git checkout mt7925-fixes-v6.19-rc5  # Bleeding edge
# or: git checkout mt7925-fixes-v6.17.13   # Older stable

# Build and install
make olddefconfig
make -j$(nproc)
sudo make modules_install install
```

### Option 2: DKMS Package (Recommended for Most Users)

```bash
cd dkms
sudo ./install.sh
```

This builds and installs patched modules via DKMS. They'll auto-rebuild on kernel updates.

### Option 3: Apply Patches Manually

```bash
# Get kernel source
git clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
cd linux
git checkout v6.18.5

# Apply patches
git am /path/to/mt7925/kernels/6.18/*.patch

# Build
make olddefconfig
make -j$(nproc)
```

## Repository Structure

```
mt7925/
├── kernels/                    # Patches organized by kernel version
│   ├── 6.17/                   # 17 patches for v6.17.13 (EOL)
│   ├── 6.18/                   # 18 patches for v6.18.5 (current stable)
│   ├── 6.19-rc/                # 18 patches for v6.19-rc5 (bleeding edge)
│   └── nbd168/                 # 18 patches for nbd168/wireless tree
├── dkms/                       # DKMS package for easy installation
│   ├── install.sh              # One-command installer
│   ├── uninstall.sh            # Clean removal
│   ├── dkms.conf               # DKMS configuration
│   └── src/                    # Pre-patched mt76 source
├── linux-6.19-rc4/             # Legacy patches (historical reference)
├── scripts/
│   └── validate-patches.sh     # Verify patches apply cleanly
├── docs/
│   └── PATCH_DIFFERENCES.md    # How patches differ between versions
├── AGENTS.md                   # Instructions for AI agents
├── stress-test.sh              # WiFi stress testing script
└── monitor.sh                  # Driver monitoring script
```

## Pre-Patched Kernel Fork

We maintain a Linux kernel fork with all patches pre-applied:

**Repository:** https://github.com/zbowling/linux-wifi

| Branch | Base Tag | Patches | Status |
|--------|----------|---------|--------|
| `mt7925-fixes-v6.17.13` | v6.17.13 | 17 | EOL but still used |
| `mt7925-fixes-v6.18.5` | v6.18.5 | 18 | **Current stable** |
| `mt7925-fixes-v6.19-rc5` | v6.19-rc5 | 18 | Bleeding edge |
| `mt7925-fixes-nbd168` | nbd168/mt76 | 18 | Upstream staging |

Base tags are pushed so you can easily compare: `git diff v6.18.5..mt7925-fixes-v6.18.5`

## DKMS Installation

### Requirements

- DKMS installed (`pacman -S dkms` / `apt install dkms`)
- Kernel headers for your running kernel
- Clang (if your kernel was built with clang)

### Install

```bash
cd dkms
sudo ./install.sh
```

The installer will:
1. Check dependencies
2. Blacklist stock mt76 modules
3. Build and install via DKMS
4. Load the new modules

### Uninstall

```bash
cd dkms
sudo ./uninstall.sh
```

### Verify

```bash
dkms status                           # Check DKMS status
lsmod | grep mt7925                   # Verify modules loaded
modinfo mt7925e | grep srcversion     # Check module version
```

## Problem Description

The MT7925 WiFi driver (mt7925e) has several related bugs:

1. **NULL Pointer Dereference**: Kernel panics during reset or state transitions
2. **Mutex Deadlock in Reset/ROC Paths**: System hangs during network switching
3. **Mutex Deadlock in Power Management**: Deadlocks during suspend/resume
4. **Missing Error Handling**: MCU command failures cause inconsistent state

### Affected Hardware

- Framework Desktop (AMD Ryzen AI Max 300 Series)
- Framework Laptop 13 (AMD Ryzen AI 300 Series) with MT7925
- Any system using MediaTek MT7925 WiFi hardware

### Symptoms

- Kernel panics with NULL pointer dereference
- System hangs during WiFi network switching
- Processes stuck in uninterruptible sleep (D state)
- System unresponsive, requiring force reboot
- Hangs during suspend/resume cycles

## Patch Summary (18 patches)

| # | Patch | Category | Description |
|---|-------|----------|-------------|
| 01 | fix-NULL-pointer-dereference-in-vif | Critical | NULL pointer fix in vif iteration |
| 02 | fix-missing-mutex-protection-in-res | Critical | Missing mutex in reset/ROC abort |
| 03 | fix-missing-mutex-protection-in-run | Critical | Missing mutex in runtime PM/MLO PM |
| 04 | add-NULL-checks-in-MCU-STA-TLV | NULL Checks | NULL checks in MCU STA TLV |
| 05 | add-NULL-checks-for-link_conf | NULL Checks | NULL checks for link_conf/mlink |
| 06 | add-error-handling-for-AMPDU | Error Handling | AMPDU MCU error handling |
| 07 | add-error-handling-for-BSS-info-MCU | Error Handling | BSS info in sta_add |
| 08 | add-error-handling-for-BSS-info-in | Error Handling | BSS info in key setup |
| 09 | add-NULL-checks-in-MLO-link | NULL Checks | MLO link/chanctx checks |
| 10 | fix-NULL-pointer-dereference-in-TX | Critical | TX path NULL fix (mt792x) |
| 11 | add-lockdep-assertions | Debug | Mutex verification |
| 12 | fix-key-removal-failure | MLO Fix | MLO roaming key removal |
| 13 | fix-kernel-warning-in-MLO-ROC | MLO Fix | MLO ROC setup warning |
| 14 | add-NULL-checks-for-MLO-link-pointe | NULL Checks | MCU MLO link checks |
| 15 | fix-firmware-reload-failure | Recovery | Firmware reload fix (mt792x) |
| 16 | add-mutex-protection-in-resume | Mutex | Resume path protection |
| 17 | add-NULL-checks-for-link-pointers | NULL Checks | sta_add/conf_tx checks |
| 18 | mt7921-fix-missing-mutex | MT7921 | Same bugs in MT7921 |

## CI Validation

Patches are automatically validated via GitHub Actions:

- **Patch application**: Tests patches apply cleanly to each kernel version
- **Module build**: Builds mt76 modules with sccache
- **Targets**: 6.17.13, 6.18.5, 6.19-rc5, nbd168/wireless

Run locally:
```bash
./scripts/validate-patches.sh        # Test all versions
./scripts/validate-patches.sh 6.18   # Test specific version
```

## Building with Clang

If your kernel was built with clang (common on Arch/CachyOS), build modules with:

```bash
make CC=clang -j$(nproc) M=drivers/net/wireless/mediatek/mt76
```

Or for DKMS, ensure clang is available and the build will auto-detect.

## Upstream Status

| Patch | Status |
|-------|--------|
| 0001-0003 | Submitted to LKML / [OpenWrt PR #1029](https://github.com/openwrt/mt76/pull/1029) |
| 0004-0005 | [OpenWrt PR #1030](https://github.com/openwrt/mt76/pull/1030) |
| 0006-0008 | [OpenWrt PR #1031](https://github.com/openwrt/mt76/pull/1031) |
| 0009 | [OpenWrt PR #1032](https://github.com/openwrt/mt76/pull/1032) |
| 0010 | [OpenWrt PR #1033](https://github.com/openwrt/mt76/pull/1033) |
| 0011-0018 | Submitted to LKML |

## Related Issues

- [Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
- [Ubuntu Launchpad Bug #2137291](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)
- [Linux Kernel Mailing List Thread](https://lore.kernel.org/all/CAA5_Hq7vNOy9oCGkkgyukq2OP=a5yL_3ZKBdmNtBXS+zp6byiQ@mail.gmail.com/T/#u)
- [OpenWrt mt76 Issue #1027](https://github.com/openwrt/mt76/issues/1027)

## Contributing

1. Test the patches on your system
2. Report results in the [Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
3. Update the [Ubuntu Launchpad bug](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)

## License

These patches are provided under the same license as the Linux kernel (GPL v2).
