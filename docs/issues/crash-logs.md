# Crash Logs Repository

Raw crash logs and kernel traces collected during MT7925 driver development and testing.

[:material-folder-open: Browse All Crash Logs on GitHub](https://github.com/zbowling/mt7925/tree/main/crashes){ .md-button .md-button--primary }

---

## Log Categories

### NULL Pointer Crashes

These crashes involve NULL pointer dereferences, typically during VIF iteration or reset work.

| Log File | Date | Issue |
|----------|------|-------|
| [:material-file-document: crash-2026-01-10-reset-work-null-ptr.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-10-reset-work-null-ptr.log) | Jan 10 | NULL pointer in `mt76_connac_mcu_uni_add_dev` during reset work after MCU timeouts |
| [:material-file-document: crash-2026-01-10-2112-reset-work-null-vif.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-10-2112-reset-work-null-vif.log) | Jan 10 | NULL VIF during reset work iteration |
| [:material-file-document: crash-2026-01-10-2123-reset-work-null-vif.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-10-2123-reset-work-null-vif.log) | Jan 10 | Same pattern, different trigger |
| [:material-file-document: crash-2026-01-10-2131-reset-work-null-vif.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-10-2131-reset-work-null-vif.log) | Jan 10 | Same pattern, multiple occurrences |

**Root Cause:** During `mt7925_mac_reset_work`, the driver iterates VIFs via `ieee80211_iterate_active_interfaces`. If a VIF is removed during iteration, the pointer becomes NULL.

**Fix:** Patches 0003, 0005, 0017 add NULL checks for VIF and link pointers.

---

### MLO (Multi-Link Operation) Issues

Crashes and hangs related to WiFi 7 Multi-Link Operation.

| Log File | Date | Issue |
|----------|------|-------|
| [:material-file-document: crash-2026-01-11-1819-mlo-roam-hang.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-11-1819-mlo-roam-hang.log) | Jan 11 | System hang during MLO authentication on 6 GHz. Missing patches caused deadlock. |
| [:material-file-document: crash-2026-01-19-mlo-authentication-failure.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-19-mlo-authentication-failure.log) | Jan 19 | Repeated MLO auth failures with ROC timeouts on WiFi 7 network |

**Key Symptoms:**

- `nl80211: kernel reports: link ID must for MLO group key`
- ROC (Remain On Channel) command timeouts
- Firmware resets during MLO link establishment

**Root Cause:** MLO key handling and link ID management issues in the upstream driver.

**Fix:** Patches 0012-0017 address various MLO issues.

---

### MCU Timeout Events

MCU (Microcontroller Unit) command timeouts that may or may not lead to crashes.

| Log File | Date | Issue |
|----------|------|-------|
| [:material-file-document: crash-2026-01-12-2210-auth-loop-mcu-timeout.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-12-2210-auth-loop-mcu-timeout.log) | Jan 12 | Auth loop with MCU timeout, recovered gracefully (patches working) |
| [:material-file-document: crash-2026-01-13-0030-mcu-timeout-recovery.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-13-0030-mcu-timeout-recovery.log) | Jan 13 | 5 consecutive MCU timeouts with successful firmware reload recovery |

**Key Observation:** With patches applied, MCU timeouts trigger firmware reload and recovery instead of kernel panic. This demonstrates the patches are working correctly.

---

### 6 GHz Band Issues

Issues specifically related to 6 GHz band operation.

| Log File | Date | Issue |
|----------|------|-------|
| [:material-file-document: behavior-2026-01-19-6ghz-comeback-roc-timeout.log](https://github.com/zbowling/mt7925/blob/main/crashes/behavior-2026-01-19-6ghz-comeback-roc-timeout.log) | Jan 19 | Repeated pattern: 6 GHz disconnect → comeback rejection → ROC timeout → firmware reload |

**Pattern Observed:**

1. Station on 6 GHz disconnects
2. Driver attempts to connect to 5 GHz fallback
3. AP sends "comeback later" (status 30)
4. AP forgets auth state during comeback wait
5. ROC commands timeout
6. Firmware reload recovers

**Status:** Under investigation. May indicate firmware instability with certain AP rejection sequences.

---

### Authentication Failures

Connection and authentication issues.

| Log File | Date | Issue |
|----------|------|-------|
| [:material-file-document: crash-2026-01-12-1959-wifi-auth-failures.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-12-1959-wifi-auth-failures.log) | Jan 12 | Multiple auth failures with status 37 (SAE/WPA3 rejection) |

---

### Unrelated System Issues

Some logs capture crashes from other subsystems occurring at the same time.

| Log File | Date | Issue |
|----------|------|-------|
| [:material-file-document: crash-2026-01-14-1731-amdgpu-mes-hang.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-14-1731-amdgpu-mes-hang.log) | Jan 14 | AMDGPU MES (Micro Engine Scheduler) hang - unrelated to WiFi driver |
| [:material-file-document: crash-2026-01-10-journalctl.log](https://github.com/zbowling/mt7925/blob/main/crashes/crash-2026-01-10-journalctl.log) | Jan 10 | General journal output from crash session |

---

### Summary Documentation

| File | Description |
|------|-------------|
| [:material-file-document: OTHER_CRASHES.md](https://github.com/zbowling/mt7925/blob/main/crashes/OTHER_CRASHES.md) | Detailed analysis of hard lockup and station removal deadlock bugs |

---

## Common Error Messages

### MCU Timeout
```text
mt7925e 0000:bf:00.0: Message 00020002 (seq 12) timeout
```
The MCU (firmware) didn't respond to a command within the timeout period.

### MLO Key Error
```text
nl80211: kernel reports: link ID must for MLO group key
```
Multi-Link Operation key handling error - requires MLO patches.

### NULL Pointer Dereference
```text
BUG: kernel NULL pointer dereference, address: 0000000000000000
```
A pointer was NULL when the driver expected a valid object.

### Hung Task
```text
INFO: task kworker/u128:0:48737 blocked for more than 122 seconds.
```
A kernel worker thread is stuck, usually due to mutex deadlock.

---

## Contributing Crash Logs

If you experience a crash, please [open an issue](https://github.com/zbowling/mt7925/issues/new) with:

1. Kernel version (`uname -r`)
2. DKMS version (`dkms status | grep mt76`)
3. dmesg output around the crash
4. What you were doing when it crashed

See [Debugging Guide](debugging.md) for instructions on collecting crash information.
