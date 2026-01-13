# Building MT7925 WiFi Fixes on Arch Linux / CachyOS

This guide covers building a patched kernel with MT7925 WiFi driver fixes on Arch Linux or CachyOS.

## Prerequisites

```bash
sudo pacman -S base-devel git ccache
```

### Configure ccache for Kernel Builds

Kernel builds are large - increase ccache size to 20GB for best results:

```bash
# Set cache size to 20GB
ccache -M 20G

# Verify settings
ccache -s
```

## Option 1: CachyOS Kernel with Patches (Recommended)

This method builds a CachyOS kernel with all MT7925 patches applied.

### Setup Build Directory

```bash
mkdir -p ~/cachyos-kernel-build/build
cd ~/cachyos-kernel-build

# Clone CachyOS kernel PKGBUILD
git clone https://github.com/CachyOS/linux-cachyos.git
cp -r linux-cachyos/linux-cachyos/* build/
cd build
```

### Get the Patches

```bash
# Clone the patches repo
git clone https://github.com/zbowling/mt7925.git ~/mt7925-patches

# Copy patches to build directory (for kernel 6.18.x)
cp ~/mt7925-patches/patches/mt7925/000[1-9]-*.patch .
cp ~/mt7925-patches/patches/mt7925/001[0-7]-*.patch .

# Or for kernel 6.19+
# cp ~/mt7925-patches/linux-6.19-rc4/*.patch .
```

### Modify PKGBUILD

Edit the `PKGBUILD` to add the patches. Add the patch filenames to the `source` array and corresponding checksums to `b2sums`:

```bash
# Add to source array (after the config line):
source=(
    ...
    "0001-wifi-mt76-mt7925-fix-NULL-pointer-dereference-in-vif.patch"
    "0002-wifi-mt76-mt7925-fix-missing-mutex-protection-in-res.patch"
    # ... add all patches
)

# Add 'SKIP' entries to b2sums for each patch:
b2sums=(
    ...
    'SKIP'  # 0001 patch
    'SKIP'  # 0002 patch
    # ... one SKIP per patch
)
```

In the `prepare()` function, add patch application after the CachyOS patches:

```bash
prepare() {
    ...
    # After existing patches, add:
    echo "Applying MT7925 WiFi fixes..."
    local src
    for src in "${source[@]}"; do
        src="${src%%::*}"
        src="${src##*/}"
        [[ $src = 0*.patch ]] || continue
        echo "Applying patch $src..."
        patch -Np1 < "../$src"
    done
}
```

### Optional: Customize Package Name

To distinguish from stock CachyOS kernel:

```bash
# Change in PKGBUILD:
_pkgsuffix=cachyos-wifi-fix
pkgrel=1  # increment if rebuilding
```

### Build

```bash
# Build the kernel
makepkg -sf

# This will produce packages like:
# linux-cachyos-wifi-fix-6.18.4-1-x86_64.pkg.tar.zst
# linux-cachyos-wifi-fix-headers-6.18.4-1-x86_64.pkg.tar.zst
```

### Install

```bash
sudo pacman -U linux-cachyos-wifi-fix-*.pkg.tar.zst
```

### Reboot

Select the new kernel in your bootloader, or if using systemd-boot/GRUB, it should be default.

```bash
sudo reboot
```

## Option 2: Build Module Only (Quick Test)

For quick testing without rebuilding the entire kernel:

```bash
# Install kernel headers
sudo pacman -S linux-headers  # or linux-cachyos-headers

# Get kernel source matching your version
KVER=$(uname -r | sed 's/-.*//')
git clone --depth 1 --branch v$KVER https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
cd linux

# Apply patches
git clone https://github.com/zbowling/mt7925.git ~/mt7925-patches
for patch in ~/mt7925-patches/patches/mt7925/000[1-9]-*.patch \
             ~/mt7925-patches/patches/mt7925/001[0-7]-*.patch; do
    patch -p1 < "$patch" || echo "May need adjustment: $patch"
done

# Prepare for module build
zcat /proc/config.gz > .config
make olddefconfig
make modules_prepare

# Build just mt76 modules
make -j$(nproc) M=drivers/net/wireless/mediatek/mt76

# Install modules
sudo make M=drivers/net/wireless/mediatek/mt76 modules_install
sudo depmod -a

# Reload modules
sudo modprobe -r mt7925e mt7925_common mt792x_lib mt76_connac_lib mt76
sudo modprobe mt7925e

# Or just reboot
sudo reboot
```

## Verification

```bash
# Check kernel version
uname -r

# Check module loaded
lsmod | grep mt7925

# Check for errors
dmesg | grep -i mt7925

# Verify srcversion changed
modinfo mt7925_common | grep srcversion
```

## Troubleshooting

### Build fails with patch errors

The patches are written for specific kernel versions. If patches fail:

1. Check your kernel version: `uname -r`
2. Try the patches from `linux-6.19-rc4/` folder for newer kernels
3. Try the unified patch: `patches/mt7925/mt7925_unified.patch`

### Kernel won't boot

Boot into the previous kernel from your bootloader menu and remove the broken package:

```bash
sudo pacman -R linux-cachyos-wifi-fix linux-cachyos-wifi-fix-headers
```

## Related Resources

- [Main README](README.md)
- [CachyOS Linux Kernel](https://github.com/CachyOS/linux-cachyos)
- [Framework Community Thread](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
