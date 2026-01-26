# Debian / Ubuntu Installation

## Option A: Add Repository (Recommended)

Adding the repository enables automatic updates when new versions are released.

### Quick Setup

```bash
curl -1sLf 'https://dl.cloudsmith.io/public/mt76/packages/setup.deb.sh' | sudo -E bash
sudo apt update
sudo apt install mt76-mt7925-dkms
```

### Manual Repository Configuration

<details>
<summary>Click to expand manual setup</summary>

```bash
# Install dependencies
sudo apt install apt-transport-https curl gnupg

# Import GPG key
curl -1sLf 'https://dl.cloudsmith.io/public/mt76/packages/gpg.5993EEFA4E82E600.key' | \
  sudo gpg --dearmor -o /usr/share/keyrings/mt76-packages.gpg

# Add repository (auto-detects your release codename)
CODENAME=$(lsb_release -cs)
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
echo "deb [signed-by=/usr/share/keyrings/mt76-packages.gpg] https://dl.cloudsmith.io/public/mt76/packages/deb/${DISTRO} ${CODENAME} main" | \
  sudo tee /etc/apt/sources.list.d/mt76-packages.list

# Install
sudo apt update
sudo apt install mt76-mt7925-dkms
```

</details>

## Option B: Manual Download

Download from [GitHub Releases](https://github.com/zbowling/mt7925/releases/latest):

```bash
# Download the latest release (check GitHub for current version)
wget https://github.com/zbowling/mt7925/releases/latest/download/mt76-mt7925-dkms_VERSION-1_all.deb
sudo apt install ./mt76-mt7925-dkms_*_all.deb
```

## Verify Installation

```bash
# Check DKMS status
dkms status | grep mt76-mt7925

# Check module path (should be updates/dkms)
modinfo mt7925e | grep filename

# Check WiFi interface
ip link | grep wl
```

## Update

With repository configured:

```bash
sudo apt update
sudo apt upgrade
```

## Kernel Requirements

!!! warning "Ubuntu 24.04 LTS"
    Ubuntu 24.04 ships with kernel 6.8, which is **not supported**. You need kernel 6.17+.

    Options:

    - Use the [HWE kernel](https://ubuntu.com/kernel/lifecycle) when available
    - Install a [mainline kernel](https://kernel.ubuntu.com/mainline/)
    - Use the [patch method](../patches/index.md) for older kernels

## Tested Distributions

| Distribution | Kernel | Status |
|--------------|--------|--------|
| Ubuntu 25.10 | 6.17+ | :material-check: Working |
| Debian Testing | 6.17+ | :material-check: Working |
| Ubuntu 24.04 | 6.8 | :material-close: Needs newer kernel |
