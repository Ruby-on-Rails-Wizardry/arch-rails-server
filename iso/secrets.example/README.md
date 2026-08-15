# Optional secrets baked into the ISO at build time

Copy this directory to `iso/secrets/` (gitignored) and add:

| File | Destination on live media |
|------|---------------------------|
| `authorized_keys` | `/opt/arch-rails-server/config/authorized_keys` |
| `defaults.env` | `/opt/arch-rails-server/config/defaults.env` (`OPERATOR_USER`, hostname, timezone) |
| `wifi.yaml` | iwd profiles under `/var/lib/iwd/` (live AutoConnect only) |

`wifi.yaml` uses the same list shape as Phototherapy_Timer `secrets/wifi.yaml` (ssid + password). Household copy:

```bash
mkdir -p iso/secrets
cp ~/UserHackable/Phototherapy_Timer/secrets/wifi.yaml iso/secrets/wifi.yaml
```

Do **not** put `wifi.yaml` into the staged kit — only iwd profiles are baked, so `ars copy-to-target` does not copy passphrases onto the installed host.

```bash
mkdir -p iso/secrets
cp iso/secrets.example/authorized_keys.example iso/secrets/authorized_keys
# paste your real public keys
./bin/build-iso   # as root when ready
```

Never commit `iso/secrets/` with real keys.
