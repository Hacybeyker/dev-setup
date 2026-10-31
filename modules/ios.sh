# shellcheck shell=bash
# Grupo ios: no instala nada. Revisa Xcode para compilar el target iOS de KMP y dice qué falta.
# Nunca corre sudo: el cambio de xcode-select lo haces tú.

xcode_app() { printf '%s' "${DEV_SETUP_XCODE_APP:-/Applications/Xcode.app}"; }

ios_check() {
  local app selected
  section "Xcode (grupo ios)"
  app="$(xcode_app)"
  if [ ! -d "$app" ]; then
    warn "Falta Xcode: instálalo desde la App Store (pide tu Apple ID y ocupa unos 15 GB)"
    return 0
  fi
  ok "Xcode en $app"
  selected="$(xcode-select -p 2>/dev/null || true)"
  case "$selected" in
    "$app"/*) ok "xcode-select usa ese Xcode" ;;
    *) warn "xcode-select usa ${selected:-nada}. Para compilar iOS: sudo xcode-select -s $app/Contents/Developer" ;;
  esac
}

ios_install() {
  if group_enabled ios; then ios_check; fi
}
ios_update() { ios_install; }

ios_doctor() {
  if group_enabled ios; then
    ios_check
  else
    section "Xcode (grupo ios)"
    info "Grupo ios desactivado"
  fi
}
