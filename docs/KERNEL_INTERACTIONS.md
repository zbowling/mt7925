# Kernel Subsystem Interactions

## Overview

This document describes how the MT7925 driver integrates with various Linux kernel subsystems, including mac80211, PCI, DMA, interrupts, and power management.

## mac80211 Integration

### Overview

mac80211 is the Linux kernel's software MAC (Media Access Control) implementation for IEEE 802.11 wireless devices. The MT7925 driver implements the `ieee80211_ops` interface to provide hardware-specific functionality.

### Operations Structure

**Location:** `mt7925/main.c:2240`

```c
const struct ieee80211_ops mt7925_ops = {
    .tx = mt792x_tx,
    .start = mt7925_start,
    .stop = mt792x_stop,
    .config = mt7925_config,
    .add_interface = mt792x_add_interface,
    .remove_interface = mt792x_remove_interface,
    .configure_filter = mt7925_configure_filter,
    .sta_add = mt7925_mac_sta_add,
    .sta_remove = mt7925_mac_sta_remove,
    // ... more operations
};
```

### Key mac80211 Structures

#### `struct ieee80211_hw`

**Purpose:** Represents the wireless hardware device.

**Allocation:** `mt76_alloc_device()` in `mt76/mac80211.c`

**Key Fields:**
- `priv` - Points to `struct mt76_phy`
- `wiphy` - Wireless PHY structure
- `queues` - TX queues

#### `struct ieee80211_vif`

**Purpose:** Represents a virtual interface (station, AP, etc.).

**Driver Private Data:**
```c
struct mt792x_vif {
    struct mt792x_bss_conf bss_conf;  // must be first
    // ... more fields
};
```

**Access Pattern:**
```c
struct mt792x_vif *mvif = (struct mt792x_vif *)vif->drv_priv;
```

#### `struct ieee80211_sta`

**Purpose:** Represents a station (peer device).

**Driver Private Data:**
```c
struct mt792x_sta {
    struct mt792x_link_sta deflink;  // must be first
    // ... more fields
};
```

**Access Pattern:**
```c
struct mt792x_sta *msta = (struct mt792x_sta *)sta->drv_priv;
```

#### `struct ieee80211_bss_conf`

**Purpose:** BSS (Basic Service Set) configuration for a link.

**MLO Support:**
- Non-MLO: Single `bss_conf` per VIF
- MLO: Multiple `bss_conf` structures (one per link)

**Access Pattern:**
```c
// Get BSS config for a link
struct ieee80211_bss_conf *link_conf = 
    rcu_dereference_protected(vif->link_conf[link_id],
                              lockdep_is_held(&dev->mt76.mutex));
```

### Registration Flow

1. **Allocate Hardware:** `mt76_alloc_device()`
2. **Initialize Wiphy:** `mt792x_init_wiphy()`
3. **Register Device:** `mt76_register_device()`

**Location:** `mt76/mac80211.c:2120`

```c
int mt76_register_device(struct mt76_dev *dev, bool vht,
                        struct ieee80211_rate *rates, int n_rates)
{
    struct ieee80211_hw *hw = dev->hw;
    
    // Set up supported bands
    // Register with mac80211
    ret = ieee80211_register_hw(hw);
    
    return ret;
}
```

### Operation Callbacks

#### `.start` - Hardware Start

**Function:** `mt7925_start()`

**Location:** `mt7925/main.c`

**Purpose:** Called when interface is brought up.

**Operations:**
- Enable hardware
- Start DMA
- Configure MAC

#### `.tx` - Packet Transmission

**Function:** `mt792x_tx()`

**Location:** `mt792x_core.c:80`

**Purpose:** Entry point for packet transmission.

See [CONTROL_FLOW.md](CONTROL_FLOW.md) for detailed TX flow.

#### `.config` - Configuration Changes

**Function:** `mt7925_config()`

**Location:** `mt7925/main.c`

**Purpose:** Handle channel, bandwidth, or power changes.

**Operations:**
- Update channel
- Update bandwidth
- Update TX power

#### `.add_interface` - Interface Creation

**Function:** `mt792x_add_interface()`

**Location:** `mt7925/main.c`

**Purpose:** Create a virtual interface (station, AP, etc.).

**Operations:**
- Allocate BSS config
- Configure MAC address
- Send MCU command to firmware

#### `.sta_add` - Station Association

