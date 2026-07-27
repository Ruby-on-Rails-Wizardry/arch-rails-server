# Live media: ensure helpers are obvious on login shells.
if [[ -d /opt/arch-rails-server ]] && [[ $- == *i* ]]; then
  export ARS_ROOT=/opt/arch-rails-server
  # motd already prints; keep this quiet unless ARS_BANNER=1
  if [[ "${ARS_BANNER:-0}" == "1" ]]; then
    echo "arch-rails-server kit: ${ARS_ROOT}  (ars help)"
  fi
fi
