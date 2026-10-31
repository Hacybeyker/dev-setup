# shellcheck shell=bash
# Sistema y dev-setup: no instala nada, solo informa.

is_macos() { [ "$(uname -s)" = Darwin ]; }

dev_setup_version() {
  git -C "$DEV_SETUP_ROOT" describe --tags --always --dirty 2>/dev/null || printf 'desconocida'
}

system_doctor() {
  local group state var
  section "Sistema"
  info "dev-setup $(dev_setup_version) en $DEV_SETUP_ROOT"
  if is_macos; then
    info "macOS $(sw_vers -productVersion) ($(uname -m))"
    [ "$(uname -m)" = arm64 ] || warn "Probado solo en Apple silicon"
  else
    warn "$(uname -s) no es macOS: dev-setup solo instala en macOS"
  fi
  info "Bash $BASH_VERSION"

  section "Grupos opcionales"
  for group in $DEV_SETUP_GROUPS; do
    var="$(group_var "$group")"
    case "${!var:-}" in
      1) state="sí" ;;
      0) state="no" ;;
      *) state="sin elegir (se pregunta en bootstrap)" ;;
    esac
    info "$group: $state — $(group_description "$group")"
  done
}