**Function:** `mt7925_mac_sta_add()`

**Location:** `mt7925/main.c`

**Purpose:** Associate a station.

**Operations:**
- Allocate WCID
- Configure station in hardware
- Send MCU command

## PCI Subsystem Integration

### PCI Driver Structure

**Location:** `mt7925/pci.c:626`

```c
static struct pci_driver mt7925_pci_driver = {
    .name = KBUILD_MODNAME,
    .id_table = mt7925_pci_device_table,
    .probe = mt7925_pci_probe,
    .remove = mt7925_pci_remove,
    .driver = {
        .pm = &mt7925_pm_ops,
    },
};
```

### PCI Device Table

**Location:** `mt7925/pci.c:13`

```c
static const struct pci_device_id mt7925_pci_device_table[] = {
    { PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7925),
      .driver_data = (kernel_ulong_t)MT7925_FIRMWARE_WM },
    { PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x0717),  // RZ717
      .driver_data = (kernel_ulong_t)MT7925_FIRMWARE_WM },
    { },
};
```

### MMIO Operations

**Location:** `mt7925/pci.c:188`

The driver uses memory-mapped I/O for register access:

```c
static u32 mt7925_rr(struct mt76_dev *mdev, u32 offset)
{
    struct mt792x_dev *dev = container_of(mdev, struct mt792x_dev, mt76);
    u32 addr = __mt7925_reg_addr(dev, offset);
    return dev->bus_ops->rr(mdev, addr);
}
```

**Register Remapping:**
MT7925 uses a complex register remapping scheme to map physical addresses to MMIO addresses. See `mt7925_reg_map_l1()` and `mt7925_reg_map_l2()`.

### IRQ Handling

**Registration:** `mt7925_pci_probe:406`

```c
ret = devm_request_irq(mdev->dev, pdev->irq, mt792x_irq_handler,
                       IRQF_SHARED, KBUILD_MODNAME, dev);
```

**Handler:** `mt792x_irq_handler()`

**Location:** `mt792x_dma.c:11`

See [CONTROL_FLOW.md](CONTROL_FLOW.md) for interrupt flow details.

### Power Management

**Suspend:** `mt7925_pci_suspend()`

**Location:** `mt7925/pci.c:443`

**Resume:** `mt7925_pci_resume()`

**Location:** `mt7925/pci.c:500`

## DMA Subsystem

### DMA Ring Buffers

**Structure:** `struct mt76_queue`

**Location:** `mt76/dma.h`

**Purpose:** Represents a DMA ring buffer for TX or RX.

**Key Fields:**
- `desc` - DMA descriptors
- `entry` - Ring entries (SKBs)
- `head` - Producer index
- `tail` - Consumer index
- `ndesc` - Number of descriptors

### TX Queues

**Per-AC Queues:**
- `MT_TXQ_VO` - Voice
- `MT_TXQ_VI` - Video
- `MT_TXQ_BE` - Best Effort
- `MT_TXQ_BK` - Background

**MCU Queues:**
- `MT_MCUQ_WM` - Wireless MAC commands
- `MT_MCUQ_WA` - Wireless Assistant commands
- `MT_MCUQ_FWDL` - Firmware download

**Management Queues:**
- `MT_TXQ_BEACON` - Beacon frames
- `MT_TXQ_CAB` - Contention-free period frames

### RX Queues

**Data Queues:**
- `MT_RXQ_MAIN` - Main data RX
- `MT_RXQ_BAND1` - Band 1 RX (5GHz)
- `MT_RXQ_BAND2` - Band 2 RX (6GHz)

**MCU Queues:**
- `MT_RXQ_MCU` - MCU responses (WM)
- `MT_RXQ_MCU_WA` - MCU responses (WA)

### NAPI Integration

**Purpose:** Deferred interrupt processing for better performance.

**TX NAPI:**
```c
netif_napi_add_tx(dev->mt76.tx_napi_dev, &dev->mt76.tx_napi,
                  mt792x_poll_tx);
```

**RX NAPI:**
```c
netif_napi_add(dev->mt76.napi_dev, &dev->mt76.napi[MT_RXQ_MAIN],
               mt792x_rx_poll_complete);
```

**Scheduling:**
```c
napi_schedule(&dev->mt76.tx_napi);
napi_schedule(&dev->mt76.napi[MT_RXQ_MAIN]);
```

