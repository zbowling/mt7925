# Developer Debugging Guide

Advanced debugging techniques for driver developers working on the MT7925 driver.

## Debug Build Configuration

### Kernel Config Options

Enable these options for debugging:

```
CONFIG_MT76_DEBUG=y           # MT76 debug messages
CONFIG_MT76_TRACER=y          # MT76 tracepoints
CONFIG_PROVE_LOCKING=y        # Lockdep for deadlock detection
CONFIG_DEBUG_LOCK_ALLOC=y     # Lock debugging
CONFIG_LOCKDEP=y              # Lock dependency tracking
CONFIG_DEBUG_OBJECTS=y        # Object debugging
CONFIG_KASAN=y                # Memory error detection
```

### Module Parameters

```bash
# Load with debug messages
modprobe mt7925e dyndbg=+p
```

## Debugfs Interface

### Location

```
/sys/kernel/debug/ieee80211/phyN/mt76/
```

### Key Entries

| Entry | Description |
|-------|-------------|
| `fw_debug` | Firmware debug logging (0/1/2) |
| `chip_reset` | Trigger chip reset |
| `regidx`/`regval` | Direct register access |
| `xmit-queues` | TX queue status |
| `rx-queues` | RX queue status |
| `tx_stats` | TX statistics |
| `txpower_sku` | TX power limits |
| `runtime-pm` | Power management control |

### Firmware Debug

```bash
# Enable extended logging
echo 2 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/fw_debug

# Watch firmware messages
dmesg -w | grep mt7925
```

### Chip Reset with Coredump

```bash
# Trigger coredump + reset
echo 0 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/chip_reset

# Check coredumps
ls /sys/class/devcoredump/
```

### Register Access

```bash
# Set register address
echo 0xd4200 | sudo tee /sys/kernel/debug/ieee80211/phy0/mt76/regidx

# Read value
sudo cat /sys/kernel/debug/ieee80211/phy0/mt76/regval
```

!!! warning "Caution"
    Direct register access can crash the system. Use only if you understand the hardware.

## Tracepoints

### Enable Tracing

```bash
# Enable all mt76 tracepoints
echo 1 | sudo tee /sys/kernel/debug/tracing/events/mt76/enable

# View trace
cat /sys/kernel/debug/tracing/trace

# Clear trace
echo > /sys/kernel/debug/tracing/trace
```

### Available Tracepoints

- `mt76:dev_irq` - Interrupt events
- `mt76:tx` - TX events
- `mt76:rx` - RX events
- `mt76:mcu_msg` - MCU messages

### Filtering

```bash
# Filter specific events
echo 'eid==0x02' | sudo tee /sys/kernel/debug/tracing/events/mt76/mcu_msg/filter
```

## Lockdep Analysis

### Check for Warnings

```bash
dmesg | grep -i lockdep
dmesg | grep -i "held lock"
dmesg | grep -i deadlock
```

### Add Assertions

In driver code:

```c
int mt7925_mcu_function(struct mt792x_dev *dev, ...)
{
    lockdep_assert_held(&dev->mt76.mutex);
    // ... function body
}
```

## Memory Debugging

### KASAN (Kernel Address Sanitizer)

Enable `CONFIG_KASAN=y` to detect:

- Use-after-free
- Out-of-bounds access
- Memory leaks

```bash
dmesg | grep -i kasan
```

### SLUB Debug

```bash
# Enable SLUB debugging for mt76
echo 1 > /sys/kernel/slab/kmalloc-*/sanity_checks
```

## GDB Debugging

### Load Symbols

```bash
gdb vmlinux
(gdb) add-symbol-file drivers/net/wireless/mediatek/mt76/mt7925/mt7925-common.ko
```

### With kgdb

```bash
# Enable kgdb in kernel config
CONFIG_KGDB=y
CONFIG_KGDB_SERIAL_CONSOLE=y

# Connect from remote
target remote /dev/ttyS0
```

## Crash Dump Analysis

### kdump Setup

```bash
# Check if kdump is enabled
systemctl status kdump

# Analyze crash dump
crash /var/crash/vmcore /usr/lib/debug/vmlinux
```

### crash Commands

```
crash> bt              # Backtrace
crash> log             # Kernel log
crash> mod -t          # List loaded modules
crash> struct mt792x_dev <addr>
```

## Common Debug Scenarios

### MCU Timeout

```bash
# Check MCU log
cat /sys/kernel/debug/ieee80211/phy0/mt76/mcu

# Enable MCU tracing
echo 1 > /sys/kernel/debug/tracing/events/mt76/mcu_msg/enable
```

### Deadlock Investigation

```bash
# Check process state
ps aux | awk '$8 ~ /D/'

# Get backtrace of stuck process
echo t > /proc/sysrq-trigger
dmesg | tail -100
```

### NULL Pointer

```bash
# Get call trace
dmesg | grep -A 30 "BUG:"

# Check symbol
addr2line -e vmlinux <address>
```

## Performance Profiling

### perf

```bash
# Record driver activity
perf record -g -a -e 'sched:*' -- sleep 10

# Analyze
perf report
```

### ftrace

```bash
# Trace mt76 functions
echo 'mt76*' > /sys/kernel/debug/tracing/set_ftrace_filter
echo function > /sys/kernel/debug/tracing/current_tracer
echo 1 > /sys/kernel/debug/tracing/tracing_on
```

## Log Collection Script

```bash
#!/bin/bash
# collect-debug.sh

OUTPUT_DIR="mt7925-debug-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

# System info
uname -a > "$OUTPUT_DIR/uname.txt"
lspci -vnn | grep -A20 "MediaTek" > "$OUTPUT_DIR/lspci.txt"
dmesg > "$OUTPUT_DIR/dmesg.txt"

# Module info
modinfo mt7925e > "$OUTPUT_DIR/modinfo.txt"
dkms status > "$OUTPUT_DIR/dkms.txt"

# Debugfs (if accessible)
if [ -d /sys/kernel/debug/ieee80211/phy0/mt76 ]; then
    cat /sys/kernel/debug/ieee80211/phy0/mt76/xmit-queues > "$OUTPUT_DIR/xmit-queues.txt" 2>/dev/null
    cat /sys/kernel/debug/ieee80211/phy0/mt76/tx_stats > "$OUTPUT_DIR/tx_stats.txt" 2>/dev/null
fi

# Network info
iw dev > "$OUTPUT_DIR/iw-dev.txt"
ip link show > "$OUTPUT_DIR/ip-link.txt"

echo "Debug info collected in $OUTPUT_DIR"
tar czf "$OUTPUT_DIR.tar.gz" "$OUTPUT_DIR"
```
