# DKMS Packaging for MT7925/MT7921 Drivers

This document describes the DKMS (Dynamic Kernel Module Support) packaging design and implementation for the MT7925/MT7921 WiFi drivers.

## Overview

DKMS enables automatic rebuilding of kernel modules when the kernel is updated, eliminating the need to manually recompile drivers after system updates. Our DKMS package includes:

- **12 kernel modules**: mt76, mt76-connac-lib, mt792x-lib, mt76-usb, mt792x-usb, mt76-sdio, mt7921-common, mt7921e, mt7921s, mt7921u, mt7925-common, mt7925e
- **Support for both chipsets**: MT7925 (primary) and MT7921 (shared ABI compatibility)
- **Multi-bus support**: PCIe, USB, and SDIO interfaces

## Package Formats

### Arch Linux (PKGBUILD)

Location: `dkms/PKGBUILD`

```bash
# Key fields
pkgname=mt76-mt7925-dkms
pkgver=1.4.0
depends=('dkms' 'linux-firmware')
source=("https://github.com/.../mt76-mt7925-dkms-${pkgver}.tar.gz")
```

**Best Practices Applied:**
- Uses `dkms.install` for standard DKMS hooks
- Installs to `/usr/src/${pkgname}-${pkgver}/`
- Includes LICENSE file in package
- Follows AUR packaging guidelines

### Debian/Ubuntu (debian/*)

Location: `dkms/debian/`

**Key Files:**

| File | Purpose |
|------|---------|
| `control` | Package metadata and dependencies |
| `rules` | Build rules (uses dh-dkms) |
| `changelog` | Version history |
| `copyright` | License information |
| `source/format` | Source format (3.0 quilt) |

**Build-Depends:**
```
debhelper-compat (= 13), dkms
```

**Runtime Depends:**
```
dkms, linux-firmware
```

**debian/rules Overview:**
```makefile
#!/usr/bin/make -f

VERSION := $(shell dpkg-parsechangelog -S Version | sed 's/-.*//')

%:
	dh $@ --with dkms

override_dh_dkms:
	dh_dkms -V $(VERSION)

override_dh_auto_install:
	mkdir -p debian/mt76-mt7925-dkms/usr/src/mt76-mt7925-$(VERSION)/
	cp -a src debian/mt76-mt7925-dkms/usr/src/mt76-mt7925-$(VERSION)/
	cp dkms.conf debian/mt76-mt7925-dkms/usr/src/mt76-mt7925-$(VERSION)/
```

**Best Practices Applied:**
- Uses `debhelper-compat (= 13)` for modern debhelper
- Uses `dh-dkms` integration for automatic DKMS handling
- Dynamic version extraction from changelog
- Follows Debian Policy for DKMS packages
- Architecture: `all` (source-only, builds on target)

### Fedora/RHEL (RPM Spec)

Location: `dkms/mt76-mt7925-dkms.spec`

**Key Sections:**
```spec
%define module mt76-mt7925
%define version 1.4.0

Name:       %{module}-dkms
Version:    %{version}
Release:    1%{?dist}
BuildArch:  noarch
Requires:   dkms kernel-devel linux-firmware
```

**DKMS Scriptlets:**
```spec
%post
dkms add -m %{module} -v %{version} --rpm_safe_upgrade
dkms build -m %{module} -v %{version}
dkms install -m %{module} -v %{version} --force

%preun
dkms remove -m %{module} -v %{version} --all --rpm_safe_upgrade
```

**Best Practices Applied:**
- Uses `--rpm_safe_upgrade` for proper upgrade handling
- Uses `--force` to override stock modules
- Includes `%{?dist}` for distribution tagging
- Requires `kernel-devel` for headers
- Architecture: `noarch` (source-only)

## DKMS Configuration

Location: `dkms/dkms.conf`

```bash
PACKAGE_NAME="mt76-mt7925"
PACKAGE_VERSION="1.4.0"
AUTOINSTALL="yes"

# Build configuration
MAKE[0]="make -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build modules"
CLEAN="make -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build clean"

# Module definitions (12 modules)
BUILT_MODULE_NAME[0]="mt76"
DEST_MODULE_LOCATION[0]="/updates/dkms"
# ... (all 12 modules)
```

### Key Design Decisions

1. **DEST_MODULE_LOCATION: `/updates/dkms`**
   - Higher priority than stock modules in `/kernel/`
   - Follows depmod search order: `updates > extramodules > built-in`
   - No blacklisting needed

2. **AUTOINSTALL="yes"**
   - Automatically builds for new kernels
   - Handles kernel updates transparently

3. **Clang Support**
   - Makefile auto-detects `CONFIG_CC_IS_CLANG=y`
   - Uses `CC=clang LD=ld.lld LLVM=1` when needed

## Module Priority and Loading

### Priority Order (depmod)

