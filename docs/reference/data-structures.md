# Data Structures

Key data structures used in the MT7925 driver and their relationships.

## Structure Hierarchy

```
mt792x_dev (chipset device)
├── mt76_dev (core device)
│   ├── mt76_phy (primary PHY)
│   │   ├── ieee80211_hw
│   │   └── sband_2g, sband_5g, sband_6g
│   ├── mt76_wcid[] (WCID table)
│   ├── mt76_queue[] (DMA rings)
│   └── bus_ops (MMIO/USB/SDIO)
├── mt792x_phy (chipset PHY)
│   └── mt792x_vif[] (virtual interfaces)
│       ├── mt792x_bss_conf
│       └── mt792x_sta
└── mt76_connac_pm (power management)
```

## Core Structures

### `struct mt76_dev`

Base device structure used by all mt76 chipsets.

**Location:** `mt76/mt76.h`

```c
struct mt76_dev {
    struct device *dev;
    struct mt76_phy *phy;
    struct mt76_wcid *wcid;
    struct mt76_queue *q_tx[__MT_TXQ_MAX];
    struct mt76_queue *q_rx[__MT_RXQ_MAX];
    struct mt76_queue *q_mcu[__MT_MCUQ_MAX];
    struct mutex mutex;
    // ...
};
```

| Field | Description |
|-------|-------------|
| `dev` | Linux device |
| `phy` | Primary PHY |
| `wcid` | WCID table |
| `q_tx` | TX DMA queues |
| `q_rx` | RX DMA queues |
| `q_mcu` | MCU queues |
| `mutex` | Main device mutex |

### `struct mt76_phy`

PHY abstraction supporting multi-band operation.

**Location:** `mt76/mt76.h`

```c
struct mt76_phy {
    struct ieee80211_hw *hw;
    struct mt76_dev *dev;
    struct mt76_sband sband_2g;
    struct mt76_sband sband_5g;
    struct mt76_sband sband_6g;
    unsigned long state;
    // ...
};
```

### `struct mt76_wcid`

Wireless Client ID - identifies stations/interfaces in hardware.

**Location:** `mt76/mt76.h`

```c
struct mt76_wcid {
    u16 idx;
    u8 hw_key_idx;
    u8 sta:1;
    u8 ext_phy:1;
    u8 amsdu:1;
    unsigned long flags;
    struct rate_info rate;
    // ...
};
```

**Usage:**

- One WCID per station or interface
- Used in TX/RX paths to identify packets
- Indexed in hardware WTBL (Wireless Table)

---

## MT792x Structures

### `struct mt792x_dev`

MT792x device state (shared by MT7921 and MT7925).

**Location:** `mt792x.h`

```c
struct mt792x_dev {
    union {
        struct mt76_dev mt76;  // must be first
        struct mt76_phy mphy;
    };
    struct mt792x_phy phy;
    const struct mt76_bus_ops *bus_ops;
    struct mt76_connac_pm pm;
    const struct mt792x_hif_ops *hif_ops;
    // ...
};
```

**Access Pattern:**

```c
struct mt792x_dev *dev = container_of(mdev, struct mt792x_dev, mt76);
```

### `struct mt792x_phy`

MT792x PHY state.

**Location:** `mt792x.h`

```c
struct mt792x_phy {
    struct mt76_phy *mt76;
    struct mt792x_dev *dev;
    u64 omac_mask;
    u16 noise;
    struct mt76_mib_stats mib;
    // ...
};
```

### `struct mt792x_vif`

Virtual interface state (station, AP, etc.).

**Location:** `mt792x.h`

```c
struct mt792x_vif {
    struct mt792x_bss_conf bss_conf;  // Default link
    struct mt792x_bss_conf __rcu *link_conf[IEEE80211_MLD_MAX_NUM_LINKS];
    u16 valid_links;
    u8 deflink_id;
    struct mt792x_phy *phy;
    // ...
};
```

### `struct mt792x_sta`

Station state (MLO-aware).

**Location:** `mt792x.h`

```c
struct mt792x_sta {
    struct mt792x_link_sta deflink;  // Default link
    struct mt792x_link_sta __rcu *link[IEEE80211_MLD_MAX_NUM_LINKS];
    u16 valid_links;
    u8 deflink_id;
    // ...
};
```

### `struct mt792x_link_sta`

Per-link station state.

**Location:** `mt792x.h`

```c
struct mt792x_link_sta {
    struct mt76_wcid wcid;  // must be first
    u32 airtime_ac[8];
    int ack_signal;
    struct mt792x_sta *sta;
};
```

---

## Access Functions

### VIF Access

```c
// Get driver VIF from mac80211 VIF
struct mt792x_vif *mvif = (struct mt792x_vif *)vif->drv_priv;

// Get BSS config for link
struct mt792x_bss_conf *mconf = mt792x_vif_to_link(mvif, link_id);
```

### Station Access

```c
// Get driver STA from mac80211 STA
struct mt792x_sta *msta = (struct mt792x_sta *)sta->drv_priv;

// Get link state
struct mt792x_link_sta *mlink = mt792x_sta_to_link(msta, link_id);
```

### Device Access

```c
// Get mt792x_dev from mt76_dev
struct mt792x_dev *dev = container_of(mdev, struct mt792x_dev, mt76);

// Get mt76_dev from mt792x_dev
struct mt76_dev *mdev = &dev->mt76;
```

---

## Memory Layout

### mt792x_dev Layout

```
+------------------+
| mt76_dev (union) |  <- First member for container_of()
|   mutex          |
|   phy            |
|   wcid[]         |
|   q_tx[], q_rx[] |
+------------------+
| mt792x_phy       |
|   dev            |
|   noise          |
+------------------+
| pm               |  <- Power management state
+------------------+
```

### mt792x_vif Layout (MLO)

```
+------------------+
| bss_conf         |  <- Default link (always present)
+------------------+
| link_conf[0]     |  -> RCU pointer to additional link
| link_conf[1]     |
| link_conf[2]     |
| link_conf[3]     |
+------------------+
| valid_links      |  <- Bitmap of active links
| deflink_id       |
+------------------+
```

---

## RCU Considerations

MLO link arrays are RCU-protected:

```c
// Safe read access
rcu_read_lock();
struct mt792x_bss_conf *mconf = rcu_dereference(mvif->link_conf[link_id]);
if (mconf) {
    // use mconf
}
rcu_read_unlock();

// Protected access (with mutex held)
struct mt792x_bss_conf *mconf = rcu_dereference_protected(
    mvif->link_conf[link_id],
    lockdep_is_held(&dev->mt76.mutex)
);
```
