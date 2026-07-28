#!/usr/bin/env bash
# Populate a YUMI/Ventoy USB with:
#   - latest official Arch ISO (replace stale copies)
#   - offline pacman package cache (rescue + arch-rails-server bootstrap)
#   - slim single-branch git archives (remotes preserved, gc'd .git)
#
# Usage (no root required for typical YUMI mount):
#   USB_ROOT=/run/media/rob/YUMI ./scripts/populate-sneakernet-usb.sh
set -euo pipefail

USB_ROOT="${USB_ROOT:-/run/media/rob/YUMI}"
ISO_DIR="${ISO_DIR:-${USB_ROOT}/YUMI/Linux-ISOs}"
SNK="${USB_ROOT}/sneakernet"
PACMAN_DIR="${SNK}/pacman"
PKG_DIR="${PACMAN_DIR}/pkg"
REPOS_DIR="${SNK}/repos"
RORW_SRC="${RORW_SRC:-/home/rob/Ruby-on-Rails-Wizardry}"
CAPN_SRC="${CAPN_SRC:-/home/rob/Capnregex}"
WORK="${WORK:-${TMPDIR:-/tmp}/ars-sneakernet-$$}"
ARCH_ISO_VERSION="${ARCH_ISO_VERSION:-2026.07.01}"
ARCH_ISO_URL="${ARCH_ISO_URL:-https://geo.mirror.pkgbuild.com/iso/${ARCH_ISO_VERSION}/archlinux-${ARCH_ISO_VERSION}-x86_64.iso}"
ARCH_ISO_NAME="archlinux-${ARCH_ISO_VERSION}-x86_64.iso"
PARALLEL_JOBS="${PARALLEL_JOBS:-4}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -d "${USB_ROOT}" ]] || die "USB_ROOT not mounted: ${USB_ROOT}"
[[ -d "${ISO_DIR}" ]] || die "ISO dir missing: ${ISO_DIR} (is this a YUMI stick?)"

