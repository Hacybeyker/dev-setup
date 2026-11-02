# shellcheck shell=bash
# Grupo node: nvm (instalador oficial, sin tocar el perfil de la terminal) y Node.js LTS.
# pnpm se instala desde el Brewfile. Si Node.js ya existe o lo gestiona otra herramienta, se respeta.

NVM_VERSION="0.40.8"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh"

nvm_dir() { printf '%s' "${NVM_DIR:-$HOME/.nvm}"; }
nvm_installed() { [ -s "$(nvm_dir)/nvm.sh" ]; }

nvm_installed_version() {
  # shellcheck disable=SC1091
  (. "$(nvm_dir)/nvm.sh" --no-use >/dev/null 2>&1 && nvm --version) 2>/dev/null || true
}

# version_lt <a> <b>: a es menor que b (versiones X.Y.Z).
version_lt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -n 1)" = "$1" ]
}

# Versiones de Node.js instaladas con nvm, separadas por espacios.
node_versions_in_nvm() {
  local dir list=""
  for dir in "$(nvm_dir)"/versions/node/*/; do
    [ -d "$dir" ] || continue
    dir="${dir%/}"
    list="$list${list:+ }${dir##*/}"
  done
  printf '%s' "$list"
}
node_path() { command -v node 2>/dev/null; }

# Otro gestor de versiones de Node.js, si hay alguno.
node_other_manager() {
  local tool
  for tool in fnm volta mise asdf; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf '%s' "$tool"
      return 0
    fi
  done
  return 1
}

# Instala nvm en nvm_dir, fijado a NVM_VERSION. PROFILE=/dev/null evita que toque ~/.zshrc.
nvm_run_installer() {
  if ! run_cmd mkdir -p "$(nvm_dir)" ||
    ! run_remote_installer "$NVM_INSTALL_URL" "NVM_DIR=$(nvm_dir)" PROFILE=/dev/null; then
    warn "No se pudo instalar nvm $NVM_VERSION"
  fi
}

node_install() {
  local manager node_bin
  group_enabled node || return 0
  section "Node.js (grupo node)"
  if nvm_installed; then
    ok "nvm en $(nvm_dir)"
  elif manager="$(node_other_manager)"; then
    ok "Node.js lo gestiona $manager: no se instala nvm"
    return 0
  elif node_bin="$(node_path)"; then
    ok "Node.js $(node --version 2>/dev/null) en $node_bin: se respeta y no se instala nvm"
    return 0
  else
    nvm_run_installer
    is_dry_run || nvm_installed || return 0
  fi

  if [ -n "$(node_versions_in_nvm)" ]; then
    ok "Node.js en nvm: $(node_versions_in_nvm)"
  elif node_bin="$(node_path)"; then
    ok "Node.js $(node --version 2>/dev/null) en $node_bin: se respeta"
  else
    # shellcheck disable=SC2016
    run_cmd /bin/bash -c '. "$1/nvm.sh" && nvm install --lts' _ "$(nvm_dir)" || warn "No se pudo instalar Node.js LTS"
  fi
}

# Lleva nvm a NVM_VERSION solo si se instaló con su instalador (un clon de git) y es más antiguo.
# No cambia la versión de Node.js: eso lo decides tú con nvm.
node_update() {
  local version
  group_enabled node || return 0
  section "Node.js (grupo node)"
  if ! nvm_installed; then
    info "nvm no está instalado: nada que actualizar"
    return 0
  fi
  version="$(nvm_installed_version)"
  if [ -z "$version" ]; then
    warn "No se pudo leer la versión de nvm en $(nvm_dir)"
  elif ! version_lt "$version" "$NVM_VERSION"; then
    ok "nvm $version"
  elif [ -d "$(nvm_dir)/.git" ]; then
    nvm_run_installer
  else
    info "nvm $version no se instaló con su instalador: se actualiza por su cuenta"
  fi
}

node_doctor() {
  local manager node_bin version
  section "Node.js (grupo node)"
  if ! group_enabled node; then
    info "Grupo node desactivado"
    return 0
  fi
  if nvm_installed; then
    version="$(nvm_installed_version)"
    ok "nvm ${version:-} en $(nvm_dir)"
  elif manager="$(node_other_manager)"; then
    ok "Node.js lo gestiona $manager"
  else
    warn "Falta nvm"
  fi
  if node_bin="$(node_path)"; then
    ok "Node.js $(node --version 2>/dev/null) en $node_bin"
  elif [ -n "$(node_versions_in_nvm)" ]; then
    ok "Node.js en nvm: $(node_versions_in_nvm)"
  else
    warn "Falta Node.js"
  fi
}

# Carga nvm en zsh si el grupo está activo y nada lo cargó antes.
node_shell() {
  group_enabled node || return 0
  # shellcheck disable=SC2016
  printf '%s\n' 'if ! command -v nvm >/dev/null 2>&1 && [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"; . "$NVM_DIR/nvm.sh"; fi'
}
