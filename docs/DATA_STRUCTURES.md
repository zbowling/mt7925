# Data Structures

## Overview

This document describes the key data structures used in the MT7925 driver, their relationships, and memory layout.

## Core Structures

### `struct mt76_dev`

**Location:** `mt76/mt76.h`

**Purpose:** Base device structure used by all mt76 chipsets.

**Key Fields:**
```c
struct mt76_dev {
    struct device *dev;
    struct mt76_phy *phy;
    struct mt76_wcid *wcid;
    struct mt76_queue *q_tx[__MT_TXQ_MAX];
    struct mt76_queue *q_rx[__MT_RXQ_MAX];
    struct mt76_queue *q_mcu[__MT_MCUQ_MAX];
    struct mutex mutex;
    // ... more fields
};
```

**Relationship:**
- `mt792x_dev` contains `mt76_dev` as first member (union)
- All chipsets inherit from this structure

### `struct mt76_phy`

**Location:** `mt76/mt76.h`

**Purpose:** PHY abstraction supporting multi-band operation.

**Key Fields:**
```c
struct mt76_phy {
    struct ieee80211_hw *hw;
    struct mt76_dev *dev;
    struct mt76_sband sband_2g;
    struct mt76_sband sband_5g;
    struct mt76_sband sband_6g;
    unsigned long state;
    // ... more fields
};
```

**Relationship:**
- `mt792x_dev.mt76.phy` - Primary PHY
- `mt792x_phy.mt76` - Points back to `mt76_phy`

### `struct mt76_wcid`

**Location:** `mt76/mt76.h`

**Purpose:** Wireless Client ID - identifies stations/interfaces in hardware.

**Key Fields:**
```c
struct mt76_wcid {
    u16 idx;
    u8 hw_key_idx;
    u8 sta:1;
    u8 ext_phy:1;
    u8 amsdu:1;
    unsigned long flags;
    struct rate_info rate;
    // ... more fields
};
```

**Usage:**
- One WCID per station or interface
- Used in TX/RX paths to identify packets
- Indexed in hardware WTBL (Wireless Table)

## MT792x Structures

### `struct mt792x_dev`

**Location:** `mt792x.h:217`

**Purpose:** MT792x device state (shared by MT7921 and MT7925).

**Key Fields:**
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
    // ... more fields
};
```

**Memory Layout:**
```
mt792x_dev
├─ mt76_dev (union first member)
│  ├─ mt76_phy
│  ├─ mt76_wcid[]
│  └─ mt76_queue[]
├─ mt792x_phy
└─ pm (power management)
```

**Access Pattern:**
```c
struct mt792x_dev *dev = container_of(mdev, struct mt792x_dev, mt76);
```

### `struct mt792x_phy`

**Location:** `mt792x.h:152`

**Purpose:** MT792x PHY state.

**Key Fields:**
```c
struct mt792x_phy {
    struct mt76_phy *mt76;
    struct mt792x_dev *dev;
    u64 omac_mask;
    u16 noise;
    struct mt76_mib_stats mib;
    // ... more fields
};
```

**Relationship:**
- `dev->phy` - PHY state
- `dev->mt76.phy.priv` - Points to `mt792x_phy`

### `struct mt792x_vif`

**Location:** `mt792x.h:136`

**Purpose:** Virtual interface state (station, AP, etc.).

**Key Fields:**
```c
struct mt792x_vif {
    struct mt792x_bss_conf bss_conf;  // must be first
    struct mt792x_bss_conf __rcu *link_conf[IEEE80211_MLD_MAX_NUM_LINKS];
    struct mt792x_sta sta;
    struct mt792x_phy *phy;
    u16 valid_links;
    u8 deflink_id;
    // ... more fields
};
```

**MLO Support:**
- `link_conf[]` - Array of BSS configs (one per link)
- `valid_links` - Bitmap of active links
- `deflink_id` - Default link ID

**Access Pattern:**
```c
struct mt792x_vif *mvif = (struct mt792x_vif *)vif->drv_priv;
```

### `struct mt792x_bss_conf`

**Location:** `mt792x.h:128`

**Purpose:** BSS (Basic Service Set) configuration for a link.

**Key Fields:**
```c
struct mt792x_bss_conf {
    struct mt76_vif_link mt76;  // must be first
    struct mt792x_vif *vif;
    struct ewma_rssi rssi;
    struct ieee80211_tx_queue_params queue_params[IEEE80211_NUM_ACS];
    unsigned int link_id;
};
```

**MLO Usage:**
- Non-MLO: Single `bss_conf` in `mt792x_vif.bss_conf`
- MLO: Multiple `bss_conf` structures in `link_conf[]` array

**Access Pattern:**
```c
// Non-MLO
struct mt792x_bss_conf *mconf = &mvif->bss_conf;

