#!/usr/bin/env python3
"""Write archinstall --config / --creds JSON for a UEFI whole-disk install."""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from pathlib import Path

MIB = 1024 * 1024
GIB = 1024 * 1024 * 1024
MIN_DISK = 16 * GIB
BOOT_START = 1 * MIB
BOOT_SIZE = 1024 * MIB
GPT_RESERVE = 1 * MIB


def size_block(value: int) -> dict:
    return {
        "sector_size": {"unit": "B", "value": 512},
        "unit": "B",
        "value": value,
    }


def write_configs(args: argparse.Namespace) -> None:
    disk_b = int(args.disk_size_bytes)
    if disk_b < MIN_DISK:
        raise SystemExit(f"disk {args.disk} is too small ({disk_b} bytes); need >= 16 GiB")

    root_start = BOOT_START + BOOT_SIZE
    aligned = (disk_b // MIB) * MIB
    root_size = aligned - root_start - GPT_RESERVE
    if root_size < 12 * GIB:
        raise SystemExit("not enough space after ESP for root filesystem")

    users = []
    for name in (args.operator, args.deploy):
        if not name:
            continue
        if any(u["username"] == name for u in users):
            continue
        users.append(
            {
                "username": name,
                "enc_password": args.password_hash,
                "sudo": True,
                "groups": [],
            }
        )
    if not users:
        raise SystemExit("need --operator and/or --deploy")

    creds = {
        "root_enc_password": args.password_hash,
        "users": users,
    }

    config = {
        "archinstall-language": "English",
        "audio_config": None,
        "bootloader_config": {
            "bootloader": "Systemd-boot",
            "uki": False,
            "removable": False,
        },
        "debug": False,
        "disk_config": {
            "config_type": "default_layout",
            "device_modifications": [
                {
                    "device": args.disk,
                    "wipe": True,
                    "partitions": [
                        {
                            "btrfs": [],
                            "dev_path": None,
                            "flags": ["boot", "esp"],
                            "fs_type": "fat32",
                            "size": size_block(BOOT_SIZE),
                            "mount_options": [],
                            "mountpoint": "/boot",
                            "obj_id": str(uuid.uuid4()),
                            "start": size_block(BOOT_START),
                            "status": "create",
                            "type": "primary",
                        },
                        {
                            "btrfs": [],
                            "dev_path": None,
                            "flags": [],
                            "fs_type": "ext4",
                            "size": size_block(root_size),
                            "mount_options": [],
                            "mountpoint": "/",
                            "obj_id": str(uuid.uuid4()),
                            "start": size_block(root_start),
                            "status": "create",
                            "type": "primary",
                        },
                    ],
                }
            ],
        },
        "hostname": args.hostname,
        "kernels": ["linux"],
        "locale_config": {
            "kb_layout": "us",
            "sys_enc": "UTF-8",
            "sys_lang": "en_US",
        },
        "mirror_config": {
            "custom_servers": [],
            "mirror_regions": {},
            "optional_repositories": [],
            "custom_repositories": [],
        },
        "network_config": {"type": "nm"},
        "no_pkg_lookups": False,
        "ntp": True,
        "offline": False,
        "packages": [
            "openssh",
            "git",
            "curl",
            "sudo",
            "vim",
            "base-devel",
            "wget",
            "rsync",
            "jq",
            "nftables",
        ],
        "pacman_config": {"parallel_downloads": 5},
        "profile_config": {
            "gfx_driver": None,
            "greeter": None,
            "profile": {"details": [], "main": "Minimal"},
        },
        "script": "guided",
        "silent": True,
        "swap": {"enabled": True, "algorithm": "zstd"},
        "timezone": args.timezone,
        "services": ["sshd", "NetworkManager"],
        "version": "3.0.2",
    }

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / "user_configuration.json").write_text(json.dumps(config, indent=2) + "\n")
    (out / "user_credentials.json").write_text(json.dumps(creds, indent=2) + "\n")
    print(f"wrote {out / 'user_configuration.json'}")
    print(f"wrote {out / 'user_credentials.json'}")


def self_test() -> None:
    import tempfile

    tmp = Path(tempfile.mkdtemp())
    ns = argparse.Namespace(
        disk="/dev/nvme0n1",
        disk_size_bytes=64 * GIB,
        hostname="rails-host",
        timezone="UTC",
        operator="rob",
        deploy="deploy",
        password_hash="$6$testhash",
        out_dir=str(tmp),
    )
    write_configs(ns)
    cfg = json.loads((tmp / "user_configuration.json").read_text())
    creds = json.loads((tmp / "user_credentials.json").read_text())
    assert cfg["hostname"] == "rails-host"
    assert cfg["silent"] is True
    assert cfg["disk_config"]["device_modifications"][0]["wipe"] is True
    names = [u["username"] for u in creds["users"]]
    assert names == ["rob", "deploy"]
    print("self-test: ok")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--disk", required=False)
    p.add_argument("--disk-size-bytes", type=int)
    p.add_argument("--hostname", default="rails-host")
    p.add_argument("--timezone", default="UTC")
    p.add_argument("--operator", default="")
    p.add_argument("--deploy", default="deploy")
    p.add_argument("--password-hash", default="")
    p.add_argument("--out-dir", default=".")
    p.add_argument("--self-test", action="store_true")
    args = p.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.disk or not args.disk_size_bytes or not args.password_hash:
        p.error("--disk, --disk-size-bytes, and --password-hash are required")
    write_configs(args)


if __name__ == "__main__":
    sys.exit(main())
