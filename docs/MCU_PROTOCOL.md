# MCU Communication Protocol

## Overview

The MCU (Microcontroller Unit) is firmware running on the WiFi chip that handles station management, power management, regulatory domain handling, and scan operations. This document describes the MCU communication protocol used by MT7925.

## MCU Architecture

### MCU Components

1. **WM (Wireless MAC)** - Main MAC firmware
2. **WA (Wireless Assistant)** - Assistant firmware for power management and other features
3. **N9** - Network processor

### MCU Queues

**TX Queues (Driver → MCU):**
- `MT_MCUQ_WM` - WM commands
- `MT_MCUQ_WA` - WA commands
- `MT_MCUQ_FWDL` - Firmware download

**RX Queues (MCU → Driver):**
- `MT_RXQ_MCU` - WM responses
- `MT_RXQ_MCU_WA` - WA responses

## Command Format

### Command Header

**Unified Command Format (Connac2/Connac3):**

**Location:** `mt76_connac_mcu.h:95`

```c
struct mt76_connac2_mcu_uni_txd {
    __le32 txd[8];           // Hardware descriptor
    
    __le16 len;              // Total length (not including txd)
    __le16 cid;              // Command ID
    
    u8 rsv;
    u8 pkt_type;             // Must be 0xa0 (cmd packet)
    u8 frag_n;               // Fragment number
    u8 seq;                  // Sequence number
    
    __le16 checksum;
    u8 s2d_index;            // Source to destination index
    u8 option;               // Command options
};
```

### Command Options

**Option Bits:**
- `BIT(0)` - `UNI_CMD_OPT_BIT_ACK` - Request firmware reply
- `BIT(1)` - `UNI_CMD_OPT_BIT_UNI_CMD` - Unified command (vs original)
- `BIT(2)` - `UNI_CMD_OPT_BIT_SET_QUERY` - SET (1) or QUERY (0)

### TLV Encoding

Commands use TLV (Type-Length-Value) encoding for data:

```c
struct tlv {
    __le16 tag;    // TLV type
    __le16 len;    // TLV length
    u8 data[];     // TLV data
};
```

**TLV Building:**
```c
struct tlv *tlv = mt76_connac_mcu_add_tlv(skb, TLV_TYPE, sizeof(data));
memcpy(tlv->data, &data, sizeof(data));
```

## Response Format

### Response Header

**Location:** `mt76_connac_mcu.h:117`

```c
struct mt76_connac2_mcu_rxd {
    __le32 rxd[6];           // Hardware descriptor
    
    __le16 len;              // Response length
    __le16 pkt_type_id;      // Packet type ID
    
    u8 eid;                  // Event ID
    u8 seq;                  // Sequence number
    u8 option;               // Response options
    u8 rsv;
    u8 ext_eid;              // Extended event ID
    u8 rsv1[2];
    u8 s2d_index;            // Source to destination index
    
    u8 tlv[];                // TLV data
};
```

### Event IDs

**Common Events:**
- `0x01` - `UNI_EVENT_ID_CMD_RESULT` - Command result
- `0x02` - `UNI_EVENT_ID_BSS_BEACON_LOSS` - Beacon loss
- `0x03` - `UNI_EVENT_ID_STA_STATISTICS` - Station statistics
- `0x04` - `UNI_EVENT_ID_MT_PATCH_SEM` - Patch semaphore event

## Common MCU Commands

### Station Management

#### STA_REC_UPDATE

**Command ID:** `MCU_WMWA_UNI_CMD(STA_REC_UPDATE)`

**Purpose:** Add, update, or remove station.

**TLV Types:**
- `STA_REC_BASIC` - Basic station info
- `STA_REC_HT` - HT capabilities
- `STA_REC_VHT` - VHT capabilities
- `STA_REC_HE` - HE capabilities
- `STA_REC_EHT` - EHT capabilities
- `STA_REC_HDR_TRANS` - Header translation
- `STA_REC_BA` - Block ACK
- `STA_REC_AMSDU` - AMSDU configuration

**Example:**
```c
int mt7925_mcu_sta_add(struct mt792x_dev *dev, struct ieee80211_vif *vif,
                       struct ieee80211_sta *sta, bool enable)
{
    struct sk_buff *skb;
    
    skb = __mt76_connac_mcu_alloc_sta_req(&dev->mt76, &mconf->mt76,
                                          &mlink->wcid,
                                          MT7925_STA_UPDATE_MAX_SIZE);
    
    // Add TLVs
    mt7925_mcu_sta_basic_tlv(skb, vif, sta, enable);
    mt7925_mcu_sta_phy_tlv(skb, vif, sta);
    // ... more TLVs
    
    return mt76_mcu_skb_send_msg(&dev->mt76, skb,
                                MCU_WMWA_UNI_CMD(STA_REC_UPDATE), true);
}
```

### BSS Management

#### BSS_INFO_UPDATE

**Command ID:** `MCU_WMWA_UNI_CMD(BSS_INFO_UPDATE)`

**Purpose:** Update BSS configuration.

**TLV Types:**
- `BSS_INFO_BCN_CONTENT` - Beacon content
- `BSS_INFO_BASIC` - Basic BSS info
- `BSS_INFO_OMAC` - OMAC (Operating MAC) info
- `BSS_INFO_BMC` - Broadcast/Multicast config

