# Instructions for AI Agents

This document captures the user's intent and requirements for maintaining this repository. AI agents assisting with this project should follow these guidelines.

## Critical Requirements

### Patch Quality

1. **Patches MUST apply cleanly**
   - No hunk errors, no fuzz, no offset warnings
   - Each patch should apply with `git apply` without any modifications
   - This is embarrassing when users report patch failures - see GitHub issues
   - Always validate with `./scripts/validate-patches.sh` before committing

2. **Maintain individual patches, NOT squashed**
   - NEVER squash patches into a single mega-patch
   - Each fix should be its own numbered patch file (0001-*, 0002-*, etc.)
   - This preserves the history of what was fixed and why
   - The full patchset documents the debugging journey and all intermediate work

3. **Patches come from git branches**
   - The source of truth is the [zbowling/linux-wifi](https://github.com/zbowling/linux-wifi) fork
   - Patches in `kernels/` are exported from those branches using `git format-patch`
   - Never hand-edit patches - edit the source branch and re-export

4. **Test before committing**
   - Run `./scripts/validate-patches.sh` to verify patches apply
   - CI workflow tests patch application and builds
   - Manual testing on actual hardware when possible

### Multi-Kernel Support

This repository maintains patches for multiple kernel versions:

| Priority | Version | Directory | Notes |
|----------|---------|-----------|-------|
| Primary | 6.18.x | `kernels/6.18/` | Current stable - Arch, Fedora 42 |
| High | 6.19-rcX | `kernels/6.19-rc/` | Bleeding edge |
| Medium | 6.17.x | `kernels/6.17/` | EOL but still used |
| Reference | nbd168 | `kernels/nbd168/` | Upstream staging patches |

When porting patches to a new kernel version:
1. Create a new branch in zbowling/linux-wifi from the kernel tag
2. Apply patches from closest working version
3. Fix any conflicts manually (check function renames, line numbers)
4. Export clean patches with `git format-patch`
5. Validate with `./scripts/validate-patches.sh`

### Patch Differences

Different kernel versions have different function names and code structure. See `docs/PATCH_DIFFERENCES.md` for detailed explanation of:
- Which functions changed between versions
- How to adapt patches for new kernels
- Common issues and solutions

## Repository Structure

```
mt7925/
├── kernels/
│   ├── 6.17/           # Patches for 6.17.x kernels
│   ├── 6.18/           # Patches for 6.18.x kernels (primary)
│   ├── 6.19-rc/        # Patches for 6.19-rcX kernels
│   └── nbd168/         # Upstream staging patches
├── linux-6.19-rc4/     # Legacy patches (historical reference)
├── scripts/
│   └── validate-patches.sh
├── .github/
│   └── workflows/      # CI validation and build testing
├── docs/
│   └── PATCH_DIFFERENCES.md
└── dkms/               # DKMS package (when complete)
```

## Workflow for Adding New Patches

1. **Work in linux-wifi fork**
   ```bash
   cd ~/projects/linux-wifi
   git checkout mt7925-fixes-v6.18.5
   # Make changes
   git commit -m "wifi: mt76: mt7925: <description>"
   git push origin mt7925-fixes-v6.18.5
   ```

2. **Export patches**
   ```bash
   cd ~/projects/linux-wifi
   rm ~/projects/mt7925/kernels/6.18/*.patch
   git format-patch v6.18.5..mt7925-fixes-v6.18.5 -o ~/projects/mt7925/kernels/6.18
   ```

3. **Validate**
   ```bash
   cd ~/projects/mt7925
   ./scripts/validate-patches.sh 6.18
   ```

4. **Port to other versions**
   - Repeat for 6.17, 6.19-rc as needed
   - Some patches may need adaptation (see docs/PATCH_DIFFERENCES.md)

5. **Commit and push**
   ```bash
   git add kernels/
   git commit -m "Update patches for 6.18.5 - add <description>"
   git push
   ```

## Context: Why These Patches Exist

The MT7925 is a WiFi 7 (802.11be) chip from MediaTek. The upstream driver has several issues:

1. **NULL pointer dereferences** - MLO (Multi-Link Operation) code paths don't check for NULL links
2. **Race conditions** - Missing mutex protection around `ieee80211_iterate_*` calls
3. **Error handling** - MCU commands can fail silently causing undefined behavior
4. **Deadlocks** - Incorrect mutex nesting in some paths

These issues cause:
- Kernel panics during roaming
- WiFi disconnections
- System hangs on suspend/resume
- Crashes during MLO operations

MediaTek's upstream progress is slow. These patches are our workaround until proper fixes are merged into mainline.

## Contact

This repository is maintained by Zac Bowling. Patches have been submitted to LKML but MediaTek's response time is... not great.
