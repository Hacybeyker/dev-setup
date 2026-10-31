# shellcheck shell=bash
# Android Studio: memoria máxima del IDE (-Xmx) en el studio.vmoptions de la versión más reciente.
# Si ya tiene un -Xmx (por ejemplo, puesto desde Settings > Memory Settings), se respeta.

# Carpeta de configuración de la versión más reciente (no incluye las Preview).
studio_config_dir() {
  local dir latest=""
  for dir in "$HOME/Library/Application Support/Google"/AndroidStudio[0-9]*/; do
    [ -d "$dir" ] && latest="${dir%/}"
  done
  [ -n "$latest" ] || return 1
  printf '%s' "$latest"
}

# RAM en GiB. Los tests la fijan con DEV_SETUP_RAM_GIB.
ram_gib() {
  local bytes
  if [ -n "${DEV_SETUP_RAM_GIB:-}" ]; then
    printf '%s' "$DEV_SETUP_RAM_GIB"
  elif bytes="$(sysctl -n hw.memsize 2>/dev/null)"; then
    printf '%s' $((bytes / 1073741824))
  else
    printf '0'
  fi
}

# El -Xmx de local.env o uno según la RAM, que deja memoria a Gradle y al emulador.
studio_desired_xmx() {
  local gib
  if [ -n "${DEV_SETUP_STUDIO_XMX:-}" ]; then
    printf '%s' "$DEV_SETUP_STUDIO_XMX"
    return 0
  fi
  gib="$(ram_gib)"
  if [ "$gib" -ge 64 ]; then
    printf '8192m'
  elif [ "$gib" -ge 32 ]; then
    printf '6144m'
  else
    printf '4096m'
  fi
}

# studio_current_xmx <archivo>: el -Xmx que ya tiene, si tiene.
studio_current_xmx() {
  [ -f "$1" ] || return 1
  grep -E '^-Xmx[0-9]+[mMgG]$' "$1" | tail -n 1 | sed 's/^-Xmx//'
}

studio_ensure_memory() {
  local dir file current new
  section "Android Studio"
  if ! android_studio_app >/dev/null; then
    info "Android Studio no está instalado: instálalo desde JetBrains Toolbox y vuelve a correr dev-setup"
    return 0
  fi
  if ! dir="$(studio_config_dir)"; then
    info "Android Studio aún no tiene configuración: ábrelo una vez y vuelve a correr dev-setup"
    return 0
  fi
  file="$dir/studio.vmoptions"
  current="$(studio_current_xmx "$file" || true)"
  if [ -n "$current" ]; then
    ok "Memoria del IDE: -Xmx$current (se respeta)"
    return 0
  fi
  new="$(new_temp_file)"
  [ ! -f "$file" ] || cat "$file" >"$new"
  printf -- '-Xmx%s\n' "$(studio_desired_xmx)" >>"$new"
  apply_file_change "$file" "$new"
  if ! is_dry_run && [ -n "$(studio_current_xmx "$file" || true)" ]; then
    info "Reinicia Android Studio para aplicar la memoria"
  fi
}

studio_install() { studio_ensure_memory; }
studio_update() { studio_ensure_memory; }

studio_doctor() {
  local dir current
  section "Android Studio"
  if ! android_studio_app >/dev/null; then
    info "Android Studio no está instalado"
    return 0
  fi
  if ! dir="$(studio_config_dir)"; then
    info "Android Studio aún no tiene configuración"
    return 0
  fi
  current="$(studio_current_xmx "$dir/studio.vmoptions" || true)"
  if [ -n "$current" ]; then
    ok "Memoria del IDE: -Xmx$current"
  else
    warn "Memoria del IDE por defecto: dev-setup propone -Xmx$(studio_desired_xmx)"
  fi
}
