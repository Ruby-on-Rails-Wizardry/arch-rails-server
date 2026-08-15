#!/usr/bin/env bash
# Shared helpers for bootstrap modules.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "run as root (e.g. sudo ./bin/bootstrap)"
  fi
}

load_defaults() {
  # shellcheck disable=SC1091
  if [[ -f "${REPO_ROOT}/config/defaults.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${REPO_ROOT}/config/defaults.env"
    set +a
    log "loaded config/defaults.env"
  else
    log "no config/defaults.env; using built-in defaults (see config/defaults.env.example)"
  fi

  : "${DEPLOY_USER:=deploy}"
  : "${OPERATOR_USER:=}"
  : "${HOSTNAME:=}"
  : "${ASK_HOSTNAME:=1}"
  : "${TIMEZONE:=UTC}"
  : "${INSTALL_ROOT_AUTHORIZED_KEYS:=1}"
  : "${SSH_PASSWORD_AUTHENTICATION:=no}"
  : "${SSH_PERMIT_ROOT_LOGIN:=prohibit-password}"
  : "${FIREWALL_ENABLE:=1}"
  : "${FIREWALL_ALLOW_SSH:=1}"
  : "${FIREWALL_ALLOW_HTTP:=1}"
  : "${FIREWALL_ALLOW_HTTPS:=1}"
  : "${FIREWALL_EXTRA_TCP:=}"
  : "${DOCKER_ENABLE:=1}"
  : "${DOCKER_COMPOSE:=1}"
  : "${DOCKER_BUILDX:=1}"
  : "${ENABLE_TIMESYNCD:=1}"
  : "${EXTRA_PACKAGES:=}"
}

is_arch() {
  [[ -f /etc/arch-release ]] || grep -qi 'arch' /etc/os-release 2>/dev/null
}

pacman_install() {
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  log "pacman -S --needed --noconfirm ${pkgs[*]}"
  pacman -Sy --needed --noconfirm "${pkgs[@]}"
}

ensure_file() {
  local src="$1" dest="$2" mode="${3:-0644}"
  [[ -f "$src" ]] || die "missing source file: $src"
  install -d "$(dirname "$dest")"
  install -m "$mode" "$src" "$dest"
  log "installed $dest"
}

ensure_line_in_file() {
  local line="$1" file="$2"
  touch "$file"
  if grep -Fqx "$line" "$file" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$line" >>"$file"
}
