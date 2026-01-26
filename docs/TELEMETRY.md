# Building Privacy-Respecting Telemetry for a WiFi Driver

*How I implemented opt-in telemetry for the MT7925 DKMS package while respecting user privacy and handling the unique challenge of replacing the very network hardware needed to send telemetry.*

## The Problem

I maintain a DKMS package that fixes critical bugs in the MediaTek MT7925 WiFi driver. Users download it, run the installer, and (hopefully) their WiFi stops crashing. But I had no visibility into:

- How many people are actually using this?
- Which distros and kernel versions are common?
- What percentage of installs fail, and why?
- Are people using MT7925 or MT7921 chipsets?
- PCIe, USB, or SDIO interfaces?

Without this data, I was flying blind. Bug reports are great, but they're biased toward failures. I needed to understand the full picture.

## Design Principles

Before writing any code, I established some ground rules:

### 1. Opt-In by Default

Unlike many projects that use opt-out telemetry, I wanted explicit consent. During installation, users see:

```
Enable telemetry? [y/N]
```

The default is **No**. Users have to actively choose to help. This is more conservative than Homebrew or .NET CLI (both opt-out), but I think it's the right approach for a kernel driver that people install to fix crashes.

### 2. No Personal Data

I defined a strict list of what's acceptable:

**Collected:**
- Kernel version (`6.18.7-2-cachyos`)
- Distro name (`Arch Linux`)
- Chip type (`mt7925` or `mt7921`)
- Bus type (`pcie`, `usb`, `sdio`)
- PCI device ID (`[14c3:7925]`)
- Whether clang was used to build (`true`/`false`)
- Install duration and result

**Never collected:**
- IP addresses
- MAC addresses
- Hostnames or usernames
- File contents or paths
- Anything that could identify a specific user

### 3. Transparent Implementation

