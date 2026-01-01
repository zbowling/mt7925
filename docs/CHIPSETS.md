# MediaTek MT76 Chipset Reference

This document provides a comprehensive overview of all MediaTek Wi-Fi chipsets supported by the `mt76` driver, including their technical specifications, release dates, form factors, and key differences.

## Table of Contents

- [Chipset Families](#chipset-families)
- [Wi-Fi 4 Chipsets (802.11n)](#wi-fi-4-chipsets-80211n)
- [Wi-Fi 5 Chipsets (802.11ac)](#wi-fi-5-chipsets-80211ac)
- [Wi-Fi 6 Chipsets (802.11ax)](#wi-fi-6-chipsets-80211ax)
- [Wi-Fi 7 Chipsets (802.11be)](#wi-fi-7-chipsets-80211be)
- [Technical Comparison](#technical-comparison)
- [Driver Architecture by Chipset](#driver-architecture-by-chipset)

---

## Chipset Families

The `mt76` driver organizes chipsets into several families based on shared architecture:

1. **mt76x0** - Entry-level Wi-Fi 5 chipsets (MT7610E/U, MT7630E)
2. **mt76x2** - Mid-range Wi-Fi 5 chipsets (MT7612E, MT7602, MT7662)
3. **mt7603** - Wi-Fi 4 chipsets (MT7603E, MT7628)
4. **mt7615** - High-performance Wi-Fi 5 chipsets (MT7615, MT7622, MT7663)
5. **mt7915** - Wi-Fi 6 chipsets (MT7915, MT7916, MT7981, MT7986)
6. **mt7921** - Wi-Fi 6E chipsets (MT7920, MT7921, MT7922)
7. **mt7925** - Wi-Fi 7 chipsets (MT7925, RZ717)
8. **mt7996** - High-end Wi-Fi 7 chipsets (MT7996, MT7992, MT7990)

---

## Wi-Fi 4 Chipsets (802.11n)

### MT7603E / MT7628

**Specifications:**
- **Wi-Fi Standard:** 802.11b/g/n
- **MIMO Configuration:** 2T2R
- **Frequency Bands:** 2.4 GHz only
- **Max PHY Rate:** N300 (300 Mbps)
- **Interface:** PCIe (MT7603E) / SoC (MT7628)
- **Form Factor:** Mini PCIe card / Integrated SoC
- **Release Date:** ~2015
- **Kernel Support:** Linux 4.7+

**Key Features:**
- Cost-effective solution for 2.4 GHz-only applications
- MT7628 is an SoC variant commonly used in routers and IoT devices
- Dual-band support not available

**Use Cases:**
- Budget routers
- IoT devices
- Embedded systems requiring 2.4 GHz connectivity

**Driver Location:** `drivers/net/wireless/mediatek/mt76/mt7603/`

**Device IDs:**
- MT7603E: `0x7603`

---

## Wi-Fi 5 Chipsets (802.11ac)

### MT76x0 Family (MT7610E, MT7610U, MT7630E)

**Specifications:**
- **Wi-Fi Standard:** 802.11a/b/g/n/ac
- **MIMO Configuration:** 1T1R
- **Frequency Bands:** 2.4/5 GHz
- **Max PHY Rate:** AC433 (433 Mbps)
- **Interface:** PCIe (MT7610E, MT7630E) / USB (MT7610U)
- **Form Factor:** Mini PCIe card / USB dongle
- **Release Date:** ~2014
- **Kernel Support:** Linux 4.7+

**Key Features:**
- Entry-level Wi-Fi 5 solution
- Single-stream (1T1R) configuration limits throughput
- USB variant (MT7610U) for external adapters

**Use Cases:**
- Entry-level laptops
- USB Wi-Fi adapters
- Low-cost embedded systems

**Driver Location:** `drivers/net/wireless/mediatek/mt76/mt76x0/`

**Device IDs:**
- MT7610E: `0x7610`
- MT7630E: `0x7630`
- MT7650E: `0x7650`

### MT76x2 Family (MT7612E, MT7602, MT7662)

**Specifications:**
- **Wi-Fi Standard:** 802.11a/b/g/n/ac
- **MIMO Configuration:** 2T2R
- **Frequency Bands:** 2.4/5 GHz
- **Max PHY Rate:** AC1200 (1200 Mbps)
- **Interface:** PCIe (MT7612E, MT7602) / USB (MT7662U)
- **Form Factor:** Mini PCIe card / USB dongle
- **Release Date:** ~2014
- **Kernel Support:** Linux 4.7+

**Key Features:**
- Dual-stream (2T2R) configuration
- Better performance than MT76x0 family
- USB variant available

**Use Cases:**
- Mid-range laptops
- Desktop Wi-Fi cards
- USB adapters

**Driver Location:** `drivers/net/wireless/mediatek/mt76/mt76x2/`

**Device IDs:**
- MT7662: `0x7662`
- MT7612: `0x7612`
- MT7602: `0x7602`

### MT7615 / MT7622 / MT7663

**Specifications:**
- **Wi-Fi Standard:** 802.11a/b/g/n/ac
- **MIMO Configuration:** 4T4R (MT7615, MT7622) / 2T2R (MT7663)
- **Frequency Bands:** 2.4/5 GHz
- **Max PHY Rate:** AC3600 (MT7615) / AC1200 (MT7663)
- **Interface:** PCIe (MT7615, MT7663) / SoC (MT7622) / USB/SDIO (MT7663)
- **Form Factor:** Mini PCIe card / SoC / M.2 (MT7663)
- **Release Date:** ~2017-2020
- **Kernel Support:** Linux 5.2+ (MT7615), 5.7+ (MT7622), 5.8+ (MT7663)

**Key Features:**
- High-performance Wi-Fi 5 solution
- MT7615 offers 4x4 MIMO for maximum throughput
- MT7622 is an SoC variant for routers
- MT7663 supports multiple interfaces (PCIe/USB/SDIO) and includes Bluetooth

**Use Cases:**
- High-end laptops
- Enterprise access points
- Routers (MT7622)
- M.2 modules (MT7663)

**Driver Location:** `drivers/net/wireless/mediatek/mt76/mt7615/`

**Device IDs:**
- MT7615: `0x7615`
- MT7663: `0x7663`
- MT7611: `0x7611`

---

## Wi-Fi 6 Chipsets (802.11ax)

### MT7915 / MT7916 / MT7981 / MT7986

**Specifications:**
- **Wi-Fi Standard:** 802.11a/b/g/n/ac/ax (Wi-Fi 6)
- **MIMO Configuration:** 4T4R (MT7915, MT7986) / 2T2R (MT7916, MT7981)
- **Frequency Bands:** 2.4/5 GHz
- **Max PHY Rate:** AX6000 (MT7915, MT7986) / AX3000 (MT7916, MT7981)
- **Interface:** PCIe (MT7915, MT7916) / SoC (MT7981, MT7986)
- **Form Factor:** Mini PCIe card / Integrated SoC
- **Release Date:** ~2020-2022
- **Kernel Support:** Linux 5.9+ (MT7915/MT7916), 5.18+ (MT7981/MT7986)

**Marketing Names:**
- MT7915: Filogic 615
- MT7916: Filogic 630
- MT7981: Filogic 820
- MT7986: Filogic 830

**Key Features:**
- First MediaTek Wi-Fi 6 chipsets
- OFDMA support for improved efficiency
- Target Wake Time (TWT) for power savings
- MU-MIMO support
- MT798x series are SoC variants for routers

**Use Cases:**
- Wi-Fi 6 routers
- Mesh access points
- Enterprise networking equipment

**Driver Location:** `drivers/net/wireless/mediatek/mt76/mt7915/`

**Device IDs:**
- MT7915: `0x7915`
- MT7906: `0x7906`
- MT7916: `0x7916`
- MT790a: `0x790a`

### MT7921 Family (MT7920, MT7921, MT7922)

**Specifications:**
- **Wi-Fi Standard:** 802.11a/b/g/n/ac/ax (Wi-Fi 6/6E)
- **MIMO Configuration:** 2T2R
- **Frequency Bands:** 2.4/5/6 GHz (6 GHz for Wi-Fi 6E variants)
- **Max PHY Rate:** AX1800
- **Interface:** PCIe / USB / SDIO
- **Form Factor:** M.2 (NGFF) module
- **Release Date:** ~2020-2021
- **Kernel Support:** Linux 5.12+ (PCIe), 5.16+ (SDIO), 5.18+ (USB)

**Key Features:**
- Multi-interface support (PCIe/USB/SDIO)
- Wi-Fi 6E support (6 GHz band) on MT7921/MT7922
- Integrated Bluetooth 5.0+ LE
- Common in modern laptops
- Uses shared `mt792x` driver architecture

**Use Cases:**
- Modern laptops (Dell, Lenovo, Framework)
- Desktop Wi-Fi cards
- USB adapters
- SDIO modules for embedded systems

**Driver Location:** `drivers/net/wireless/mediatek/mt76/mt7921/`

**Device IDs:**
- MT7921: `0x7961`
- MT7922: `0x7922`
- MT7920: `0x0608`, `0x0616`, `0x7920`

**Firmware Files:**
- MT7921: `mediatek/WIFI_RAM_CODE_MT7961_1.bin`
- MT7922: `mediatek/WIFI_RAM_CODE_MT7922_1.bin`
- MT7920: `mediatek/WIFI_RAM_CODE_MT7961_1a.bin`

---

## Wi-Fi 7 Chipsets (802.11be)

### MT7925 / RZ717

**Specifications:**
- **Wi-Fi Standard:** 802.11a/b/g/n/ac/ax/be (Wi-Fi 7)
- **MIMO Configuration:** 2T2R
- **Frequency Bands:** 2.4/5/6 GHz
- **Max PHY Rate:** BE3600 (3600 Mbps)
- **Interface:** PCIe / USB
- **Form Factor:** M.2 (NGFF) module
- **Release Date:** ~2023
- **Kernel Support:** Linux 6.0+

**Key Features:**
- First MediaTek Wi-Fi 7 chipset
- Multi-Link Operation (MLO) support
- Enhanced High Throughput (EHT) features
- 320 MHz channel width support (where available)
- Integrated Bluetooth 5.3+
- Uses shared `mt792x` driver architecture with MT7921

**Known Issues:**
- MLO implementation has had stability issues (see patches in this repo)
- Firmware-related MCU timeouts during roaming
- Suspend/resume reliability issues

**Use Cases:**
- Next-generation laptops (Framework 13 AMD, etc.)
- High-performance Wi-Fi 7 adapters
- USB Wi-Fi 7 dongles

**Driver Location:** `drivers/net/wireless/mediatek/mt76/mt7925/`

**Device IDs:**
- MT7925: `0x7925`
- RZ717: `0x0717` (Framework-specific variant)

**Firmware Files:**
- `mediatek/mt7925/WIFI_RAM_CODE_MT7925_1_1.bin`
- `mediatek/mt7925/WIFI_MT7925_PATCH_MCU_1_1_hdr.bin`

**Related Documentation:**
- See `MLO.md` for Multi-Link Operation details
- See `KNOWN_ISSUES.md` for known firmware-related problems

### MT7996 Family (MT7996, MT7992, MT7990)

**Specifications:**
- **Wi-Fi Standard:** 802.11a/b/g/n/ac/ax/be (Wi-Fi 7)
- **MIMO Configuration:** 4T4R (MT7996) / 2T3R (MT7992, MT7990)
- **Frequency Bands:** 2.4/5/6 GHz (MT7996) / 2.4/5 GHz (MT7992, MT7990)
- **Max PHY Rate:** BE19000 (MT7996) / BE7200 (MT7992) / BE3600 (MT7990)
- **Interface:** PCIe
- **Form Factor:** Mini PCIe card
- **Release Date:** ~2024-2025
- **Kernel Support:** Linux 6.2+

**Marketing Names:**
- MT7996: Filogic 880/680
- MT7992: Filogic 860/660
- MT7990: Filogic 850/650

**Key Features:**
- High-end Wi-Fi 7 solution
- Tri-band support (MT7996)
- Advanced MLO capabilities
- Maximum throughput configurations
- Multiple device ID variants for different configurations

**Use Cases:**
- High-end Wi-Fi 7 routers
- Enterprise access points
- Mesh networking systems
- Professional networking equipment

**Driver Location:** `drivers/net/wireless/mediatek/mt76/mt7996/`

**Device IDs:**
- MT7996: `0x7990`, `0x7991`
- MT7992: `0x7992`, `0x799a`
- MT7990: `0x7993`, `0x799b`

**Firmware Files:**
- `mediatek/mt7996/mt7996_wa.bin`
- `mediatek/mt7996/mt7996_wm.bin`
- `mediatek/mt7996/mt7996_dsp.bin`
- `mediatek/mt7996/mt7996_rom_patch.bin`

---

## Technical Comparison

### Architecture Generations

| Generation | Chipsets | Driver Architecture | Key Features |
|------------|----------|---------------------|--------------|
| **Gen 1** | MT76x0, MT76x2, MT7603 | `mt76x0`, `mt76x2`, `mt7603` | Basic Wi-Fi 4/5, minimal MCU |
| **Gen 2** | MT7615 | `mt7615` | Enhanced MCU, better performance |
| **Gen 3** | MT7915, MT7921 | `mt7915`, `mt7921` | Wi-Fi 6, connac MCU protocol |
| **Gen 4** | MT7925, MT7996 | `mt7925`, `mt7996` | Wi-Fi 7, MLO, connac3 MCU protocol |

### MCU Protocol Evolution

1. **Legacy MCU** (mt76x0, mt76x2, mt7603)
   - Simple command/response protocol
   - Limited functionality

2. **Connac MCU** (mt7615, mt7915, mt7921)
   - Unified command format
   - Better error handling
   - Support for advanced features

3. **Connac3 MCU** (mt7925, mt7996)
   - Enhanced for Wi-Fi 7 features
   - MLO support
   - Improved power management

### Interface Support Matrix

| Chipset | PCIe | USB | SDIO | SoC |
|---------|------|-----|------|-----|
| MT76x0 | ✓ | ✓ | ✗ | ✗ |
| MT76x2 | ✓ | ✓ | ✗ | ✗ |
| MT7603 | ✓ | ✗ | ✗ | ✓ (MT7628) |
| MT7615 | ✓ | ✗ | ✗ | ✓ (MT7622) |
| MT7663 | ✓ | ✓ | ✓ | ✗ |
| MT7915 | ✓ | ✗ | ✗ | ✓ (MT798x) |
| MT7921 | ✓ | ✓ | ✓ | ✗ |
| MT7925 | ✓ | ✓ | ✗ | ✗ |
| MT7996 | ✓ | ✗ | ✗ | ✗ |

### Frequency Band Support

| Chipset | 2.4 GHz | 5 GHz | 6 GHz |
|---------|--------|------|-------|
| MT7603 | ✓ | ✗ | ✗ |
| MT76x0 | ✓ | ✓ | ✗ |
| MT76x2 | ✓ | ✓ | ✗ |
| MT7615 | ✓ | ✓ | ✗ |
| MT7915 | ✓ | ✓ | ✗ |
| MT7921 | ✓ | ✓ | ✓ (6E) |
| MT7925 | ✓ | ✓ | ✓ (7) |
| MT7996 | ✓ | ✓ | ✓ (7) |

---

## Driver Architecture by Chipset

### Shared Components

All chipsets share common infrastructure:

- **Core (`mt76/`)**: Base driver framework, DMA, USB/SDIO support
- **mac80211 Integration**: Common mac80211 callbacks and helpers
- **Debugfs**: Unified debugging interface
- **Testmode**: Common testmode framework

### Chipset-Specific Components

Each chipset family has its own directory with:

- **MAC Layer**: Frame processing, rate control
- **MCU Layer**: Firmware communication
- **PHY Layer**: Radio control, calibration
- **PCI/USB/SDIO**: Bus-specific initialization

### Code Sharing Patterns

1. **mt792x Family** (MT7921, MT7925)
   - Shared core in `mt792x_core.c`
   - Common MCU protocol
   - Chipset-specific MAC/PHY differences

2. **mt76x02 Family** (MT76x0, MT76x2)
   - Shared library in `mt76x02-lib`
   - Common register definitions
   - Unified USB support

3. **connac Family** (MT7615, MT7915, MT7921, MT7925)
   - Shared MCU protocol in `mt76_connac_mcu.c`
   - Common power management
   - Unified BSS/STA management

---

## Form Factor Details

### Mini PCIe Cards
- Standard laptop Wi-Fi card form factor
- M.2 Key A/E (2230, 1216 sizes)
- Used by: MT7615, MT7915, MT7996

### M.2 NGFF Modules
- Modern laptop form factor
- M.2 Key A/E (2230, 1216 sizes)
- Used by: MT7921, MT7925

### USB Dongles
- External adapter form factor
- USB 2.0/3.0 compatible
- Used by: MT7610U, MT7662U, MT7921U, MT7925U

### SoC Integration
- Integrated into system-on-chip
- No separate module required
- Used by: MT7628, MT7622, MT7981, MT7986

### SDIO Modules
- Embedded system form factor
- Common in IoT devices
- Used by: MT7663S, MT7921S

---

## Release Timeline

```
2014: MT76x0, MT76x2 (Wi-Fi 5 entry/mid-range)
2015: MT7603 (Wi-Fi 4)
2017: MT7615 (Wi-Fi 5 high-end)
2020: MT7915, MT7921 (Wi-Fi 6)
2021: MT7922 (Wi-Fi 6E)
2022: MT798x (Wi-Fi 6 SoC)
2023: MT7925 (Wi-Fi 7)
2024: MT7996 (Wi-Fi 7 high-end)
```

---

## References

- [Linux Wireless MT76 Documentation](https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html)
- [OpenWrt MT76 Repository](https://github.com/openwrt/mt76)
- [MediaTek Filogic Product Pages](https://www.mediatek.com/products/broadband-wifi)
- [Wi-Fi Alliance Standards](https://www.wi-fi.org/discover-wi-fi/wi-fi-certified)

---

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Overall driver architecture
- [MCU_PROTOCOL.md](MCU_PROTOCOL.md) - MCU communication details
- [MLO.md](MLO.md) - Multi-Link Operation specifics
- [FILE_REFERENCE.md](FILE_REFERENCE.md) - File organization by chipset

