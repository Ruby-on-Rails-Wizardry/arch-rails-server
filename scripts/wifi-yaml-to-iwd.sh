#!/usr/bin/env bash
# Convert Phototherapy-style secrets/wifi.yaml into iwd AutoConnect profiles.
#
# Usage:
#   ./scripts/wifi-yaml-to-iwd.sh WIFI.yaml DEST_DIR
#   ./scripts/wifi-yaml-to-iwd.sh --self-test
#
# Same list shape as ~/UserHackable/Phototherapy_Timer/secrets/wifi.yaml:
#   ---
#   - ssid: ExampleHome
#     password: "change-me"
#
# Writes DEST_DIR/<SSID>.psk (or .open). Does not print passphrases.
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  wifi-yaml-to-iwd.sh WIFI.yaml DEST_DIR
  wifi-yaml-to-iwd.sh --self-test

Reads a Phototherapy-style wifi.yaml (ssid/password list) and writes iwd
profiles with AutoConnect=true. Destination is typically:

  work/iso/profile/airootfs/var/lib/iwd
EOF
}

# iwd: alphanumeric + '-' stay literal; anything else is '=' + lowercase hex.
iwd_basename() {
  local ssid="$1" suffix="$2"
  if [[ "${ssid}" =~ ^[A-Za-z0-9-]+$ ]]; then
    printf '%s%s' "${ssid}" "${suffix}"
    return
  fi
  local hex
  hex="$(printf '%s' "${ssid}" | od -An -tx1 | tr -d ' \n')"
  printf '=%s%s' "${hex}" "${suffix}"
}

# systemd/iwd keyfile: quote if the value would be ambiguous.
iwd_escape_value() {
  local v="$1"
  if [[ "${v}" =~ [[:space:]#=\\] || "${v}" == *'"'* ]]; then
    v="${v//\\/\\\\}"
    v="${v//\"/\\\"}"
    printf '"%s"' "${v}"
  else
    printf '%s' "${v}"
  fi
}

strip_yaml_scalar() {
  local raw="$1"
  raw="${raw%"${raw##*[![:space:]]}"}"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  if [[ "${raw}" == \"*\" && "${raw}" == *\" ]]; then
    raw="${raw:1:${#raw}-2}"
  elif [[ "${raw}" == \'*\' && "${raw}" == *\' ]]; then
    raw="${raw:1:${#raw}-2}"
  fi
  printf '%s' "${raw}"
}

write_profile() {
  local dest="$1" ssid="$2" password="$3"
  local suffix=".psk"
  [[ -n "${password}" ]] || suffix=".open"
  local name path
  name="$(iwd_basename "${ssid}" "${suffix}")"
  path="${dest}/${name}"
  {
    if [[ -n "${password}" ]]; then
      printf '[Security]\n'
      printf 'Passphrase=%s\n' "$(iwd_escape_value "${password}")"
      printf '\n'
    fi
    printf '[Settings]\n'
    printf 'AutoConnect=true\n'
  } >"${path}"
  chmod 0600 "${path}"
  printf '%s\n' "${ssid}"
}

parse_and_write() {
  local yaml="$1" dest="$2"
  [[ -f "${yaml}" ]] || die "wifi yaml not found: ${yaml}"
  mkdir -p "${dest}"
  chmod 0700 "${dest}"

  local ssid="" password="" line raw wrote=0
  flush() {
    [[ -n "${ssid}" ]] || return 0
    write_profile "${dest}" "${ssid}" "${password}"
    wrote=$((wrote + 1))
    ssid=""
    password=""
  }

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
    if [[ "${line}" =~ ^[[:space:]]*-[[:space:]]*ssid:[[:space:]]*(.*)$ ]]; then
      flush
      ssid="$(strip_yaml_scalar "${BASH_REMATCH[1]}")"
      password=""
      continue
    fi
    if [[ "${line}" =~ ^[[:space:]]*password:[[:space:]]*(.*)$ ]]; then
      raw="$(strip_yaml_scalar "${BASH_REMATCH[1]}")"
      password="${raw}"
    fi
  done <"${yaml}"
  flush

  [[ "${wrote}" -gt 0 ]] || die "no ssid entries in ${yaml}"
  printf 'wrote %s iwd profile(s) -> %s\n' "${wrote}" "${dest}" >&2
}

self_test() {
  local tmp yaml dest
  tmp="$(mktemp -d)"
  yaml="${tmp}/wifi.yaml"
  dest="${tmp}/iwd"
  cat >"${yaml}" <<'YAML'
---
server_ip: 192.168.1.202
- ssid: Ferney
  password: "example-pass"
- ssid: Space Net
  password: 'hash#tag'
- ssid: OpenCafe
  password:
YAML
  parse_and_write "${yaml}" "${dest}" >/dev/null
  [[ -f "${dest}/Ferney.psk" ]] || die "self-test: missing Ferney.psk"
  grep -q '^AutoConnect=true$' "${dest}/Ferney.psk" || die "self-test: AutoConnect"
  grep -q '^Passphrase=example-pass$' "${dest}/Ferney.psk" || die "self-test: passphrase"
  local hex_name
  hex_name="$(iwd_basename 'Space Net' '.psk')"
  [[ -f "${dest}/${hex_name}" ]] || die "self-test: hex-encoded SSID missing"
  grep -q '^Passphrase="hash#tag"$' "${dest}/${hex_name}" || die "self-test: quoted passphrase"
  [[ -f "${dest}/OpenCafe.open" ]] || die "self-test: open network"
  rm -rf "${tmp}"
  echo "self-test: ok"
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --self-test) self_test ;;
    "") usage; exit 1 ;;
    *)
      [[ $# -eq 2 ]] || die "expected WIFI.yaml DEST_DIR (try --help)"
      parse_and_write "$1" "$2"
      ;;
  esac
}

main "$@"