The telemetry code is in plain bash, readable by anyone. The API key is write-only (can send events but can't read them back), so it's safe to embed in public code.

## The Network Problem

Here's the interesting challenge: the installer *replaces the WiFi driver*. The typical flow is:

1. User runs `install.sh`
2. Script unloads existing mt76 modules → **WiFi goes down**
3. Script builds and installs new modules
4. Script loads new modules → **WiFi comes back up (eventually)**
5. Script tries to send telemetry → **Network might not be ready**

If I tried to send telemetry at the end of a successful install, there's a good chance the network isn't back yet. The new driver needs time to:
- Initialize the hardware
- Scan for networks
- Reconnect to the previous network
- Get an IP address

This could take 5-30 seconds depending on the network environment.

### Solution: Wait + Queue

I implemented a two-part solution:

**1. Network Wait Function**

```bash
wait_for_network() {
    local max_wait="${1:-30}"
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        if curl -s --max-time 3 -o /dev/null "https://us.i.posthog.com/"; then
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
    done
    return 1
}
```

For success telemetry, the script waits up to 30 seconds for the network to come back.

**2. Event Queue**

If the network isn't available (or the curl fails), events are queued to a file:

```
/var/lib/mt7925-telemetry-queue
```

Each event is stored as a JSON line. The next time the user runs `install.sh` (for an upgrade, for example), the script sends any queued events before starting the new install.

**3. Smart Timing**

- `install_started` → Sent immediately (network is still up)
- `install_success` → Wait for network, queue if unavailable
- `install_failure` → Try immediately (might work for early failures), queue if not

This means even if a successful install can't send telemetry, I'll get the data on the next interaction.

## Session Tracking

To correlate start and end events, I generate a session ID at the beginning of each script:

```bash
SESSION_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N | sha256sum | head -c 32)
SESSION_START=$(date +%s)
```

Every event includes:
- `session_id` - Links `install_started` to `install_success/failure`
- `duration_seconds` - Time since script started

This lets me answer questions like:
- What percentage of started installs complete successfully?
- How long do installs typically take?
- Do failures happen early (dependency check) or late (build/load)?

## Hardware Detection

I wanted to know what hardware people are using. The detection is straightforward:

```bash
detect_hardware_info() {
    # PCIe devices (most common)
    if lspci -nn 2>/dev/null | grep -qi "14c3:7925"; then
        echo "mt7925:pcie"
    elif lspci -nn 2>/dev/null | grep -qi "14c3:7921"; then
        echo "mt7921:pcie"
    # USB devices
    elif lsusb 2>/dev/null | grep -qi "0e8d:7961"; then
        echo "mt7921:usb"
    # SDIO devices
    elif [[ -d /sys/bus/sdio/devices ]] && ...; then
        echo "mt7921:sdio"
    else
        echo "unknown:unknown"
    fi
}
```

I also detect whether the kernel was built with clang:

```bash
detect_uses_clang() {
    if grep -q "CONFIG_CC_IS_CLANG=y" "/lib/modules/$(uname -r)/build/.config" 2>/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}
```

This is useful because clang-built kernels require clang+lld to build DKMS modules, and I want to know how common this is.

## Choosing a Backend

I evaluated several options:

| Service | Pros | Cons |
|---------|------|------|
| GoatCounter | Privacy-first, simple | API needs secret token, pixel endpoint filters CLI requests |
| Sentry | Great for errors, OSS-friendly | Overkill for simple events |
| Plausible | No token needed | No free tier, web-focused |
| PostHog | Write-only keys, 1M events free | More features than needed |

I went with **PostHog** because:

1. **Write-only API keys** - The `phc_*` keys can only send events, not read them. Safe to embed in public bash scripts.
2. **No filtering of CLI requests** - Unlike GoatCounter's pixel endpoint, PostHog accepts all curl requests.
3. **Generous free tier** - 1M events/month is plenty for an open source project.
4. **Good HTTP API** - Simple JSON POST, perfect for bash.

## The Final Implementation

Here's what an event looks like:

```json
{
  "api_key": "phc_...",
  "event": "install_success",
  "distinct_id": "anonymous",
  "properties": {
    "kernel": "6.18.7-2-cachyos",
    "distro": "CachyOS",
    "chip": "mt7925",
    "bus_type": "pcie",
    "hardware": "[14c3:7925]",
    "uses_clang": true,
    "version": "1.4.1",
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "duration_seconds": 47,
    "error_type": "none"
  }
}
```

## What I Can Learn

With this data, I can answer:

- **Completion rate**: What % of `install_started` have a matching `install_success`?
- **Failure modes**: Which `error_type` values are most common?
- **Duration distribution**: How long do installs take? Are some distros slower?
- **Hardware breakdown**: MT7925 vs MT7921? PCIe vs USB?
- **Toolchain usage**: How many users have clang-built kernels?
- **Distro coverage**: Am I testing on the distros people actually use?

## Lessons Learned

1. **Opt-in is worth it.** Yes, you get less data. But the data you get comes from users who actively want to help, and you don't have to worry about privacy backlash.

2. **Think about your network situation.** If your installer touches networking, you need to handle the case where telemetry can't be sent immediately.

3. **Queue events for reliability.** A simple file-based queue handles offline/failed sends gracefully.

4. **Session IDs are powerful.** Correlating start/end events gives you funnel analysis for free.

5. **Keep it simple.** Bash + curl + JSON is all you need. No SDKs, no dependencies.

## Try It Yourself

If you're using the MT7925 driver package, consider enabling telemetry when prompted. It really does help me improve the project.

```bash
cd dkms
sudo ./install.sh
# When prompted: "Enable telemetry? [y/N]" → y
```

Your data helps me know what's working and what needs attention. Thanks for reading!

---

*The full telemetry implementation is in [dkms/install.sh](../dkms/install.sh) and [dkms/uninstall.sh](../dkms/uninstall.sh).*
