# Architecture Overview

The MediaTek mt76 WiFi driver is a Linux kernel module that provides support for MediaTek wireless chipsets. The module follows a layered architecture with shared libraries for common functionality and chipset-specific drivers for hardware variations.

## Module Layering

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
│  • mt76-connac-lib - Connac architecture (MT7615+)      │
│  • mt76x02-lib     - MT7602/MT7612 shared code          │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│      Chipset Driver Layer                               │
│  • mt7925/  - MT7925 specific implementation            │
│  • mt7921/  - MT7921 specific implementation            │
│  • mt7915/  - MT7915 specific implementation            │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              Hardware (PCIe/USB)                        │
│         MediaTek WiFi chipsets                          │
└─────────────────────────────────────────────────────────┘
```

## Module Dependencies

```
mt7925e.ko (PCIe driver)
    ├── depends on: mt7925-common.ko
    │   ├── depends on: mt792x-lib.ko
    │   │   ├── depends on: mt76-connac-lib.ko
    │   │   │   └── depends on: mt76.ko
    │   │   └── depends on: mt76.ko
    │   └── depends on: mt76.ko
    └── depends on: mt76.ko
```

## Core Data Structures

| Structure | Description |
|-----------|-------------|
| `mt76_dev` | Base device structure (all chipsets) |
| `mt76_phy` | PHY abstraction (supports multi-band) |
| `mt76_wcid` | Wireless Client ID (per-station/per-interface) |
| `mt76_queue` | DMA ring buffer descriptor |
| `mt792x_dev` | MT792x device state |
| `mt792x_vif` | Virtual interface state |
| `mt792x_sta` | Station state (MLO-aware) |

## Pages in This Section

<div class="grid cards" markdown>

-   :material-link-variant:{ .lg .middle } __Multi-Link Operation__

    ---

    WiFi 7 MLO support with up to 4 simultaneous links

    [:octicons-arrow-right-24: MLO docs](mlo.md)

-   :material-lock:{ .lg .middle } __Locking__

    ---

    Mutex patterns and lock ordering

    [:octicons-arrow-right-24: Locking guide](locking.md)

-   :material-chip:{ .lg .middle } __MCU Protocol__

    ---

    Firmware communication protocol

    [:octicons-arrow-right-24: MCU docs](mcu-protocol.md)

-   :material-wifi:{ .lg .middle } __Supported Chipsets__

    ---

    MT7925, MT7921, and related hardware

    [:octicons-arrow-right-24: Chipset info](chipsets.md)

</div>

## Key Design Patterns

### 1. Mutex Protection

All MCU operations must be protected by `dev->mt76.mutex`:

```c
mt792x_mutex_acquire(dev);
/* MCU operations here */
mt792x_mutex_release(dev);
```

!!! warning "Common Bug"
    Missing mutex protection around `ieee80211_iterate_active_interfaces()` callbacks that call MCU functions.

### 2. MLO Link State Management

Always check for NULL when accessing MLO links:

```c
struct mt792x_link_sta *mlink = mt792x_sta_to_link(msta, link_id);
if (!mlink)
    return -EINVAL;
```

### 3. RCU-Protected Access

MLO link configs are RCU-protected:

```c
struct mt792x_bss_conf *mconf = rcu_dereference_protected(
    mvif->link_conf[link_id],
    lockdep_is_held(&dev->mt76.mutex)
);
```

## Bus Abstraction

The module supports three bus types via `struct mt76_bus_ops`:

| Bus | Description | Used By |
|-----|-------------|---------|
| MMIO (PCIe) | Memory-mapped I/O | MT7925e, MT7915e |
| USB | USB control transfers | MT7925u, MT7921u |
| SDIO | SDIO commands | MT7921s |
