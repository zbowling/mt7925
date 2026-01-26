# Quick Start

Get the patched MT7925/MT7921 WiFi driver installed in under 5 minutes.

These are quick install instructions to install or build the dynamic kernel module package and replace the drivers loaded by your system. For more detailed instructions, including patching your own kernel, are in the [full installation guide](installation/index.md).

## Choose Your Installation Method

### Manual (from source)

    Make sure you have kernel headers and development packages for your system. See [requirements](installation/requirements.md) for more detailed information.

    ```bash
    git clone https://github.com/zbowling/mt7925.git
    cd mt7925/dkms
    sudo ./install.sh
    ```

### Arch Linux

    ```bash
    # Using yay
    yay -S mt76-mt7925-dkms

    # Or using paru
    paru -S mt76-mt7925-dkms
    ```

### Debian/Ubuntu (Not fully tested)

    ```bash
    # Add repository (recommended - enables auto-updates)
    curl -1sLf 'https://dl.cloudsmith.io/public/mt76/packages/setup.deb.sh' | sudo -E bash

    # Install
    sudo apt update
    sudo apt install mt76-mt7925-dkms
    ```

### Fedora/RHEL (Not fully tested)

    ```bash
    # Add repository (recommended - enables auto-updates)
    curl -1sLf 'https://dl.cloudsmith.io/public/mt76/packages/setup.rpm.sh' | sudo -E bash

    # Install
    sudo dnf install mt76-mt7925-dkms
    ```


## Verify Installation

After installation, verify the driver is working:

```bash
# Check DKMS status
dkms status | grep mt76-mt7925

# Check modules are loaded
lsmod | grep mt7925

# Check WiFi interface exists
ip link | grep wl
```

You should see output like:

```text
mt76-mt7925/x.y.z, 6.x.y-your-kernel, x86_64: installed
```

## What's Included

The DKMS package includes 12 kernel modules:

| Module | Description |
|--------|-------------|
| `mt76` | Core MT76 driver |
| `mt76-connac-lib` | Common connectivity library |
| `mt792x-lib` | Shared MT792x library |
| `mt7925-common` | MT7925 common code |
| `mt7925e` | MT7925 PCIe driver |
| `mt7921-common` | MT7921 common code |
| `mt7921e` | MT7921 PCIe driver |
| `mt7921u` | MT7921 USB driver |
| `mt7921s` | MT7921 SDIO driver |
| `mt76-usb` | USB transport |
| `mt76-sdio` | SDIO transport |
| `mt792x-usb` | MT792x USB helpers |

## Next Steps

- [View Requirements](installation/requirements.md) - Check system requirements
- [Known Issues](issues/known-issues.md) - Common problems and workarounds
- [Debugging Guide](issues/debugging.md) - Troubleshoot problems