## Interrupt Subsystem

### Interrupt Types

1. **MSI/MSI-X:** Preferred for better performance
2. **Legacy INTx:** Fallback

**Allocation:** `mt7925_pci_probe:331`

```c
ret = pci_alloc_irq_vectors(pdev, 1, 1, PCI_IRQ_ALL_TYPES);
```

### Interrupt Masking

**Interrupt Sources:**
- TX completion
- RX data
- MCU responses
- Hardware errors

**Masking:**
```c
mt76_wr(dev, MT_INT_MASK_CSR, 0);  // Disable all
// Process interrupts
mt76_wr(dev, MT_INT_MASK_CSR, mask);  // Re-enable
```

## Power Management

### Runtime PM

**Purpose:** Allow device to enter low-power state when idle.

**Entry:** `mt7925_set_runtime_pm()`

**Location:** `mt7925/main.c:751`

**Operations:**
- Transfer control to MCU
- Device enters sleep
- Wake on packet arrival

**Critical:** Mutex protection required:
```c
mt792x_mutex_acquire(dev);
ieee80211_iterate_active_interfaces(hw, ..., mt7925_pm_interface_iter, dev);
mt792x_mutex_release(dev);
```

**Bug Fix:** Patch 0003 adds missing mutex protection.

### Suspend/Resume

**Suspend Entry:** `mt7925_pci_suspend()`

**Operations:**
1. Cancel work queues
2. Abort ROC
3. Transfer control to MCU
4. Disable interrupts
5. Save state

**Resume Entry:** `mt7925_pci_resume()`

**Operations:**
1. Enable interrupts
2. Transfer control from MCU
3. Restore state
4. Resume work queues

### WOWLAN (Wake-on-WLAN)

**Purpose:** Wake system from suspend on network activity.

**Configuration:** `mt76_connac_wowlan_support`

**Location:** `mt76_connac_mcu.h`

## RCU (Read-Copy-Update)

### RCU-Protected Structures

**MLO Link Configs:**
```c
struct mt792x_bss_conf __rcu *link_conf[IEEE80211_MLD_MAX_NUM_LINKS];
```

**MLO Link Stations:**
```c
struct mt792x_link_sta __rcu *link[IEEE80211_MLD_MAX_NUM_LINKS];
```

### RCU Access Patterns

**Protected Read:**
```c
rcu_read_lock();
link_conf = rcu_dereference(vif->link_conf[link_id]);
// Use link_conf
rcu_read_unlock();
```

**Protected Write (with mutex):**
```c
lockdep_assert_held(&dev->mt76.mutex);
link_conf = rcu_dereference_protected(vif->link_conf[link_id],
                                      lockdep_is_held(&dev->mt76.mutex));
```

## Work Queues

### Work Queue Types

1. **System Work Queue:** `schedule_work()`
2. **Delayed Work:** `schedule_delayed_work()`
3. **Per-Device Work:** `INIT_WORK()`

### Key Work Queues

**Reset Work:**
```c
INIT_WORK(&dev->reset_work, mt7925_mac_reset_work);
```

**Init Work:**
```c
INIT_WORK(&dev->init_work, mt7925_init_work);
```

**Power Save Work:**
```c
INIT_DELAYED_WORK(&dev->pm.ps_work, mt792x_pm_power_save_work);
```

**MLO PM Work:**
```c
INIT_DELAYED_WORK(&dev->mlo_pm_work, mt7925_mlo_pm_work);
```

## Mutex Usage

### Driver Mutex

**Location:** `dev->mt76.mutex`

**Purpose:** Protects MCU operations and driver state.

**Acquisition:**
```c
mt792x_mutex_acquire(dev);
// Protected operations
mt792x_mutex_release(dev);
```

**Critical Pattern:**
All MCU operations and `ieee80211_iterate_active_interfaces()` callbacks that call MCU functions must be protected by this mutex.

**Common Bugs:**
- Missing mutex around `ieee80211_iterate_active_interfaces()`
- Missing mutex around MCU calls
- Deadlock from nested mutex acquisition

## Related Documentation

- [ENTRY_POINTS.md](ENTRY_POINTS.md) - Initialization flows
- [CONTROL_FLOW.md](CONTROL_FLOW.md) - Runtime control flows
- [DATA_STRUCTURES.md](DATA_STRUCTURES.md) - Data structure details

