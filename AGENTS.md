# Instructions for AI Agents

This document helps AI agents effectively work with this repository. It provides critical requirements, workflow guidelines, and a documentation index for finding relevant information.

## Documentation Index (Progressive Disclosure)

The `docs/` folder contains comprehensive documentation. Use this index to find the right file for your task.

### Quick Reference: What Do You Need?

| If you need to... | Read this file |
|-------------------|----------------|
| Understand the overall driver architecture | [ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Find where a specific function is defined | [FILE_REFERENCE.md](docs/FILE_REFERENCE.md) |
| Trace how a feature works end-to-end | [NAVIGATION_GUIDE.md](docs/NAVIGATION_GUIDE.md) |
| Debug a crash or hang | [DEBUGGING.md](docs/DEBUGGING.md) |
| Use debugfs entries (fw_debug, chip_reset, etc.) | [DEBUGFS.md](docs/DEBUGFS.md) |
| Use sysfs entries (temperature, rfkill, etc.) | [SYSFS.md](docs/SYSFS.md) |
| Understand MCU command timeouts | [MCU_PROTOCOL.md](docs/MCU_PROTOCOL.md) |
| Fix or understand MLO (Multi-Link) issues | [MLO.md](docs/MLO.md) |
| Understand or fix locking/deadlock issues | [LOCKING.md](docs/LOCKING.md) |
| Port patches between kernel versions | [PATCH_DIFFERENCES.md](docs/PATCH_DIFFERENCES.md) |
| Understand chipset differences | [CHIPSETS.md](docs/CHIPSETS.md) |

---

### Documentation by Category

#### Architecture & Code Understanding

| File | Contents | When to Read |
|------|----------|--------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Module layering (core → connac → mt792x → mt7925), design patterns, component relationships | Understanding how the driver is structured |
| [DATA_STRUCTURES.md](docs/DATA_STRUCTURES.md) | Core structs (`mt76_dev`, `mt792x_dev`, `mt76_wcid`, `mt792x_vif`), field meanings, relationships | Working with driver data structures |
| [FILE_REFERENCE.md](docs/FILE_REFERENCE.md) | Every source file organized by layer, what each file contains, line counts | Finding where specific code lives |
| [ENTRY_POINTS.md](docs/ENTRY_POINTS.md) | PCI probe, module init, mac80211 registration, initialization sequence | Understanding driver startup |
| [CONTROL_FLOW.md](docs/CONTROL_FLOW.md) | TX/RX packet paths, interrupt handling, work queue flows | Tracing runtime behavior |
| [NAVIGATION_GUIDE.md](docs/NAVIGATION_GUIDE.md) | How to trace features, grep patterns, common code paths | Finding related code quickly |

#### Debugging & Diagnostics

| File | Contents | When to Read |
|------|----------|--------------|
| [DEBUGGING.md](docs/DEBUGGING.md) | Common issues (NULL derefs, deadlocks, MCU timeouts), diagnostic commands, stress testing | Debugging any driver issue |
| [DEBUGFS.md](docs/DEBUGFS.md) | All debugfs entries: `fw_debug`, `chip_reset`, `regval`, queues, trace events, MCU command IDs | Using `/sys/kernel/debug/ieee80211/phy*/mt76/` |
| [SYSFS.md](docs/SYSFS.md) | Hwmon (temperature), rfkill, network stats, PCI device control, power management | Using `/sys/class/` interfaces |
| [lock-audit.md](docs/lock-audit.md) | Which functions acquire mutex, which expect it held, call patterns | Analyzing lock-related bugs |

#### Protocols & Features

| File | Contents | When to Read |
|------|----------|--------------|
| [MCU_PROTOCOL.md](docs/MCU_PROTOCOL.md) | MCU command format, TLV encoding, command IDs, response handling, timeout behavior | MCU communication issues |
| [MLO.md](docs/MLO.md) | Multi-Link Operation architecture, link structures, common NULL pointer bugs, link iteration | WiFi 7 / MLO issues |
| [KERNEL_INTERACTIONS.md](docs/KERNEL_INTERACTIONS.md) | mac80211 integration, PCI subsystem, DMA, power management, cfg80211 | Kernel API usage |
| [LOCKING.md](docs/LOCKING.md) | Mutex patterns, `mt792x_mutex_acquire`, work queue interactions, deadlock scenarios | Concurrency bugs |

#### Chipset & Version Specifics

| File | Contents | When to Read |
|------|----------|--------------|
| [CHIPSETS.md](docs/CHIPSETS.md) | All MediaTek WiFi chipsets (7603→7925), specs, release dates, driver mapping | Understanding hardware differences |
| [PATCH_DIFFERENCES.md](docs/PATCH_DIFFERENCES.md) | Function renames between kernel versions, API changes, porting guidance | Porting patches to new kernels |

#### Known Issues & Workarounds

| File | Contents | When to Read |
|------|----------|--------------|
| [6ghz-mlo-workaround.md](docs/6ghz-mlo-workaround.md) | 6GHz band not associating in MLO, ACPI/regulatory workaround | 6GHz not working with MLO |

---

## Critical Requirements

### Patch Quality

1. **Patches MUST apply cleanly**
   - No hunk errors, no fuzz, no offset warnings
   - Each patch should apply with `git apply` without any modifications
   - Always validate with `./scripts/validate-patches.sh` before committing

2. **Maintain individual patches, NOT squashed**
   - NEVER squash patches into a single mega-patch
   - Each fix should be its own numbered patch file (0001-*, 0002-*, etc.)
   - This preserves the history of what was fixed and why

3. **Patches come from git branches**
   - Source of truth: [zbowling/linux-wifi](https://github.com/zbowling/linux-wifi) fork
   - Patches in `kernels/` are exported using `git format-patch`
   - Never hand-edit patches - edit the source branch and re-export

4. **Validate before committing in this repo**
   - Run `./scripts/validate-patches.sh` to verify patches apply
   - CI workflow tests patch application and builds

### Multi-Kernel Support

| Priority | Version | Directory | Notes |
|----------|---------|-----------|-------|
| Primary | 6.18.x | `kernels/6.18/` | Current stable - Arch, Fedora 42 |
| High | 6.19-rcX | `kernels/6.19-rc/` | Bleeding edge |
| Medium | 6.17.x | `kernels/6.17/` | EOL but still used |
| Reference | nbd168 | `kernels/nbd168/` | Upstream staging patches |

When porting patches to a new kernel version, see [PATCH_DIFFERENCES.md](docs/PATCH_DIFFERENCES.md).

---

## Repository Structure

```
mt7925/
├── kernels/
│   ├── 6.17/           # Patches for 6.17.x kernels
│   ├── 6.18/           # Patches for 6.18.x kernels (primary)
│   ├── 6.19-rc/        # Patches for 6.19-rcX kernels
│   └── nbd168/         # Upstream staging patches
├── dkms/               # DKMS package with patched source
│   └── src/            # Full mt76 driver source (patched)
├── scripts/
│   └── validate-patches.sh
├── docs/               # Documentation (see index above)
└── .github/
    └── workflows/      # CI validation and build testing
```

---

## Workflow for Adding New Patches

1. **Work in linux-wifi fork**
   ```bash
   cd <path-to-linux-wifi-fork>
   git checkout mt7925-fixes-v6.18.5
   # Make changes
   git commit -m "wifi: mt76: mt7925: <description>"
   ```

2. **Export patches**
   ```bash
   git format-patch v6.18.5..mt7925-fixes-v6.18.5 -o <path-to-this-repo>/kernels/6.18
   ```

3. **Validate (before committing in this repo)**
   ```bash
   ./scripts/validate-patches.sh 6.18
   ```

4. **Port to other versions** (see [PATCH_DIFFERENCES.md](docs/PATCH_DIFFERENCES.md))

5. **Commit and push in this repo**

---

## Context: Why These Patches Exist

The MT7925 is a WiFi 7 (802.11be) chip from MediaTek. The upstream driver has several issues:

1. **NULL pointer dereferences** - MLO code paths don't check for NULL links
2. **Race conditions** - Missing mutex protection around `ieee80211_iterate_*` calls
3. **MCU timeouts** - Commands can flood MCU during rapid state changes
4. **Deadlocks** - Incorrect mutex nesting, work queue interactions

For detailed analysis, see:
- [MLO.md](docs/MLO.md) - NULL pointer issues
- [LOCKING.md](docs/LOCKING.md) - Deadlock scenarios
- [MCU_PROTOCOL.md](docs/MCU_PROTOCOL.md) - Timeout handling

---

## DKMS Package

The `dkms/` directory contains a complete patched mt76 driver that can be installed via DKMS:

```bash
cd dkms
sudo dkms install .
```

The source in `dkms/src/` has all patches pre-applied and may contain experimental fixes not yet in the patch files.

---

## Contact

Maintained by Zac Bowling. Patches have been submitted to LKML but MediaTek's response time is slow.
