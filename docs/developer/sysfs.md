# Sysfs Reference

The MT7925 driver exposes interfaces through the Linux sysfs filesystem for monitoring and control.

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

| | |
|---|---|
| **File** | `temp1_input` |
| **Permissions** | Read-only |
| **Unit** | Millidegrees Celsius |

```bash
# Read chip temperature
cat /sys/class/ieee80211/phy0/hwmon*/temp1_input
# Output: 54000 = 54.0°C

# Convert to degrees
echo "scale=1; $(cat /sys/class/ieee80211/phy0/hwmon*/temp1_input) / 1000" | bc
```

**Integration with lm-sensors:**

```bash
# Install lm-sensors
sudo pacman -S lm_sensors   # Arch
sudo apt install lm-sensors  # Debian/Ubuntu

# View temperatures
sensors
```

---

## RFKill Interface

Controls the radio on/off state.

### Location

```
/sys/class/ieee80211/phy*/rfkill*/
```

### Entries

| File | Description |
|------|-------------|
| `soft` | Software kill switch (0=on, 1=off) |
| `hard` | Hardware kill switch (0=on, 1=off) |
| `state` | Combined state (0=disabled, 1=enabled, 2=soft blocked) |
| `name` | Device name |
| `type` | Device type (wlan) |

```bash
# Check rfkill status
cat /sys/class/ieee80211/phy0/rfkill*/soft
cat /sys/class/ieee80211/phy0/rfkill*/hard
cat /sys/class/ieee80211/phy0/rfkill*/state

# Using rfkill command
rfkill list wifi
```

**Enabling/Disabling Radio:**

```bash
# Using rfkill command (preferred)
sudo rfkill block wifi     # Disable WiFi
sudo rfkill unblock wifi   # Enable WiFi

# Using sysfs directly
echo 1 | sudo tee /sys/class/ieee80211/phy0/rfkill*/soft  # Block
echo 0 | sudo tee /sys/class/ieee80211/phy0/rfkill*/soft  # Unblock
```

---

## IEEE80211 PHY Interface

### Location

```
/sys/class/ieee80211/phy*/
```

### Entries

| File | Description |
|------|-------------|
| `name` | PHY name (e.g., phy0) |
| `index` | PHY index number |
| `macaddress` | Hardware MAC address |
| `addresses` | Supported MAC addresses |

```bash
cat /sys/class/ieee80211/phy0/name
cat /sys/class/ieee80211/phy0/macaddress
```

---

## Network Device Interface

### Location

```
/sys/class/net/wlan0/
```

### Key Entries

| File | Description | R/W |
|------|-------------|-----|
| `address` | Current MAC address | R |
| `operstate` | Operational state | R |
| `carrier` | Link carrier state | R |
| `mtu` | Maximum transmission unit | R/W |
| `statistics/` | Network statistics | R |

```bash
# Check interface state
cat /sys/class/net/wlan0/operstate    # up, down, dormant
cat /sys/class/net/wlan0/carrier      # 1 = connected

# View statistics
cat /sys/class/net/wlan0/statistics/rx_packets
cat /sys/class/net/wlan0/statistics/tx_packets
cat /sys/class/net/wlan0/statistics/rx_bytes
cat /sys/class/net/wlan0/statistics/tx_bytes
```

---

## PCI Device Interface

### Location

Find your device:

```bash
lspci -d 14c3: | head -1
# Example: bf:00.0 Network controller: MEDIATEK Corp. MT7925
```

Then access:

```
/sys/bus/pci/devices/0000:bf:00.0/
```

### Key Entries

| File | Description | R/W |
|------|-------------|-----|
| `device` | PCI device ID | R |
| `vendor` | PCI vendor ID (14c3) | R |
| `enable` | Device enable state | R/W |
| `remove` | Remove device from bus | W |
| `reset` | Reset device | W |
| `current_link_speed` | PCIe link speed | R |
| `current_link_width` | PCIe link width | R |
| `power_state` | Power state (D0-D3) | R |

```bash
# Check PCIe link
cat /sys/bus/pci/devices/0000:bf:00.0/current_link_speed
cat /sys/bus/pci/devices/0000:bf:00.0/current_link_width

# Check power state
cat /sys/bus/pci/devices/0000:bf:00.0/power_state
```

### Power Management

| File | Description |
|------|-------------|
| `power/control` | Runtime PM control (auto/on) |
| `power/runtime_status` | Current PM status |
| `power/autosuspend_delay_ms` | Delay before suspend |

```bash
# Check runtime PM status
cat /sys/bus/pci/devices/0000:bf:00.0/power/runtime_status

# Disable runtime PM
echo on | sudo tee /sys/bus/pci/devices/0000:bf:00.0/power/control

# Enable runtime PM
echo auto | sudo tee /sys/bus/pci/devices/0000:bf:00.0/power/control
```

---

## Quick Reference Script

```bash
#!/bin/bash
# mt7925-sysfs-info.sh

PHY=$(iw dev | grep -m1 "phy#" | cut -d'#' -f2)
DEV=$(iw dev | grep -m1 Interface | awk '{print $2}')

echo "=== MT7925 Sysfs Info ==="
echo "PHY: phy$PHY"
echo "Interface: $DEV"
echo ""

echo "=== Temperature ==="
cat /sys/class/ieee80211/phy$PHY/hwmon*/temp1_input 2>/dev/null | awk '{printf "%.1f°C\n", $1/1000}'

echo ""
echo "=== Interface State ==="
cat /sys/class/net/$DEV/operstate

echo ""
echo "=== RFKill ==="
rfkill list wifi

echo ""
echo "=== Statistics ==="
echo "RX packets: $(cat /sys/class/net/$DEV/statistics/rx_packets)"
echo "TX packets: $(cat /sys/class/net/$DEV/statistics/tx_packets)"
```
