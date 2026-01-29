# Installation Overview

Multiple installation methods are available depending on your distribution and preferences.

## Recommended: Package Manager

Using your distribution's package manager with our repository enables automatic updates:

| Distribution | Method | Auto-Updates |
|--------------|--------|--------------|
| Arch Linux | [AUR](arch-linux.md) | :material-check: Yes |
| Debian/Ubuntu | [APT Repository](debian-ubuntu.md) | :material-check: Yes |
| Fedora/RHEL | [DNF Repository](fedora-rhel.md) | :material-check: Yes |

## Alternative: Manual Download

Download packages directly from [GitHub Releases](https://github.com/zbowling/mt7925/releases/latest):

- `mt76-mt7925-dkms_1.5.0-1_all.deb` - Debian/Ubuntu
- `mt76-mt7925-dkms-1.5.0-1.noarch.rpm` - Fedora/RHEL
- `mt76-mt7925-dkms-1.5.0-1-any.pkg.tar.zst` - Arch Linux

## Manual Installation

For unsupported distributions or custom setups:

```bash
git clone https://github.com/zbowling/mt7925.git
cd mt7925/dkms
sudo ./install.sh
```

See [Manual Installation](manual.md) for details.

## What Gets Installed

The DKMS package installs:

1. **Source code** to `/usr/src/mt76-mt7925-<version>/`
2. **12 kernel modules** built via DKMS for each installed kernel
3. **Module signing** (if Secure Boot is configured)

Modules are installed to `/lib/modules/<kernel>/updates/dkms/` which takes priority over stock kernel modules.

## After Installation

1. **Reboot** or reload modules manually
2. **Verify** with `dkms status | grep mt76-mt7925`
3. **Check WiFi** with `ip link | grep wl`

If you encounter issues, see the [Debugging Guide](../issues/debugging.md).