```
/lib/modules/<kernel>/
├── updates/dkms/      # Highest - DKMS modules go here
├── updates/           # High
├── extra/             # Medium
└── kernel/            # Lowest - stock modules
```

DKMS modules automatically take precedence over stock modules without blacklisting.

### Module Load Order

1. `mt76` (core)
2. `mt76-connac-lib` (common functionality)
3. `mt792x-lib` (shared MT792x code)
4. `mt7925-common` or `mt7921-common`
5. `mt7925e` / `mt7921e` / `mt7921u` / `mt7921s` (bus-specific)

## CI/CD Pipeline

### Build Matrix

| Distribution | Package Format | Build Method |
|--------------|----------------|--------------|
| Arch Linux | `.pkg.tar.zst` | Docker + makepkg |
| Debian/Ubuntu | `.deb` | dpkg-buildpackage |
| Fedora/RHEL | `.rpm` | rpmbuild |

### GitHub Actions Workflow

```yaml
# Simplified structure
jobs:
  build-packages:
    steps:
      - Create source tarball
      - Build DEB (dpkg-buildpackage)
      - Build RPM (rpmbuild)
      - Build Arch (Docker container)
      - Upload artifacts

  release:
    needs: build-packages
    if: startsWith(github.ref, 'refs/tags/')
    steps:
      - Download artifacts
      - Create GitHub Release

  publish-aur:
    needs: release
    steps:
      - Update PKGBUILD checksum
      - Push to AUR
```

### Arch Linux Build (Docker)

The Arch build uses a Docker container because GitHub runners are Ubuntu-based:

```bash
docker run --rm archlinux:latest bash -c '
  pacman -Syu --noconfirm base-devel dkms linux-firmware
  useradd -m builder
  echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
  chown -R builder:builder /build
  su builder -c "makepkg --noconfirm"
'
```

## Installation Methods

### Direct Install (Development)

```bash
cd dkms
sudo ./install.sh
```

The installer:
1. Checks kernel version (6.17+ required)
2. Checks dependencies (dkms, headers, clang if needed)
3. Removes previous versions
4. Unloads existing modules
5. Installs source to `/usr/src/`
6. Runs `dkms add/build/install`
7. Loads new modules

### Package Install (Production)

```bash
# Arch
yay -S mt76-mt7925-dkms

# Debian/Ubuntu
sudo dpkg -i mt76-mt7925-dkms_*.deb

# Fedora
sudo dnf install mt76-mt7925-dkms-*.rpm
```

## Best Practices Summary

### Debian Packaging

1. **Use dh-dkms** - Handles DKMS integration automatically
2. **Use debhelper-compat** - Modern approach, no debian/compat file needed
3. **Dynamic versioning** - Extract from changelog with `dpkg-parsechangelog`
4. **Architecture: all** - DKMS packages are source-only
5. **Install to /usr/src** - Standard DKMS source location

### RPM Packaging

1. **Use --rpm_safe_upgrade** - Proper handling during upgrades
2. **Use --force in install** - Override stock modules
3. **BuildArch: noarch** - Source-only package
4. **Require kernel-devel** - Headers for building
5. **Include %{?dist}** - Distribution-specific releases

### DKMS Configuration

1. **AUTOINSTALL=yes** - Automatic builds for new kernels
2. **Use /updates/dkms** - Higher priority than stock modules
3. **Clean Makefile** - Support both gcc and clang builds
4. **Module dependencies** - Define BUILT_MODULE_NAME/DEST_MODULE_LOCATION for all

## Troubleshooting

### Build Failures

```bash
# Check DKMS build logs
sudo cat /var/lib/dkms/mt76-mt7925/1.4.0/build/make.log

# Manual build test
cd /usr/src/mt76-mt7925-1.4.0
make -C /lib/modules/$(uname -r)/build M=$PWD
```

### Module Loading Issues

```bash
# Check module priority
modinfo mt7925e | grep filename
# Should show: /lib/modules/.../updates/dkms/mt7925e.ko

# Force reload
sudo modprobe -r mt7925e mt7925-common mt792x-lib mt76-connac-lib mt76
sudo modprobe mt7925e
```

### Clang-Built Kernels

```bash
# Check if kernel uses clang
grep CONFIG_CC_IS_CLANG /lib/modules/$(uname -r)/build/.config

# Install clang toolchain
sudo pacman -S clang lld  # Arch
sudo apt install clang lld  # Debian
sudo dnf install clang lld  # Fedora
```

## References

- [DKMS Documentation](https://github.com/dell/dkms)
- [Debian DKMS Packaging Guide](https://wiki.debian.org/DKMS)
- [Fedora Packaging Guidelines: Kernel Modules](https://docs.fedoraproject.org/en-US/packaging-guidelines/Kernel_Modules/)
- [Arch Wiki: DKMS](https://wiki.archlinux.org/title/DKMS)
