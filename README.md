<div align="center">

```
███╗   ███╗████████╗███████╗ █████╗ ██████╗ ███████╗
████╗ ████║╚══██╔══╝╚════██║██╔══██╗╚════██╗██╔════╝
██╔████╔██║   ██║       ██╔╝╚██████║ █████╔╝███████╗
██║╚██╔╝██║   ██║      ██╔╝  ╚═══██║██╔═══╝ ╚════██║
██║ ╚═╝ ██║   ██║      ██║   █████╔╝███████╗███████║
╚═╝     ╚═╝   ╚═╝      ╚═╝   ╚════╝ ╚══════╝╚══════╝
```

# Linux MT7921/MT7925 WiFi Driver Fixes

[![Patch Validation](https://img.shields.io/github/actions/workflow/status/zbowling/mt7925/validate-patches.yml?branch=main&label=patches&logo=linux&logoColor=white)](https://github.com/zbowling/mt7925/actions/workflows/validate-patches.yml)
[![DKMS Build](https://img.shields.io/github/actions/workflow/status/zbowling/mt7925/dkms-build-test.yml?branch=main&label=dkms%20build&logo=github)](https://github.com/zbowling/mt7925/actions/workflows/dkms-build-test.yml)
[![Latest Release](https://img.shields.io/github/v/release/zbowling/mt7925?logo=github&label=release)](https://github.com/zbowling/mt7925/releases/latest)
[![AUR Version](https://img.shields.io/aur/version/mt76-mt7925-dkms?logo=archlinux&logoColor=white&label=AUR)](https://aur.archlinux.org/packages/mt76-mt7925-dkms)
[![License](https://img.shields.io/badge/license-ISC%20%2F%20GPL--2.0-blue?logo=opensourceinitiative&logoColor=white)](LICENSE)
[![Kernel](https://img.shields.io/badge/kernel-6.17%2B-orange?logo=linux&logoColor=white)](https://kernel.org)
[![GitHub Stars](https://img.shields.io/github/stars/zbowling/mt7925?style=flat&logo=github)](https://github.com/zbowling/mt7925/stargazers)

**Fixes for kernel panics, deadlocks, and system hangs on MT7921/MT7925 WiFi cards**

[**📚 Documentation**](https://zbowling.github.io/mt7925) ·
[**🚀 Quick Start**](https://zbowling.github.io/mt7925/quick-start/) ·
[**📦 Releases**](https://github.com/zbowling/mt7925/releases) ·
[**🐛 Report Issue**](https://github.com/zbowling/mt7925/issues/new)

</div>

---

## The Problem

The MediaTek MT7921 and MT7925 WiFi drivers in stock Linux 6.8–6.19 kernels have several bugs that cause:

- **Kernel panics** (NULL pointer dereferences)
- **System hangs** (mutex deadlocks, processes stuck in D state)
- **WiFi drops** during network switching or suspend/resume

These issues are especially bad on WiFi 6E/7 setups with fast roaming, 6 GHz bands, or MLO enabled—often crashing every few minutes on affected hardware laptops and desktops

Hopefully these patches get integrated upstream soon and this project is no longer needed. Until then...

## Quick Install

### Manual / From Source

```bash
git clone https://github.com/zbowling/mt7925.git
cd mt7925/dkms
sudo ./install.sh
```

### Arch Linux (AUR)

```bash
# yay

yay -S mt76-mt7925-dkms
# paru

paru -S mt76-mt7925-dkms
```

### Debian / Ubuntu (Beta)

```bash
# Add repository
curl -1sLf 'https://dl.cloudsmith.io/public/mt76/packages/setup.deb.sh' | sudo -E bash

# Install
sudo apt update && sudo apt install mt76-mt7925-dkms
```

### Fedora / RHEL (Beta)

```bash
# Add repository
curl -1sLf 'https://dl.cloudsmith.io/public/mt76/packages/setup.rpm.sh' | sudo -E bash

# Install
sudo dnf install mt76-mt7925-dkms
```


> **Requires kernel 6.17+** — For older kernels, see [patch installation](https://zbowling.github.io/mt7925/installation/manual/).

## What's Included

| Component | Version | Description |
|-----------|---------|-------------|
| **DKMS Package** | v1.5.0 | Drop-in replacement for stock mt76 modules |
| **Patch Series** | v7 (6 patches) | For manual kernel patching |
| **Documentation** | [Website](https://zbowling.github.io/mt7925) | Architecture, debugging, crash analysis |

### Patch Summary (nbd168 Upstream)

6 patches targeting critical MLO stability bugs:

| # | Patch |
| --- | ------- |
| 1 | Fix double wcid initialization race condition |
| 2 | Add NULL pointer protection for MLO operations |
| 3 | Add mutex protection in critical paths |
| 4 | Add MCU command error handling in AMPDU actions |
| 5 | Add lockdep assertions for mutex verification |
| 6 | Fix MLO ROC setup error handling |

### DKMS Package Features

The DKMS package includes additional features beyond the upstream patches:

- **RSSI Monitor**: CQM threshold notifications via firmware events
- **CSA Support**: Handle AP-initiated channel switches
- **Debug Features**: Optional verbose logging (compile-time flag)

See [full patch list](https://zbowling.github.io/mt7925/patches/patch-list/) for details.

## Supported Hardware

- **MT7925** — WiFi 7 (802.11be) PCIe
- **MT7921** — WiFi 6E (802.11ax) PCIe/USB/SDIO

### Known Affected Systems

- Framework Desktop (AMD Ryzen AI Max 300)
- Framework Laptop 13/16 with MT7925
- Lenovo, Dell, ASUS, Acer laptops with MT7921/MT7925

## Supported Kernels

| Kernel | Status |
|--------|--------|
| 6.18.x | ✅ **Recommended** |
| 6.19-rc | ✅ Supported |
| 6.17.x | ✅ Supported (EOL) |
| < 6.17 | ⚠️ Use kernel patches |

## Documentation

Full documentation available at **[zbowling.github.io/mt7925](https://zbowling.github.io/mt7925)**

- [Installation Guide](https://zbowling.github.io/mt7925/installation/)
- [Known Issues & Workarounds](https://zbowling.github.io/mt7925/issues/)
- [Driver Architecture](https://zbowling.github.io/mt7925/architecture/)
- [Debugging Guide](https://zbowling.github.io/mt7925/developer/debugging/)
- [Contributing](https://zbowling.github.io/mt7925/contributing/)

## Upstream Status

Patches are being submitted upstream to:
- **linux-wireless** mailing list
- **nbd168/wireless** staging tree
- **OpenWRT mt76**

Track progress: [Upstream Status](https://zbowling.github.io/mt7925/patches/upstream-status/)

## Related Links

- [Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301)
- [Ubuntu Bug #2137291](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)
- [LKML Discussion](https://lore.kernel.org/all/CAA5_Hq7vNOy9oCGkkgyukq2OP=a5yL_3ZKBdmNtBXS+zp6byiQ@mail.gmail.com/T/#u)

## License

ISC AND GPL-2.0-only (dual licensed, same as upstream mt76)
