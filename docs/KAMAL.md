# Deploying Rails with Kamal to this host

This host is built for **current Rails conventions**:

| Piece | Role |
|-------|------|
| App Dockerfile | Multi-stage production image (`rails new` default) |
| Kamal | Build, push, deploy, proxy, accessories |
| Thruster | HTTP proxy inside the app image (Rails default) |
| Solid Queue / Cache / Cable | Default queue/cache/cable backends |
| SQLite volumes **or** DB accessories | App-owned data plane |

The server only needs **Docker + SSH**. It does **not** install host Ruby, rbenv, or system PostgreSQL.

## App-side checklist

In your Rails app (8.x style):

1. `config/deploy.yml` — servers, image, proxy host, registry
2. `.kamal/secrets` — `KAMAL_REGISTRY_PASSWORD`, `RAILS_MASTER_KEY`, etc.
3. Working `Dockerfile` and `bin/docker-entrypoint` from `rails new`
4. This machine reachable on SSH (port 22) and later 80/443 from the public internet (or your LB)

### Minimal `deploy.yml` pieces

See also [config/deploy.snippet.yml](../config/deploy.snippet.yml).

```yaml
servers:
  web:
    - 203.0.113.10   # this host

proxy:
  ssl: true
  host: app.example.com

ssh:
  user: deploy
```

Use the same user bootstrap created (`deploy` by default). That user is in the `docker` group.

### First deploy

From a machine that can build/push images (often your laptop or CI):

```bash
bin/kamal setup    # installs Kamal proxy + prepares host
bin/kamal deploy
```

Kamal will SSH to the host and run Docker commands. No extra agent is installed by this repo.

## DNS and TLS

- Point `app.example.com` at the host’s public IP (A/AAAA).
- With `proxy.ssl: true`, Kamal’s proxy obtains certificates (Let’s Encrypt) — **ports 80 and 443 must be reachable** from the internet on this host (or your termination point).

## Multi-app

One arch-rails-server host can run multiple Kamal apps (different `service:` names and hostnames). Disk and RAM are the limits; monitor `docker system df` and `./bin/doctor`.

## What not to do on the host

- Do not install a host-level Puma/nginx “for the Rails app” unless you intentionally leave Kamal.
- Do not put production secrets in this git repo.
- Do not run `docker system prune -a` blindly on a host with live volumes you care about.

## Accessories (optional)

PostgreSQL, Redis, etc. can be Kamal **accessories** in `deploy.yml` (containers on this host or another). That stays in the app repo; this server only provides Docker.

## Smoke test without a full app

On the host:

```bash
docker run --rm hello-world
./bin/verify
```

From your laptop (after `kamal setup` once):

```bash
bin/kamal app exec 'bin/rails about'   # example once an app is deployed
```
