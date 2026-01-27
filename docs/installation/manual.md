# Manual Installation

For distributions not covered by pre-built packages, or for custom setups.

## Prerequisites

Install required dependencies:

```bash
# Debian/Ubuntu
sudo apt install dkms build-essential linux-headers-$(uname -r)

# Fedora/RHEL
sudo dnf install dkms kernel-devel

# Arch Linux
sudo pacman -S dkms linux-headers

# openSUSE
sudo zypper install dkms kernel-devel
```

For clang-built kernels, also install:

```bash
# Debian/Ubuntu
sudo apt install clang lld

# Fedora/RHEL
sudo dnf install clang lld

# Arch Linux
sudo pacman -S clang lld
```

## Installation

### Clone and Install

```bash
git clone https://github.com/zbowling/mt7925.git
cd mt7925/dkms
sudo ./install.sh
```

### What the Installer Does

1. Checks for root privileges
2. Verifies kernel version (6.17+ required)
3. Detects existing DKMS installation and removes it
4. Copies source to `/usr/src/mt76-mt7925-<version>/`
5. Registers with DKMS
6. Builds modules for current kernel
7. Installs modules
8. Unloads old modules and loads new ones

### Installer Options

```bash
# Enable telemetry (opt-in)
sudo MT7925_TELEMETRY=1 ./install.sh

# Skip telemetry prompt
sudo MT7925_TELEMETRY=0 ./install.sh
```

## Verify Installation

```bash
# Check DKMS registered the package
dkms status | grep mt76-mt7925

# Check modules are installed
ls /lib/modules/$(uname -r)/updates/dkms/ | grep mt

# Check modules are loaded
lsmod | grep mt7925

# Check WiFi interface
ip link show | grep wl
```

## Troubleshooting

### Build Failures

Check the DKMS build log:

```bash
sudo cat /var/lib/dkms/mt76-mt7925/1.4.2/build/make.log
```

Common issues:

| Error | Solution |
|-------|----------|
| `CONFIG_CC_IS_CLANG` | Install `clang` and `lld` |
| Missing headers | Install `linux-headers-$(uname -r)` |
| Kernel too old | Upgrade to 6.17+ |

### Manual DKMS Commands

```bash
# View status
dkms status

# Rebuild for current kernel
sudo dkms build mt76-mt7925/1.4.2
sudo dkms install mt76-mt7925/1.4.2

# Remove and reinstall
sudo dkms remove mt76-mt7925/1.4.2 --all
sudo dkms add mt76-mt7925/1.4.2
sudo dkms build mt76-mt7925/1.4.2
sudo dkms install mt76-mt7925/1.4.2
```

### Module Loading

```bash
# Unload existing modules
sudo modprobe -r mt7925e mt7925_common mt792x_lib mt76_connac_lib mt76

# Load new modules
sudo modprobe mt7925e

# Check kernel messages
dmesg | grep -i mt76
```
