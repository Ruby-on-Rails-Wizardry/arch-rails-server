# Optional secrets baked into the ISO at build time

Copy this directory to `iso/secrets/` (gitignored) and add:

| File | Destination on live media |
|------|---------------------------|
| `authorized_keys` | `/opt/arch-rails-server/config/authorized_keys` |
| `defaults.env` | `/opt/arch-rails-server/config/defaults.env` |

```bash
mkdir -p iso/secrets
cp iso/secrets.example/authorized_keys.example iso/secrets/authorized_keys
# paste your real public keys
./bin/build-iso   # as root when ready
```

Never commit `iso/secrets/` with real keys.
