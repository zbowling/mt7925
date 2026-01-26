# Fedora / RHEL Installation

## Option A: Add Repository (Recommended)

Adding the repository enables automatic updates when new versions are released.

### Quick Setup

```bash
curl -1sLf 'https://dl.cloudsmith.io/public/mt76/packages/setup.rpm.sh' | sudo -E bash
sudo dnf install mt76-mt7925-dkms
```

### Manual Repository Configuration

<details>
<summary>Click to expand manual setup</summary>

```bash
# Import GPG key
sudo rpm --import 'https://dl.cloudsmith.io/public/mt76/packages/gpg.5993EEFA4E82E600.key'

# Add repository (Fedora)
curl -1sLf 'https://dl.cloudsmith.io/public/mt76/packages/config.rpm.txt?distro=fedora&codename=42' | \
  sudo tee /etc/yum.repos.d/mt76-packages.repo

# Or for RHEL/CentOS/Rocky
curl -1sLf 'https://dl.cloudsmith.io/public/mt76/packages/config.rpm.txt?distro=el&codename=9' | \
  sudo tee /etc/yum.repos.d/mt76-packages.repo

# Install
sudo dnf makecache
sudo dnf install mt76-mt7925-dkms
```

</details>

## Option B: Manual Download

Download from [GitHub Releases](https://github.com/zbowling/mt7925/releases/latest):

```bash
wget https://github.com/zbowling/mt7925/releases/latest/download/mt76-mt7925-dkms-1.4.1-1.noarch.rpm
sudo dnf install ./mt76-mt7925-dkms-1.4.1-1.noarch.rpm
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
sudo dnf upgrade
```

## Tested Distributions

| Distribution | Kernel | Status |
|--------------|--------|--------|
| Fedora 42 | 6.17+ | :material-check: Working |
| Fedora 41 | 6.17+ | :material-check: Working |
| RHEL 9 | varies | :material-alert: Needs kernel upgrade |

!!! note "RHEL/CentOS/Rocky"
    Enterprise distributions may ship with older kernels. Check your kernel version with `uname -r` and ensure it's 6.17 or newer.
