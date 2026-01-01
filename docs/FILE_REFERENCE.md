# File Reference

## Overview

This document provides a comprehensive index of files in the mt76 module, organized by layer and purpose.

## Core Layer Files (`mt76/`)

### Core Infrastructure

**`mt76.h`**
- Core data structures (`mt76_dev`, `mt76_phy`, `mt76_wcid`)
- Queue definitions
- Bus operations
- **Lines:** ~1965

**`mac80211.c`**
- mac80211 subsystem integration
- Hardware registration
- Channel/band configuration
- **Lines:** ~2120

**`dma.c`, `dma.h`**
- DMA ring buffer management
- Queue operations
- **Lines:** ~500

**`mcu.c`**
- Base MCU communication
- Command/response handling
- **Lines:** ~200

**`tx.c`**
- TX path processing
- Queue management
- **Lines:** ~400

**`agg-rx.c`**
- RX aggregation handling
- **Lines:** ~300

**`mmio.c`**
- Memory-mapped I/O operations
- **Lines:** ~200

### Bus Operations

**`usb.c`**
- USB bus operations
- USB-specific register access
- **Lines:** ~300

**`sdio.c`, `sdio.h`**
- SDIO bus operations
- SDIO-specific register access
- **Lines:** ~400

**`pci.c`**
- PCI bus operations
- PCI-specific register access
- **Lines:** ~200

### Utilities

**`util.c`, `util.h`**
- Utility functions
- Helper macros
- **Lines:** ~300

**`debugfs.c`**
- Debugfs entries
- Debugging interfaces
- **Lines:** ~400

**`trace.c`, `trace.h`**
- Tracepoint definitions
- **Lines:** ~200

## MT792x Shared Files

### Core Functions

**`mt792x_core.c`**
- Core MT792x functions
- Firmware loading (`mt792x_load_firmware()`)
- TX entry point (`mt792x_tx()`)
- **Lines:** ~1010

**`mt792x.h`**
- MT792x data structures
- Helper functions
- **Lines:** ~536

**`mt792x_mac.c`**
- MAC layer processing
- RX packet processing
- **Lines:** ~800

**`mt792x_dma.c`**
- DMA initialization
- Interrupt handling
- **Lines:** ~400

**`mt792x_debugfs.c`**
- MT792x debugfs entries
- **Lines:** ~300

**`mt792x_trace.c`, `mt792x_trace.h`**
- MT792x tracepoints
- **Lines:** ~200

**`mt792x_acpi_sar.c`, `mt792x_acpi_sar.h`**
- ACPI SAR (Specific Absorption Rate) support
- **Lines:** ~300

**`mt792x_regs.h`**
- Register definitions
- **Lines:** ~500

**`mt792x_usb.c`**
- USB-specific MT792x code
- **Lines:** ~200

## MT7925 Specific Files (`mt7925/`)

### Initialization

**`pci.c`**
- PCI probe/remove
- IRQ handling
- Register remapping
- **Lines:** ~640

**`init.c`**
- Hardware initialization
- Thermal management
- Regulatory domain handling
- **Lines:** ~428

**`usb.c`**
- USB probe/remove
- USB-specific initialization
- **Lines:** ~350

### mac80211 Operations

**`main.c`**
- mac80211 operations (`mt7925_ops`)
- Interface management
- Station management
- Channel context management
- **Lines:** ~2292

### MAC Layer

**`mac.c`, `mac.h`**
- MAC layer processing
- RX packet processing
- Station polling
- **Lines:** ~1500

### MCU Communication

**`mcu.c`, `mcu.h`**
- Chipset-specific MCU commands
- Station management commands
- BSS management commands
- Scan commands
- **Lines:** ~3847

### PCI-Specific

**`pci_mac.c`**
- PCI-specific MAC operations
- NAPI handling
- **Lines:** ~152

**`pci_mcu.c`**
- PCI-specific MCU operations
- **Lines:** ~54

### Headers

**`mt7925.h`**
- MT7925-specific definitions
- Function declarations
- **Lines:** ~268

**`regs.h`**
- MT7925 register definitions
- **Lines:** ~200

**`debugfs.c`**
- MT7925 debugfs entries
- **Lines:** ~300

**`testmode.c`**
- Test mode support
- **Lines:** ~200

## Connac Library Files

### MCU Protocol

**`mt76_connac_mcu.c`**
- Connac MCU protocol implementation
- Command/response handling
- **Lines:** ~3263

**`mt76_connac_mcu.h`**
- MCU command definitions
- TLV structures
- **Lines:** ~2069

**`mt76_connac.h`**
- Connac common definitions
- **Lines:** ~200

