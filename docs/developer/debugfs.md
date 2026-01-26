# Debugfs Reference

The MT7925 driver exposes debugging interfaces through the Linux debugfs filesystem.

## Location

```
/sys/kernel/debug/ieee80211/phyN/mt76/
```

Find your PHY:

```bash
ls -la /sys/kernel/debug/ieee80211/
iw dev wlan0 info | grep wiphy
```

## Available Entries

### Firmware Debug (`fw_debug`)

Controls firmware debug logging to the host.

| | |
|---|---|
| **Permissions** | Read/Write (0600) |
| **Values** | 0=disabled, 1=basic, 2=extended |

```bash
# Check current state
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug

# Enable extended logging
echo 2 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug

# Disable logging
echo 0 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug
```

!!! note
    Firmware debug output appears in kernel logs (`dmesg`). Enabling may impact performance.

---

### Chip Reset (`chip_reset`)

Triggers a chip reset, optionally collecting a firmware coredump first.

| | |
|---|---|
| **Permissions** | Write-only (0600) |
| **Values** | 0=coredump+reset (default), 1=direct reset |

```bash
# Trigger coredump + reset
echo 0 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/chip_reset

# Direct reset without coredump
echo 1 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/chip_reset
```

**Viewing Coredumps:**

```bash
ls /sys/class/devcoredump/
```

---

### Register Access (`regidx`, `regval`)

Direct hardware register read/write access.

| | |
|---|---|
| **Permissions** | Read/Write (0600) |

```bash
# Set register address
echo 0xd4200 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/regidx

# Read register value
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/regval

# Write register value
echo 0x12345678 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/regval
```

!!! danger "Warning"
    Direct register access can crash the system. Use only if you understand the hardware.

---

### TX Queues (`xmit-queues`)

Shows transmit queue status including DMA ring state.

| | |
|---|---|
| **Permissions** | Read-only (0400) |

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

| | |
|---|---|
| **Permissions** | Read-only (0400) |

```bash
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/acq
```

---

### RX Queues (`rx-queues`)

Shows receive queue status.

| | |
|---|---|
| **Permissions** | Read-only (0400) |

```bash
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/rx-queues
```

---

### TX Statistics (`tx_stats`)

Shows detailed transmit statistics.

| | |
|---|---|
| **Permissions** | Read-only (0400) |

```bash
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/tx_stats
```

---

### TX Power SKU (`txpower_sku`)

Shows current TX power limits per rate/band.

| | |
|---|---|
| **Permissions** | Read-only (0400) |

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

| | |
|---|---|
| **Permissions** | Read/Write (0600) |
| **Values** | 0=disabled, 1=enabled |

```bash
# Check current state
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/runtime-pm

# Disable runtime PM
echo 0 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/runtime-pm
```

---

### Idle Timeout (`idle-timeout`)

Sets the idle timeout before entering power save.

| | |
|---|---|
| **Permissions** | Read/Write (0600) |
| **Values** | Timeout in milliseconds |

```bash
# Check current timeout
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/idle-timeout

# Set to 100ms
echo 100 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/idle-timeout
```

---

## Tracepoints

If `CONFIG_MT76_TRACER` is enabled:

```bash
# Enable all mt76 tracepoints
echo 1 | sudo tee /sys/kernel/debug/tracing/events/mt76/enable

# View trace
cat /sys/kernel/debug/tracing/trace
```

**Available tracepoints:**

- `mt76:dev_irq` - Interrupt events
- `mt76:tx` - TX events
- `mt76:rx` - RX events
- `mt76:mcu_msg` - MCU messages
