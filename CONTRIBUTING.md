# Contributing to MT7925 WiFi Driver Fixes

Thank you for your interest in contributing! This project maintains patches for
the MediaTek MT7925/MT7921 WiFi driver to fix stability issues not yet resolved
upstream.

## Ways to Contribute

### Reporting Issues

- **Kernel panics/crashes**: Include full dmesg output and stack traces
- **WiFi disconnects**: Note the circumstances and any error messages
- **Build failures**: Include kernel version, distribution, and error output

Open an issue at: https://github.com/zbowling/mt7925/issues

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

## Code of Conduct

Please be respectful and constructive in all interactions. See
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details.

## License

By contributing, you agree that your contributions will be licensed under the
project's dual ISC/GPL-2.0 license. See [LICENSE](LICENSE) for details.

## Questions?

Open a discussion at: https://github.com/zbowling/mt7925/discussions
