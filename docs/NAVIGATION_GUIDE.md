# Navigation Guide

## Overview

This guide provides techniques for navigating and understanding the mt76 codebase. Use these patterns to trace features, find related code, and understand control flow.

## How to Trace a Feature

### Step 1: Find the Entry Point

**User-Space Actions:**
- `iw` commands → `net/mac80211/` → `ieee80211_ops` callbacks
- `wpa_supplicant` → `net/mac80211/` → `ieee80211_ops` callbacks
- `NetworkManager` → `net/mac80211/` → `ieee80211_ops` callbacks

**mac80211 Operations:**
Check `mt7925_ops` in `mt7925/main.c:2240` to find which callback handles the operation.

**Example: Tracing Station Association**

1. User-space: `wpa_supplicant` requests association
2. Kernel: `net/mac80211/` calls `.sta_add` operation
3. Driver: `mt7925_ops.sta_add` → `mt7925_mac_sta_add()`

### Step 2: Follow the Call Chain

**Use grep to find callers:**
```bash
# Find where a function is called
grep -r "function_name" mt7925/

# Find function definition
grep -r "^function_name\|^static.*function_name" mt7925/
```

**Check header files:**
```bash
# Find function declaration
grep -r "function_name" mt7925/*.h
```

**Example: Tracing MCU Command**

1. Find command builder: `grep -r "STA_REC_UPDATE" mt7925/mcu.c`
2. Find command usage: `grep -r "mt7925_mcu_sta_add" mt7925/`
3. Find MCU send: `grep -r "mt76_mcu_skb_send_msg" mt7925/`

### Step 3: Understand Data Flow

**Start with data structures:**
```c
// Find structure definition
grep -r "struct mt792x_dev" mt792x.h

// Find structure usage
grep -r "mt792x_dev" mt7925/
```

**Follow pointers:**
- `dev->mt76` - Core device
- `dev->phy` - PHY state
- `dev->mt76.phy` - mac80211 PHY
- `dev->mt76.hw` - mac80211 hardware

### Step 4: Trace MCU Commands

**Find MCU command ID:**
```bash
grep -r "MCU_CMD\|MCU_EXT_CMD\|MCU_WMWA_UNI_CMD" mt76_connac_mcu.h
```

**Find command builder:**
```bash
# Find function that builds the command
grep -r "STA_REC_UPDATE\|STA_REC_ADD" mt7925/mcu.c
```

**Find response handler:**
```bash
# Find event handler
grep -r "case.*EVENT\|UNI_EVENT" mt7925/mcu.c
```

## Search Patterns

### Find mac80211 Operations

```bash
# Find where an operation is implemented
grep -r "\.op_name" mt7925/main.c

# Example: Find TX operation
grep -r "\.tx" mt7925/main.c
```

### Find MCU Commands

```bash
# Find all MCU command usages
grep -r "MCU_CMD\|MCU_EXT_CMD\|MCU_WMWA_UNI_CMD" mt7925/

# Find specific command
grep -r "STA_REC_UPDATE" mt7925/
```

### Find Interrupt Handlers

```bash
# Find IRQ registration
grep -r "request_irq\|devm_request_irq" mt7925/

# Find IRQ handler
grep -r "irq_handler" mt7925/
```

### Find Mutex Usage

```bash
# Find mutex acquisition
grep -r "mutex_acquire\|mutex_lock" mt7925/

# Find mutex release
grep -r "mutex_release\|mutex_unlock" mt7925/

# Find missing mutex (common bug)
grep -r "ieee80211_iterate_active_interfaces" mt7925/ | grep -v "mutex_acquire"
```

### Find MLO Code

```bash
# Find MLO link access
grep -r "mt792x_sta_to_link\|mt792x_vif_to_link" mt7925/

# Find MLO NULL checks (or lack thereof)
grep -r "mt792x_sta_to_link" mt7925/ -A 2 | grep -v "if.*mlink"
```

### Find Work Queues

```bash
# Find work queue initialization
grep -r "INIT_WORK\|INIT_DELAYED_WORK" mt7925/

# Find work queue scheduling
grep -r "schedule_work\|schedule_delayed_work" mt7925/
```

## Understanding Call Chains

### Example: Station Association Flow

```
User Space (wpa_supplicant)
    ↓
Kernel (mac80211)
    ↓
mt7925_ops.sta_add (mt7925/main.c:2240)
    ↓
mt7925_mac_sta_add() (mt7925/main.c)
    ↓
mt7925_mcu_sta_add() (mt7925/mcu.c)
    ↓
mt76_mcu_skb_send_msg() (mt76/mcu.c)
    ↓
mt76_queue_tx() (mt76/tx.c)
    ↓
Hardware DMA
    ↓
MCU Response Interrupt
    ↓
mt7925_mcu_rx_event() (mt7925/mcu.c)
```

