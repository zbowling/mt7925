# MT7925 Debugfs Reference

## Overview

The MT7925 driver exposes debugging interfaces through the Linux debugfs filesystem. These interfaces provide visibility into driver state, firmware status, and allow runtime configuration changes for debugging purposes.

## Location

Debugfs entries are located at:
```
/sys/kernel/debug/ieee80211/phyN/mt76/
```

Where `N` is the PHY number (typically 0, but may be higher if other WiFi devices are present). To find your PHY:

```bash
# Find the mt7925 PHY
ls -la /sys/kernel/debug/ieee80211/
iw dev wlan0 info | grep wiphy
```

## Available Debugfs Entries

### Firmware Debug (`fw_debug`)

Controls firmware debug logging to the host.

**Location:** `fw_debug`
**Permissions:** Read/Write (0600)

**Values:**
- `0` - Disabled
- `1` - Basic firmware logging enabled (default after firmware load)
- `2` - Extended firmware logging

**Usage:**
```bash
# Check current state
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug

# Enable extended logging
sudo sh -c 'echo 2 > /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug'

# Disable logging
sudo sh -c 'echo 0 > /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug'
```

**Notes:**
- Firmware debug output appears in kernel logs (`dmesg`)
- Some firmware builds may not have debug output compiled in
- Enabling debug logging may impact performance

---

### Chip Reset (`chip_reset`)

Triggers a chip reset, optionally collecting a firmware coredump first.

**Location:** `chip_reset`
**Permissions:** Write-only (0600)

**Values:**
- `0` (default) - Collect coredump, then reset
- `1` - Direct reset without coredump

**Usage:**
```bash
# Trigger coredump + reset (for debugging firmware crashes)
sudo sh -c 'echo 0 > /sys/kernel/debug/ieee80211/phy0/mt76/chip_reset'

# Direct reset without coredump
sudo sh -c 'echo 1 > /sys/kernel/debug/ieee80211/phy0/mt76/chip_reset'
```

**Coredump Collection:**
When triggered with value `0`:
1. Driver sends "assert" command to firmware
2. Firmware dumps its state via MCU messages
3. Coredump is submitted to Linux devcoredump framework
4. Chip is reset and firmware reloaded

**Viewing Coredumps:**
```bash
# Check for available coredumps
ls /sys/class/devcoredump/

# Coredumps appear as device-specific entries
# View with standard tools or copy for analysis
```

---

### Register Access (`regidx`, `regval`)

Direct hardware register read/write access.

**Location:** `regidx`, `regval`
**Permissions:** Read/Write (0600)

**Usage:**
```bash
# Set register address to read/write
sudo sh -c 'echo 0xd4200 > /sys/kernel/debug/ieee80211/phy0/mt76/regidx'

# Read register value
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/regval

# Write register value
sudo sh -c 'echo 0x12345678 > /sys/kernel/debug/ieee80211/phy0/mt76/regval'
```

**Warning:** Direct register access can crash the system or corrupt hardware state. Use with caution and only if you understand the hardware.

---

### TX Queues (`xmit-queues`)

Shows transmit queue status including DMA ring state.

**Location:** `xmit-queues`
**Permissions:** Read-only (0400)

**Usage:**
```bash
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/xmit-queues
```

**Output includes:**
- Queue index
- Head/tail pointers
- Queued packet count
- DMA ring status

---

### AC Queues (`acq`)

Shows access category queue status.

**Location:** `acq`
**Permissions:** Read-only (0400)

**Usage:**
```bash
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/acq
```

---

### RX Queues (`rx-queues`)

Shows receive queue status.

**Location:** `rx-queues`
**Permissions:** Read-only (0400)

**Usage:**
```bash
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/rx-queues
```

---

### TX Statistics (`tx_stats`)

Shows detailed transmit statistics.

**Location:** `tx_stats`
**Permissions:** Read-only (0400)

**Usage:**
```bash
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/tx_stats
```

---

### TX Power SKU (`txpower_sku`)

Shows current TX power limits per rate/band.

**Location:** `txpower_sku`
**Permissions:** Read-only (0400)

**Usage:**
```bash
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/txpower_sku
```

**Output includes:**
- Power limits for each MCS rate
- Organized by band (2.4GHz, 5GHz, 6GHz)
- Values in 0.5 dBm units

---

### Runtime PM (`runtime-pm`)

Controls runtime power management.

**Location:** `runtime-pm`
**Permissions:** Read/Write (0600)

**Usage:**
```bash
# Check current state
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/runtime-pm

# Enable runtime PM
sudo sh -c 'echo 1 > /sys/kernel/debug/ieee80211/phy0/mt76/runtime-pm'

# Disable runtime PM
sudo sh -c 'echo 0 > /sys/kernel/debug/ieee80211/phy0/mt76/runtime-pm'
```

---

### PM Idle Timeout (`idle-timeout`)

Sets the idle timeout before entering power save mode.

**Location:** `idle-timeout`
**Permissions:** Read/Write (0600)

**Usage:**
```bash
# Check current timeout
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/idle-timeout

# Set timeout (in jiffies, typically 1 jiffy = 4ms on x86)
sudo sh -c 'echo 250 > /sys/kernel/debug/ieee80211/phy0/mt76/idle-timeout'
```

---

### Runtime PM Statistics (`runtime_pm_stats`)

Shows power management statistics.

**Location:** `runtime_pm_stats`
**Permissions:** Read-only (0400)

**Usage:**
```bash
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/runtime_pm_stats
```

**Output includes:**
- `awake time` - Time spent in active state (jiffies)
- `doze time` - Time spent in power save (jiffies)
- `low power wakes` - Number of wake events

---

