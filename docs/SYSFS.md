# MT7925 Sysfs Reference

## Overview

The MT7925 driver exposes several interfaces through the Linux sysfs filesystem for monitoring hardware status, power management, and device control.

## Hardware Monitoring (hwmon)

The driver registers with the Linux hwmon subsystem for temperature monitoring.

### Location

```bash
# Find the hwmon device
ls /sys/class/ieee80211/phy*/hwmon*/

# Or find by name
cat /sys/class/hwmon/hwmon*/name | grep -n mt7925
```

### Temperature Reading

**File:** `temp1_input`
**Permissions:** Read-only

**Usage:**
```bash
# Read chip temperature (millidegrees Celsius)
cat /sys/class/ieee80211/phy6/hwmon*/temp1_input
# Output: 54000 = 54.0°C

# Convert to degrees
echo "scale=1; $(cat /sys/class/ieee80211/phy6/hwmon*/temp1_input) / 1000" | bc
```

**Integration with lm-sensors:**
```bash
# Install lm-sensors
sudo pacman -S lm_sensors   # Arch
sudo apt install lm-sensors  # Debian/Ubuntu

# Detect sensors
sudo sensors-detect

# View all temperatures including WiFi chip
sensors
```

---

## RFKill Interface

Controls the radio on/off state (software and hardware kill switches).

### Location

```bash
/sys/class/ieee80211/phy*/rfkill*/
```

### Entries

| File | Description |
|------|-------------|
| `soft` | Software kill switch (0=enabled, 1=disabled) |
| `hard` | Hardware kill switch (0=enabled, 1=disabled) |
| `state` | Combined state (0=disabled, 1=enabled, 2=soft blocked) |
| `name` | Device name |
| `type` | Device type (wlan) |

**Usage:**
```bash
# Check rfkill status
cat /sys/class/ieee80211/phy6/rfkill*/soft  # 0 = radio on
cat /sys/class/ieee80211/phy6/rfkill*/hard  # 0 = hardware switch on
cat /sys/class/ieee80211/phy6/rfkill*/state # 1 = radio enabled

# Alternative using rfkill command
rfkill list wifi
```

**Enabling/Disabling Radio:**
```bash
# Using rfkill command (preferred)
sudo rfkill block wifi     # Disable WiFi
sudo rfkill unblock wifi   # Enable WiFi

# Using sysfs directly
sudo sh -c 'echo 1 > /sys/class/ieee80211/phy6/rfkill*/soft'  # Block
sudo sh -c 'echo 0 > /sys/class/ieee80211/phy6/rfkill*/soft'  # Unblock
```

---

## IEEE80211 PHY Interface

General wireless PHY information.

### Location

```bash
/sys/class/ieee80211/phy*/
```

### Entries

| File | Description |
|------|-------------|
| `name` | PHY name (e.g., phy6) |
| `index` | PHY index number |
| `macaddress` | Hardware MAC address |
| `addresses` | List of supported MAC addresses |
| `address_mask` | Address mask for virtual interfaces |

**Usage:**
```bash
# Show PHY information
cat /sys/class/ieee80211/phy6/name
cat /sys/class/ieee80211/phy6/macaddress
cat /sys/class/ieee80211/phy6/index
```

---

## Network Device Interface

Standard Linux network device sysfs entries.

### Location

```bash
/sys/class/net/wlan0/
```

### Useful Entries

| File | Description | R/W |
|------|-------------|-----|
| `address` | Current MAC address | R |
| `operstate` | Operational state (up/down/dormant) | R |
| `carrier` | Link carrier state | R/W |
| `mtu` | Maximum transmission unit | R/W |
| `flags` | Interface flags | R/W |
| `tx_queue_len` | TX queue length | R/W |
| `statistics/` | Network statistics directory | R |

**Usage:**
```bash
# Check interface state
cat /sys/class/net/wlan0/operstate    # up, down, or dormant
cat /sys/class/net/wlan0/carrier      # 1 = connected

# View MAC address
cat /sys/class/net/wlan0/address

# View statistics
cat /sys/class/net/wlan0/statistics/rx_packets
cat /sys/class/net/wlan0/statistics/tx_packets
cat /sys/class/net/wlan0/statistics/rx_bytes
cat /sys/class/net/wlan0/statistics/tx_bytes
cat /sys/class/net/wlan0/statistics/rx_errors
cat /sys/class/net/wlan0/statistics/tx_errors
```

---

## PCI Device Interface

PCI bus device information and control.

### Location

```bash
/sys/bus/pci/devices/XXXX:XX:XX.X/
```

Find your device:
```bash
lspci -d 14c3: | head -1
# Example: bf:00.0 Network controller: MEDIATEK Corp. MT7925 802.11be Wireless LAN Adapter
```

### Key Entries

| File | Description | R/W |
|------|-------------|-----|
| `device` | PCI device ID | R |
| `vendor` | PCI vendor ID (14c3 for MediaTek) | R |
| `class` | PCI class code | R |
| `enable` | Device enable state | R/W |
| `remove` | Remove device from bus | W |
| `rescan` | Rescan PCI bus | W |
| `reset` | Reset device | W |
| `config` | Raw PCI config space | R/W |
| `current_link_speed` | Current PCIe link speed | R |
| `current_link_width` | Current PCIe link width | R |
| `max_link_speed` | Maximum supported speed | R |
| `max_link_width` | Maximum supported width | R |
| `power_state` | Current power state (D0-D3) | R |
| `d3cold_allowed` | D3cold power state allowed | R/W |