### Tracing Technique

1. **Start at entry point:** Find the mac80211 operation
2. **Follow function calls:** Use grep to find callers/callees
3. **Check return values:** Understand error paths
4. **Find hardware interaction:** Look for register writes or DMA operations

## Finding Related Code

### By Functionality

**Power Management:**
```bash
grep -r "pm\|power\|sleep\|wake" mt7925/ | grep -v ".o\|.ko"
```

**MLO (Multi-Link Operation):**
```bash
grep -r "mlo\|MLO\|link_id\|link_conf" mt7925/
```

**Firmware:**
```bash
grep -r "firmware\|fw\|mcu" mt7925/ | grep -v ".o\|.ko"
```

### By Data Structure

**Find structure usage:**
```bash
# Find where a structure is used
grep -r "mt792x_dev\|mt792x_vif\|mt792x_sta" mt7925/
```

**Find structure members:**
```bash
# Find where a field is accessed
grep -r "\.field_name" mt7925/
```

### By File Pattern

**MCU-related files:**
- `mt7925/mcu.c` - MCU commands
- `mt76_connac_mcu.c` - MCU protocol
- `mt76/mcu.c` - MCU base

**MAC-related files:**
- `mt7925/mac.c` - MAC processing
- `mt792x_mac.c` - Shared MAC code
- `mt76_connac_mac.c` - Connac MAC

## Debugging Techniques

### Enable Debug Logging

**Kernel messages:**
```bash
# Enable debug messages
echo 8 > /proc/sys/kernel/printk

# Filter mt7925 messages
dmesg | grep mt7925
```

**Tracepoints:**
```bash
# Enable tracepoints (if CONFIG_MT76_TRACER)
echo 1 > /sys/kernel/debug/tracing/events/mt76/enable
cat /sys/kernel/debug/tracing/trace
```

### Use Debugfs

**Location:** `/sys/kernel/debug/ieee80211/phy*/mt76/`

**Useful entries:**
- `queues` - DMA queue status
- `mcu` - MCU command/response log
- `reset` - Trigger hardware reset

### Check Kernel Logs

**Common error patterns:**
```bash
# MCU timeouts
dmesg | grep "timeout"

# NULL pointer dereferences
dmesg | grep "NULL pointer\|BUG"

# Mutex issues
dmesg | grep "mutex\|deadlock"
```

### Use Git Blame

**Find when code was added:**
```bash
git blame mt7925/main.c | grep "function_name"
```

**Find related commits:**
```bash
git log --all --grep="mt7925" --oneline
```

## Code Organization Patterns

### File Naming Conventions

- `*_core.c` - Core functionality
- `*_mac.c` - MAC layer
- `*_mcu.c` - MCU communication
- `*_dma.c` - DMA operations
- `*_init.c` - Initialization
- `pci.c` - PCI-specific code
- `usb.c` - USB-specific code

### Function Naming Conventions

- `mt7925_*` - MT7925-specific functions
- `mt792x_*` - MT792x shared functions
- `mt76_*` - Core mt76 functions
- `mt76_connac_*` - Connac architecture functions

### Structure Naming

- `struct mt792x_*` - MT792x structures
- `struct mt76_*` - Core structures
- `struct mt76_connac_*` - Connac structures

## Common Code Patterns

### Mutex Protection Pattern

**Correct:**
```c
mt792x_mutex_acquire(dev);
ieee80211_iterate_active_interfaces(hw, ..., callback, dev);
mt792x_mutex_release(dev);
```

**Incorrect (common bug):**
```c
ieee80211_iterate_active_interfaces(hw, ..., callback, dev);
// Missing mutex protection!
```

### MLO Link Access Pattern

**Correct:**
```c
mlink = mt792x_sta_to_link(msta, link_id);
if (!mlink)
    return -EINVAL;  // or continue, depending on context
// Use mlink
```

**Incorrect (common bug):**
```c
mlink = mt792x_sta_to_link(msta, link_id);
wcid = &mlink->wcid;  // NULL pointer dereference if mlink is NULL!
```

### MCU Command Pattern

**Correct:**
```c
mt792x_mutex_acquire(dev);
skb = mt76_mcu_msg_alloc(&dev->mt76, NULL, len);
// Build command
ret = mt76_mcu_skb_send_msg(&dev->mt76, skb, cmd, true);
mt792x_mutex_release(dev);
```

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Module architecture
- [ENTRY_POINTS.md](ENTRY_POINTS.md) - Entry points
- [CONTROL_FLOW.md](CONTROL_FLOW.md) - Control flows
- [DEBUGGING.md](DEBUGGING.md) - Debugging techniques

