# Supported Chipsets

Comprehensive overview of MediaTek Wi-Fi chipsets supported by the mt76 driver.

## Chipset Families

| Family | Chipsets | Wi-Fi Standard | Description |
|--------|----------|----------------|-------------|
| mt7921 | MT7920, MT7921, MT7922 | Wi-Fi 6E | Client devices |
| mt7925 | MT7925, RZ717 | Wi-Fi 7 | Client devices (this project) |
| mt7915 | MT7915, MT7916 | Wi-Fi 6 | Access points |
| mt7996 | MT7996, MT7992 | Wi-Fi 7 | High-end AP |

## MT7925 (Wi-Fi 7)

| Specification | Value |
|---------------|-------|
| **Wi-Fi Standard** | 802.11a/b/g/n/ac/ax/be |
| **MIMO** | 2T2R |
| **Frequency Bands** | 2.4/5/6 GHz |
| **Max PHY Rate** | BE3600 (3600 Mbps) |
| **Interface** | PCIe / USB |
| **Form Factor** | M.2 (NGFF) |
| **Kernel Support** | Linux 6.0+ |

### Features

- :material-check: Multi-Link Operation (MLO)
- :material-check: Enhanced High Throughput (EHT)
- :material-check: 320 MHz channel width (where available)
- :material-check: Integrated Bluetooth 5.3+

### Device IDs

| ID | Device |
|----|--------|
| `0x7925` | MT7925 |
| `0x0717` | RZ717 (Framework variant) |

### Firmware Files

- `mediatek/mt7925/WIFI_RAM_CODE_MT7925_1_1.bin`
- `mediatek/mt7925/WIFI_MT7925_PATCH_MCU_1_1_hdr.bin`

### Known Issues

!!! warning "Stability Issues"
    The MT7925 has known stability issues that this project addresses. See [Known Issues](../issues/known-issues.md).

---

## MT7921 Family (Wi-Fi 6E)

| Specification | Value |
|---------------|-------|
| **Wi-Fi Standard** | 802.11a/b/g/n/ac/ax |
| **MIMO** | 2T2R |
| **Frequency Bands** | 2.4/5/6 GHz |
| **Max PHY Rate** | AX1800 |
| **Interface** | PCIe / USB / SDIO |
| **Kernel Support** | Linux 5.12+ |

### Device IDs

| ID | Device |
|----|--------|
| `0x7961` | MT7921 |
| `0x7922` | MT7922 |
| `0x7920` | MT7920 |

### Common Usage

- Modern laptops (Dell, Lenovo, Framework)
- Desktop Wi-Fi cards
- USB adapters

---

## Technical Comparison

### Architecture Generations

| Generation | Chipsets | Key Features |
|------------|----------|--------------|
| Gen 3 | MT7915, MT7921 | Wi-Fi 6, connac MCU |
| Gen 4 | MT7925, MT7996 | Wi-Fi 7, MLO, connac3 MCU |

### Interface Support

| Chipset | PCIe | USB | SDIO |
|---------|------|-----|------|
| MT7921 | :material-check: | :material-check: | :material-check: |
| MT7925 | :material-check: | :material-check: | :material-close: |
| MT7996 | :material-check: | :material-close: | :material-close: |

### Band Support

| Chipset | 2.4 GHz | 5 GHz | 6 GHz |
|---------|---------|-------|-------|
| MT7921 | :material-check: | :material-check: | :material-check: (6E) |
| MT7925 | :material-check: | :material-check: | :material-check: (7) |

---

## Driver Architecture

### Shared Components

MT7921 and MT7925 share common infrastructure:

- Core in `mt792x_core.c`
- Common MCU protocol
- Unified DMA handling
- Shared power management

### Chipset-Specific Code

| Directory | Purpose |
|-----------|---------|
| `mt7921/` | MT7921-specific MAC, MCU, init |
| `mt7925/` | MT7925-specific MAC, MCU, init |
| `mt792x_*.c` | Shared library code |

---

## Form Factors

### M.2 NGFF Modules

Modern laptop form factor used by MT7921 and MT7925.

- M.2 Key A/E
- Sizes: 2230, 1216

### USB Dongles

External adapter form factor.

- USB 2.0/3.0 compatible
- MT7921U, MT7925U variants

---

## References

- [Linux Wireless MT76 Documentation](https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html)
- [OpenWrt MT76 Repository](https://github.com/openwrt/mt76)
- [MediaTek Filogic Products](https://www.mediatek.com/products/broadband-wifi)
