# Known Issues & Troubleshooting

This section documents known issues with the MT7925 driver, crash analysis, and debugging techniques.

## Issue Status Overview

| Issue | Severity | Status | Mitigation |
|-------|----------|--------|------------|
| MCU Timeout During MLO Roaming | :material-alert:{ .yellow } Medium | Partially Mitigated | Patches prevent crash |
| Performance vs Intel | :material-alert-circle:{ .red } Medium | Unmitigated | Hardware/Firmware |
| Frequent Deauth Cycles | :material-alert:{ .yellow } Low-Medium | Partially Mitigated | Power save off |

## Pages in This Section

<div class="grid cards" markdown>

-   :material-bug:{ .lg .middle } __Known Issues__

    ---

    Documented issues with root cause analysis and mitigation status

    [:octicons-arrow-right-24: View issues](known-issues.md)

-   :material-alert-decagram:{ .lg .middle } __Crash Analysis__

    ---

    Detailed analysis of crashes and deadlocks

    [:octicons-arrow-right-24: Crash reports](crash-analysis.md)

-   :material-wrench:{ .lg .middle } __Debugging Guide__

    ---

    How to debug MT7925 driver issues

    [:octicons-arrow-right-24: Debug guide](debugging.md)

</div>

## Quick Troubleshooting

### WiFi Not Working After Install

```bash
# Check if modules are loaded
lsmod | grep mt7925

# Check kernel messages
dmesg | grep -i mt76

# Reload modules
sudo modprobe -r mt7925e && sudo modprobe mt7925e
```

### Frequent Disconnections

```bash
# Disable power management
sudo iw dev wlan0 set power_save off

# Set regulatory domain (replace XX with country code)
sudo iw reg set XX
```

### MCU Timeouts

If you see MCU timeout messages, our patches help the driver recover automatically. Check that you have the latest version:

```bash
dkms status | grep mt76-mt7925
```
