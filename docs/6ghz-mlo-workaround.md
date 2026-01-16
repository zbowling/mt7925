# 6GHz MLO Workaround for MT7925

## Problem

The MT7925 driver may fail to establish 6GHz links during MLO (Multi-Link Operation)
negotiation, even when:
- The hardware supports 6GHz (Band 4 present in `iw phy`)
- The AP is broadcasting on 6GHz (visible in `nmcli device wifi list`)
- The regulatory domain allows 6GHz (US, etc.)

Symptoms:
- MLO connects with only 2.4 GHz + 5 GHz links
- 6GHz BSSID is visible but not included in association
- No errors in dmesg, just silently omitted

## Workaround

Switching the regulatory domain and back forces the driver to re-evaluate
channel permissions and renegotiate MLO links:

```bash
# Switch to another country and back
sudo iw reg set KR && sleep 1 && sudo iw reg set US

# Then reconnect
nmcli device disconnect wlan0
nmcli device wifi connect "YourSSID"
```

Or as a one-liner:
```bash
sudo iw reg set KR && sleep 1 && sudo iw reg set US && nmcli device disconnect wlan0 && sleep 2 && nmcli device wifi connect "YourSSID"
```

## Verification

Check that 6GHz link is established:
```bash
iw dev wlan0 link
```

Should show something like:
```
Link 1 BSSID xx:xx:xx:xx:xx:xd
    freq: 5765.0
Link 2 BSSID xx:xx:xx:xx:xx:xe
    freq: 6535.0
```

6GHz frequencies are in the 5925-7125 MHz range (channels starting around 5955 MHz).

## Technical Details

### Why This Works

The regulatory domain switch triggers:
1. Driver re-reads channel flags from wireless-regdb
2. Re-scans available frequencies on all bands
3. Forces MLO link renegotiation with AP
4. AP includes 6GHz in the new association response

### 6GHz Regulatory in Linux

The US regulatory domain shows for 6GHz:
```
(5925 - 7125 @ 320), (N/A, 12), (N/A), NO-OUTDOOR, PASSIVE-SCAN
```

- `PASSIVE-SCAN` - Device can only passively scan (listen for beacons), cannot active probe
- `NO-OUTDOOR` - Indoor use only
- This does NOT prevent connections - once a beacon is received, connection is allowed

### MLO Configurations Observed

| Config | Bands | Stability |
|--------|-------|-----------|
| Tri-band | 2.4 + 5 + 6 GHz | Caused hard lockup (needs investigation) |
| Dual-band | 5 + 6 GHz | Stable so far |
| Dual-band | 2.4 + 5 GHz | Stable (default fallback) |

## Known Issues

### Hard Lockup with Tri-band MLO (2026-01-15)

A complete system freeze occurred while connected with tri-band MLO (2.4 + 5 + 6 GHz).
No kernel panic was logged - appears to be a hard lockup in the driver.

Conditions:
- Connected to all three bands simultaneously
- Switching between network profiles
- Testing 6GHz connectivity

The dual-band (5 + 6 GHz) configuration appears more stable.

## Hardware/Software

- Chip: MediaTek MT7925 (WiFi 7, 802.11be)
- Supported bands: 2.4 GHz, 5 GHz, 6 GHz (tri-band)
- Max width: 160 MHz on 6 GHz
- MLO: Multi-Link Operation supported
- Driver: mt7925e (DKMS patched)

## See Also

- `iw phy` - Check hardware band support
- `iw reg get` - Check current regulatory domain
- `nmcli device wifi list` - See available networks with frequencies
- `/sys/kernel/debug/ieee80211/phy0/` - Debug info (if debugfs mounted)
