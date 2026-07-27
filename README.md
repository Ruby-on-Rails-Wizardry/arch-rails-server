# arch-rails-server

Bare-metal **Arch Linux** host build for deploying **Rails** the current way: **Kamal** + **Docker** + the stock Rails Dockerfile (Thruster, Solid Queue/Cache/Cable, SQLite or accessories).

This is a **production host**, not a development image. For Arch + mise dev containers, see [arch-mise](https://github.com/Ruby-on-Rails-Wizardry/arch-mise).

## What you get

| Layer | Role |
|-------|------|
| [archinstall/](archinstall/) | Declarative base install (minimal server, SSH, disk left for you to set) |
| [bootstrap/](bootstrap/) | Post-install hardening: Docker Engine, firewall, deploy user, sysctl |
| [docs/](docs/) | Install walkthrough + Kamal wiring for Rails apps |

After bootstrap, the machine is ready for:

```bash
# from your Rails app
bin/kamal setup
bin/kamal deploy
```

## Quick path

1. Boot the official [Arch ISO](https://archlinux.org/download/) on the new server.
2. Customize and run **archinstall** with this repo’s profile (see [docs/INSTALL.md](docs/INSTALL.md)).
3. Reboot into the new system, clone this repo (or copy `bootstrap/`), run:

   ```bash
   sudo ./bin/bootstrap
   ```

4. Point your app’s `config/deploy.yml` `servers:` at the host IP/DNS and deploy with Kamal.

## Requirements

- **x86_64** (or aarch64 if you adjust packages/kernel — documented as experimental)
- Bare metal (or VM) with network access during install
- At least **20 GiB** disk recommended (images + volumes grow quickly)
- Outbound HTTPS for `pacman` and container registries

## Host layout (defaults)

| Item | Default |
|------|---------|
| Hostname | set in archinstall config |
| Deploy user | `deploy` (docker group, passwordless sudo for bootstrap tasks only if configured) |
| SSH | key-only recommended; port 22 |
| Docker | `docker.service` enabled; rootless **not** used (Kamal expects classic Docker) |
| Firewall | `nftables`: allow 22, 80, 443 |
| App data | Docker volumes under `/var/lib/docker` (back up volumes you care about) |

Override via `config/defaults.env` (see `config/defaults.env.example`).

## Repo layout

```
archinstall/     # user_configuration.json template + notes
bootstrap/       # post-install modules
config/          # env, sshd drop-in, nftables, sysctl
bin/             # bootstrap, verify, doctor, setup-remotes
docs/            # INSTALL, KAMAL, HARDENING, RELEASE
```

## Day-to-day

```bash
./bin/doctor          # read-only host health
./bin/verify          # assert Kamal host prerequisites
sudo ./bin/bootstrap  # idempotent; safe to re-run after git pull
```

## Remotes

| Name | Role | URL |
|------|------|-----|
| **github** | canonical | `git@github.com:Ruby-on-Rails-Wizardry/arch-rails-server.git` |
| **gitlab** | backup | `git@gitlab.com:ruby-on-rails-wizardry/arch-rails-server.git` |

```bash
./bin/setup-remotes
git push github master && git push gitlab master
```

## Releases

See [docs/RELEASE.md](docs/RELEASE.md). History: [CHANGELOG.md](CHANGELOG.md).

Agent/human shortcuts **send it** / **ship it** / **cut a release** mean run that process end-to-end when a version is ready.

## License

MIT — see [LICENSE](LICENSE).
