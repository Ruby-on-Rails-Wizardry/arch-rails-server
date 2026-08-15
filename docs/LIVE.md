# arch-rails-server — live media walkthrough

You have booted the installer stick. This is a **live** Arch
environment with the kit already on disk. It does **not** wipe a
disk until you confirm.

Login: `root` (empty password on stock live media).

This file on the live system: `less ~/README`  
Same text in the kit: `less /opt/arch-rails-server/docs/LIVE.md`  
Helper: `ars help`

------------------------------------------------------------------------

## Automated install (preferred)

Needs **UEFI**, a network, and `config/authorized_keys` staged
(baked from `iso/secrets/authorized_keys`).

```bash
ars status          # network + keys + operator/deploy names
ars install         # asks hostname and which disk, then YES to wipe
```

That runs archinstall unattended, copies the kit, and bootstraps
Docker / firewall / SSH keys. It creates:

| Account | Role |
|---------|------|
| `OPERATOR_USER` (e.g. `rob`) | Personal admin, key login, passwordless sudo |
| `deploy` | Kamal / Docker |
| `root` | Key login (`prohibit-password`) |

The same `authorized_keys` file is installed for all three.

It will ask:

1. **Hostname** (unless `HOSTNAME` is set and `ASK_HOSTNAME=0`)
2. **Which disk to wipe** (USB stick is hidden). Type `YES`.

Then sit back. Write down the **console password** it prints
(local TTY only; SSH is keys).

```bash
reboot
# remove USB, then:
ssh rob@<hostname>
/opt/arch-rails-server/bin/verify
```

Set `OPERATOR_USER` / `TIMEZONE` in `iso/secrets/defaults.env` before
building the ISO.

## What is already done

- Kit at `/opt/arch-rails-server`
- Wired DHCP if a cable has link
- Wi-Fi AutoConnect only if this image was built with
  `iso/secrets/wifi.yaml` (check with `ars status`)
- `sshd` is running on the *live* system (you can work over the
  network once you have an address)

## Manual path

Use this on BIOS machines or when you need a custom disk layout.

### 1. Status

```bash
ars status
ars keys
ip -br a
```

Need a network. `ars status` should say `network: ok`.

**No cable, no Wi-Fi yet:**

```bash
iwctl
# station list
# station wlan0 scan
# station wlan0 get-networks
# station wlan0 connect 'YourSSID'
```

Then `ars status` again.

**No SSH public keys staged** (`ars keys` fails): paste them before
bootstrap or you can lock yourself out after hardening.

```bash
nano /opt/arch-rails-server/config/authorized_keys
# one OpenSSH public key per line
```

------------------------------------------------------------------------

## 2. Install the base system

```bash
lsblk -o NAME,SIZE,TYPE,TRAN,MOUNTPOINT
archinstall
```

Suggested answers (also in
`/opt/arch-rails-server/archinstall/user_configuration.sample.json`):

| Prompt        | Use                          |
|---------------|------------------------------|
| Profile       | Minimal                      |
| Bootloader    | systemd-boot (UEFI) or GRUB  |
| Network       | NetworkManager               |
| Hostname      | e.g. `rails-host`            |
| Root password | strong; store it             |
| User          | `deploy` with sudo           |
| Additional    | openssh git curl sudo vim    |
|               | nftables rsync jq            |
| Timezone      | yours, or `UTC`              |
| Swap          | on                           |
| Services      | enable **sshd**              |

**Disk:** only the intended install disk. This wipes it.

Do **not** feed this machine a disk layout copied from another box
unless you have just verified the device names.

Leave the new system mounted at `/mnt` when archinstall finishes
(usual if you skip the immediate reboot). If you already rebooted
into the live USB again:

```bash
# mount the new root at /mnt (and EFI at /mnt/boot if needed), then:
ls /mnt/etc
```

------------------------------------------------------------------------

## 3. Kit + bootstrap (still in the live session)

```bash
ars copy-to-target
ars bootstrap-target
```

That copies the kit to `/mnt/opt/arch-rails-server` and runs
Docker, firewall (22/80/443), deploy user, and SSH hardening
inside `arch-chroot`.

If keys were missing, add them and re-run `ars bootstrap-target`
(bootstrap is safe to repeat).

------------------------------------------------------------------------

## 4. Reboot into the new host

```bash
reboot
```

Remove the USB so firmware boots the disk. Log in as `deploy` or
`root` (console or SSH with your key).

```bash
/opt/arch-rails-server/bin/verify
```

All checks should pass before you treat the box as Kamal-ready.

Point a Rails app at this host: `less /opt/arch-rails-server/docs/KAMAL.md`

------------------------------------------------------------------------

## Commands

| Command                 | What it does                          |
|-------------------------|---------------------------------------|
| `ars help`              | Helper summary                        |
| `ars status`            | Kit, network, Wi-Fi, keys, `/mnt`     |
| `ars keys`              | Whether authorized_keys is staged     |
| `ars archinstall`       | Sample config path + reminder         |
| `ars copy-to-target`    | Kit → `/mnt/opt/arch-rails-server`    |
| `ars bootstrap-target`  | `arch-chroot /mnt` + `bin/bootstrap`  |
| `ars docs LIVE`         | This walkthrough                      |
| `ars docs INSTALL`      | Full install notes (clone path too)   |
| `ars docs USB`          | How the stick was built               |
| `ars docs KAMAL`        | After the host is up                  |
| `ars docs HARDENING`    | SSH / firewall notes                  |

------------------------------------------------------------------------

## If something is wrong

| Symptom                         | What to try                                      |
|---------------------------------|--------------------------------------------------|
| `network: no ping`              | Cable / DHCP wait; or `iwctl` as above           |
| Wi-Fi radio up, no join         | No baked `wifi.yaml`; join with `iwctl`          |
| `ars keys` missing              | Edit `config/authorized_keys`, then bootstrap    |
| `/mnt` not ready                | Finish archinstall or remount the new root       |
| Locked out after reboot         | Console or IPMI; keys must exist before bootstrap |
| Secure Boot blocked the USB     | Disable Secure Boot or enroll your own keys      |

More detail: `less /opt/arch-rails-server/docs/USB.md`
