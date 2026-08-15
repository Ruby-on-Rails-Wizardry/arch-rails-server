# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Automated live install: `ars install` asks hostname + disk, then runs silent archinstall, copies the kit, and bootstraps. Creates `OPERATOR_USER` (personal admin) plus `deploy`, and installs the same `authorized_keys` on that user, deploy, and root.
- Live-console walkthrough: `docs/LIVE.md` shown as `~/README` after login (`less ~/README` / `ars readme`); MOTD points at it.
- Live ISO can AutoConnect to known Wi-Fi: bake Phototherapy-style `iso/secrets/wifi.yaml` into iwd profiles (`scripts/wifi-yaml-to-iwd.sh`). Wired DHCP is unchanged. Passphrases stay off the installed kit.
- Rootless media pipeline: `bin/build-iso-docker` (privileged Arch container, no host sudo), `bin/verify-iso` (xorriso/unsquashfs checks), `bin/test-vm` + `scripts/vm-smoke.py` (UEFI QEMU/KVM serial smoke), serial console + root autologin on live image for headless tests.
- Bootable live media: archiso-based `bin/build-iso` (embeds kit at `/opt/arch-rails-server`), `bin/make-usb` with wipe safety rails, live `ars` helper, optional `iso/secrets/` bake-in, and [docs/USB.md](docs/USB.md).
- Initial repo: archinstall minimal-server profile template, idempotent Docker/Kamal bootstrap, firewall/sysctl/sshd drop-ins, doctor/verify scripts, install and Kamal docs.
