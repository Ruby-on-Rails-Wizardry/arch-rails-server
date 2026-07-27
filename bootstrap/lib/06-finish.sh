#!/usr/bin/env bash
# Final summary.

module_finish() {
  log "module: finish"
  cat <<EOF

Bootstrap complete.

Next steps:
  1. Confirm SSH with the deploy key before closing this session:
       ssh ${DEPLOY_USER}@$(hostname -f 2>/dev/null || hostname)
  2. From your Rails app, set servers + ssh.user in config/deploy.yml
     (see config/deploy.snippet.yml and docs/KAMAL.md).
  3. bin/kamal setup && bin/kamal deploy

Checks on this host:
  ./bin/doctor
  ./bin/verify

EOF
}
