# Entry Points

Driver initialization flows and callback functions.

## Module Initialization

### PCI Driver Entry

**File:** `mt7925/pci.c`

```c
static struct pci_driver mt7925_pci_driver = {
    .name         = KBUILD_MODNAME,
    .id_table     = mt7925_pci_device_table,
    .probe        = mt7925_pci_probe,
    .remove       = mt7925_pci_remove,
    .driver.pm    = pm_ptr(&mt7925_pm_ops),
};

module_pci_driver(mt7925_pci_driver);
```

### Probe Sequence

```
mt7925_pci_probe()
├── pci_enable_device()
├── pci_request_regions()
├── pci_set_master()
├── mt792x_init_device()
│   ├── mt76_alloc_device()
│   ├── mt792x_init_wiphy()
│   └── ieee80211_alloc_hw()
├── mt7925_register_device()
│   ├── mt792x_register_device()
│   ├── mt7925_init_debugfs()
│   └── mt76_register_device()
└── ieee80211_register_hw()
```

---

## mac80211 Operations

### `mt7925_ops` Structure

**File:** `mt7925/main.c`

| Callback | Function | Description |
|----------|----------|-------------|
| `.tx` | `mt792x_tx()` | Packet transmission |
| `.start` | `mt7925_start()` | Hardware start |
| `.stop` | `mt7925_stop()` | Hardware stop |
| `.add_interface` | `mt792x_add_interface()` | VIF creation |
| `.remove_interface` | `mt792x_remove_interface()` | VIF removal |
| `.config` | `mt7925_config()` | Channel/bandwidth |
| `.configure_filter` | `mt7925_configure_filter()` | RX filters |
| `.bss_info_changed` | `mt7925_bss_info_changed()` | BSS config |
| `.sta_state` | `mt76_sta_state()` | Station state machine |
| `.sta_add` | `mt7925_mac_sta_add()` | Station add |
| `.sta_remove` | `mt7925_mac_sta_remove()` | Station remove |
| `.set_key` | `mt7925_set_key()` | Key management |
| `.remain_on_channel` | `mt7925_remain_on_channel()` | ROC |
| `.cancel_remain_on_channel` | `mt7925_cancel_remain_on_channel()` | Cancel ROC |
| `.hw_scan` | `mt7925_hw_scan()` | Hardware scan |
| `.cancel_hw_scan` | `mt7925_cancel_hw_scan()` | Cancel scan |
| `.change_vif_links` | `mt7925_change_vif_links()` | MLO links |
| `.change_sta_links` | `mt7925_change_sta_links()` | STA links |

---

## Key Entry Points

### Hardware Start

```c
int mt7925_start(struct ieee80211_hw *hw)
{
    struct mt792x_dev *dev = mt792x_hw_dev(hw);

    mt792x_mutex_acquire(dev);

    // Start hardware
    mt7925_mcu_set_mac(dev, 0, true, true);

    // Enable interrupts
    mt7925_irq_enable(dev, MT_INT_RX_DONE_ALL | MT_INT_TX_DONE_ALL);

    mt792x_mutex_release(dev);
    return 0;
}
```

### Station Add

```c
int mt7925_mac_sta_add(struct mt76_dev *mdev,
                       struct ieee80211_vif *vif,
                       struct ieee80211_sta *sta)
{
    // Allocate WCID
    // Initialize station state
    // Send MCU command
    return mt7925_mcu_sta_add(dev, vif, sta, true);
}
```

### Station Remove

```c
void mt7925_mac_sta_remove(struct mt76_dev *mdev,
                           struct ieee80211_vif *vif,
                           struct ieee80211_sta *sta)
{
    // Remove links
    mt7925_mac_sta_remove_links(dev, vif, sta, sta->valid_links);

    // Send MCU command
    mt7925_mcu_sta_add(dev, vif, sta, false);
}
```

### BSS Info Changed

```c
void mt7925_bss_info_changed(struct ieee80211_hw *hw,
                             struct ieee80211_vif *vif,
                             struct ieee80211_bss_conf *info,
                             u64 changed)
{
    mt792x_mutex_acquire(dev);

    if (changed & BSS_CHANGED_ASSOC)
        mt7925_mcu_sta_update(dev, vif, sta, info->assoc);

    if (changed & BSS_CHANGED_BEACON_INT)
        mt7925_mcu_set_beacon_filter(dev, vif);

    // Handle other changes...

    mt792x_mutex_release(dev);
}
```

---

## Interrupt Handler

**File:** `mt7925/pci.c`

```c
static irqreturn_t mt7925_irq_handler(int irq, void *dev_instance)
{
    struct mt792x_dev *dev = dev_instance;

    mt76_wr(dev, MT_WFDMA0_HOST_INT_ENA, 0);

    if (!test_bit(MT76_STATE_INITIALIZED, &dev->mphy.state))
        return IRQ_NONE;

    tasklet_schedule(&dev->mt76.irq_tasklet);
    return IRQ_HANDLED;
}
```

### Tasklet Processing

```
mt792x_irq_tasklet()
├── Process TX completions
├── Process RX
│   ├── mt76_dma_rx_poll()
│   └── mt7925_mac_rx_done()
└── Re-enable interrupts
```

---

## Power Management

### Suspend

```c
static int mt7925_pci_suspend(struct device *device)
{
    mt792x_mutex_acquire(dev);

    // Flush queues
    mt76_txq_schedule_all(&dev->mphy);

    // Enter WoW mode
    mt7925_mcu_set_wow(dev, true);

    // Stop hardware
    mt7925_stop(hw);

    mt792x_mutex_release(dev);
    return 0;
}
```

### Resume

```c
static int mt7925_pci_resume(struct device *device)
{
    mt792x_mutex_acquire(dev);

    // Restart hardware
    mt7925_start(hw);

    // Exit WoW mode
    mt7925_mcu_set_wow(dev, false);

    // Restore state
    mt7925_mcu_set_mac(dev, 0, true, true);

    mt792x_mutex_release(dev);
    return 0;
}
```

---

## MLO Entry Points

### Change VIF Links

```c
int mt7925_change_vif_links(struct ieee80211_hw *hw,
                            struct ieee80211_vif *vif,
                            u16 old_links, u16 new_links,
                            struct ieee80211_bss_conf *old[])
{
    // Remove old links
    for_each_set_bit(link_id, &removed_links, ...)
        mt7925_vif_link_remove(dev, vif, link_id);

    // Add new links
    for_each_set_bit(link_id, &added_links, ...)
        mt7925_vif_link_add(dev, vif, link_id);
}
```

### Change STA Links

```c
int mt7925_change_sta_links(struct ieee80211_hw *hw,
                            struct ieee80211_vif *vif,
                            struct ieee80211_sta *sta,
                            u16 old_links, u16 new_links)
{
    // Remove old link stations
    mt7925_mac_sta_remove_links(dev, vif, sta, removed_links);

    // Add new link stations
    mt7925_mac_sta_add_links(dev, vif, sta, added_links);
}
```