### Power Management

#### PM_POWER_CTRL

**Command ID:** `MCU_CMD(PM_POWER_CTRL)`

**Purpose:** Control power management state.

**Operations:**
- Enter sleep
- Wake from sleep
- Deep sleep control

### Scan Operations

#### SCAN_REQ

**Command ID:** `MCU_WMWA_UNI_CMD(SCAN_REQ)`

**Purpose:** Request scan operation.

**TLV Types:**
- `SCAN_REQ_CHANNEL` - Channel list
- `SCAN_REQ_SSID` - SSID list
- `SCAN_REQ_IE` - Information elements

## Command/Response Flow

### Sending a Command

**Location:** `mt76/mcu.c:72`

```c
int mt76_mcu_skb_send_and_get_msg(struct mt76_dev *dev, struct sk_buff *skb,
                                  int cmd, bool wait_resp,
                                  struct sk_buff **ret_skb)
{
    int ret, seq;
    
    mutex_lock(&dev->mcu.mutex);
    
    // Prepare message
    ret = dev->mcu_ops->mcu_skb_prepare_msg(dev, skb, cmd, &seq);
    
    // Send message
    ret = dev->mcu_ops->mcu_skb_send_msg(dev, skb, cmd, &seq);
    
    if (wait_resp) {
        // Wait for response
        skb = mt76_mcu_get_response(dev, expires);
        
        // Parse response
        ret = dev->mcu_ops->mcu_parse_response(dev, cmd, skb, seq);
    }
    
    mutex_unlock(&dev->mcu.mutex);
    return ret;
}
```

### Receiving a Response

**Location:** `mt7925/mcu.c` (chipset-specific)

```c
void mt7925_mcu_rx_event(struct mt76_dev *mdev, struct sk_buff *skb)
{
    struct mt792x_dev *dev = container_of(mdev, struct mt792x_dev, mt76);
    struct mt76_connac2_mcu_rxd *rxd = (struct mt76_connac2_mcu_rxd *)skb->data;
    u16 seq = rxd->seq;
    u8 eid = rxd->eid;
    
    // Find pending command by sequence number
    skb = idr_find(&dev->mt76.mcu.res_q, seq);
    
    if (skb) {
        // Process response
        mt76_mcu_parse_response(dev, cmd, skb, seq);
        // Wake waiting thread
        wake_up(&dev->mt76.mcu.wait);
    }
}
```

## Error Handling

### Timeout Handling

**Location:** `mt76/mcu.c:110`

If MCU doesn't respond within timeout:
```c
dev_err(dev->dev, "Message %04x (seq %d) timeout\n", cmd, seq);
```

**Common Timeouts:**
- Station management: 3 seconds
- Firmware operations: 5 seconds
- Power management: 1 second

### Retry Logic

**Location:** `mt76/mcu.c:115`

```c
if (retry++ < dev->mcu_ops->max_retry) {
    dev_err(dev->dev, "Retry message %08x (seq %d)\n", cmd, seq);
    // Retry sending
}
```

## Mutex Protection

**Critical:** All MCU operations must be protected by `dev->mt76.mutex`:

```c
mt792x_mutex_acquire(dev);
ret = mt7925_mcu_sta_add(dev, vif, sta, true);
mt792x_mutex_release(dev);
```

**Common Bug:** Missing mutex protection around `ieee80211_iterate_active_interfaces()` callbacks that call MCU functions.

## Sequence Numbers

**Purpose:** Match responses to commands.

**Allocation:**
```c
seq = ++dev->mcu.msg_seq & 0xff;
```

**Matching:**
```c
// Response contains sequence number
u16 seq = rxd->seq;

// Find pending command
skb = idr_find(&dev->mt76.mcu.res_q, seq);
```

## Command Examples

### Station Add

```c
// Allocate SKB
skb = __mt76_connac_mcu_alloc_sta_req(&dev->mt76, &mconf->mt76,
                                      &mlink->wcid,
                                      MT7925_STA_UPDATE_MAX_SIZE);

// Add basic TLV
mt7925_mcu_sta_basic_tlv(skb, vif, sta, true);

// Add PHY TLV
mt7925_mcu_sta_phy_tlv(skb, vif, sta);

// Send command
ret = mt76_mcu_skb_send_msg(&dev->mt76, skb,
                            MCU_WMWA_UNI_CMD(STA_REC_UPDATE), true);
```

### BSS Info Update

```c
// Allocate SKB
skb = __mt7925_mcu_alloc_bss_req(&dev->mt76, &mconf->mt76,
                                 MT7925_BSS_UPDATE_MAX_SIZE);

// Add basic TLV
mt7925_mcu_bss_basic_tlv(skb, vif, bss_conf, true);

// Send command
ret = mt76_mcu_skb_send_msg(&dev->mt76, skb,
                            MCU_WMWA_UNI_CMD(BSS_INFO_UPDATE), true);
```

## Related Documentation

- [CONTROL_FLOW.md](CONTROL_FLOW.md) - MCU communication flow
- [ARCHITECTURE.md](ARCHITECTURE.md) - Module architecture
- [DEBUGGING.md](DEBUGGING.md) - Debugging MCU issues

