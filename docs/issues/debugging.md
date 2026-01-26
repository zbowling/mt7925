# Debugging Guide

Techniques for debugging issues in the MT7925 driver, including common problems, debugging tools, and diagnostic procedures.

## Debug Tools

### Kernel Messages (dmesg)

View all mt7925 messages:

```bash
dmesg | grep mt7925
```

Follow messages in real-time:

```bash
dmesg -w | grep mt7925
```

Common error patterns:

```bash
# MCU timeouts
dmesg | grep "timeout"

# NULL pointer dereferences
dmesg | grep "NULL pointer\|BUG"

# Mutex issues
dmesg | grep "mutex\|deadlock"

# Firmware errors
dmesg | grep "firmware\|FW"
```

### Debugfs

**Location:** `/sys/kernel/debug/ieee80211/phy*/mt76/`

Useful entries:

| Entry | Description |
|-------|-------------|
| `queues` | DMA queue status |
| `mcu` | MCU command/response log |
| `reset` | Trigger hardware reset |
| `xmit-queues` | TX queue status |
| `wtbl` | Wireless table entries |

Example usage:

```bash
# Check queue status
cat /sys/kernel/debug/ieee80211/phy0/mt76/queues

# Check MCU log
cat /sys/kernel/debug/ieee80211/phy0/mt76/mcu

# Trigger reset (use with caution)
echo 1 > /sys/kernel/debug/ieee80211/phy0/mt76/reset
```

!!! warning "Debugfs requires root"
    Most debugfs entries require root access. Use `sudo` or run as root.

### Tracepoints

Enable tracepoints (if `CONFIG_MT76_TRACER` is enabled):

```bash
# Enable all mt76 tracepoints
echo 1 > /sys/kernel/debug/tracing/events/mt76/enable

# View trace
cat /sys/kernel/debug/tracing/trace

# Filter by function
cat /sys/kernel/debug/tracing/trace | grep mt792x_tx
```

Available tracepoints:

- `mt76:dev_irq` - Interrupt events
- `mt76:tx` - TX events
- `mt76:rx` - RX events
- `mt76:mcu_msg` - MCU messages

### Network Tools

**iw:**

```bash
# Show interface info
iw dev wlan0 info

# Show link info (MLO)
iw dev wlan0 link

# Show station info
iw dev wlan0 station dump

# Trigger scan
iw dev wlan0 scan
```

**ethtool:**

```bash
# Show statistics
ethtool -S wlan0

# Show driver info
ethtool -i wlan0
```

## Common Issues

### MCU Timeout

**Symptoms:**

```text
mt7925e 0000:c0:00.0: Message 00020002 (seq 12) timeout
```

**Causes:**

- Firmware crash
- Hardware hang
- Mutex deadlock preventing MCU response processing

**Debugging:**

```bash
# Check for mutex deadlocks
dmesg | grep -i "mutex\|deadlock"

# Check for firmware errors
dmesg | grep -i "firmware\|fw"

# Check MCU log
cat /sys/kernel/debug/ieee80211/phy0/mt76/mcu
```

**Fixes:** Our patches improve MCU timeout recovery.

### NULL Pointer Dereference

**Symptoms:**

```text
BUG: kernel NULL pointer dereference
mt7925e 0000:c0:00.0: Unable to handle kernel NULL pointer dereference
```

**Common Locations:**

- `mt792x_sta_to_link()` - MLO link access
- `mt792x_vif_to_link()` - MLO BSS config access
- `mt792x_vif_to_bss_conf()` - mac80211 BSS config access

**Debugging:**

```bash
# Check for NULL pointer errors
dmesg | grep "NULL pointer\|BUG"

# Check stack trace
dmesg | grep -A 20 "BUG:"
```

**Fixes:** Patches 0003, 0005 add NULL checks.

### Mutex Deadlock

**Symptoms:**

- System hang
- Processes stuck in D state
- Network commands hang

**Debugging:**

```bash
# Check for deadlock warnings
dmesg | grep -i "deadlock\|mutex"

# Check process state
ps aux | grep -E "mt7925|NetworkManager|wpa_supplicant"

# Check lockdep (if enabled)
dmesg | grep lockdep
```

**Common Causes:**

- Missing mutex protection around `ieee80211_iterate_active_interfaces()`
- Nested mutex acquisition
- Mutex held during MCU timeout

**Fixes:** Patches 0004, 0006 improve mutex handling.

### Firmware Crash

**Symptoms:**

```text
mt7925e 0000:c0:00.0: Firmware assertion
mt7925e 0000:c0:00.0: Message 00020002 (seq 12) timeout
```

**Debugging:**

```bash
# Check for firmware errors
dmesg | grep -i "firmware\|assertion\|crash"

# Check firmware version
dmesg | grep "Firmware Version"

# Check for reset events
dmesg | grep -i "reset"
```

### MLO Link Issues

**Symptoms:**

- Link disconnections during roaming
- NULL pointer dereferences
- Key removal failures

**Debugging:**

```bash
# Check link status
iw dev wlan0 link

# Check for MLO errors
dmesg | grep -i "link\|mlo"

# Check for NULL pointer errors
dmesg | grep "NULL pointer"
```

**Fixes:** Patches 0005, 0009 address MLO issues.

## Diagnostic Procedures

### Check Driver State

```bash
# Module status
lsmod | grep mt7925

# Interface status
ip link show wlan0

# Hardware state
cat /sys/kernel/debug/ieee80211/phy0/mt76/queues
```

### Check MCU Communication

```bash
# MCU log
cat /sys/kernel/debug/ieee80211/phy0/mt76/mcu

# MCU timeouts
dmesg | grep "timeout" | tail -20
```

### Check Power Management

```bash
# Check PM state
cat /sys/kernel/debug/ieee80211/phy0/mt76/pm

# Check PM statistics
dmesg | grep -i "pm\|power"

# Disable power save
sudo iw dev wlan0 set power_save off
```

### Check DMA Queues

```bash
# Queue status
cat /sys/kernel/debug/ieee80211/phy0/mt76/queues

# Queue errors
dmesg | grep -i "queue\|dma"
```

## Advanced Debugging

### Enable Debug Logging

```bash
# Increase log level
echo 8 > /proc/sys/kernel/printk

# Filter mt7925 messages
dmesg -w | grep mt7925
```

### Use Lockdep

If your kernel has `CONFIG_PROVE_LOCKING` enabled:

```bash
# Check lockdep warnings
dmesg | grep lockdep
```

### Crash Dumps

If kdump is configured:

```bash
# Check if kdump is enabled
systemctl status kdump

# View crash dump
crash /var/crash/vmcore /usr/lib/debug/vmlinux
```

## Stress Testing

### Roaming Test

```bash
# Connect to network
nmcli device wifi connect "SSID" password "password"

# Force roaming (if multiple APs)
# Move between APs or change BSSID
```

### Suspend/Resume Test

```bash
# Suspend
systemctl suspend

# Resume (wake machine)
# Check logs
dmesg | tail -50
```

## Reporting Issues

### Collect Information

```bash
# System info
uname -a
lspci | grep -i mediatek
dmesg > dmesg.log

# Driver info
modinfo mt7925e
dkms status | grep mt76
```

### Include in Bug Report

1. Kernel version (`uname -r`)
2. DKMS version (`dkms status`)
3. Hardware model
4. Error messages from dmesg
5. Steps to reproduce
6. Relevant logs

Open issues at: [GitHub Issues](https://github.com/zbowling/mt7925/issues)
