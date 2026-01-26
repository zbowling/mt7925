# Multi-Link Operation (MLO)

MT7925 supports Wi-Fi 7 Multi-Link Operation (MLO), which allows a device to maintain multiple simultaneous links to an access point for increased throughput and reliability.

## Overview

| Feature | Value |
|---------|-------|
| Maximum Links | 4 (`IEEE80211_MLD_MAX_NUM_LINKS`) |
| Default Link | Link ID 0 (always present) |
| Additional Links | Link IDs 1-3 |

## Data Structures

### Virtual Interface (VIF)

```c
struct mt792x_vif {
    struct mt792x_bss_conf bss_conf;  // Default link (must be first)
    struct mt792x_bss_conf __rcu *link_conf[IEEE80211_MLD_MAX_NUM_LINKS];
    u16 valid_links;  // Bitmap of active links
    u8 deflink_id;    // Default link ID
};
```

- `bss_conf` - Default link (always present)
- `link_conf[]` - Additional links (RCU-protected)
- `valid_links` - Bitmap indicating which links are active

### Station (STA)

```c
struct mt792x_sta {
    struct mt792x_link_sta deflink;  // Default link (must be first)
    struct mt792x_link_sta __rcu *link[IEEE80211_MLD_MAX_NUM_LINKS];
    u16 valid_links;  // Bitmap of active links
    u8 deflink_id;    // Default link ID
};
```

- `deflink` - Default link state (always present)
- `link[]` - Additional link states (RCU-protected)
- Each link has its own WCID for hardware identification

### Link State

```c
struct mt792x_link_sta {
    struct mt76_wcid wcid;  // Hardware WCID (must be first)
    u32 airtime_ac[8];
    int ack_signal;
    struct mt792x_sta *sta;
};
```

## Link Access Functions

### Get Link State

```c
struct mt792x_link_sta *mt792x_sta_to_link(struct mt792x_sta *msta, u8 link_id);
```

!!! warning "Can Return NULL"
    This function can return NULL during link transitions. Always check before dereferencing.

### Get BSS Config

```c
struct mt792x_bss_conf *mt792x_vif_to_link(struct mt792x_vif *mvif, u8 link_id);
```

!!! warning "Can Return NULL"
    This function can return NULL during link transitions. Always check before dereferencing.

## Common MLO Patterns

### Iterating Over Links

```c
for_each_set_bit(i, &valid_links, IEEE80211_MLD_MAX_NUM_LINKS) {
    struct ieee80211_bss_conf *link_conf;
    struct mt792x_bss_conf *mconf;

    link_conf = mt792x_vif_to_bss_conf(vif, i);
    if (!link_conf)  // CRITICAL: Check for NULL
        continue;

    mconf = mt792x_vif_to_link(mvif, i);
    // Use mconf
}
```

### Accessing Link State

```c
struct mt792x_link_sta *mlink = mt792x_sta_to_link(msta, link_id);
if (!mlink)  // CRITICAL: Check for NULL
    return -EINVAL;

wcid = &mlink->wcid;
// Use wcid
```

## MLO Lifecycle

### Link Addition

Entry: `mt7925_change_vif_links()`

1. Allocate `mt792x_bss_conf` for new link
2. Initialize link state
3. Send MCU command to add link
4. Update `valid_links` bitmap

### Link Removal

Entry: `mt7925_change_vif_links()`

1. Send MCU command to remove link
2. Clear link from `valid_links` bitmap
3. RCU-synchronize before freeing
4. Free `mt792x_bss_conf`

### Link State Transitions

During MLO Roaming:

- Old link is torn down
- New link is added
- Transition period where links may be NULL

!!! danger "Critical"
    Always check for NULL during transitions to avoid kernel panics.

## Common MLO Bugs

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
for_each_set_bit(i, &valid_links, IEEE80211_MLD_MAX_NUM_LINKS) {
    bss_conf = mt792x_vif_to_bss_conf(vif, i);
    mt7925_mcu_uni_bss_ps(dev, bss_conf);  // MCU call without mutex!
}
```

**Fix:**
```c
mt792x_mutex_acquire(dev);
for_each_set_bit(i, &valid_links, IEEE80211_MLD_MAX_NUM_LINKS) {
    bss_conf = mt792x_vif_to_bss_conf(vif, i);
    if (!bss_conf)
        continue;
    mt7925_mcu_uni_bss_ps(dev, bss_conf);
}
mt792x_mutex_release(dev);
```

### Key Removal During Link Tear-down

**Bug Pattern:**
```c
// Link is torn down
// mac80211 requests key removal
// link_conf is NULL -> returns -EINVAL
```

**Fix (Patch 0012):**
```c
if (!link_conf || !mconf || !mlink) {
    // During MLO roaming, link may be torn down before key removal
    if (cmd != SET_KEY)
        return 0;  // Successfully removed (link already gone)
    return -EINVAL;
}
```

## 6GHz Considerations

6GHz band with MLO can trigger issues:

- Regulatory domain switching
- Channel availability differences between bands
- Firmware state machine issues during band transitions

### Workarounds

If you experience frequent issues with 6GHz MLO:

```bash
# Check current regulatory domain
iw reg get

# Set regulatory domain explicitly
sudo iw reg set US
```

Consider using 2.4GHz + 5GHz only if 6GHz causes problems.

## Testing MLO

### Requirements

- Wi-Fi 7 capable AP with MLO enabled
- MLO-enabled firmware on MT7925
- Multiple bands/channels available (2.4GHz, 5GHz, 6GHz)

### Verify MLO

```bash
# Check link count
iw dev wlan0 link
# Should show multiple links

# Check kernel logs
dmesg | grep -i "link\|mlo"
# Should show link addition/removal
```

## Related Patches

| Patch | Description |
|-------|-------------|
| 0005 | NULL checks for MLO operations |
| 0009 | Fix MLO roaming and ROC setup |
| 0012 | Fix key removal during MLO roaming |
