#!/usr/bin/env bash
# Idempotent post-install bootstrap for a Kamal-ready Arch host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/01-base.sh
source "${SCRIPT_DIR}/lib/01-base.sh"
# shellcheck source=lib/02-docker.sh
source "${SCRIPT_DIR}/lib/02-docker.sh"
# shellcheck source=lib/03-user.sh
source "${SCRIPT_DIR}/lib/03-user.sh"
# shellcheck source=lib/04-ssh.sh
source "${SCRIPT_DIR}/lib/04-ssh.sh"
# shellcheck source=lib/05-firewall.sh
source "${SCRIPT_DIR}/lib/05-firewall.sh"
# shellcheck source=lib/06-finish.sh
source "${SCRIPT_DIR}/lib/06-finish.sh"

main() {
  require_root
  is_arch || die "this bootstrap targets Arch Linux (/etc/arch-release)"
  load_defaults

  log "arch-rails-server bootstrap (repo: ${REPO_ROOT})"

  module_base
  module_docker
  module_user
  module_ssh
  module_firewall
  module_finish
}

main "$@"
