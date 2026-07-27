# archinstall profile

Use the official Arch ISO, then run **archinstall** with a configuration derived from this directory.

## Files

| File | Purpose |
|------|---------|
| [user_configuration.sample.json](user_configuration.sample.json) | Minimal server-oriented answers (no desktop) |
| [user_credentials.sample.json](user_credentials.sample.json) | Placeholder credentials — **never commit real passwords** |
| [user_disk_layout.notes.md](user_disk_layout.notes.md) | Disk layout is host-specific; generate on the machine |

## Recommended flow

On the live ISO:

```bash
# Optional: bring this repo onto the ISO environment
# (USB, git clone over network, or curl raw files)

cp user_configuration.sample.json user_configuration.json
# Edit hostname, locale, timezone, mirrors, packages as needed.
# Do NOT copy a disk layout from another machine blindly.

# Interactive (safest first time): guided install, then save config for next time.
archinstall

# Or semi-declarative once you have a real disk layout saved by archinstall:
# archinstall --config user_configuration.json --creds user_credentials.json --disk-layout user_disk_layout.json
```

After first successful install, archinstall can write the three JSON files it used — keep **credentials** off shared media.

## What this profile aims for

- **Minimal** profile (no DE/WM)
- **NetworkManager** or systemd-networkd (sample uses NetworkManager)
- **openssh**, **git**, **curl**, **sudo**, **vim** in `packages`
- **swap** enabled
- **NTP** on
- Hostname you choose (sample: `rails-host`)

Docker and Kamal host setup are **not** fully done in archinstall; run `./bin/bootstrap` after first boot (see [docs/INSTALL.md](../docs/INSTALL.md)).

## Danger

`disk_config` / disk layout options **wipe disks**. Always confirm the target device (`/dev/nvme0n1`, `/dev/sda`, …) on the machine in front of you.
