# Live ISO / USB media

This directory customizes the official **archiso `releng`** profile so a single bootable stick carries:

- A normal Arch live environment (`archinstall`, networking, disk tools)
- This repo at **`/opt/arch-rails-server`**
- Console walkthrough at **`~/README`** (`docs/LIVE.md`)
- Live helpers: **`ars`** (see `overlay/airootfs/usr/local/bin/ars`)

## Build machine requirements

```bash
# Arch host (not the target server)
sudo pacman -S --needed archiso squashfs-tools libisoburn dosfstools mtools
```

Root is required for `mkarchiso` (and for writing a USB).

## Quick commands

```bash
# From repo root — produces out/arch-rails-server-YYYY.MM.DD-x86_64.iso
sudo ./bin/build-iso

# Write the newest ISO to a USB stick (WIPES THE DEVICE)
sudo ./bin/make-usb /dev/sdX --i-know-this-wipes-the-device
```

Details: [docs/USB.md](../docs/USB.md).

## Overlay layout

| Path | Purpose |
|------|---------|
| [overlay/](overlay/) | Merged into a copy of `/usr/share/archiso/configs/releng` |
| [secrets/](secrets/) | Optional **local** keys/env/wifi baked into the image at build time (gitignored) |
| [secrets.example/](secrets.example/) | Templates for `iso/secrets/` (`authorized_keys`, `defaults.env`, `wifi.yaml`) |

Do not commit real keys under `iso/secrets/`.
