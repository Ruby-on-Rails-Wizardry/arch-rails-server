# Disk layout (host-specific)

Do **not** commit a real `user_disk_layout.json` for a production disk unless you intend it as a known lab fixture.

## Generate on the target

1. Boot the Arch ISO.
2. Run `archinstall` interactively once and choose disk partitioning carefully.
3. Use **Save configuration** when offered, or copy the files archinstall writes after a dry run / install.
4. Store the resulting layout privately (password manager, private USB, encrypted notes).

## Guidance for a Rails/Kamal host

| Concern | Suggestion |
|---------|------------|
| Filesystem | `ext4` or `btrfs` on `/` — both fine; btrfs helps snapshots |
| Separate `/var` | Optional; Docker stores under `/var/lib/docker` — ensure **plenty of free space** on that volume |
| Size | Prefer **≥ 40 GiB** free after install for images + volumes |
| Encryption | LUKS is fine for laptops/colo; for pure rack servers often skip for recovery simplicity |
| Swap | Enabled in the sample config (zstd) — adjust for RAM |

## After install

Reboot, log in, clone **arch-rails-server**, run `sudo ./bin/bootstrap`.
