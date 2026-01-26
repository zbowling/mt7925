# Arch Linux Installation

The package is available in the [AUR](https://aur.archlinux.org/packages/mt76-mt7925-dkms).

## Install from AUR

=== "yay"

    ```bash
    yay -S mt76-mt7925-dkms
    ```

=== "paru"

    ```bash
    paru -S mt76-mt7925-dkms
    ```

=== "Manual"

    ```bash
    git clone https://aur.archlinux.org/mt76-mt7925-dkms.git
    cd mt76-mt7925-dkms
    makepkg -si
    ```

## What Happens During Installation

1. Downloads source tarball from GitHub releases
2. Verifies SHA256 checksum
3. Installs source to `/usr/src/mt76-mt7925-<version>/`
4. DKMS builds modules for all installed kernels
5. Signs modules if MOK is configured (Secure Boot)

## Verify Installation

```bash
# Check DKMS status
dkms status | grep mt76-mt7925

# Check module is from DKMS (not stock kernel)
modinfo mt7925e | grep filename
# Should show: /lib/modules/.../updates/dkms/mt7925e.ko.zst

# Check loaded modules
lsmod | grep mt7925
```

## Update

Updates are handled automatically by your AUR helper:

```bash
yay -Syu
# or
paru -Syu
```

## Tested Distributions

| Distribution | Kernel | Status |
|--------------|--------|--------|
| Arch Linux | 6.18.x | :material-check: Working |
| CachyOS | 6.18.x, 6.19-rc | :material-check: Working |
| EndeavourOS | 6.18.x | :material-check: Working |

!!! tip "CachyOS Users"
    CachyOS uses clang-built kernels. Make sure `clang` and `lld` are installed:
    ```bash
    sudo pacman -S clang lld
    ```
