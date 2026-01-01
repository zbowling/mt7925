# MT76 Module Architecture

## Overview

The MediaTek mt76 WiFi driver is a Linux kernel module that provides support for MediaTek wireless chipsets. The module follows a layered architecture with shared libraries for common functionality and chipset-specific drivers for hardware variations.

## Module Layering

The mt76 module is organized into three main layers:

```
┌─────────────────────────────────────────────────────────┐
│              Linux Kernel (mac80211)                    │
│         IEEE 802.11 stack, netdev, PCI/USB              │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              Core Layer (mt76/)                         │
│  • mac80211.c    - mac80211 ops registration            │
│  • dma.c         - DMA ring buffer management           │
│  • mcu.c         - MCU communication base               │
│  • tx.c          - TX path processing                   │
│  • agg-rx.c      - RX aggregation                       │
│  • mmio.c        - Memory-mapped I/O                    │
│  • usb.c/sdio.c  - USB/SDIO bus operations              │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│         Chipset Library Layer                           │
│  • mt792x-lib      - MT7921/MT7925 shared code          │
│  • mt76-connac-lib - Connac architecture (MT7615+)     │
│  • mt76x02-lib     - MT7602/MT7612 shared code          │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│      Chipset Driver Layer                               │
│  • mt7925/  - MT7925 specific implementation           │
│  • mt7921/  - MT7921 specific implementation           │
│  • mt7915/  - MT7915 specific implementation            │
│  • mt7615/  - MT7615 specific implementation            │
│  • mt7996/  - MT7996 specific implementation             │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              Hardware (PCIe/USB)                        │
│         MediaTek WiFi chipsets                          │
└─────────────────────────────────────────────────────────┘
```

## Core Layer Components

### Base Infrastructure (`mt76/`)

**Key Files:**
- `mt76.h` - Core data structures (`mt76_dev`, `mt76_phy`, `mt76_wcid`)
- `mac80211.c` - mac80211 subsystem integration and ops registration
- `dma.c`, `dma.h` - DMA ring buffer management
- `mcu.c` - Base MCU (Microcontroller Unit) communication
- `tx.c` - TX path processing and queue management
- `agg-rx.c` - RX aggregation handling
- `mmio.c` - Memory-mapped I/O operations
- `usb.c` - USB bus operations
- `sdio.c` - SDIO bus operations
- `pci.c` - PCI bus operations

**Core Data Structures:**
- `struct mt76_dev` - Base device structure (all chipsets)
- `struct mt76_phy` - PHY abstraction (supports multi-band)
- `struct mt76_wcid` - Wireless Client ID (per-station/per-interface)
- `struct mt76_queue` - DMA ring buffer descriptor

### Chipset Libraries

#### mt792x-lib (MT7921/MT7925 Shared)

**Location:** `mt792x_core.c`, `mt792x_mac.c`, `mt792x_dma.c`

**Purpose:** Shared code between MT7921 and MT7925 chipsets.

**Key Functions:**
- `mt792x_load_firmware()` - Firmware loading (shared by both chipsets)
- `mt792x_tx()` - TX path entry point
- `mt792x_dma_enable()` - DMA initialization

**Data Structures:**
- `struct mt792x_dev` - MT792x device state
- `struct mt792x_phy` - MT792x PHY state
- `struct mt792x_vif` - Virtual interface state
- `struct mt792x_sta` - Station state (MLO-aware)

#### mt76-connac-lib (Connac Architecture)

**Location:** `mt76_connac_mcu.c`, `mt76_connac_mac.c`, `mt76_connac3_mac.c`

**Purpose:** Shared MCU protocol and MAC layer for "connac" architecture chipsets (MT7615, MT7915, MT7921, MT7925, MT7996).

**Key Components:**
- MCU command/response protocol
- MAC layer processing
- Power management

#### mt76x02-lib (Legacy Chipsets)

**Location:** `mt76x02_*.c` files

**Purpose:** Shared code for older MT7602/MT7612 chipsets.

## Chipset Driver Layer

### MT7925 Driver (`mt7925/`)

**Entry Points:**
- `mt7925/pci.c:268` - `mt7925_pci_probe()` - PCI device initialization
- `mt7925/usb.c:132` - `mt7925u_probe()` - USB device initialization

**Key Files:**
- `pci.c` - PCI probe/remove, IRQ handling
- `main.c` - mac80211 operations (`mt7925_ops`)
- `mac.c` - MAC layer processing, RX/TX
- `mcu.c` - Chipset-specific MCU commands
- `init.c` - Initialization and thermal management

**mac80211 Operations:**
Defined in `mt7925/main.c:2240` as `const struct ieee80211_ops mt7925_ops`:
- `.start` → `mt7925_start()` - Hardware start
- `.tx` → `mt792x_tx()` - Packet transmission
- `.config` → `mt7925_config()` - Channel/bandwidth config
- `.add_interface` → `mt792x_add_interface()` - VIF creation
- `.sta_add` → `mt7925_mac_sta_add()` - Station association

## Data Structure Hierarchy

