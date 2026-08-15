# Install on bare metal

End-to-end path from empty machine to Kamal-ready Arch host.

**Prefer one stick with everything included?** Use **[USB.md](USB.md)** (`build-iso` + `make-usb` + live `ars` helper). This page covers the classic “official Arch ISO + clone repo” path as well as post-install bootstrap shared by both flows.

## 0. Prerequisites

- Target machine can boot USB/ISO
- Network (DHCP is fine)
- Your SSH **public** key ready
- Familiarity with wiping the install disk

## 1. Boot install media

### Option A — arch-rails-server USB (recommended)

See [USB.md](USB.md). After boot, `less ~/README` (same text as [LIVE.md](LIVE.md)):

```bash
ars install
# or the longer path:
# ars status && archinstall && ars copy-to-target && ars bootstrap-target
# then reboot and continue from "6. Point a Rails app" below
```

### Option B — official Arch ISO

1. Download the latest ISO from <https://archlinux.org/download/>.
2. Write it to USB (`dd`, `balenaEtcher`, `ddrescue`, …).
3. Boot the new server from that media (UEFI recommended).
4. If wired network is up: `ping -c1 archlinux.org`. On the custom USB, `ars status` also reports baked iwd SSIDs; join by hand with `iwctl` if none were baked.

## 2. Base install with archinstall

See [archinstall/README.md](../archinstall/README.md).

Suggested approach for the first machine:

```bash
archinstall
```

Use answers aligned with [user_configuration.sample.json](../archinstall/user_configuration.sample.json):

| Setting | Value |
|---------|--------|
| Profile | Minimal |
| Bootloader | systemd-boot (UEFI) or GRUB |
| Network | NetworkManager |
| Hostname | e.g. `rails-host` |
| Root password | strong, stored in your password manager |
| User | `deploy` with sudo |
| Packages | openssh, git, curl, sudo, vim, nftables, … (sample list) |
| Timezone | your TZ or `UTC` |
| Swap | on |

**Disk:** select the correct disk only. This erases it.

Enable **sshd** so you can finish setup over the network after reboot.

Optional: save the generated configuration files for the next identical box (keep credentials private).

## 3. First boot

```bash
# console or SSH as deploy / root
sudo pacman -Syu
```

Install git if missing, then get this repo onto the host:

```bash
sudo pacman -S --needed git
git clone git@github.com:Ruby-on-Rails-Wizardry/arch-rails-server.git
# or HTTPS:
# git clone https://github.com/Ruby-on-Rails-Wizardry/arch-rails-server.git
cd arch-rails-server
```

## 4. Configure bootstrap

```bash
cp config/defaults.env.example config/defaults.env
cp config/authorized_keys.example config/authorized_keys
# paste your ed25519/rsa public key into config/authorized_keys
$EDITOR config/defaults.env   # optional tweaks
```

## 5. Bootstrap (Docker + firewall + keys)

```bash
sudo ./bin/bootstrap
./bin/doctor
./bin/verify
```

Open a **second** SSH session as `deploy` before you close the first, to confirm key login after hardening.

## 6. Point a Rails app at the host

See [KAMAL.md](KAMAL.md).

## 7. Ongoing

```bash
cd arch-rails-server && git pull
sudo ./bin/bootstrap   # idempotent
./bin/verify
```

## Lab / VM note

The same flow works in libvirt, VMware, or VirtualBox. Give the VM **≥ 4 GiB RAM** and **≥ 40 GiB disk** if you will pull real app images.
