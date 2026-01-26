# Developer Guide

Resources for developers working with the MT7925 driver or contributing to this project.

## Pages in This Section

<div class="grid cards" markdown>

-   :material-bug:{ .lg .middle } __Debugging__

    ---

    Techniques for debugging driver issues

    [:octicons-arrow-right-24: Debug guide](debugging.md)

-   :material-folder-open:{ .lg .middle } __Debugfs Reference__

    ---

    Complete debugfs interface documentation

    [:octicons-arrow-right-24: Debugfs](debugfs.md)

-   :material-cog:{ .lg .middle } __Sysfs Reference__

    ---

    Sysfs interface for temperature and power management

    [:octicons-arrow-right-24: Sysfs](sysfs.md)

</div>

## Quick Links

### Getting Started

1. Clone the repository: `git clone https://github.com/zbowling/mt7925.git`
2. Install DKMS package: `cd dkms && sudo ./install.sh`
3. Test your changes
4. Submit a PR

### Development Setup

```bash
# Clone the kernel fork with patches applied
git clone https://github.com/zbowling/linux-wifi.git
cd linux-wifi
git checkout mt7925-upstream-v2-6.18

# Make changes following kernel coding style
# Use tabs, follow existing patterns

# Export patch
git format-patch -1
```

### Useful Commands

```bash
# Check DKMS status
dkms status | grep mt76

# Rebuild DKMS module
sudo dkms build mt76-mt7925/1.4.1
sudo dkms install mt76-mt7925/1.4.1

# View driver messages
dmesg | grep mt7925

# Check debugfs
ls /sys/kernel/debug/ieee80211/phy0/mt76/
```

## Code Organization

### Driver Source Tree

```
drivers/net/wireless/mediatek/mt76/
├── mt76.h                 # Core structures
├── mac80211.c             # mac80211 integration
├── dma.c                  # DMA management
├── mcu.c                  # MCU base
├── mt792x_core.c          # Shared MT792x code
├── mt792x_mac.c           # Shared MAC layer
├── mt7925/
│   ├── main.c             # mac80211 ops
│   ├── mac.c              # MAC processing
│   ├── mcu.c              # MCU commands
│   └── pci.c              # PCI probe/remove
└── mt7921/
    └── ...                # MT7921 specific
```

### Key Files for Patches

| File | Contains |
|------|----------|
| `mt7925/main.c` | mac80211 operations |
| `mt7925/mcu.c` | MCU command handlers |
| `mt792x_core.c` | Shared core functions |
| `mt76/mac80211.c` | Station/VIF management |

## Testing Changes

### Unit Testing

```bash
# Build kernel with CONFIG_MT76_DEBUG=y
# Enable lockdep for deadlock detection
CONFIG_PROVE_LOCKING=y
CONFIG_DEBUG_LOCK_ALLOC=y
```

### Stress Testing

```bash
# Roaming test
nmcli device wifi connect "SSID" password "pass"
# Move between APs

# Suspend/resume test
systemctl suspend
# Wake and check dmesg
```

### Verify Patches Applied

```bash
# Check module version
modinfo mt7925e | grep version

# Check for patched functions in debugfs
cat /sys/kernel/debug/ieee80211/phy0/mt76/mcu
```
