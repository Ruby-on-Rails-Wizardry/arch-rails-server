# Bootable USB media

Package **everything** for a bare-metal install onto one stick: Arch live environment + this kit + helpers.

## Overview

```
Build host (Arch)                         Target server
─────────────────                         ─────────────
iso/secrets/ (optional keys)
       │
       ▼
 ./bin/build-iso-docker   ──►  out/*.iso     (no host sudo; Docker)
   # or: sudo ./bin/build-iso
       │
       ├── ./bin/verify-iso                  (static extract checks)
       ├── ./bin/test-vm                     (QEMU KVM smoke, no sudo)
       │
       ▼
 sudo ./bin/make-usb /dev/sdX \
   --i-know-this-wipes-the-device
       │
       ▼
 boot USB ──► live root ──► archinstall ──► ars bootstrap-target ──► reboot
```

| Component | Location on live media |
|-----------|------------------------|
| Kit | `/opt/arch-rails-server` |
| Walkthrough | `less ~/README` (same file as `docs/LIVE.md`) |
| Helper | `ars help` / `ars readme` |
| MOTD | login banner pointing at `~/README` |

## Build host setup

### Rootless path (recommended for day-to-day)

Needs **Docker** (user in `docker` group) and, for VM tests, QEMU + OVMF:

```bash
# one-time (you run sudo once for packages)
sudo pacman -S --needed docker qemu-system-x86 edk2-ovmf \
  squashfs-tools libisoburn
# docker already running + your user in group docker
```

Then **no sudo** for build/test:

```bash
./bin/build-iso-docker    # privileged mkarchiso inside a container
./bin/verify-iso
./bin/test-vm             # KVM smoke; needs /dev/kvm readable
```

### Host mkarchiso path

```bash
sudo pacman -S --needed archiso squashfs-tools libisoburn dosfstools mtools
sudo ./bin/build-iso
```

`mkarchiso` always needs root **somewhere** (host or container).

Optional: bake SSH public keys into the image so bootstrap can harden SSH without a network clone. Same directory can hold a Phototherapy-style `wifi.yaml` so the live image AutoConnects to known SSIDs (`iwd`):

```bash
mkdir -p iso/secrets
cp iso/secrets.example/authorized_keys.example iso/secrets/authorized_keys
$EDITOR iso/secrets/authorized_keys   # real public keys only
# optional:
# cp config/defaults.env.example iso/secrets/defaults.env
# Household Wi-Fi (same file as Phototherapy_Timer; gitignored):
cp ~/UserHackable/Phototherapy_Timer/secrets/wifi.yaml iso/secrets/wifi.yaml
# Personal admin + keys for ars install:
cp iso/secrets.example/authorized_keys.example iso/secrets/authorized_keys
# paste your ed25519 public key
cp config/defaults.env.example iso/secrets/defaults.env
# set OPERATOR_USER=rob (or your login)
```

`iso/secrets/` is gitignored. `wifi.yaml` becomes `/var/lib/iwd/*.psk` on the **live** image only (not copied onto the installed host). Wired DHCP still comes up on its own when a cable has link; ethernet is preferred over Wi-Fi.

## Build the ISO

```bash
cd ~/Ruby-on-Rails-Wizardry/arch-rails-server
./bin/build-iso-docker
# → out/arch-rails-server-YYYY.MM.DD-x86_64.iso
# → out/arch-rails-server-latest.iso  (symlink)
```

Useful flags (passed through to `build-iso`):

| Flag | Meaning |
|------|---------|
| `--keep-work` | Keep `work/iso` for debugging |
| `--out DIR` | Alternate output directory |
| `--work DIR` | Alternate work directory |

Build time is dominated by package download/squashfs (often 10–30+ minutes depending on cache and CPU).

## Test without bare metal

```bash
./bin/verify-iso     # extract airootfs; assert kit + ars present
./bin/test-vm        # verify-iso + UEFI QEMU boot + `ars status` over serial
./bin/test-vm --interactive   # manual serial console
```

