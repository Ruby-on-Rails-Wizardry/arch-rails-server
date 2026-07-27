# Agent notes — arch-rails-server

## Purpose

Bare-metal **Arch** host for **Rails + Kamal + Docker**. Not a dev image (that is `arch-mise`).

## Conventions

- Prefer **minimal, focused diffs**. Do not add Capistrano, host Ruby, or host PostgreSQL unless explicitly requested.
- Bootstrap must stay **idempotent** (`./bin/bootstrap` safe to re-run).
- Never commit secrets: passwords, private keys, real `user_credentials.json` values, or live host inventories with credentials.
- Disk layout in archinstall is **machine-specific** — keep samples clearly marked and never wipe disks in docs without loud warnings.
- Match Ruby-on-Rails-Wizardry remote style: **`github`** (canonical) + **`gitlab`** (backup).

## Stack truth

| Concern | Choice |
|---------|--------|
| Deploy | Kamal (Rails 8 default) |
| Runtime | Docker Engine (rootful) |
| Proxy ports | 80 / 443 (Kamal proxy / Thruster in containers) |
| App DB | App-owned (Solid SQLite volumes or Kamal accessories) — not this host’s pacman packages |
| Firewall | nftables |
| Init | systemd |

## Touch points

| Path | When |
|------|------|
| `bootstrap/lib/*.sh` | Package sets, service enablement, user/firewall logic |
| `config/` | Drop-in files installed by bootstrap |
| `archinstall/` | Base install profile only |
| `iso/overlay/` | Live ISO MOTD, `ars` helper, extra packages |
| `bin/build-iso` / `bin/make-usb` | Media build/write safety and staging |
| `docs/KAMAL.md` / `docs/USB.md` | When Kamal or media flow changes |
| `CHANGELOG.md` | User-visible behavior |

## Live ISO notes

- Prefer `./bin/build-iso-docker` (root only inside container). Host `sudo ./bin/build-iso` is the fallback.
- Test with `./bin/verify-iso` and `./bin/test-vm` (no sudo; needs KVM + OVMF).
- Never commit `iso/secrets/` or `out/` or `work/`.
- Keep live package extras lean (`iso/overlay/packages.x86_64.add`); Docker belongs on the target via bootstrap.
- `make-usb` must keep wipe safety rails (whole-disk only, explicit flag, refuse `/` disk).

## Verify before shipping

```bash
# On a target host (or after bootstrap in a VM):
./bin/doctor
./bin/verify
```

Do not claim a host is production-ready without `./bin/verify` passing.

## Releases

Follow [docs/RELEASE.md](docs/RELEASE.md). Phrases **send it** / **ship it** / **cut a release** mean that checklist end-to-end.
