#!/usr/bin/env bash
# sshd drop-in hardening.

module_ssh() {
  log "module: ssh"

  local dest=/etc/ssh/sshd_config.d/99-arch-rails-server.conf
  ensure_file \
    "${REPO_ROOT}/config/sshd/99-arch-rails-server.conf" \
    "${dest}" \
    0644

  # Apply env overrides into the drop-in
  sed -i \
    -e "s/^PasswordAuthentication .*/PasswordAuthentication ${SSH_PASSWORD_AUTHENTICATION}/" \
    -e "s/^PermitRootLogin .*/PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}/" \
    "${dest}"

  # Arch ships Include /etc/ssh/sshd_config.d/*.conf in sshd_config
  if ! grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config 2>/dev/null; then
    warn "sshd_config may not Include sshd_config.d; ensure drop-ins are loaded"
  fi

  if sshd -t 2>/dev/null; then
    systemctl reload sshd.service 2>/dev/null || systemctl restart sshd.service
    log "sshd config valid; reloaded"
  else
    die "sshd -t failed after writing drop-in; fix config before continuing"
  fi
}
