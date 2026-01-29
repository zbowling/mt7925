# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-01-29

### Added
- **RSSI Monitor Support**: CQM RSSI threshold notifications via firmware events
  - New MCU command `MCU_UNI_CMD_RSSI_MONITOR` for configuring thresholds
  - Event handler for `MCU_UNI_EVENT_RSSI_MONITOR` unsolicited events
  - Integration with mac80211 `ieee80211_cqm_rssi_notify()` API
  - Automatic enable when chip has `MT792x_CHIP_CAP_RSSI_NOTIFY_EVT_EN`
- **Channel Switch Announcement (CSA) Support**: Handle AP-initiated channel switches
  - `pre_channel_switch` validation for supported scenarios
  - `channel_switch` timer-based CSA work scheduling
  - `channel_switch_rx_beacon` for beacon count updates
  - `abort_channel_switch` for CSA cancellation
  - `switch_vif_chanctx` for channel context transitions
  - Extended channel switching capability advertised in STA mode
- **Conditional Debug Features**: `MT76_DKMS_DEBUG_FEATURES` compile-time flag
  - Wraps ROC abort state (`MT76_STATE_ROC_ABORT`) for async abort handling
  - Wraps ROC rate limiting/backoff mechanism for MCU overload protection
  - Wraps verbose `dev_info()` logging throughout driver
  - Can be disabled via `-DMT76_DKMS_DEBUG_FEATURES=0` for upstream-matching builds
- **Kernel Compatibility Macros**:
  - `MT76_HAS_EHT_PUNCTURING` for kernel 6.5+ EHT puncturing support
  - `MT76_HAS_CSA_SUPPORT` for CSA feature availability
  - `MT76_KERNEL_HAS_REGD_REFACTOR` for kernel 6.19+ regulatory changes
  - `MT76_KERNEL_HAS_MLO_PM` for kernel 6.18+ MLO power management

### Changed
- **Reorganized nbd168 Patch Series**: Consolidated from 12 patches to 6 focused patches
  - Patch 01: Fix double wcid initialization race condition
  - Patch 02: Add NULL pointer protection for MLO operations
  - Patch 03: Add mutex protection in critical paths
  - Patch 04: Add MCU command error handling in AMPDU actions
  - Patch 05: Add lockdep assertions for mutex verification
  - Patch 06: Fix MLO ROC setup error handling
- DKMS source now includes upstream RSSI/CSA features from nbd168 tree
- Improved `switch_vif_chanctx` to properly iterate all vifs (not just first)
- CSA work now uses consolidated mutex acquisition pattern

### Fixed
- RSSI monitor event TLV parsing (use `tlv` pointer instead of `skb->data`)
- `GFP_KERNEL` to `GFP_ATOMIC` in atomic context for RSSI notifications
- NULL pointer dereference in `channel_switch_rx_beacon` when `new_ctx` is NULL
- `add_timer` replaced with `mod_timer` for safer CSA timer handling
- Duplicate mutex acquisition in CSA work consolidated
- Channel context lifetime tracking in `add_chanctx`/`remove_chanctx`

## [1.4.2] - 2026-01-26

### Fixed
- Debian package not building DKMS modules on install
- Added postinst/prerm scripts to properly trigger DKMS add/build/install

## [1.4.1] - 2026-01-26

### Added
- Cloudsmith package repository publishing
- Opt-in telemetry for install/uninstall tracking (PostHog)
- Hardware detection (chip type, bus type, clang usage) in telemetry
- Network wait + queue mechanism for telemetry after WiFi module replacement
- Session tracking with duration metrics

### Changed
- AUR, DEB, and RPM packages now published to Cloudsmith
- Updated documentation for telemetry

## [1.4.0] - 2026-01-24

### Added
- USB and SDIO transport modules (mt76-usb, mt76-sdio, mt792x-usb)
- Full MT7921 driver support (mt7921-common, mt7921e, mt7921s, mt7921u)
- Driver binding verification via sysfs in install script
- Multi-version DKMS cleanup in install/uninstall scripts

### Changed
- DKMS package now includes MT7921 for ABI compatibility with mt792x-lib
- Improved module loading order in install script
- Enhanced uninstall script to handle all installed versions

### Fixed
- Double wcid initialization race condition (patch 12)

## [1.3.0] - 2025-01-19

### Added
- Patch 12: Fix double wcid initialization race condition
- Cover letter for upstream submission (v6 series)

### Changed
- Reorganized to 12-patch series (squashed mt7921 patches 4 and 5)
- Sean Wang's upstream deadlock fix as patch 01 for consistency

## [1.2.0] - 2025-01-15

### Added
- Patch 11: Fix ROC deadlocks and race conditions
- Patch 10: Fix BA session teardown during beacon loss
- Patch 09: Fix MLO roaming and ROC setup issues

### Changed
- Reorganized patches from 27 to 11 cleaner patches for upstream

## [1.1.0] - 2025-01-10

### Added
- Patch 08: Add lockdep assertions for mutex verification
- Patch 07: Add MCU command error handling
- Patch 06: Add mutex protection in critical paths
- Patch 05: Add comprehensive NULL pointer protection for MLO
- DKMS package with install/uninstall scripts
- Support for clang-built kernels

### Fixed
- Missing mutex wrapper in PCI suspend path

## [1.0.0] - 2025-01-05

### Added
- Initial patch series for MT7925 stability fixes
- Patch 01: Fix potential deadlock in roc_abort_sync (Sean Wang)
- Patch 02: Fix list corruption in mt76_wcid_cleanup
- Patch 03: Fix NULL pointer and firmware reload issues (mt792x)
- Patch 04: Fix mutex and ROC deadlocks (mt7921)
- Support for kernel versions 6.17, 6.18, 6.19-rc
- Patches for nbd168/wireless upstream tree
- Documentation for driver architecture, locking, and debugging

### Fixed
- Kernel panics on Framework Desktop systems
- Mutex deadlocks during WiFi operations
- NULL pointer dereferences in MLO code paths
- MCU command timeouts during rapid state changes

[Unreleased]: https://github.com/zbowling/mt7925/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/zbowling/mt7925/compare/v1.4.2...v1.5.0
[1.4.2]: https://github.com/zbowling/mt7925/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/zbowling/mt7925/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/zbowling/mt7925/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/zbowling/mt7925/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/zbowling/mt7925/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/zbowling/mt7925/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/zbowling/mt7925/releases/tag/v1.0.0
