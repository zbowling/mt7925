# Debugging Guide

## Overview

This guide provides techniques for debugging issues in the MT7925 driver, including common problems, debugging tools, and diagnostic procedures.

## Related Documentation

For detailed interface references, see:
- **[DEBUGFS.md](DEBUGFS.md)** - Complete debugfs reference with all entries, usage examples, and trace events
- **[SYSFS.md](SYSFS.md)** - Sysfs interface reference for temperature monitoring, rfkill, and power management

## Debug Tools

### Kernel Messages (dmesg)

**View all mt7925 messages:**
```bash
dmesg | grep mt7925
```

**Follow messages in real-time:**
```bash
dmesg -w | grep mt7925
```

**Common error patterns:**
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

**Useful entries:**
- `queues` - DMA queue status
- `mcu` - MCU command/response log
- `reset` - Trigger hardware reset
- `xmit-queues` - TX queue status
- `wtbl` - Wireless table entries

**Example:**
```bash
# Check queue status
cat /sys/kernel/debug/ieee80211/phy0/mt76/queues

# Check MCU log
cat /sys/kernel/debug/ieee80211/phy0/mt76/mcu

# Trigger reset
echo 1 > /sys/kernel/debug/ieee80211/phy0/mt76/reset
```

### Tracepoints

**Enable tracepoints (if CONFIG_MT76_TRACER):**
```bash
# Enable all mt76 tracepoints
echo 1 > /sys/kernel/debug/tracing/events/mt76/enable

# View trace
cat /sys/kernel/debug/tracing/trace

# Filter by function
cat /sys/kernel/debug/tracing/trace | grep mt792x_tx
```

**Available tracepoints:**
- `mt76:dev_irq` - Interrupt events
- `mt76:tx` - TX events
- `mt76:rx` - RX events
- `mt76:mcu_msg` - MCU messages

### Network Tools

**iw:**
```bash
# Show interface info
iw dev wlp192s0 info

# Show link info (MLO)
iw dev wlp192s0 link

# Show station info
iw dev wlp192s0 station dump

# Trigger scan
iw dev wlp192s0 scan
```

**ethtool:**
```bash
# Show statistics
ethtool -S wlp192s0

# Show driver info
ethtool -i wlp192s0
```

## Common Issues

### MCU Timeout

**Symptoms:**
```
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

**Fixes:**
- Patch 0015 - Firmware reload fix
- Ensure mutex is not held during MCU operations

### NULL Pointer Dereference

**Symptoms:**
```
BUG: kernel NULL pointer dereference
[  123.456789] mt7925e 0000:c0:00.0: Unable to handle kernel NULL pointer dereference
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

**Fixes:**
- Patches 0001, 0010, 0013, 0014 - NULL checks

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

**Fixes:**
- Patches 0002, 0003 - Mutex protection

### Firmware Crash

**Symptoms:**
```
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

**Fixes:**
- Patch 0015 - Firmware reload fix
- May require firmware update

### MLO Link Issues

**Symptoms:**
- Link disconnections during roaming
- NULL pointer dereferences
- Key removal failures

**Debugging:**
```bash
# Check link status
iw dev wlp192s0 link

# Check for MLO errors
dmesg | grep -i "link\|mlo"

# Check for NULL pointer errors
dmesg | grep "NULL pointer"
```

**Fixes:**
- Patches 0001, 0012, 0013, 0014 - MLO fixes

## Diagnostic Procedures

### Check Driver State

**Module status:**
```bash
lsmod | grep mt7925
```

**Interface status:**
```bash
ip link show wlp192s0
```

**Hardware state:**
```bash
cat /sys/kernel/debug/ieee80211/phy0/mt76/queues
```

### Check MCU Communication

**MCU log:**
```bash
cat /sys/kernel/debug/ieee80211/phy0/mt76/mcu
```

**MCU timeouts:**
```bash
dmesg | grep "timeout" | tail -20
```

### Check Power Management

**Runtime PM:**
```bash
# Check PM state
cat /sys/kernel/debug/ieee80211/phy0/mt76/pm

# Check PM statistics
dmesg | grep -i "pm\|power"
```

### Check DMA Queues

**Queue status:**
```bash
cat /sys/kernel/debug/ieee80211/phy0/mt76/queues
```

**Queue errors:**
```bash
dmesg | grep -i "queue\|dma"
```

## Advanced Debugging

### Enable Debug Logging

**Kernel messages:**
```bash
# Increase log level
echo 8 > /proc/sys/kernel/printk

# Filter mt7925 messages
dmesg -w | grep mt7925
```

### Use GDB (if kernel built with debug symbols)

**Load symbols:**
```bash
# Load module symbols
gdb vmlinux
(gdb) add-symbol-file drivers/net/wireless/mediatek/mt76/mt7925/mt7925-common.ko
```

### Use Crash Dumps

**kdump:**
```bash
# Check if kdump is enabled
systemctl status kdump

# View crash dump
crash /var/crash/vmcore /usr/lib/debug/vmlinux
```

### Use Lockdep

**Enable lockdep:**
```bash
# Add to kernel command line
lockdep=1

# Check lockdep warnings
dmesg | grep lockdep
```

## Stress Testing

### Use Provided Scripts

**Stress test:**
```bash
sudo ./stress-test.sh -s "SSID" -p "password" -d 300
```

**Monitor:**
```bash
sudo ./monitor.sh
```

### Manual Testing

**Roaming test:**
```bash
# Connect to network
nmcli device wifi connect "SSID" password "password"

# Force roaming (if multiple APs)
# Move between APs or change BSSID
```

**Suspend/resume test:**
```bash
# Suspend
systemctl suspend

# Resume (wake machine)
# Check logs
dmesg | tail -50
```

## Reporting Issues

### Collect Information

**System info:**
```bash
uname -a
lspci | grep -i mediatek
dmesg > dmesg.log
```

**Driver info:**
```bash
modinfo mt7925e
ethtool -i wlp192s0
```

**Error logs:**
```bash
dmesg | grep -i "error\|fail\|timeout\|bug" > errors.log
journalctl -k | grep mt7925 > journal.log
```

### Include in Bug Report

1. Kernel version
2. Driver version
3. Hardware model
4. Error messages
5. Steps to reproduce
6. Relevant logs

## Related Documentation

- [NAVIGATION_GUIDE.md](NAVIGATION_GUIDE.md) - Code navigation
- [CONTROL_FLOW.md](CONTROL_FLOW.md) - Control flows
- [MCU_PROTOCOL.md](MCU_PROTOCOL.md) - MCU debugging

