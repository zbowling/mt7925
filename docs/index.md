# Linux MT7921/MT7925 WiFi Driver Fixes

The MediaTek MT7921 and MT7925 WiFi drivers in stock Linux 6.8–6.19 kernels have several bugs that can lead to kernel panics (NULL pointer dereferences), race conditions, mutex deadlocks, and other issues that can hang systems using these WiFi cards.

These issues are exacerbated in certain WiFi environments, especially when:

- using multi-AP setups with WiFi 6E/7 (or fast roaming enabled)
- using 6 GHz frequencies with APs that allow higher transmit power in certain regulatory domains
- using WiFi 7 environments with MLO enabled

## About this Project

This project exists to provide fixes for the issues I can solve in the kernel, and to make those fixes as easy to install as possible while I continue working with MediaTek to get these patches upstream so future kernels no longer have these bugs.

I can fix issues in the Linux kernel driver, but not the firmware running on the WiFi chip. My original goal was to prevent kernel driver bugs from crashing my machine and causing me to lose work. I can’t fix bugs that exist on the device itself or in its firmware.

The MediaTek WiFi firmware is an encrypted black box. While some adventurous folks have managed to crack and extract keys from MediaTek firmware, that is not my goal. What I have done is fix kernel-side bugs and improve recovery handling so that when firmware crashes due to its own bugs, the driver can recover quickly—and to avoid patterns I’ve noticed can aggravate firmware issues from the kernel side.

My end goal is for this project to stop being necessary once these fixes land upstream. But because the upstreaming process can take time, I’m publishing these packages so people can work around the issues now and use their machines today—especially since these bugs can cripple brand-new laptops from vendors like Framework, Lenovo, Dell, ASUS, and Acer, sometimes crashing every few minutes.

In the process of creating these patches, I’ve also documented what I’ve learned about these drivers and the hardware, different debugging methods, crashes I’ve reproduced (and reports others have sent), and a stress-testing suite that can reproduce the bugs and demonstrate that these patches fix them.

# Getting Started

<div class="grid cards" markdown>

-   :material-download:{ .lg .middle } __Quick Install__

    ---

    Quickly install the patched driver via your package manager or install script.

    [:octicons-arrow-right-24: Get Started](quick-start.md)

-   :material-bug:{ .lg .middle } __Known Issues__

    ---

    Common issues, known crashes, and some of their workarounds (either implemented in this driver package or how to avoid otherwise like disabling band stearing, fast roaming, 6ghz, MLO, etc)

    [:octicons-arrow-right-24: View Issues](issues/index.md)

-   :material-file-document:{ .lg .middle } __Patches__

    ---

    6 stability patches for kernel 6.17+

    [:octicons-arrow-right-24: Patch Details](patches/index.md)

-   :material-cog:{ .lg .middle } __Architecture__

    ---

    Deep dive into driver internals

    [:octicons-arrow-right-24: Learn More](architecture/index.md)

-   :material-account-plus:{ .lg .middle } __Contributing__

    ---

    How to report issues, test patches, and submit fixes

    [:octicons-arrow-right-24: Contribute](contributing.md)

</div>

## Status

| Component | Version | Status |
|-----------|---------|--------|
| **Patches** | Patchset v7 (7 patches) | :material-check-circle:{ .green } Stable |
| **DKMS Package** | v1.5.0 | :material-check-circle:{ .green } Released |
| **Upstreaming work** | Still in progress | :material-clock:{ .yellow } Pending review |

## Supported Hardware

- **MT7925** - WiFi 7 (802.11be) PCIe card
- **MT7921** - WiFi 6E (802.11ax) PCIe/USB/SDIO

## Supported Kernels

| Kernel | Status | Notes |
|--------|--------|-------|
| 6.17.x | :material-check-circle: Supported | Minimum version for DKMS |
| 6.18.x | :material-check-circle: Supported | Recommended |
| 6.19-rc | :material-check-circle: Supported | Release candidate |
| < 6.17 | :material-close-circle: Not supported | Use kernel patches instead. Some additional patches may be needed. |

## Quick Links

- [:material-github: GitHub Repository](https://github.com/zbowling/mt7925)
- [:material-bug: Report an Issue](https://github.com/zbowling/mt7925/issues/new)
- [:material-forum: Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301)
