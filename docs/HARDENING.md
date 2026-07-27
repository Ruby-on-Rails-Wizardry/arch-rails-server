# Hardening notes

Bootstrap applies a **practical** baseline for a single-tenant Kamal host. It is not a full CIS benchmark.

## Applied by default

| Control | Mechanism |
|---------|-----------|
| SSH keys | `config/authorized_keys` → deploy (and optional root) |
| Password SSH | Off via sshd drop-in |
| Root SSH | `prohibit-password` (keys only) |
| Host INPUT | nftables table `arch_rails_server` — allow 22/80/443 |
| Kernel | IP forwarding + common anti-redirect sysctls |
| Deploy sudo | Limited to docker systemctl actions |

## Docker and firewalls

Docker manages its own iptables/nftables rules for published ports. This project:

- Uses a **dedicated** nftables table (does not `flush ruleset`)
- Does **not** set a global `forward` drop policy that would break bridge networking

If you add another firewall tool (UFW, firewalld), resolve conflicts carefully or set `FIREWALL_ENABLE=0` and manage policy yourself.

## Recommended follow-ups

- **fail2ban** or **sshguard** for SSH brute-force (optional package)
- Automatic security updates: `pacman` via a timed systemd unit or `arch-audit` alerts — decide operationally; Arch is rolling
- Restrict SSH by `AllowUsers deploy` in a local drop-in
- Off-host backups of Docker volumes (`docker run --rm -v …` + restic/borg)
- Separate **builder** host if you do not want build load on the app server
- Unattended physical/console access policy for colo/rack

## Secrets

Never store in git:

- `user_credentials.json` with real passwords
- Private SSH keys
- Registry tokens
- `RAILS_MASTER_KEY` / Kamal secrets

## Recovery

Keep a console (IPMI/iKVM/cloud serial) path if you lock yourself out of SSH. Test a second SSH session after every bootstrap that changes sshd.
