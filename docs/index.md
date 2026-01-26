# MT7925 WiFi Driver Fixes

Critical fixes for the MediaTek MT7925 WiFi driver that resolve kernel panics, mutex deadlocks, and system hangs on Framework Desktop systems and other hardware using this WiFi card.

<div class="grid cards" markdown>

-   :material-download:{ .lg .middle } __Quick Install__

    ---

    Install the patched driver via your package manager

    [:octicons-arrow-right-24: Get Started](getting-started/quick-start.md)

-   :material-bug:{ .lg .middle } __Known Issues__

    ---

    Common crashes and their workarounds

    [:octicons-arrow-right-24: View Issues](issues/known-issues.md)

-   :material-file-document:{ .lg .middle } __Patches__

    ---

    12 stability patches for kernel 6.17+

    [:octicons-arrow-right-24: Patch Details](patches/index.md)

-   :material-cog:{ .lg .middle } __Architecture__

    ---

    Deep dive into driver internals

    [:octicons-arrow-right-24: Learn More](architecture/index.md)

</div>

## Status

| Component | Version | Status |
|-----------|---------|--------|
| **Patches** | v7 (12 patches) | :material-check-circle:{ .green } Stable |
| **DKMS Package** | v1.4.1 | :material-check-circle:{ .green } Released |
| **Upstream** | In progress | :material-clock:{ .yellow } Pending review |

## Supported Hardware

- **MT7925** - WiFi 7 (802.11be) PCIe card
- **MT7921** - WiFi 6E (802.11ax) PCIe/USB/SDIO

## Supported Kernels

| Kernel | Status | Notes |
|--------|--------|-------|
| 6.17.x | :material-check-circle: Supported | Minimum version for DKMS |
| 6.18.x | :material-check-circle: Supported | Recommended |
| 6.19-rc | :material-check-circle: Supported | Release candidate |
| < 6.17 | :material-close-circle: Not supported | Use kernel patches instead |

## Quick Links

- [:material-github: GitHub Repository](https://github.com/zbowling/mt7925)
- [:material-bug: Report an Issue](https://github.com/zbowling/mt7925/issues/new)
- [:material-forum: Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301)
- [:material-ubuntu: Ubuntu Bug Tracker](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2137291)