mkdir -p "${PKG_DIR}" "${REPOS_DIR}/ruby-on-rails-wizardry" "${REPOS_DIR}/capnregex" "${WORK}"
cleanup() { rm -rf "${WORK}"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Package set: rescue / repair / offline bootstrap for Kamal host
# ---------------------------------------------------------------------------
# shellcheck disable=SC2034
RESCUE_PKGS=(
  # core install / chroot helpers
  base base-devel linux linux-firmware mkinitcpio
  arch-install-scripts archinstall
  # network (bring-up without guessing too much)
  networkmanager iwd dhcpcd openssh
  # disks / filesystems / recovery
  btrfs-progs e2fsprogs xfsprogs dosfstools exfatprogs ntfs-3g
  gptfdisk parted util-linux
  lvm2 mdadm cryptsetup
  smartmontools nvme-cli hdparm ddrescue testdisk
  # transfer / archive
  rsync git curl wget ca-certificates
  tar gzip xz zstd unzip zip 7zip
  # editors / shell utility
  vim nano tmux less which jq
  # diagnose
  htop lsof strace tcpdump bind iproute2 iputils traceroute nmap
  man-db man-pages
  # time / mirrors
  reflector
  # arch-rails-server bootstrap target set
  sudo nftables docker docker-compose docker-buildx
  # nice-to-have for repair
  bash-completion inetutils pciutils usbutils
)

fetch_packages() {
  log "resolving package URLs (offline rescue + bootstrap set)"
  local url dest base src
  local -a urls=() good=() bad=()
  local p
  for p in "${RESCUE_PKGS[@]}"; do
    if pacman -Sp "$p" >/dev/null 2>&1; then
      good+=("$p")
    else
      bad+=("$p")
      log "warning: skip unknown package: $p"
    fi
  done
  [[ ${#good[@]} -gt 0 ]] || die "no resolvable packages"
  mapfile -t urls < <(pacman -Sp --print-format '%l' "${good[@]}" | sort -u)
  [[ ${#urls[@]} -gt 0 ]] || die "pacman -Sp returned no URLs"

  log "fetching ${#urls[@]} package files (${#good[@]} roots) into ${PKG_DIR}"
  log "note: exFAT cannot store ':' in names — epochs rewritten (docker-1:… → docker-1_…)"
  local i=0
  for url in "${urls[@]}"; do
    i=$((i + 1))
    base=$(basename "${url}")
    # exFAT/YUMI data partition rejects ':' (epoch separator in pkg names)
    safe=$(printf '%s' "${base}" | tr ':' '_')
    dest="${PKG_DIR}/${safe}"
    if [[ -f "${dest}" ]]; then
      printf '  [%d/%d] skip exists %s\n' "$i" "${#urls[@]}" "$safe"
      continue
    fi
    printf '  [%d/%d] %s\n' "$i" "${#urls[@]}" "$safe"
    if [[ "${url}" == file://* ]]; then
      src="${url#file://}"
      cp -a "${src}" "${dest}"
    else
      curl -fL --retry 3 --retry-delay 2 -o "${dest}.partial" "${url}"
      mv "${dest}.partial" "${dest}"
    fi
  done

  log "building local repo database"
  (
    cd "${PKG_DIR}"
    rm -f arch-offline.db* arch-offline.files* 2>/dev/null || true
    repo-add -q arch-offline.db.tar.zst ./*.pkg.tar.zst
  )
  ln -sfn "pkg/arch-offline.db.tar.zst" "${PACMAN_DIR}/arch-offline.db.tar.zst" 2>/dev/null || true

  cat >"${PACMAN_DIR}/README.md" <<'EOF'
# Offline pacman cache (sneakernet)

Rescue + `arch-rails-server` bootstrap packages for use **without network**.

## Use from a live ISO or installed system

Mount this USB, then either:

### A) Install packages from files

```bash
USB=/run/media/rob/YUMI   # adjust
sudo pacman -U --needed "$USB/sneakernet/pacman/pkg"/*.pkg.tar.zst
```

### B) Temporary file:// repo

```bash
USB=/run/media/rob/YUMI
sudo tee /etc/pacman.d/arch-offline.conf >/dev/null <<EOF2
[arch-offline]
SigLevel = Optional TrustAll
Server = file://${USB}/sneakernet/pacman/pkg
EOF2
# Add once under /etc/pacman.conf:
#   Include = /etc/pacman.d/arch-offline.conf
sudo pacman -Sy
sudo pacman -S docker docker-compose docker-buildx nftables openssh git
```

### C) Offline path toward Kamal host

```bash
sudo pacman -U --needed /path/to/sneakernet/pacman/pkg/*.pkg.tar.zst
# then run arch-rails-server bootstrap from ARS ISO or git archive
```

Rebuild this cache on a networked Arch machine periodically (rolling).
EOF

  cat >"${PACMAN_DIR}/package-list.txt" <<EOF
# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Requested package roots (resolved):
$(printf '%s\n' "${good[@]}")
# Skipped:
$(printf '%s\n' "${bad[@]:-}")

# Files present ($(ls -1 "${PKG_DIR}"/*.pkg.tar.zst 2>/dev/null | wc -l)):
$(ls -1 "${PKG_DIR}"/*.pkg.tar.zst 2>/dev/null | xargs -n1 basename | sort)
EOF
}

# ---------------------------------------------------------------------------
# Arch ISO
# ---------------------------------------------------------------------------
fetch_arch_iso() {
  local dest="${ISO_DIR}/${ARCH_ISO_NAME}"
  if [[ -f "${dest}" ]]; then
    log "Arch ISO already present: ${dest}"
  else
    log "downloading ${ARCH_ISO_URL}"
    curl -fL --progress-bar -o "${dest}.partial" "${ARCH_ISO_URL}"
    mv "${dest}.partial" "${dest}"
  fi
  # remove stale official Arch ISOs (keep arch-rails-server and others)
  local f
  for f in "${ISO_DIR}"/archlinux-*.iso; do
    [[ -e "$f" ]] || continue
    base=$(basename "$f")
    if [[ "${base}" != "${ARCH_ISO_NAME}" ]]; then
      log "removing old Arch ISO: ${base}"
      rm -f "$f"
    fi
  done
  # also plain archlinux-x86_64.iso duplicate name
  if [[ -f "${ISO_DIR}/archlinux-x86_64.iso" ]]; then
    log "removing duplicate archlinux-x86_64.iso"
    rm -f "${ISO_DIR}/archlinux-x86_64.iso"
  fi
  # refresh YUMI Installed.txt if present
  local inst="${USB_ROOT}/YUMI/Installed.txt"
  if [[ -d "${ISO_DIR}" ]]; then
    {
      for f in "${ISO_DIR}"/*.iso; do
        [[ -e "$f" ]] || continue
        echo "Linux-ISOs/$(basename "$f")"
      done
    } | sort >"${inst}"
  fi
}

# ---------------------------------------------------------------------------
# Slim git archive: single-branch, remotes from source, gc aggressive
# ---------------------------------------------------------------------------
primary_branch() {
  local repo="$1"
  if git -C "$repo" rev-parse --verify master >/dev/null 2>&1; then
    echo master
  elif git -C "$repo" rev-parse --verify main >/dev/null 2>&1; then
    echo main
  else
    git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD
  fi
}

export_one_repo() {
  local src="$1" out_dir="$2" name="$3"
  local branch work rname rurl
  branch=$(primary_branch "$src")
  # safe filesystem slug
  local slug
  slug=$(printf '%s' "${name}" | tr '/' '__' | tr -c 'A-Za-z0-9._+@-' '_')
  work="${WORK}/export-${slug}-$$"
  rm -rf "$work"
  mkdir -p "$work"

  if ! git -C "$src" rev-parse --verify "${branch}" >/dev/null 2>&1; then
    printf 'SKIP  %s (no usable branch)\n' "$name"
    return 0
  fi

  # single-branch clone of only that branch history (no other branches / baggage)
  if ! git clone --quiet --single-branch --branch "${branch}" --no-local "${src}" "${work}/${slug}" 2>/dev/null; then
    # fallback without --no-local
    git clone --quiet --single-branch --branch "${branch}" "${src}" "${work}/${slug}"
  fi

  # drop default origin; re-apply remotes from source (URLs only — no remote-tracking branches)
  git -C "${work}/${slug}" remote remove origin 2>/dev/null || true
  while read -r rname rurl; do
    [[ -z "${rname}" || -z "${rurl}" ]] && continue
    if ! git -C "${work}/${slug}" remote get-url "${rname}" >/dev/null 2>&1; then
      git -C "${work}/${slug}" remote add "${rname}" "${rurl}" 2>/dev/null || true
    else
      git -C "${work}/${slug}" remote set-url "${rname}" "${rurl}" 2>/dev/null || true
    fi
  done < <(git -C "$src" remote -v | awk '/\(fetch\)/ {print $1, $2}')

  # prune remote-tracking leftovers; keep configured remotes only
  git -C "${work}/${slug}" for-each-ref --format='%(refname)' refs/remotes 2>/dev/null \
    | while read -r ref; do git -C "${work}/${slug}" update-ref -d "$ref" 2>/dev/null || true; done

  {
    echo "name=${name}"
    echo "slug=${slug}"
    echo "branch=${branch}"
    echo "exported_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "source_path=${src}"
    echo "commit=$(git -C "${work}/${slug}" rev-parse HEAD)"
    echo "remotes:"
    git -C "${work}/${slug}" remote -v
  } >"${work}/${slug}/SNEAKERNET.txt"

  git -C "${work}/${slug}" reflog expire --expire=now --all 2>/dev/null || true
  git -C "${work}/${slug}" gc --prune=now --quiet 2>/dev/null || true

  tar -C "${work}" -cJf "${out_dir}/${slug}.tar.xz" "${slug}"
  printf 'OK    %s  branch=%s  %s\n' "$name" "$branch" "$(du -h "${out_dir}/${slug}.tar.xz" | cut -f1)"
  rm -rf "$work"
}

export_org() {
  local src_root="$1" out_rel="$2"
  local out_dir="${REPOS_DIR}/${out_rel}"
  mkdir -p "${out_dir}"
  log "exporting git repos from ${src_root} -> ${out_dir}"

  local -a repos=()
  while IFS= read -r g; do
    repos+=("$(dirname "$g")")
  done < <(find "${src_root}" -name .git \( -type d -o -type f \) 2>/dev/null | sort)

  log "${#repos[@]} repos under ${src_root}"
  local repo rel
  for repo in "${repos[@]}"; do
    rel=$(realpath --relative-to="${src_root}" "${repo}" 2>/dev/null || basename "${repo}")
    export_one_repo "${repo}" "${out_dir}" "${rel}" || printf 'FAIL  %s\n' "${rel}"
  done

  (
    cd "${out_dir}"
    sha256sum ./*.tar.xz > SHA256SUMS 2>/dev/null || true
    echo "archive count: $(ls -1 ./*.tar.xz 2>/dev/null | wc -l)"
    ls -lhS ./*.tar.xz 2>/dev/null | head -25 || true
    du -sh .
  )
}

write_top_readme() {
  cat >"${SNK}/README.md" <<EOF
# Sneakernet payload

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Layout

| Path | Purpose |
|------|---------|
| \`../YUMI/Linux-ISOs/\` | Boot ISOs (Ventoy/YUMI) including Arch ${ARCH_ISO_VERSION} + arch-rails-server |
| \`pacman/\` | Offline package cache + local repo db for rescue / bootstrap without network |
| \`repos/ruby-on-rails-wizardry/\` | Slim single-branch archives (\`.tar.xz\`) with remotes preserved |
| \`repos/capnregex/\` | Same for Capnregex org clones |

## Restore a code archive

\`\`\`bash
tar -xJf ruby-on-rails-wizardry/arch-rails-server.tar.xz
cd arch-rails-server
cat SNEAKERNET.txt
git remote -v
git status
# later, with network:
git fetch github   # or whatever remotes were saved
\`\`\`

Each archive is a **working clone** of one branch only (master/main), remotes
configured, reflogs pruned, \`git gc\` applied — not a full multi-branch mirror.

## Offline packages

See \`pacman/README.md\`.
EOF
}

main() {
  log "USB_ROOT=${USB_ROOT}"
  df -h "${USB_ROOT}"
  fetch_arch_iso
  fetch_packages
  export_org "${RORW_SRC}" "ruby-on-rails-wizardry"
  if [[ -d "${CAPN_SRC}" ]]; then
    export_org "${CAPN_SRC}" "capnregex"
  else
    log "Capnregex path missing (${CAPN_SRC}); skip"
  fi
  write_top_readme
  sync
  log "done"
  df -h "${USB_ROOT}"
  du -sh "${SNK}" "${SNK}"/* 2>/dev/null || true
  ls -lhS "${ISO_DIR}"/*.iso
}

main "$@"
