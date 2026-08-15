#!/usr/bin/env bash
# Deploy user, docker group, authorized_keys, limited sudoers.

module_user() {
  log "module: user (${DEPLOY_USER})"

  if ! id -u "${DEPLOY_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G wheel "${DEPLOY_USER}"
    log "created user ${DEPLOY_USER}"
  else
    log "user ${DEPLOY_USER} already exists"
  fi

  # Docker access for Kamal over SSH as deploy
  if getent group docker >/dev/null 2>&1; then
    usermod -aG docker "${DEPLOY_USER}"
    log "added ${DEPLOY_USER} to docker group"
  else
    warn "docker group missing; skip usermod (run docker module first)"
  fi

  # Passwordless wheel is not enabled by default on Arch; we install limited sudoers.
  ensure_file \
    "${REPO_ROOT}/config/sudoers.d/deploy" \
    /etc/sudoers.d/99-arch-rails-server-deploy \
    0440

  # Rewrite sudoers user if DEPLOY_USER is not "deploy"
  if [[ "${DEPLOY_USER}" != "deploy" ]]; then
    sed -i "s/^deploy /${DEPLOY_USER} /g; s/Defaults:deploy /Defaults:${DEPLOY_USER} /g" \
      /etc/sudoers.d/99-arch-rails-server-deploy
  fi

  if ! visudo -cf /etc/sudoers.d/99-arch-rails-server-deploy >/dev/null; then
    rm -f /etc/sudoers.d/99-arch-rails-server-deploy
    die "sudoers validation failed; removed drop-in"
  fi

  install_authorized_keys_for "${DEPLOY_USER}"

  if [[ -n "${OPERATOR_USER}" && "${OPERATOR_USER}" != "${DEPLOY_USER}" ]]; then
    [[ "${OPERATOR_USER}" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "invalid OPERATOR_USER: ${OPERATOR_USER}"
    ensure_operator_user
    install_authorized_keys_for "${OPERATOR_USER}"
  fi

  if [[ "${INSTALL_ROOT_AUTHORIZED_KEYS}" == "1" ]]; then
    install_authorized_keys_for root
  fi
}

ensure_operator_user() {
  if ! id -u "${OPERATOR_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G wheel "${OPERATOR_USER}"
    log "created user ${OPERATOR_USER}"
  else
    usermod -aG wheel "${OPERATOR_USER}" 2>/dev/null || true
    log "user ${OPERATOR_USER} already exists"
  fi

  local dest=/etc/sudoers.d/99-arch-rails-server-operator
  cat >"${dest}" <<EOF
# Personal admin created by arch-rails-server bootstrap. SSH is key-only.
Defaults:${OPERATOR_USER} !requiretty
${OPERATOR_USER} ALL=(ALL:ALL) NOPASSWD: ALL
EOF
  chmod 0440 "${dest}"
  if ! visudo -cf "${dest}" >/dev/null; then
    rm -f "${dest}"
    die "sudoers validation failed for ${OPERATOR_USER}; removed drop-in"
  fi
  log "sudoers installed for ${OPERATOR_USER}"
}

install_authorized_keys_for() {
  local user="$1"
  local keys_src="${REPO_ROOT}/config/authorized_keys"
  local home ssh_dir auth

  if [[ ! -f "${keys_src}" ]]; then
    warn "no config/authorized_keys — skip SSH keys for ${user} (copy from authorized_keys.example)"
    return 0
  fi

  if [[ "${user}" == "root" ]]; then
    home=/root
  else
    home="$(getent passwd "${user}" | cut -d: -f6)"
  fi
  [[ -n "${home}" && -d "${home}" ]] || die "home for ${user} not found"

  ssh_dir="${home}/.ssh"
  auth="${ssh_dir}/authorized_keys"
  install -d -m 0700 -o "${user}" -g "${user}" "${ssh_dir}"

  # Merge keys (idempotent by full line)
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    if [[ -f "${auth}" ]] && grep -Fqx "${line}" "${auth}" 2>/dev/null; then
      continue
    fi
    printf '%s\n' "${line}" >>"${auth}"
  done <"${keys_src}"

  chown "${user}:${user}" "${auth}"
  chmod 0600 "${auth}"
  log "authorized_keys updated for ${user}"
}
