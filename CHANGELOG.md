# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Rootless media pipeline: `bin/build-iso-docker` (privileged Arch container, no host sudo), `bin/verify-iso` (xorriso/unsquashfs checks), `bin/test-vm` + `scripts/vm-smoke.py` (UEFI QEMU/KVM serial smoke), serial console + root autologin on live image for headless tests.
- Bootable live media: archiso-based `bin/build-iso` (embeds kit at `/opt/arch-rails-server`), `bin/make-usb` with wipe safety rails, live `ars` helper, optional `iso/secrets/` bake-in, and [docs/USB.md](docs/USB.md).
- Initial repo: archinstall minimal-server profile template, idempotent Docker/Kamal bootstrap, firewall/sysctl/sshd drop-ins, doctor/verify scripts, install and Kamal docs.
