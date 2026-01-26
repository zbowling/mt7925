# Reference

Technical reference documentation for the MT7925 driver.

## Pages in This Section

<div class="grid cards" markdown>

-   :material-database:{ .lg .middle } __Data Structures__

    ---

    Core driver data structures and their relationships

    [:octicons-arrow-right-24: Data structures](data-structures.md)

-   :material-file-tree:{ .lg .middle } __File Reference__

    ---

    Driver source file organization

    [:octicons-arrow-right-24: File reference](file-reference.md)

-   :material-call-split:{ .lg .middle } __Entry Points__

    ---

    Driver initialization and callback functions

    [:octicons-arrow-right-24: Entry points](entry-points.md)

</div>

## Quick Reference

### Module Hierarchy

```
mt7925e.ko
├── mt7925-common.ko
│   ├── mt792x-lib.ko
│   │   ├── mt76-connac-lib.ko
│   │   │   └── mt76.ko
│   │   └── mt76.ko
│   └── mt76.ko
└── mt76.ko
```

### Key Source Files

| File | Description |
|------|-------------|
| `mt7925/main.c` | mac80211 operations |
| `mt7925/mcu.c` | MCU command handlers |
| `mt7925/mac.c` | MAC layer processing |
| `mt7925/pci.c` | PCI probe/remove |
| `mt792x_core.c` | Shared core functions |
| `mac80211.c` | mac80211 integration |

### Core Structures

| Structure | Description |
|-----------|-------------|
| `mt76_dev` | Base device structure |
| `mt76_phy` | PHY abstraction |
| `mt76_wcid` | Wireless Client ID |
| `mt792x_dev` | MT792x device state |
| `mt792x_vif` | Virtual interface state |
| `mt792x_sta` | Station state (MLO-aware) |

### mac80211 Operations

Key callbacks in `mt7925_ops`:

| Callback | Function | Description |
|----------|----------|-------------|
| `.start` | `mt7925_start()` | Hardware start |
| `.tx` | `mt792x_tx()` | Packet transmission |
| `.config` | `mt7925_config()` | Channel/bandwidth config |
| `.add_interface` | `mt792x_add_interface()` | VIF creation |
| `.sta_add` | `mt7925_mac_sta_add()` | Station association |
| `.sta_remove` | `mt7925_mac_sta_remove()` | Station removal |