// MLO
struct mt792x_bss_conf *mconf = mt792x_vif_to_link(mvif, link_id);
```

### `struct mt792x_sta`

**Location:** `mt792x.h:112`

**Purpose:** Station state (MLO-aware).

**Key Fields:**
```c
struct mt792x_sta {
    struct mt792x_link_sta deflink;  // must be first
    struct mt792x_link_sta __rcu *link[IEEE80211_MLD_MAX_NUM_LINKS];
    struct mt792x_vif *vif;
    u16 valid_links;
    u8 deflink_id;
};
```

**MLO Support:**
- `link[]` - Array of link states (one per link)
- `valid_links` - Bitmap of active links
- `deflink_id` - Default link ID

**Access Pattern:**
```c
struct mt792x_sta *msta = (struct mt792x_sta *)sta->drv_priv;
```

### `struct mt792x_link_sta`

**Location:** `mt792x.h:95`

**Purpose:** Per-link station state.

**Key Fields:**
```c
struct mt792x_link_sta {
    struct mt76_wcid wcid;  // must be first
    u32 airtime_ac[8];
    int ack_signal;
    struct ewma_avg_signal avg_ack_signal;
    struct mt792x_sta *sta;
    struct ieee80211_link_sta *pri_link;
};
```

**Relationship:**
- Contains `mt76_wcid` for hardware identification
- Linked to `mt792x_sta` via `sta` pointer

**Access Pattern:**
```c
struct mt792x_link_sta *mlink = mt792x_sta_to_link(msta, link_id);
if (!mlink)
    return -EINVAL;  // Link not available
```

## Structure Relationships

### Device Hierarchy

```
mt792x_dev
    │
    ├─► mt76_dev (core)
    │   ├─► mt76_phy
    │   │   ├─► ieee80211_hw
    │   │   └─► sband_2g, sband_5g, sband_6g
    │   │
    │   ├─► mt76_wcid[] (WCID table)
    │   │
    │   └─► mt76_queue[] (DMA rings)
    │       ├─► TX queues (per-AC + MCU)
    │       └─► RX queues (data + MCU)
    │
    ├─► mt792x_phy
    │   └─► mt792x_vif[] (virtual interfaces)
    │       ├─► mt792x_bss_conf (BSS config)
    │       └─► mt792x_sta (station state)
    │           └─► mt792x_link_sta[] (per-link state)
    │
    └─► mt76_connac_pm (power management)
```

### MLO Structure Relationships

```
ieee80211_vif (mac80211)
    │
    └─► mt792x_vif (driver private)
        │
        ├─► bss_conf (default link)
        │   └─► mt76_vif_link
        │
        └─► link_conf[] (MLO links)
            └─► mt792x_bss_conf (RCU-protected)
                └─► mt76_vif_link

ieee80211_sta (mac80211)
    │
    └─► mt792x_sta (driver private)
        │
        ├─► deflink (default link)
        │   └─► mt76_wcid
        │
        └─► link[] (MLO links)
            └─► mt792x_link_sta (RCU-protected)
                └─► mt76_wcid
```

## Helper Functions

### MLO Link Access

**Get Link State:**
```c
static inline struct mt792x_link_sta *
mt792x_sta_to_link(struct mt792x_sta *msta, u8 link_id)
{
    if (!ieee80211_vif_is_mld(vif) || link_id >= IEEE80211_LINK_UNSPECIFIED)
        return &msta->deflink;
    
    return rcu_dereference_protected(msta->link[link_id],
        lockdep_is_held(&msta->vif->phy->dev->mt76.mutex));
}
```

**Get BSS Config:**
```c
static inline struct mt792x_bss_conf *
mt792x_vif_to_link(struct mt792x_vif *mvif, u8 link_id)
{
    if (!ieee80211_vif_is_mld(vif) || link_id >= IEEE80211_LINK_UNSPECIFIED)
        return &mvif->bss_conf;
    
    return rcu_dereference_protected(mvif->link_conf[link_id],
        lockdep_is_held(&mvif->phy->dev->mt76.mutex));
}
```

**Critical:** These functions can return NULL during MLO link transitions. Always check for NULL before dereferencing.

## Memory Layout Considerations

### Structure Alignment

**First Member Rule:**
Many structures have a specific first member to enable container_of() usage:

```c
struct mt792x_vif {
    struct mt792x_bss_conf bss_conf;  // must be first
    // ...
};
```

This allows:
```c
struct mt792x_bss_conf *mconf = &mvif->bss_conf;
struct mt792x_vif *mvif = container_of(mconf, struct mt792x_vif, bss_conf);
```

### RCU Protection

**MLO Link Configs:**
```c
struct mt792x_bss_conf __rcu *link_conf[IEEE80211_MLD_MAX_NUM_LINKS];
```

**Access Patterns:**
- Read: `rcu_dereference()` or `rcu_dereference_protected()`
- Write: `rcu_assign_pointer()` (with mutex held)

**Critical:** Always use RCU-safe access patterns for MLO link configs.

## Common Bugs

### NULL Pointer Dereference

**Bug Pattern:**
```c
mlink = mt792x_sta_to_link(msta, link_id);
wcid = &mlink->wcid;  // Crash if mlink is NULL!
```

**Fix:**
```c
mlink = mt792x_sta_to_link(msta, link_id);
if (!mlink)
    return -EINVAL;
wcid = &mlink->wcid;
```

### Missing Mutex Protection

**Bug Pattern:**
```c
ieee80211_iterate_active_interfaces(hw, ..., callback, dev);
// callback calls MCU functions without mutex!
```

**Fix:**
```c
mt792x_mutex_acquire(dev);
ieee80211_iterate_active_interfaces(hw, ..., callback, dev);
mt792x_mutex_release(dev);
```

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Module architecture
- [MLO.md](MLO.md) - Multi-Link Operation details
- [NAVIGATION_GUIDE.md](NAVIGATION_GUIDE.md) - Code navigation techniques

