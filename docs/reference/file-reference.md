# File Reference

Organization of driver source files in the MT7925 driver.

## Directory Structure

```
drivers/net/wireless/mediatek/mt76/
├── mt76.h                 # Core data structures
├── mac80211.c             # mac80211 integration
├── dma.c, dma.h           # DMA management
├── mcu.c                  # MCU base
├── tx.c                   # TX path
├── agg-rx.c               # RX aggregation
├── mmio.c                 # MMIO operations
├── usb.c                  # USB support
├── sdio.c                 # SDIO support
├── pci.c                  # PCI support
│
├── mt76_connac_mcu.c/h    # Connac MCU protocol
├── mt76_connac_mac.c/h    # Connac MAC layer
├── mt76_connac3_mac.c/h   # Connac3 MAC (Wi-Fi 7)
│
├── mt792x_core.c          # MT792x core
├── mt792x_mac.c           # MT792x MAC
├── mt792x_dma.c           # MT792x DMA
├── mt792x.h               # MT792x structures
│
├── mt7925/                # MT7925 specific
│   ├── main.c             # mac80211 ops
│   ├── mac.c              # MAC processing
│   ├── mcu.c/h            # MCU commands
│   ├── pci.c              # PCI driver
│   ├── usb.c              # USB driver
│   └── init.c             # Initialization
│
└── mt7921/                # MT7921 specific
    └── ...
```

## Core Files

### mt76.h

Core data structures: `mt76_dev`, `mt76_phy`, `mt76_wcid`, `mt76_queue`

### mac80211.c

mac80211 integration:

- `mt76_sta_add()` / `mt76_sta_remove()` - Station management
- `mt76_set_channel()` - Channel configuration
- `mt76_register_device()` - Device registration

### dma.c

DMA ring management:

- `mt76_dma_tx_queue_skb()` - TX queue
- `mt76_dma_rx_poll()` - RX polling
- `mt76_dma_init()` - Initialization

### mcu.c

MCU base:

- `mt76_mcu_send_msg()` - Send MCU command
- `mt76_mcu_get_response()` - Get response

### tx.c

TX path:

- `mt76_tx()` - Main TX entry
- `mt76_txq_schedule()` - Queue scheduling

---

## MT792x Shared Files

### mt792x_core.c

Core functions shared by MT7921/MT7925:

- `mt792x_init_device()` - Device initialization
- `mt792x_register_device()` - Registration
- `mt792x_load_firmware()` - Firmware loading
- `mt792x_irq_handler()` - Interrupt handling

### mt792x_mac.c

MAC layer:

- `mt792x_tx()` - TX entry point
- `mt792x_mac_wtbl_update()` - WTBL updates
- `mt792x_get_antenna()` - Antenna configuration

### mt792x.h

MT792x data structures:

- `struct mt792x_dev` - Device state
- `struct mt792x_phy` - PHY state
- `struct mt792x_vif` - VIF state
- `struct mt792x_sta` - Station state

---

## MT7925 Specific Files

### mt7925/main.c

mac80211 operations (`mt7925_ops`):

| Function | Callback |
|----------|----------|
| `mt7925_start()` | `.start` |
| `mt7925_stop()` | `.stop` |
| `mt7925_config()` | `.config` |
| `mt7925_bss_info_changed()` | `.bss_info_changed` |
| `mt7925_change_vif_links()` | `.change_vif_links` |

### mt7925/mac.c

MAC processing:

- `mt7925_mac_sta_add()` - Add station
- `mt7925_mac_sta_remove()` - Remove station
- `mt7925_mac_link_sta_add()` - Add MLO link
- `mt7925_mac_link_sta_remove()` - Remove MLO link

### mt7925/mcu.c

MCU commands:

- `mt7925_mcu_sta_add()` - STA_REC_UPDATE
- `mt7925_mcu_add_bss_info()` - BSS_INFO_UPDATE
- `mt7925_mcu_set_roc()` - Remain-on-channel
- `mt7925_mcu_uni_bss_ps()` - Power save

### mt7925/pci.c

PCI driver:

- `mt7925_pci_probe()` - Device probe
- `mt7925_pci_remove()` - Device removal
- `mt7925_pci_suspend()` - Suspend
- `mt7925_pci_resume()` - Resume

### mt7925/init.c

Initialization:

- `mt7925_init_hardware()` - Hardware init
- `mt7925_init_thermal()` - Thermal management
- `mt7925_init_debugfs()` - Debugfs setup

---

## Connac Library Files

### mt76_connac_mcu.c

Shared MCU protocol:

- TLV encoding/decoding
- Common MCU commands
- Response parsing

### mt76_connac_mac.c

Shared MAC operations:

- TX descriptor setup
- RX descriptor parsing
- Rate control helpers

### mt76_connac3_mac.c

Wi-Fi 7 specific MAC:

- EHT rate handling
- MLO MAC helpers

---

## Key Functions by Category

### Station Management

| Function | File | Description |
|----------|------|-------------|
| `mt7925_mac_sta_add()` | `mt7925/mac.c` | Add station |
| `mt7925_mac_sta_remove()` | `mt7925/mac.c` | Remove station |
| `mt76_sta_remove()` | `mac80211.c` | Base removal |

### VIF Management

| Function | File | Description |
|----------|------|-------------|
| `mt792x_add_interface()` | `mt792x_core.c` | Add VIF |
| `mt792x_remove_interface()` | `mt792x_core.c` | Remove VIF |
| `mt7925_change_vif_links()` | `mt7925/main.c` | MLO links |

### MCU Operations

| Function | File | Description |
|----------|------|-------------|
| `mt7925_mcu_sta_add()` | `mt7925/mcu.c` | Send STA cmd |
| `mt7925_mcu_add_bss_info()` | `mt7925/mcu.c` | Send BSS cmd |
| `mt76_mcu_send_msg()` | `mcu.c` | Base send |

### Power Management

| Function | File | Description |
|----------|------|-------------|
| `mt7925_pci_suspend()` | `mt7925/pci.c` | Suspend |
| `mt7925_pci_resume()` | `mt7925/pci.c` | Resume |
| `mt792x_pm_power_save_work()` | `mt792x_core.c` | PS work |
