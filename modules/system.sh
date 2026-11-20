# shellcheck shell=bash
# Sistema y dev-setup: no instala nada, solo informa.

is_macos() { [ "$(uname -s)" = Darwin ]; }

dev_setup_version() {
  # --no-optional-locks: doctor no debe escribir ni el índice de git.
  git --no-optional-locks -C "$DEV_SETUP_ROOT" describe --tags --always --dirty 2>/dev/null || printf 'desconocida'
}

# Última versión publicada: el tag vX.Y.Z más alto del origin. Vacía si no hay red, el clon no tiene
# origin o la consulta tarda más de DEV_SETUP_UPDATE_CHECK_TIMEOUT segundos (5). Nunca pregunta nada.
dev_setup_latest_release() {
  local out pid waited=0 limit="${DEV_SETUP_UPDATE_CHECK_TIMEOUT:-5}"
  out="$(new_temp_file)"
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=$limit" \
    git --no-optional-locks -C "$DEV_SETUP_ROOT" ls-remote --tags --refs origin 'v*' >"$out" 2>/dev/null 3>&- &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge $((limit * 10)) ]; then
      kill "$pid" 2>/dev/null || true
      break
    fi
    sleep 0.1
    waited=$((waited + 1))
  done
  wait "$pid" 2>/dev/null || true
  sed -n 's|.*refs/tags/v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$|\1|p' "$out" |
    sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1 | sed 's/^/v/'
  rm -f "$out"
}

# La versión nueva, si el clon está fijo en un tag más antiguo que la última publicada (como lo deja
# install.sh). En una rama, como main, no dice nada: ahí se actualiza con git pull. Los tests la apagan
# con DEV_SETUP_UPDATE_CHECK=0 para no usar la red.
dev_setup_newer_release() {
  local current latest
  [ "${DEV_SETUP_UPDATE_CHECK:-1}" = 1 ] || return 1
  git --no-optional-locks -C "$DEV_SETUP_ROOT" symbolic-ref -q HEAD >/dev/null 2>&1 && return 1
  current="$(git --no-optional-locks -C "$DEV_SETUP_ROOT" describe --tags --exact-match HEAD 2>/dev/null)" || return 1
  case "$current" in v[0-9]*.[0-9]*.[0-9]*) ;; *) return 1 ;; esac
  latest="$(dev_setup_latest_release)"
  [ -n "$latest" ] && version_lt "${current#v}" "${latest#v}" || return 1
  printf '%s' "$latest"
}

# Comandos para pasar el clon a <versión>, con ~ en vez de la carpeta personal.
dev_setup_upgrade_cmd() {
  local dir="$DEV_SETUP_ROOT"
  case "$dir" in "$HOME"/*) dir='~'"${dir#"$HOME"}" ;; esac
  printf 'git -C %s fetch --tags && git -C %s checkout %s' "$dir" "$dir" "$1"
}

system_next_steps() {
  local newer
  if newer="$(dev_setup_newer_release)"; then
    next_step "Hay una versión nueva de dev-setup ($newer). Para pasar a ella: $(dev_setup_upgrade_cmd "$newer")"
  fi
}

system_doctor() {
  local group state var newer
  section "Sistema"
  info "dev-setup $(dev_setup_version) en $DEV_SETUP_ROOT"
  if newer="$(dev_setup_newer_release)"; then
    warn "Hay una versión nueva de dev-setup ($newer). Para pasar a ella: $(dev_setup_upgrade_cmd "$newer")"
  fi
  if is_macos; then
    info "macOS $(sw_vers -productVersion) ($(uname -m))"
    [ "$(uname -m)" = arm64 ] || warn "Probado solo en Apple silicon"
  else
    warn "$(uname -s) no es macOS: dev-setup solo instala en macOS"
  fi
  info "Bash $BASH_VERSION"

  section "Grupos"
  for group in $DEV_SETUP_GROUPS; do
    var="$(group_var "$group")"
    case "${!var:-}" in
      1) state="sí" ;;
      0) state="no" ;;
      *) if [ "$(group_default "$group")" = 1 ]; then state="sí (por defecto)"; else state="no (por defecto)"; fi ;;
    esac
    info "$group: $state — $(group_description "$group")"
  done
}
