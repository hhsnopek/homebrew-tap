# hhsnopek/tap

Homebrew formulae for my own tools.

```
brew install hhsnopek/tap/utc-clock
brew services start utc-clock
```

| Formula | What it is |
|---|---|
| `utc-clock` | A menu bar clock that shows UTC and copies an RFC 3339 timestamp, built from source |
| `tailscale` | Homebrew core's tailscale with [tailscale/tailscale#18202](https://github.com/tailscale/tailscale/pull/18202), so tailscaled on macOS can use exit nodes and keeps the Wi-Fi route when one is cleared |

The `tailscale` formula replaces core's, since both install the same commands and service: `brew uninstall tailscale`, then `brew install hhsnopek/tap/tailscale`. A daily workflow merges the patch onto each new Tailscale release and opens a pull request when the router tests and the build pass, or an issue when the patch needs a person.
