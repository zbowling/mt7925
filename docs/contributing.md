# Contributing

Thank you for your interest in contributing! This project maintains patches for the MediaTek MT7925/MT7921 WiFi driver to fix stability issues not yet resolved upstream.

## Ways to Contribute

### Reporting Issues

When reporting issues, include:

- **Kernel panics/crashes**: Full dmesg output and stack traces
- **WiFi disconnects**: Circumstances and error messages
- **Build failures**: Kernel version, distribution, and error output

Open an issue at: [GitHub Issues](https://github.com/zbowling/mt7925/issues)

### Testing Patches

Testing on different hardware and kernel versions is extremely valuable:

1. Apply patches to your kernel or use the DKMS package
2. Test normal WiFi operations, sleep/resume, and stress scenarios
3. Report results in the relevant issue or discussion

### Submitting Patches

#### For New Fixes

1. **Work in the linux-wifi fork** (not this repo directly):

    ```bash
    git clone https://github.com/zbowling/linux-wifi.git
    cd linux-wifi
    git checkout mt7925-upstream-v2-6.18  # or appropriate branch
    ```

2. **Make your changes** following kernel coding style:
    - Use tabs for indentation
    - Follow existing patterns in the driver
    - Add appropriate error handling

3. **Commit with a proper message**:

    ```
    wifi: mt76: mt7925: <short description>

    <detailed explanation of the problem and fix>

    Signed-off-by: Your Name <your@email.com>
    ```

4. **Export the patch**:

    ```bash
    git format-patch -1
    ```

5. **Open a PR** with the patch and explanation

#### Patch Requirements

- Patches MUST apply cleanly (no fuzz, no offsets)
- Each fix should be a separate patch
- Include a clear commit message explaining the problem and solution
- Test on at least one kernel version before submitting

### Documentation

Improvements to documentation are always welcome:

- Clarifications to existing docs
- New debugging tips
- Hardware compatibility reports

## Commit Message Format

Follow the kernel commit message style:

```
wifi: mt76: mt7925: fix NULL pointer in sta_link_rc_work

The sta_link_rc_work function could dereference a NULL pointer when
the station was removed during rate control work. Add a NULL check
before accessing the link state.

Fixes: abc123def456 ("wifi: mt76: mt7925: add MLO support")
Signed-off-by: Your Name <your@email.com>
```

### Subject Line

- Start with subsystem prefix: `wifi: mt76: mt7925:`
- Use imperative mood: "fix", "add", "remove" (not "fixed", "adds")
- Keep under 72 characters

### Body

- Explain the problem being fixed
- Explain the solution
- Reference related commits with `Fixes:` tag if applicable
- Add your `Signed-off-by` line

## Code Style

Follow Linux kernel coding style:

```c
// Use tabs for indentation
// 80 column limit (soft)
// Opening brace on same line for functions

int mt7925_example_function(struct mt792x_dev *dev,
                           struct ieee80211_vif *vif)
{
    int ret;

    if (!dev || !vif)
        return -EINVAL;

    mt792x_mutex_acquire(dev);
    ret = mt7925_mcu_some_command(dev, vif);
    mt792x_mutex_release(dev);

    return ret;
}
```

### Common Patterns

#### Mutex Protection

```c
mt792x_mutex_acquire(dev);
/* MCU operations */
mt792x_mutex_release(dev);
```

#### NULL Checks

```c
struct mt792x_link_sta *mlink = mt792x_sta_to_link(msta, link_id);
if (!mlink)
    return -EINVAL;
```

#### Error Handling

```c
ret = mt7925_mcu_command(dev);
if (ret)
    goto out;
```

## Development Workflow

### Setting Up

```bash
# Clone linux-wifi fork
git clone https://github.com/zbowling/linux-wifi.git
cd linux-wifi

# Checkout the appropriate branch
git checkout mt7925-upstream-v2-6.18

# Create a feature branch
git checkout -b fix-my-issue
```

### Making Changes

```bash
# Edit driver files
vim drivers/net/wireless/mediatek/mt76/mt7925/main.c

# Build (if doing kernel build)
make M=drivers/net/wireless/mediatek/mt76/ modules
```

### Testing

```bash
# Install module
sudo rmmod mt7925e mt7925_common mt792x_lib mt76_connac_lib mt76
sudo insmod drivers/net/wireless/mediatek/mt76/mt76.ko
# ... install other modules

# Or use DKMS for easier testing
```

### Submitting

```bash
# Export patch
git format-patch -1

# Submit via PR to mt7925 repo
```

## Code of Conduct

Please be respectful and constructive in all interactions.

## License

By contributing, you agree that your contributions will be licensed under the project's dual ISC/GPL-2.0 license.

## Questions?

Open a discussion at: [GitHub Discussions](https://github.com/zbowling/mt7925/discussions)
