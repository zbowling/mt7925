# MCU Communication Protocol

The MCU (Microcontroller Unit) is firmware running on the WiFi chip that handles station management, power management, regulatory domain handling, and scan operations.

## MCU Architecture

### Components

| Component | Description |
|-----------|-------------|
| WM (Wireless MAC) | Main MAC firmware |
| WA (Wireless Assistant) | Assistant firmware for power management |
| N9 | Network processor |

### MCU Queues

**TX Queues (Driver → MCU):**

- `MT_MCUQ_WM` - WM commands
- `MT_MCUQ_WA` - WA commands
- `MT_MCUQ_FWDL` - Firmware download

**RX Queues (MCU → Driver):**

- `MT_RXQ_MCU` - WM responses
- `MT_RXQ_MCU_WA` - WA responses

## Command Format

### Unified Command Header

```c
struct mt76_connac2_mcu_uni_txd {
    __le32 txd[8];           // Hardware descriptor

    __le16 len;              // Total length
    __le16 cid;              // Command ID

    u8 rsv;
    u8 pkt_type;             // Must be 0xa0
    u8 frag_n;               // Fragment number
    u8 seq;                  // Sequence number

    __le16 checksum;
    u8 s2d_index;            // Source to destination
    u8 option;               // Command options
};
```

### Command Options

| Bit | Name | Description |
|-----|------|-------------|
| 0 | `UNI_CMD_OPT_BIT_ACK` | Request firmware reply |
| 1 | `UNI_CMD_OPT_BIT_UNI_CMD` | Unified command |
| 2 | `UNI_CMD_OPT_BIT_SET_QUERY` | SET (1) or QUERY (0) |

### TLV Encoding

Commands use TLV (Type-Length-Value) encoding:

```c
struct tlv {
    __le16 tag;    // TLV type
    __le16 len;    // TLV length
    u8 data[];     // TLV data
};
```

Building a TLV:

```c
struct tlv *tlv = mt76_connac_mcu_add_tlv(skb, TLV_TYPE, sizeof(data));
memcpy(tlv->data, &data, sizeof(data));
```

## Response Format

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
    u8 s2d_index;            // Source to destination

    u8 tlv[];                // TLV data
};
```

### Common Event IDs

| ID | Name | Description |
|----|------|-------------|
| 0x01 | `UNI_EVENT_ID_CMD_RESULT` | Command result |
| 0x02 | `UNI_EVENT_ID_BSS_BEACON_LOSS` | Beacon loss |
| 0x03 | `UNI_EVENT_ID_STA_STATISTICS` | Station statistics |

## Common MCU Commands

### Station Management

#### STA_REC_UPDATE

Add, update, or remove station.

**TLV Types:**

- `STA_REC_BASIC` - Basic station info
- `STA_REC_HT` - HT capabilities
- `STA_REC_VHT` - VHT capabilities
- `STA_REC_HE` - HE capabilities
- `STA_REC_EHT` - EHT capabilities
- `STA_REC_BA` - Block ACK
- `STA_REC_AMSDU` - AMSDU configuration

**Example:**

```c
skb = __mt76_connac_mcu_alloc_sta_req(&dev->mt76, &mconf->mt76,
                                      &mlink->wcid,
                                      MT7925_STA_UPDATE_MAX_SIZE);

mt7925_mcu_sta_basic_tlv(skb, vif, sta, enable);
mt7925_mcu_sta_phy_tlv(skb, vif, sta);

return mt76_mcu_skb_send_msg(&dev->mt76, skb,
                            MCU_WMWA_UNI_CMD(STA_REC_UPDATE), true);
```

### BSS Management

#### BSS_INFO_UPDATE

Update BSS configuration.

**TLV Types:**

- `BSS_INFO_BCN_CONTENT` - Beacon content
- `BSS_INFO_BASIC` - Basic BSS info
- `BSS_INFO_OMAC` - OMAC info
- `BSS_INFO_BMC` - Broadcast/Multicast config

### Power Management

#### PM_POWER_CTRL

Control power management state:

- Enter sleep
- Wake from sleep
- Deep sleep control

### Scan Operations

#### SCAN_REQ

Request scan operation.

**TLV Types:**

- `SCAN_REQ_CHANNEL` - Channel list
- `SCAN_REQ_SSID` - SSID list
- `SCAN_REQ_IE` - Information elements

## Command/Response Flow

### Sending a Command

```c
int mt76_mcu_skb_send_and_get_msg(struct mt76_dev *dev, struct sk_buff *skb,
                                  int cmd, bool wait_resp,
                                  struct sk_buff **ret_skb)
{
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

## Error Handling

### Timeout Handling

If MCU doesn't respond within timeout:

```
mt7925e 0000:c0:00.0: Message 00020002 (seq 12) timeout
```

**Common Timeouts:**

| Operation | Timeout |
|-----------|---------|
| Station management | 3 seconds |
| Firmware operations | 5 seconds |
| Power management | 1 second |

### Retry Logic

The driver automatically retries failed commands up to `max_retry` times.

## Mutex Protection

!!! danger "Critical"
    All MCU operations must be protected by `dev->mt76.mutex`

```c
mt792x_mutex_acquire(dev);
ret = mt7925_mcu_sta_add(dev, vif, sta, true);
mt792x_mutex_release(dev);
```

## Sequence Numbers

Purpose: Match responses to commands.

```c
// Allocation
seq = ++dev->mcu.msg_seq & 0xff;

// Matching
skb = idr_find(&dev->mt76.mcu.res_q, seq);
```

## Debugging MCU Issues

### Check MCU Log

```bash
cat /sys/kernel/debug/ieee80211/phy0/mt76/mcu
```

### Check Timeouts

```bash
dmesg | grep "timeout" | tail -20
```

### Common MCU Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Message timeout | Firmware hang or mutex deadlock | Our patches improve recovery |
| Invalid response | Protocol mismatch | Firmware update |
| Queue full | Too many pending commands | Rate limiting |
