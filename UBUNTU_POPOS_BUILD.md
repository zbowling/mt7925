# Building MT7925 WiFi Fixes on Ubuntu/Pop_OS

This guide covers building the MT7925 WiFi driver patches on Ubuntu or Pop_OS with kernel 6.17 or 6.18.

## Prerequisites

```bash
sudo apt update
sudo apt install build-essential libncurses-dev bison flex libssl-dev libelf-dev ccache git
```

## Option 1: Build Just the mt76 Module (Quick - Recommended)

This method only rebuilds the WiFi driver modules, which is much faster than a full kernel build.

```bash
# Install kernel headers and source
sudo apt install linux-headers-$(uname -r)
apt-get source linux-image-$(uname -r)
cd linux-*/

# Clone the patches
git clone https://github.com/zbowling/mt7925.git ~/mt7925-patches

# Apply patches (use patches/mt7925 folder for 6.17/6.18 kernels)
for patch in ~/mt7925-patches/patches/mt7925/000[1-9]-*.patch \
             ~/mt7925-patches/patches/mt7925/001[0-7]-*.patch; do
    patch -p1 < "$patch" || echo "May need adjustment: $patch"
done

# Build just mt76 modules
make -C /lib/modules/$(uname -r)/build M=$(pwd)/drivers/net/wireless/mediatek/mt76 modules

# Backup existing modules (optional but recommended)
sudo cp /lib/modules/$(uname -r)/kernel/drivers/net/wireless/mediatek/mt76/*.ko \
        /lib/modules/$(uname -r)/kernel/drivers/net/wireless/mediatek/mt76/*.ko.bak 2>/dev/null

# Install new modules
sudo make -C /lib/modules/$(uname -r)/build M=$(pwd)/drivers/net/wireless/mediatek/mt76 modules_install
sudo depmod -a

# Reboot to load new modules
sudo reboot
```

## Option 2: Full Kernel Build

Use this if you want to build and install a complete patched kernel.

```bash
# Get kernel source
git clone --depth 1 --branch v6.17 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
cd linux

# Clone and apply patches
git clone https://github.com/zbowling/mt7925.git ~/mt7925-patches
for patch in ~/mt7925-patches/patches/mt7925/000[1-9]-*.patch \
             ~/mt7925-patches/patches/mt7925/001[0-7]-*.patch; do
    git apply "$patch" || echo "May need adjustment: $patch"
done

# Configure using your current kernel's config
cp /boot/config-$(uname -r) .config
make olddefconfig

# Build (using ccache speeds up rebuilds significantly)
make CC="ccache gcc" -j$(nproc)
make CC="ccache gcc" modules -j$(nproc)

# Install
sudo make modules_install
sudo make install
sudo update-initramfs -c -k 6.17.0+
sudo update-grub

# Reboot into new kernel
sudo reboot
```

## For Kernel 6.19-rc4 or Newer

If you're on kernel 6.19-rc4 or newer, use the `linux-6.19-rc4/` folder instead:

```bash
for patch in ~/mt7925-patches/linux-6.19-rc4/*.patch; do
    patch -p1 < "$patch" || git apply "$patch"
done
```

## Verification

After rebooting, verify the patched modules are loaded:

```bash
# Check module is loaded
lsmod | grep mt7925

# Check for any errors
dmesg | grep -i mt7925

# Verify module version changed (srcversion will be different from stock)
modinfo mt7925_common | grep srcversion
```

## Troubleshooting

### Patches fail to apply

If patches fail with "Hunk FAILED", the kernel source may have diverged. Try:

1. Check if there's a unified patch: `~/mt7925-patches/patches/mt7925/mt7925_unified.patch`
2. Apply patches manually, adjusting line numbers as needed
3. Open an issue at https://github.com/zbowling/mt7925/issues

### Module won't load

```bash
# Check for signature issues (if Secure Boot is enabled)
sudo mokutil --sb-state

# Try loading manually to see errors
sudo modprobe -r mt7925e mt7925_common mt792x_lib mt76_connac_lib mt76
sudo modprobe mt76
sudo modprobe mt76_connac_lib
sudo modprobe mt792x_lib
sudo modprobe mt7925_common
sudo modprobe mt7925e
```

### WiFi still crashes

Check kernel logs for clues:
```bash
sudo dmesg -w | grep -i mt7925
```

Report issues with full dmesg output at: https://github.com/zbowling/mt7925/issues

## Related Resources

- [Main README](README.md) - Full documentation and patch descriptions
- [Framework Community Thread](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301/9)
- [Ubuntu Bug #2137291](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)