**Usage:**
```bash
# Check PCIe link info
cat /sys/bus/pci/devices/0000:bf:00.0/current_link_speed
cat /sys/bus/pci/devices/0000:bf:00.0/current_link_width

# Check power state
cat /sys/bus/pci/devices/0000:bf:00.0/power_state

# Check AER (Advanced Error Reporting) status
cat /sys/bus/pci/devices/0000:bf:00.0/aer_dev_correctable
cat /sys/bus/pci/devices/0000:bf:00.0/aer_dev_fatal
cat /sys/bus/pci/devices/0000:bf:00.0/aer_dev_nonfatal
```

### Device Reset

**Warning:** This will reset the WiFi hardware and disconnect!

```bash
# Reset the PCI device
sudo sh -c 'echo 1 > /sys/bus/pci/devices/0000:bf:00.0/reset'

# Remove and rescan (full re-enumeration)
sudo sh -c 'echo 1 > /sys/bus/pci/devices/0000:bf:00.0/remove'
sudo sh -c 'echo 1 > /sys/bus/pci/rescan'
```

---

## Power Management

### Runtime PM via sysfs

Located at `/sys/bus/pci/devices/XXXX:XX:XX.X/power/`

| File | Description |
|------|-------------|
| `control` | auto or on (auto enables runtime PM) |
| `runtime_status` | active, suspended, suspending, resuming |
| `runtime_active_time` | Time in active state (ms) |
| `runtime_suspended_time` | Time suspended (ms) |
| `autosuspend_delay_ms` | Delay before auto-suspend |

**Usage:**
```bash
# Check runtime PM status
cat /sys/bus/pci/devices/0000:bf:00.0/power/runtime_status
cat /sys/bus/pci/devices/0000:bf:00.0/power/control

# Enable runtime PM
sudo sh -c 'echo auto > /sys/bus/pci/devices/0000:bf:00.0/power/control'

# Disable runtime PM (always on)
sudo sh -c 'echo on > /sys/bus/pci/devices/0000:bf:00.0/power/control'

# Set autosuspend delay (milliseconds)
sudo sh -c 'echo 5000 > /sys/bus/pci/devices/0000:bf:00.0/power/autosuspend_delay_ms'
```

---

## Firmware Information

### Viewing Loaded Firmware

```bash
# Check kernel messages for firmware info
dmesg | grep -i "firmware\|fw"

# Firmware files location
ls -la /lib/firmware/mediatek/mt7925/
```

### Firmware Version

The driver logs firmware version during initialization:
```bash
dmesg | grep "Firmware Version"
# Example: mt7925e 0000:bf:00.0: WM Firmware Version: ____000000, Build Time: 20260106153120
```

---

## Module Parameters

Check and modify driver module parameters.

```bash
# List module parameters
ls /sys/module/mt7925e/parameters/ 2>/dev/null
ls /sys/module/mt7925_common/parameters/ 2>/dev/null
ls /sys/module/mt76/parameters/ 2>/dev/null

# View modinfo for available parameters
modinfo mt7925e
modinfo mt7925_common
modinfo mt76
```

---

## Quick Status Script

Create a script to check all relevant status information:

```bash
#!/bin/bash
# mt7925-status.sh - Quick status check for MT7925 WiFi

PHY=$(ls /sys/class/ieee80211/ | head -1)
DEV=$(ls /sys/class/net/ | grep -E "^wlan|^wlp" | head -1)
PCI=$(readlink -f /sys/class/net/$DEV/device | xargs basename)

echo "=== MT7925 Status ==="
echo

echo "Device: $DEV (PHY: $PHY, PCI: $PCI)"
echo

echo "--- Temperature ---"
temp=$(cat /sys/class/ieee80211/$PHY/hwmon*/temp1_input 2>/dev/null)
if [ -n "$temp" ]; then
    echo "Chip temp: $(echo "scale=1; $temp/1000" | bc)°C"
fi
echo

echo "--- Interface Status ---"
echo "State: $(cat /sys/class/net/$DEV/operstate)"
echo "Carrier: $(cat /sys/class/net/$DEV/carrier)"
echo "MAC: $(cat /sys/class/net/$DEV/address)"
echo

echo "--- RFKill ---"
echo "Soft block: $(cat /sys/class/ieee80211/$PHY/rfkill*/soft)"
echo "Hard block: $(cat /sys/class/ieee80211/$PHY/rfkill*/hard)"
echo

echo "--- PCIe Link ---"
echo "Speed: $(cat /sys/bus/pci/devices/$PCI/current_link_speed 2>/dev/null)"
echo "Width: $(cat /sys/bus/pci/devices/$PCI/current_link_width 2>/dev/null)"
echo "Power: $(cat /sys/bus/pci/devices/$PCI/power_state 2>/dev/null)"
echo

echo "--- Statistics ---"
echo "RX packets: $(cat /sys/class/net/$DEV/statistics/rx_packets)"
echo "TX packets: $(cat /sys/class/net/$DEV/statistics/tx_packets)"
echo "RX errors: $(cat /sys/class/net/$DEV/statistics/rx_errors)"
echo "TX errors: $(cat /sys/class/net/$DEV/statistics/tx_errors)"
```

---

## Related Documentation

- [DEBUGFS.md](DEBUGFS.md) - Kernel debug filesystem entries
- [DEBUGGING.md](DEBUGGING.md) - General debugging guide
- [CONTROL_FLOW.md](CONTROL_FLOW.md) - Driver control flows
