# Multi-Link Operation (MLO)

## Overview

MT7925 supports Wi-Fi 7 Multi-Link Operation (MLO), which allows a device to maintain multiple simultaneous links to an access point for increased throughput and reliability.

## MLO Architecture

### Link Structure

**Maximum Links:** `IEEE80211_MLD_MAX_NUM_LINKS` (typically 4)

**Link IDs:**
- `0` - Default link (always present)
- `1-3` - Additional links

### Data Structures

#### Virtual Interface (VIF)

**Location:** `mt792x.h:136`

```c
struct mt792x_vif {
    struct mt792x_bss_conf bss_conf;  // Default link (must be first)
    struct mt792x_bss_conf __rcu *link_conf[IEEE80211_MLD_MAX_NUM_LINKS];
    u16 valid_links;  // Bitmap of active links
    u8 deflink_id;    // Default link ID
};
```

**Key Points:**
- `bss_conf` - Default link (always present)
- `link_conf[]` - Additional links (RCU-protected)
- `valid_links` - Bitmap indicating which links are active

#### Station (STA)

**Location:** `mt792x.h:112`

```c
struct mt792x_sta {
    struct mt792x_link_sta deflink;  // Default link (must be first)
    struct mt792x_link_sta __rcu *link[IEEE80211_MLD_MAX_NUM_LINKS];
    u16 valid_links;  // Bitmap of active links
    u8 deflink_id;    // Default link ID
};
```

**Key Points:**
- `deflink` - Default link state (always present)
- `link[]` - Additional link states (RCU-protected)
- Each link has its own WCID for hardware identification

#### Link State

**Location:** `mt792x.h:95`

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

**Function:** `mt792x_sta_to_link()`

**Location:** `mt792x.h:280`

```c
static inline struct mt792x_link_sta *
mt792x_sta_to_link(struct mt792x_sta *msta, u8 link_id)
{
    struct ieee80211_vif *vif;
    
    vif = container_of((void *)msta->vif, struct ieee80211_vif, drv_priv);
    
    // Non-MLO or invalid link ID -> return default link
    if (!ieee80211_vif_is_mld(vif) || link_id >= IEEE80211_LINK_UNSPECIFIED)
        return &msta->deflink;
    
    // MLO -> return link from array (RCU-protected)
    return rcu_dereference_protected(msta->link[link_id],
        lockdep_is_held(&msta->vif->phy->dev->mt76.mutex));
}
```

**Critical:** This function can return NULL during link transitions. Always check for NULL before dereferencing.

### Get BSS Config

**Function:** `mt792x_vif_to_link()`

**Location:** `mt792x.h:262`

```c
static inline struct mt792x_bss_conf *
mt792x_vif_to_link(struct mt792x_vif *mvif, u8 link_id)
{
    struct ieee80211_vif *vif;
    struct mt792x_bss_conf *bss_conf;
    
    vif = container_of((void *)mvif, struct ieee80211_vif, drv_priv);
    
    // Non-MLO or invalid link ID -> return default BSS config
    if (!ieee80211_vif_is_mld(vif) || link_id >= IEEE80211_LINK_UNSPECIFIED)
        return &mvif->bss_conf;
    
    // MLO -> return link config from array (RCU-protected)
    bss_conf = rcu_dereference_protected(mvif->link_conf[link_id],
                                         lockdep_is_held(&mvif->phy->dev->mt76.mutex));
    
    // Fallback to default if link not available
    return bss_conf ? bss_conf : &mvif->bss_conf;
}
```

**Critical:** This function can return NULL during link transitions. Always check for NULL before dereferencing.

### Get mac80211 BSS Config

**Function:** `mt792x_vif_to_bss_conf()`

**Location:** `mt792x.h:304`

```c
static inline struct ieee80211_bss_conf *
mt792x_vif_to_bss_conf(struct ieee80211_vif *vif, unsigned int link_id)
{
    // Non-MLO -> return default BSS config
    if (!ieee80211_vif_is_mld(vif) || link_id >= IEEE80211_LINK_UNSPECIFIED)
        return &vif->bss_conf;
    
    // MLO -> return link config from mac80211 (RCU-protected)
    return link_conf_dereference_protected(vif, link_id);
}
```

**Critical:** This function can return NULL during link transitions. Always check for NULL before dereferencing.

## Common MLO Patterns

### Iterating Over Links

**Pattern:**
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

**Common Bug:** Missing NULL check causes kernel panic during link transitions.

### Accessing Link State

**Pattern:**
```c
struct mt792x_link_sta *mlink = mt792x_sta_to_link(msta, link_id);
if (!mlink)  // CRITICAL: Check for NULL
    return -EINVAL;  // or continue, depending on context

wcid = &mlink->wcid;
// Use wcid
```

**Common Bug:** Dereferencing `mlink` without NULL check causes kernel panic.

## MLO Lifecycle

### Link Addition

**Entry:** `mt7925_change_vif_links()`

**Location:** `mt7925/main.c`

**Operations:**
1. Allocate `mt792x_bss_conf` for new link
2. Initialize link state
3. Send MCU command to add link
4. Update `valid_links` bitmap

### Link Removal

**Entry:** `mt7925_change_vif_links()`

**Location:** `mt7925/main.c`

**Operations:**
1. Send MCU command to remove link
2. Clear link from `valid_links` bitmap
3. RCU-synchronize before freeing
4. Free `mt792x_bss_conf`

### Link State Transitions

**During MLO Roaming:**
- Old link is torn down
- New link is added
- Transition period where links may be NULL

**Critical:** Always check for NULL during transitions.

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

**Patches:**
- 0001 - NULL checks in `mt7925_vif_connect_iter()`
- 0014 - NULL checks in MCU functions

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

**Patches:**
- 0003 - Mutex protection in `mt7925_mlo_pm_work()`

### Key Removal During Link Tear-down

**Bug Pattern:**
```c
// Link is torn down
// mac80211 requests key removal
// link_conf is NULL -> returns -EINVAL
```

**Fix:**
```c
if (!link_conf || !mconf || !mlink) {
    // During MLO roaming, link may be torn down before key removal
    if (cmd != SET_KEY)
        return 0;  // Successfully removed (link already gone)
    return -EINVAL;
}
```

**Patches:**
- 0012 - Key removal fix during MLO roaming

## MLO-Specific MCU Commands

### MLO ROC (Remain-on-Channel)

**Command:** `mt7925_mcu_set_mlo_roc()`

**Location:** `mt7925/mcu.c:1337`

**Purpose:** Set up ROC on multiple links simultaneously.

**Bug Fix:** Patch 0013 adds NULL checks for link configs and channels.

### MLO Power Save

**Command:** `mt7925_mcu_uni_bss_ps()`

**Location:** `mt7925/mcu.c:1527`

**Purpose:** Configure power save state for MLO links.

**Critical:** Must be called with mutex held.

## Testing MLO

### Enable MLO

**Requirements:**
- Wi-Fi 7 capable AP
- MLO-enabled firmware
- Multiple bands/channels available

### Verify MLO

**Check link count:**
```bash
iw dev wlp192s0 link
# Should show multiple links
```

**Check kernel logs:**
```bash
dmesg | grep -i "link\|mlo"
# Should show link addition/removal
```

## Related Documentation

- [DATA_STRUCTURES.md](DATA_STRUCTURES.md) - MLO data structures
- [CONTROL_FLOW.md](CONTROL_FLOW.md) - MLO control flows
- [DEBUGGING.md](DEBUGGING.md) - Debugging MLO issues

