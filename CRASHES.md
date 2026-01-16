# MT7925 Crash Log

## 2026-01-15 21:18 - Hard Lockup

**Conditions:**
- Connected to tri-band MLO (2.4 + 5 + 6 GHz simultaneously)
- Just switched connection profiles between networks
- Testing 6GHz connectivity

**Symptoms:**
- Complete system freeze (hard lockup)
- No kernel panic logged
- Required hard reboot

**Possible causes:**
- MLO link switching on 6GHz
- Driver state machine issue with tri-band MLO
- 6GHz regulatory/channel switching

**Last logs before crash:**
```
Jan 15 21:18:06 - Chrome crash report directory error (unrelated)
```

No WiFi-related errors logged before crash.

See also: [docs/6ghz-mlo-workaround.md](docs/6ghz-mlo-workaround.md)
