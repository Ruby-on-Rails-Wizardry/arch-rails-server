#!/usr/bin/env bash
# Docker Engine for Kamal.

module_docker() {
  if [[ "${DOCKER_ENABLE}" != "1" ]]; then
    log "module: docker (skipped)"
    return 0
  fi
  log "module: docker"

  local pkgs=(docker)
  if [[ "${DOCKER_COMPOSE}" == "1" ]]; then
    pkgs+=(docker-compose)
  fi
  if [[ "${DOCKER_BUILDX}" == "1" ]]; then
    # Package name on Arch is docker-buildx
    pkgs+=(docker-buildx)
  fi

  pacman_install "${pkgs[@]}"

  # Sysctl forwarding before first docker start
  ensure_file \
    "${REPO_ROOT}/config/sysctl.d/99-arch-rails-server.conf" \
    /etc/sysctl.d/99-arch-rails-server.conf \
    0644
  sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-arch-rails-server.conf || true

  systemctl enable --now docker.service
  log "docker.service enabled and started"

  # Sanity: docker responds
  if ! docker info >/dev/null 2>&1; then
    die "docker installed but 'docker info' failed"
  fi

  log "docker version: $(docker version --format '{{.Server.Version}}' 2>/dev/null || docker version | head -1)"
}