### MAC Layer

**`mt76_connac_mac.c`**
- Connac MAC layer
- **Lines:** ~800

**`mt76_connac3_mac.c`, `mt76_connac3_mac.h`**
- Connac3 MAC layer (Wi-Fi 7)
- **Lines:** ~600

**`mt76_connac2_mac.h`**
- Connac2 MAC definitions
- **Lines:** ~400

## Legacy Library Files

### MT76x02 Library

**`mt76x02_*.c`**
- Shared code for MT7602/MT7612
- **Files:**
  - `mt76x02_util.c`
  - `mt76x02_mac.c`
  - `mt76x02_mcu.c`
  - `mt76x02_eeprom.c`
  - `mt76x02_phy.c`
  - `mt76x02_mmio.c`
  - `mt76x02_txrx.c`
  - `mt76x02_trace.c`
  - `mt76x02_debugfs.c`
  - `mt76x02_dfs.c`
  - `mt76x02_beacon.c`

**`mt76x02.h`**
- MT76x02 data structures
- **Lines:** ~285

## Chipset Driver Directories

### MT7921 (`mt7921/`)
- Similar structure to MT7925
- Shares code via `mt792x-lib`

### MT7915 (`mt7915/`)
- Connac architecture
- Wi-Fi 6E support

### MT7615 (`mt7615/`)
- Older Connac chipset
- Wi-Fi 5 support

### MT7996 (`mt7996/`)
- Latest Connac chipset
- Wi-Fi 7 support

### MT7603 (`mt7603/`)
- Legacy chipset
- Wi-Fi 4 support

## File Organization Patterns

### By Functionality

**Initialization:**
- `pci.c` / `usb.c` - Bus-specific probe
- `init.c` - Hardware initialization
- `*_core.c` - Core initialization

**mac80211 Integration:**
- `main.c` - Operations structure
- `mac80211.c` - Core integration

**MAC Layer:**
- `mac.c` - MAC processing
- `*_mac.c` - Shared MAC code

**MCU Communication:**
- `mcu.c` - Chipset-specific commands
- `mt76_connac_mcu.c` - Protocol implementation
- `mt76/mcu.c` - Base MCU code

**DMA:**
- `dma.c` - Core DMA
- `*_dma.c` - Chipset-specific DMA

### By Layer

**Core Layer:**
- `mt76/*.c` - Base functionality

**Library Layer:**
- `mt792x_*.c` - MT792x shared
- `mt76_connac_*.c` - Connac shared
- `mt76x02_*.c` - Legacy shared

**Chipset Layer:**
- `mt7925/*.c` - MT7925 specific

## Key Files for Common Tasks

### Finding Entry Points

**PCI Probe:**
- `mt7925/pci.c:268` - `mt7925_pci_probe()`

**mac80211 Operations:**
- `mt7925/main.c:2240` - `mt7925_ops`

**TX Entry:**
- `mt792x_core.c:80` - `mt792x_tx()`

**RX Entry:**
- `mt7925/mac.c` - `mt7925_queue_rx_skb()`

### Finding MCU Commands

**Command Definitions:**
- `mt76_connac_mcu.h` - Command IDs

**Command Builders:**
- `mt7925/mcu.c` - Chipset-specific commands

**Protocol Implementation:**
- `mt76_connac_mcu.c` - Protocol handling

### Finding Data Structures

**Core Structures:**
- `mt76/mt76.h` - Core structures

**MT792x Structures:**
- `mt792x.h` - MT792x structures

**Chipset Structures:**
- `mt7925/mt7925.h` - MT7925 structures

### Finding Bug Fixes

**NULL Pointer Fixes:**
- `mt7925/mac.c` - Patch 0001
- `mt7925/main.c` - Patches 0004, 0005, 0009
- `mt7925/mcu.c` - Patches 0013, 0014

**Mutex Fixes:**
- `mt7925/mac.c` - Patch 0002
- `mt7925/main.c` - Patch 0003
- `mt7925/pci.c` - Patch 0002

## Build System

### Makefile

**Location:** `mt76/Makefile`

**Key Sections:**
- Core module objects
- Library module objects
- Chipset module objects

**Module Dependencies:**
```
mt7925e.ko
    ├─► mt7925-common.ko
    │   ├─► mt792x-lib.ko
    │   │   ├─► mt76-connac-lib.ko
    │   │   │   └─► mt76.ko
    │   │   └─► mt76.ko
    │   └─► mt76.ko
    └─► mt76.ko
```

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Module architecture
- [NAVIGATION_GUIDE.md](NAVIGATION_GUIDE.md) - Code navigation techniques