Live media enables **serial console** (`ttyS0`) and root autologin on that getty so headless CI/VM checks work.

## Write the USB stick

1. Plug in the stick and identify the **whole disk** (not a partition):

   ```bash
   lsblk -o NAME,SIZE,TYPE,RM,TRAN,MOUNTPOINT
   ```

2. Unmount any automounted partitions on that disk.

3. Write (this **erases** the device):

   ```bash
   sudo ./bin/make-usb /dev/sdX --i-know-this-wipes-the-device
   ```

Safety rails:

- Requires `--i-know-this-wipes-the-device`
- Refuses partitions (`/dev/sdb1`, `…p1`)
- Refuses the disk that backs `/`
- Refuses non-removable disks unless `--allow-non-removable`
- Refuses if any filesystem on the device is mounted
- Checks device size ≥ ISO size

Dry run:

```bash
sudo ./bin/make-usb /dev/sdX --i-know-this-wipes-the-device --dry-run
```

## On the target machine

1. Boot from USB (UEFI preferred; Secure Boot may need to be disabled depending on firmware).
2. Log in as `root` (Arch live default; empty password on stock releng — follow current Arch live docs).
3. Read the on-console walkthrough: `less ~/README` (also `ars readme`).
4. Preferred: `ars install` (hostname + disk, then unattended). Or confirm kit and network:

   ```bash
   ars status
   ars keys
   ```

5. Install the base system:

   ```bash
   archinstall
   # or: ars archinstall
   ```

   Use answers aligned with `archinstall/user_configuration.sample.json`. **Confirm the disk carefully.**

6. When archinstall finishes and the new root is still mounted at `/mnt` (or remount it):

   ```bash
   ars copy-to-target
   ars bootstrap-target
   ```

   That copies the kit to `/opt/arch-rails-server` on the new system and runs the Kamal/Docker bootstrap inside `arch-chroot`.

7. Reboot, remove the USB, SSH in as `deploy` (or root with keys), run:

   ```bash
   /opt/arch-rails-server/bin/verify
   ```

8. Point your Rails app’s Kamal `config/deploy.yml` at the host ([KAMAL.md](KAMAL.md)).

## Without baking keys

If you skipped `iso/secrets/authorized_keys`:

```bash
# on the live system before bootstrap-target
nano /opt/arch-rails-server/config/authorized_keys
# paste public keys
ars bootstrap-target
```

## Updating the stick

Rebuild and rewrite when bootstrap or docs change:

```bash
git pull
sudo ./bin/build-iso
sudo ./bin/make-usb /dev/sdX --i-know-this-wipes-the-device
```

There is no persistent “data partition” in the default hybrid ISO layout; the kit is inside the squashfs.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| `releng not found` | `pacman -S archiso` |
| `mkarchiso` permission errors | run `build-iso` with `sudo` |
| USB not bootable | UEFI vs BIOS mode; try another stick; verify `dd` finished (`sync`) |
| `make-usb` refuses device | use whole disk; unmount; check `RM`/`TRAN` with `lsblk` |
| No network in live | Cable: wait for DHCP (`ars status`). Wi-Fi: bake `iso/secrets/wifi.yaml` before build, or `iwctl` then retry |
| Locked out after bootstrap | console/IPMI; ensure keys were in `authorized_keys` before bootstrap |

## Size and contents

The image is based on official Arch **releng** (installer live) plus:

- Extra packages: `git`, `jq`, `rsync`, `nftables` (see `iso/overlay/packages.x86_64.add`)
- Full kit under `/opt/arch-rails-server` (repo without `.git` / build artifacts)
- `ars` / `ars-copy-to-target` helpers
- Optional iwd AutoConnect profiles from `iso/secrets/wifi.yaml`

Docker is **not** preinstalled on the live ISO; `bootstrap` installs it on the target host.