### Deep Sleep (`deep-sleep`)

Controls deep sleep power saving mode.

**Location:** `deep-sleep`
**Permissions:** Read/Write (0600)

**Usage:**
```bash
# Check current state
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/deep-sleep

# Enable deep sleep
sudo sh -c 'echo 1 > /sys/kernel/debug/ieee80211/phy0/mt76/deep-sleep'

# Disable deep sleep
sudo sh -c 'echo 0 > /sys/kernel/debug/ieee80211/phy0/mt76/deep-sleep'
```

---

### LED Pin (`led_pin`)

Controls which GPIO pin is used for the activity LED.

**Location:** `led_pin`
**Permissions:** Read/Write (0600)

---

### NAPI Threaded (`napi_threaded`)

Controls threaded NAPI mode for packet processing.

**Location:** `napi_threaded`
**Permissions:** Read/Write (0600)

**Usage:**
```bash
# Check current state
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/napi_threaded

# Enable threaded NAPI
sudo sh -c 'echo 1 > /sys/kernel/debug/ieee80211/phy0/mt76/napi_threaded'
```

---

### EEPROM (`eeprom`)

Raw EEPROM/efuse data dump.

**Location:** `eeprom`
**Permissions:** Read-only (0400)

**Usage:**
```bash
# Dump EEPROM (binary data)
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/eeprom > eeprom.bin
hexdump -C eeprom.bin | head -50
```

---

## Kernel Trace Events

The mt76 driver provides kernel tracepoints for detailed debugging.

### Available Events

Located at `/sys/kernel/tracing/events/mt76/`:

| Event | Description |
|-------|-------------|
| `dev_irq` | Interrupt events with mask values |
| `reg_rr` | Register read operations |
| `reg_wr` | Register write operations |
| `mac_txdone` | TX completion events |

### Enabling Trace Events

```bash
# Enable all mt76 events
sudo sh -c 'echo 1 > /sys/kernel/tracing/events/mt76/enable'

# Enable specific event
sudo sh -c 'echo 1 > /sys/kernel/tracing/events/mt76/dev_irq/enable'

# View trace buffer
sudo cat /sys/kernel/tracing/trace | tail -100

# Clear trace buffer
sudo sh -c 'echo > /sys/kernel/tracing/trace'

# Follow trace in real-time
sudo cat /sys/kernel/tracing/trace_pipe
```

### mac80211 Trace Events

Additional WiFi stack events at `/sys/kernel/tracing/events/mac80211/`:

```bash
# Enable all mac80211 events
sudo sh -c 'echo 1 > /sys/kernel/tracing/events/mac80211/enable'

# Useful events for debugging
# - drv_sta_state - Station state changes
# - drv_wake_tx_queue - TX queue wake events
# - api_connection_loss - Connection loss events
# - api_beacon_loss - Beacon loss events
```

---

## Debugging Procedures

### Capturing MCU Timeout

When you encounter MCU timeouts:

```bash
# 1. Enable trace events before reproducing
sudo sh -c 'echo 1 > /sys/kernel/tracing/events/mt76/enable'
sudo sh -c 'echo 1 > /sys/kernel/tracing/events/mac80211/enable'
sudo sh -c 'echo > /sys/kernel/tracing/trace'

# 2. Enable firmware debug
sudo sh -c 'echo 2 > /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug'

# 3. Reproduce the issue

# 4. Capture trace and logs
sudo cat /sys/kernel/tracing/trace > trace.log
sudo dmesg > dmesg.log
```

### Triggering Firmware Coredump

To analyze firmware state after a hang:

```bash
# Trigger coredump (this will reset the chip)
sudo sh -c 'echo 0 > /sys/kernel/debug/ieee80211/phy0/mt76/chip_reset'

# Check for coredump
ls -la /sys/class/devcoredump/
```

### Monitoring Power States

```bash
# Watch PM stats in real-time
watch -n 1 'cat /sys/kernel/debug/ieee80211/phy0/mt76/runtime_pm_stats'
```

---

## MCU Command Reference

When debugging MCU timeouts, the command ID in the error message can be decoded:

| Command ID | Name | Description |
|------------|------|-------------|
| `0x00020001` | DEV_INFO_UPDATE | Device info update |
| `0x00020002` | BSS_INFO_UPDATE | BSS configuration |
| `0x00020003` | STA_REC_UPDATE | Station record update |
| `0x00020006` | OFFLOAD | Offload configuration |
| `0x00020008` | BAND_CONFIG | Band configuration |
| `0x00020015` | SET_DOMAIN_INFO | Regulatory domain |
| `0x00020016` | SCAN_REQ | Scan request |
| `0x00020027` | ROC | Remain on channel |
| `0x0002002c` | SET_POWER_LIMIT | TX power limits |

The format is `0x0002XXXX` where `XXXX` is the command type. The `0002` prefix indicates a UNI (unified) command.

---

## Troubleshooting Tips

### No debugfs entries visible
```bash
# Check if debugfs is mounted
mount | grep debugfs

# Mount if needed
sudo mount -t debugfs none /sys/kernel/debug
```

### Permission denied
```bash
# Most entries require root access
sudo su -
cat /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug
```

### PHY number changed
```bash
# Find current PHY for your device
ls /sys/kernel/debug/ieee80211/
# Look for phy with mt76 directory
ls /sys/kernel/debug/ieee80211/phy*/mt76/ 2>/dev/null
```

---

## Related Documentation

- [DEBUGGING.md](DEBUGGING.md) - General debugging guide
- [MCU_PROTOCOL.md](MCU_PROTOCOL.md) - MCU command details
- [CONTROL_FLOW.md](CONTROL_FLOW.md) - Driver control flows
