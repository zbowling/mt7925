# Telemetry

This project includes optional, privacy-respecting telemetry to help understand usage and improve the driver.

## Overview

Telemetry is **disabled by default** and only enabled if you explicitly opt-in during installation.

### What is Collected

When telemetry is enabled, the following anonymous data is sent:

| Data | Example | Purpose |
|------|---------|---------|
| Event type | `install`, `uninstall` | Track adoption |
| Kernel version | `6.18.5` | Kernel compatibility |
| Package version | `1.4.1` | Version distribution |
| Chip type | `mt7925`, `mt7921` | Hardware support |
| Bus type | `pci`, `usb` | Interface usage |
| Clang kernel | `yes`, `no` | Build compatibility |
| Session ID | `abc123` | Correlate install/uninstall |

### What is NOT Collected

- IP addresses (not logged by analytics service)
- MAC addresses
- Personal information
- WiFi network names/passwords
- System hostname
- User accounts

## How it Works

Telemetry uses [GoatCounter](https://www.goatcounter.com/), a privacy-focused analytics service:

- No cookies
- No personal data collection
- Open source
- GDPR compliant

Events are sent as simple HTTP requests:

```bash
curl -s "https://mt7925.goatcounter.com/count?p=/install&t=MT7925%20DKMS%20v1.4.1"
```

## Enabling Telemetry

### During Installation

```bash
# Enable telemetry
sudo MT7925_TELEMETRY=1 ./install.sh

# Disable telemetry (default)
sudo MT7925_TELEMETRY=0 ./install.sh
```

### Check Current Status

```bash
cat /etc/mt7925-telemetry.conf
# Outputs: MT7925_TELEMETRY=1 or MT7925_TELEMETRY=0
```

### Disable After Installation

```bash
echo "MT7925_TELEMETRY=0" | sudo tee /etc/mt7925-telemetry.conf
```

## Network Handling

Since the telemetry runs during WiFi driver installation, network may not be available immediately. The installer handles this by:

1. **Attempt immediate send** - If network is available
2. **Queue for later** - If network is unavailable, event is saved
3. **Retry on boot** - Queued events are sent on next boot

Queue location: `/var/lib/mt7925-telemetry-queue`

## Source Code

The telemetry implementation is fully transparent:

- Install script: `dkms/install.sh`
- Uninstall script: `dkms/uninstall.sh`
- Config file: `/etc/mt7925-telemetry.conf`

## Removing Telemetry Data

To completely remove telemetry:

```bash
# Disable telemetry
echo "MT7925_TELEMETRY=0" | sudo tee /etc/mt7925-telemetry.conf

# Remove queue file
sudo rm -f /var/lib/mt7925-telemetry-queue

# Remove config file (optional)
sudo rm -f /etc/mt7925-telemetry.conf
```

## Why Telemetry?

Anonymous usage data helps:

1. **Prioritize kernel versions** - Know which kernels need support
2. **Track adoption** - Understand how many users benefit from fixes
3. **Identify issues** - Correlate hardware types with problems
4. **Justify upstream work** - Show maintainers that fixes are needed

## Questions?

If you have concerns about telemetry, please open a [GitHub Discussion](https://github.com/zbowling/mt7925/discussions).
