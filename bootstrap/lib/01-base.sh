#!/usr/bin/env bash
# Base packages and time sync.

module_base() {
  log "module: base"

  local pkgs=(
    openssh
    git
    curl
    sudo
    vim
    jq
    rsync
    wget
    ca-certificates
    nftables
  )

  # shellcheck disable=SC2206
  local extra=( ${EXTRA_PACKAGES:-} )
  if [[ ${#extra[@]} -gt 0 ]]; then
    pkgs+=("${extra[@]}")
  fi

  pacman_install "${pkgs[@]}"

  if [[ "${ENABLE_TIMESYNCD}" == "1" ]]; then
    systemctl enable --now systemd-timesyncd.service 2>/dev/null \
      || warn "could not enable systemd-timesyncd (may already use chrony)"
  fi

  systemctl enable --now sshd.service
  log "sshd enabled"
}
