# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/zbowling/mt7925/compare/v1.4.2...HEAD
[1.4.2]: https://github.com/zbowling/mt7925/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/zbowling/mt7925/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/zbowling/mt7925/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/zbowling/mt7925/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/zbowling/mt7925/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/zbowling/mt7925/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/zbowling/mt7925/releases/tag/v1.0.0
