# Installing MT7925 Driver Packages (Experimental)

> **Status: Experimental / Beta**
>
> These packages are brand new and only lightly tested. They work on my machines, but I need your help testing them on different hardware and distributions. Please [file issues](https://github.com/zbowling/mt7925/issues) if you encounter problems!

## Overview

I've created pre-built packages for the patched MT7925/MT7921 WiFi drivers to make installation easier. Instead of manually applying kernel patches and rebuilding, you can now install via your distro's package manager.

**What's included:**
- 12 kernel modules (mt76 core, mt7925, mt7921, USB/SDIO transports)
- DKMS integration (auto-rebuilds when you update your kernel)
- All 12 stability patches from the patch series

**Requirements:**
- Kernel 6.17 or newer
- Kernel headers installed
- For clang-built kernels: clang and lld

---

## Installation

### Arch Linux (AUR)

The easiest option for Arch users:

```bash
# Using yay
yay -S mt76-mt7925-dkms

# Or using paru
paru -S mt76-mt7925-dkms

# Or manually
git clone https://aur.archlinux.org/mt76-mt7925-dkms.git
cd mt76-mt7925-dkms
makepkg -si
```

The package will automatically:
1. Install source to `/usr/src/mt76-mt7925-<version>/`
2. Build modules via DKMS for all installed kernels
3. Sign modules if you have Secure Boot configured

**Tested on:** Arch Linux, CachyOS (6.18.x, 6.19-rc kernels)

### Debian / Ubuntu

Download the `.deb` package from the [latest release](https://github.com/zbowling/mt7925/releases/latest):

```bash
# Download (replace version as needed)
wget https://github.com/zbowling/mt7925/releases/latest/download/mt76-mt7925-dkms_1.4.0_all.deb

# Install
sudo apt install ./mt76-mt7925-dkms_1.4.0_all.deb

# Or using dpkg directly
sudo dpkg -i mt76-mt7925-dkms_1.4.0_all.deb
sudo apt-get install -f  # Fix any missing dependencies
```

**Note:** Requires kernel 6.17+. Ubuntu 24.04 ships with 6.8, so you'll need a newer kernel (e.g., from the HWE stack or mainline PPA).

**Tested on:** Ubuntu 25.10 (in CI only - needs real-world testing!)

### Fedora / RHEL

Download the `.rpm` package from the [latest release](https://github.com/zbowling/mt7925/releases/latest):

```bash
# Download (replace version as needed)
wget https://github.com/zbowling/mt7925/releases/latest/download/mt76-mt7925-dkms-1.4.0-1.noarch.rpm

# Install with dnf (handles dependencies)
sudo dnf install ./mt76-mt7925-dkms-1.4.0-1.noarch.rpm

# Or with rpm directly
sudo rpm -ivh mt76-mt7925-dkms-1.4.0-1.noarch.rpm
```

**Tested on:** Fedora 42 (in CI only - needs real-world testing!)

### Manual Install (Any Distro)

If packages don't work for your distro:

```bash
git clone https://github.com/zbowling/mt7925.git
cd mt7925/dkms
sudo ./install.sh
```

---

## Verifying Installation

After installation, verify everything is working:

```bash
# Check DKMS status
dkms status | grep mt76-mt7925

# Should show something like:
# mt76-mt7925/1.4.0, 6.18.7-2-cachyos, x86_64: installed

# Check modules are loaded
lsmod | grep mt7925

# Check module info (should show /updates/dkms/ path)
modinfo mt7925e | grep filename

# Check WiFi interface exists
ip link | grep wl
```

---

## Uninstalling

### Arch Linux
```bash
sudo pacman -R mt76-mt7925-dkms
```

### Debian / Ubuntu
```bash
sudo apt remove mt76-mt7925-dkms
```

### Fedora / RHEL
```bash
sudo dnf remove mt76-mt7925-dkms
```

### Manual Install
```bash
cd mt7925/dkms
sudo ./uninstall.sh
```

---

## Telemetry (Opt-In)

The installer includes **optional, opt-in telemetry** to help me understand which systems are using the driver and catch issues.

### What's Collected (If You Opt In)

| Data | Example | Why |
|------|---------|-----|
| Kernel version | `6.18.7-2-cachyos` | Find kernel-specific bugs |
| Distribution | `Arch Linux` | Discover distros to test |
| Hardware ID | `[14c3:7925]` | Track device variants |
| Install result | `success` / `failure` | Catch build issues |

### What's NOT Collected

- IP addresses
- MAC addresses
- Hostnames
- Usernames
- Any personally identifiable information

### How It Works

During installation, you'll see a prompt:

```
Enable telemetry? [y/N]
```

- Press **Enter** or **n**: Telemetry disabled (default)
- Press **y**: Telemetry enabled

Your choice is saved to `/etc/mt7925-telemetry.conf` for future installs.

### Environment Variable Override

```bash
# Force enable
sudo MT7925_TELEMETRY=1 ./install.sh

# Force disable
sudo MT7925_TELEMETRY=0 ./install.sh
```

### Why Enable Telemetry?

This is a one-person project. Telemetry helps me:
- Discover which distros and kernels people are using
- Find out about build failures I can't reproduce locally
- Prioritize which systems to test

It's completely optional, and I appreciate those who enable it!

---

## Reporting Issues

**These packages are experimental!** I need your help finding bugs.

### Before Reporting

1. Run the log collector:
   ```bash
   cd mt7925/dkms
   sudo ./collect-logs.sh
   ```

2. This creates a `mt7925-debug-YYYYMMDD-HHMMSS.txt` file with:
   - System info (kernel, distro, architecture)
   - Hardware detection
   - DKMS status
   - Kernel messages
   - Firmware status

### How to Report

1. Go to [New Issue](https://github.com/zbowling/mt7925/issues/new)
2. Select "Bug Report" template
3. Paste the debug log output
4. Describe what happened

### What Makes a Good Bug Report

- **What you expected** vs **what happened**
- **Steps to reproduce** (if possible)
- **Debug log output** from `collect-logs.sh`
- **Any error messages** you saw

---

## Known Limitations

1. **Kernel 6.17+ required** - The driver source uses APIs not available in older kernels. For Ubuntu 24.04 (kernel 6.8), use the patch method instead (and there may be more changes for that old of kernel).

2. **Clang-built kernels** - If your kernel was built with clang (CachyOS, some Arch configs), you need `clang` and `lld` installed. The build system auto-detects this.

3. **Secure Boot** - DKMS will sign modules if you have MOK (Machine Owner Key) configured. If not, you may need to disable Secure Boot or set up MOK.

4. **Multiple kernel versions** - DKMS builds for all installed kernels. If a build fails for one kernel but succeeds for others, you'll see warnings but the working builds will still install.

---

## Feedback Welcome!

This is my first time packaging DKMS modules for multiple distros. If you:

- Successfully installed on a distro I haven't tested
- Found a bug in the packaging
- Have suggestions for improvements
- Want to help maintain packages for your distro

Please reach out via [GitHub Issues](https://github.com/zbowling/mt7925/issues) or the [Framework Community Forum](https://community.frame.work/t/kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301).

Thanks for testing!