```
mt792x_dev (chipset device)
    │
    ├─► mt76_dev (core device)
    │   ├─► mt76_phy (primary PHY)
    │   │   ├─► ieee80211_hw (mac80211 hardware)
    │   │   └─► sband_2g, sband_5g, sband_6g (supported bands)
    │   │
    │   ├─► mt76_wcid[] (WCID table - per-station/per-interface)
    │   │
    │   ├─► mt76_queue[] (DMA rings)
    │   │   ├─► TX queues (per-AC + MCU)
    │   │   └─► RX queues (data + MCU)
    │   │
    │   └─► bus_ops (MMIO/USB/SDIO operations)
    │
    ├─► mt792x_phy (chipset PHY)
    │   └─► mt792x_vif[] (virtual interfaces)
    │       ├─► mt792x_bss_conf (BSS configuration)
    │       └─► mt792x_sta (station state)
    │
    └─► mt76_connac_pm (power management)
```

## Module Dependencies

```
mt7925e.ko (PCIe driver)
    ├─► depends on: mt7925-common.ko
    │   ├─► depends on: mt792x-lib.ko
    │   │   ├─► depends on: mt76-connac-lib.ko
    │   │   │   └─► depends on: mt76.ko
    │   │   └─► depends on: mt76.ko
    │   └─► depends on: mt76.ko
    └─► depends on: mt76.ko
```

## Bus Abstraction

The module supports three bus types via `struct mt76_bus_ops`:

1. **MMIO (PCIe)** - Memory-mapped I/O
   - Register read/write via MMIO
   - Used by: MT7925e (PCIe), MT7915e, MT7615e

2. **USB** - USB bus
   - Register access via USB control transfers
   - Used by: MT7925u (USB), MT7921u

3. **SDIO** - SDIO bus
   - Register access via SDIO commands
   - Used by: MT7921s (SDIO)

## MCU Communication

The MCU (Microcontroller Unit) is a firmware component that handles:
- Firmware management
- Station management
- Power management
- Regulatory domain handling
- Scan operations

**Communication Protocol:**
- Commands sent via DMA rings (`MT_MCUQ_WM`, `MT_MCUQ_WA`, `MT_MCUQ_FWDL`)
- TLV (Type-Length-Value) encoding
- Asynchronous command/response model

See [MCU_PROTOCOL.md](MCU_PROTOCOL.md) for detailed protocol documentation.

## Multi-Link Operation (MLO)

MT7925 supports Wi-Fi 7 Multi-Link Operation:
- Up to 4 simultaneous links (`IEEE80211_MLD_MAX_NUM_LINKS`)
- Per-link state management
- Link aggregation for higher throughput

**Key Structures:**
- `struct mt792x_sta` - Contains `link[]` array for per-link state
- `struct mt792x_vif` - Contains `link_conf[]` array for per-link BSS config

See [MLO.md](MLO.md) for detailed MLO documentation.

## Power Management

**Runtime PM:**
- Controlled via `mt7925_set_runtime_pm()`
- Deep sleep mode support
- MLO-aware power save

**Suspend/Resume:**
- `mt7925_pci_suspend()` / `mt7925_pci_resume()`
- WOWLAN (Wake-on-WLAN) support
- Firmware state preservation

## File Organization

### Core Files (`mt76/`)
- `mt76.h` - Core data structures
- `mac80211.c` - mac80211 integration
- `dma.c`, `dma.h` - DMA management
- `mcu.c` - MCU base
- `tx.c` - TX path
- `agg-rx.c` - RX aggregation
- `mmio.c` - MMIO operations
- `usb.c`, `sdio.c` - Bus operations

### MT792x Shared (`mt792x_*.c`)
- `mt792x_core.c` - Core functions (firmware load, etc.)
- `mt792x_mac.c` - MAC layer
- `mt792x_dma.c` - DMA setup
- `mt792x.h` - MT792x data structures

### MT7925 Specific (`mt7925/`)
- `pci.c` - PCI probe/remove
- `main.c` - mac80211 ops
- `mac.c` - MAC processing
- `mcu.c` - MCU commands
- `init.c` - Initialization

See [FILE_REFERENCE.md](FILE_REFERENCE.md) for complete file index.

## Key Design Patterns

### 1. Mutex Protection

**Critical Pattern:** All MCU operations must be protected by `dev->mt76.mutex`:

```c
mt792x_mutex_acquire(dev);
/* MCU operations here */
mt792x_mutex_release(dev);
```

**Common Bug:** Missing mutex protection around `ieee80211_iterate_active_interfaces()` callbacks that call MCU functions.

### 2. MLO Link State Management

**Pattern:** Always check for NULL when accessing MLO links:

```c
struct mt792x_link_sta *mlink = mt792x_sta_to_link(msta, link_id);
if (!mlink)
    return -EINVAL;  /* or continue, depending on context */
```

**Common Bug:** Dereferencing `mt792x_sta_to_link()` or `mt792x_vif_to_link()` without NULL checks.

### 3. RCU-Protected Access

**Pattern:** MLO link configs are RCU-protected:

```c
struct mt792x_bss_conf *mconf = rcu_dereference_protected(
    mvif->link_conf[link_id],
    lockdep_is_held(&dev->mt76.mutex)
);
```

## Related Documentation

- [ENTRY_POINTS.md](ENTRY_POINTS.md) - Initialization flows
- [CONTROL_FLOW.md](CONTROL_FLOW.md) - Packet and MCU flows
- [DATA_STRUCTURES.md](DATA_STRUCTURES.md) - Detailed structure documentation
- [MCU_PROTOCOL.md](MCU_PROTOCOL.md) - MCU communication protocol
- [MLO.md](MLO.md) - Multi-Link Operation details

