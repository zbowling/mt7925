# Uninstalling

## Package Manager Uninstall

=== "Arch Linux"

    ```bash
    sudo pacman -R mt76-mt7925-dkms
    ```

=== "Debian/Ubuntu"

    ```bash
    sudo apt remove mt76-mt7925-dkms

    # Optional: Remove repository
    sudo rm /etc/apt/sources.list.d/mt76-packages.list
    sudo rm /usr/share/keyrings/mt76-packages.gpg
    ```

=== "Fedora/RHEL"

    ```bash
    sudo dnf remove mt76-mt7925-dkms

    # Optional: Remove repository
    sudo rm /etc/yum.repos.d/mt76-packages.repo
    sudo rm /etc/yum.repos.d/mt76-packages-source.repo
    ```

## Manual Uninstall

If you installed using `install.sh`:

```bash
cd mt7925/dkms
sudo ./uninstall.sh
```

### What the Uninstaller Does

1. Removes DKMS module for all kernel versions
2. Removes source from `/usr/src/mt76-mt7925-*/`
3. Restores stock kernel modules (via `depmod`)
4. Reloads modules (stock versions)
5. Removes telemetry config file (if exists)

## Manual DKMS Removal

If the uninstall script isn't available:

```bash
# Remove from all kernels (replace x.y.z with your version)
sudo dkms remove mt76-mt7925/x.y.z --all

# Remove source directory
sudo rm -rf /usr/src/mt76-mt7925-*

# Rebuild module dependencies
sudo depmod -a

# Reload stock modules
sudo modprobe -r mt7925e mt7925_common mt792x_lib mt76_connac_lib mt76
sudo modprobe mt7925e
```

## Verify Removal

```bash
# Check DKMS status (should be empty)
dkms status | grep mt76-mt7925

# Check module path (should be kernel/, not updates/dkms/)
modinfo mt7925e | grep filename
```

After uninstalling, your system will use the stock kernel modules again.

## Complete Cleanup

To remove all traces including config files:

```bash
# Remove telemetry config
sudo rm -f /etc/mt7925-telemetry.conf

# Remove telemetry queue
sudo rm -f /var/lib/mt7925-telemetry-queue
```
