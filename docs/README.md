# MT76 Module Documentation

## Overview

This documentation provides a comprehensive guide to understanding, navigating, and debugging the MediaTek mt76 WiFi driver module. This knowledge store was created to help developers understand this complex codebase and serve as a reference for future auditing and debugging.

## Documentation Index

### Architecture and Design

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Module architecture overview, layering, and design patterns
- **[DATA_STRUCTURES.md](DATA_STRUCTURES.md)** - Core data structures, relationships, and memory layout
- **[FILE_REFERENCE.md](FILE_REFERENCE.md)** - Complete file index organized by layer and purpose
- **[CHIPSETS.md](CHIPSETS.md)** - Comprehensive chipset reference with specifications, release dates, and technical differences

### Entry Points and Flows

- **[ENTRY_POINTS.md](ENTRY_POINTS.md)** - Initialization flows, probe functions, and entry points
- **[CONTROL_FLOW.md](CONTROL_FLOW.md)** - Packet transmission/reception, MCU communication, and interrupt handling flows

### Kernel Integration

- **[KERNEL_INTERACTIONS.md](KERNEL_INTERACTIONS.md)** - Integration with mac80211, PCI, DMA, interrupts, and power management subsystems

### Protocols and Features

- **[MCU_PROTOCOL.md](MCU_PROTOCOL.md)** - MCU communication protocol, command format, and examples
- **[MLO.md](MLO.md)** - Multi-Link Operation (MLO) architecture, data structures, and common bugs

### Concurrency and Synchronization

- **[LOCKING.md](LOCKING.md)** - Locking patterns, mutex usage, work queue interactions, and deadlock analysis

### Development Guides

- **[NAVIGATION_GUIDE.md](NAVIGATION_GUIDE.md)** - How to navigate the codebase, trace features, and find related code
- **[DEBUGGING.md](DEBUGGING.md)** - Debugging techniques, common issues, and diagnostic procedures

## Quick Start

### Understanding the Module

1. **Start with [ARCHITECTURE.md](ARCHITECTURE.md)** to understand the overall structure
2. **Read [CHIPSETS.md](CHIPSETS.md)** to understand which chipsets are supported
3. **Read [ENTRY_POINTS.md](ENTRY_POINTS.md)** to understand initialization
4. **Review [CONTROL_FLOW.md](CONTROL_FLOW.md)** to understand runtime behavior
5. **Check [DATA_STRUCTURES.md](DATA_STRUCTURES.md)** for structure relationships

### Tracing a Feature

1. **Find the entry point** - Check [ENTRY_POINTS.md](ENTRY_POINTS.md) or [NAVIGATION_GUIDE.md](NAVIGATION_GUIDE.md)
2. **Follow the call chain** - Use grep patterns from [NAVIGATION_GUIDE.md](NAVIGATION_GUIDE.md)
3. **Understand data flow** - Reference [DATA_STRUCTURES.md](DATA_STRUCTURES.md)
4. **Check MCU commands** - See [MCU_PROTOCOL.md](MCU_PROTOCOL.md)

### Debugging an Issue

1. **Check [DEBUGGING.md](DEBUGGING.md)** for common issues and tools
2. **Review [CONTROL_FLOW.md](CONTROL_FLOW.md)** to understand the flow
3. **Use [NAVIGATION_GUIDE.md](NAVIGATION_GUIDE.md)** to find relevant code
4. **Reference [MLO.md](MLO.md)** if MLO-related

## Module Overview

The mt76 module is a Linux kernel WiFi driver for MediaTek wireless chipsets. It follows a layered architecture:

```
┌─────────────────────────────────────────┐
│         Linux Kernel (mac80211)         │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      mt76 Core Layer                    │
│  - mac80211 integration                 │
│  - DMA management                       │
│  - MCU base                             │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│   Chipset Library Layer                 │
│  - mt792x-lib (MT7921/7925 shared)      │
│  - mt76-connac-lib (connac chips)       │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│   Chipset Driver (mt7925/)              │
│  - PCI/USB probe                        │
│  - mac80211 ops                         │
│  - MCU commands                         │
└─────────────────────────────────────────┘
```

## Key Concepts

### Mutex Protection

**Critical Pattern:** All MCU operations must be protected by `dev->mt76.mutex`:

```c
mt792x_mutex_acquire(dev);
// MCU operations here
mt792x_mutex_release(dev);
```

**Common Bug:** Missing mutex protection around `ieee80211_iterate_active_interfaces()` callbacks.

### MLO Link Access

**Critical Pattern:** Always check for NULL when accessing MLO links:

```c
mlink = mt792x_sta_to_link(msta, link_id);
if (!mlink)
    return -EINVAL;  // or continue
```

**Common Bug:** Dereferencing `mt792x_sta_to_link()` or `mt792x_vif_to_link()` without NULL checks.

### MCU Communication

**Pattern:** MCU uses TLV-encoded commands sent via DMA rings:

```c
skb = mt76_mcu_msg_alloc(&dev->mt76, NULL, len);
// Build TLV data
ret = mt76_mcu_skb_send_msg(&dev->mt76, skb, cmd, true);
```

## Common Issues and Fixes

### NULL Pointer Dereference

**Symptoms:** Kernel panic with NULL pointer dereference

**Common Locations:**
- MLO link access (`mt792x_sta_to_link()`, `mt792x_vif_to_link()`)
- BSS config access (`mt792x_vif_to_bss_conf()`)

**Fixes:** Patches 0001, 0010, 0013, 0014

### Mutex Deadlock

**Symptoms:** System hang, processes stuck in D state

**Common Causes:**
- Missing mutex around `ieee80211_iterate_active_interfaces()`
- Nested mutex acquisition

**Fixes:** Patches 0002, 0003

### MCU Timeout

**Symptoms:** "Message timeout" errors, firmware crashes

**Common Causes:**
- Firmware crash
- Mutex deadlock preventing response processing

**Fixes:** Patch 0015 (firmware reload fix)

## Related Resources

### Upstream Repositories

- **OpenWrt mt76:** https://github.com/openwrt/mt76
- **Linux Kernel:** https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git

### Bug Reports

- **GitHub Issues:** https://github.com/openwrt/mt76/issues
- **LKML Threads:** Search for "mt7925" on lore.kernel.org

### Community

- **Framework Community:** https://community.frame.work/
- **Linux Wireless Mailing List:** linux-wireless@vger.kernel.org

## Contributing

When contributing fixes or improvements:

1. **Understand the architecture** - Read [ARCHITECTURE.md](ARCHITECTURE.md)
2. **Follow patterns** - Check existing code for patterns
3. **Test thoroughly** - Use stress testing scripts
4. **Document changes** - Update relevant documentation

## License

This documentation is provided under the same license as the Linux kernel (GPL v2).

## Acknowledgments

This documentation was created through analysis of:
- Kernel panic dumps and logs
- Code review and comparison with other drivers
- Community bug reports and discussions
- Upstream kernel source code

