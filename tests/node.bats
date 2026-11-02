#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  load_libs
  DEV_SETUP_NODE=1
  # La máquina que corre los tests puede tener Node.js en /usr/bin: por defecto se simula que no hay.
  node_path() { return 1; }
}

# Instalador falso de nvm: crea nvm.sh y registra con qué PROFILE corrió.
stub_nvm_installer() {
  export FAKE_INSTALLER_SCRIPT="$BATS_TEST_TMPDIR/nvm-install.sh"
  cat >"$FAKE_INSTALLER_SCRIPT" <<'SCRIPT'
printf 'profile=%s\n' "$PROFILE" >>"$FAKE_LOG"
cat >"$NVM_DIR/nvm.sh" <<'NVM'
nvm() {
  case "$1" in
    --version) echo "0.40.8" ;;
    *) printf 'nvm %s\n' "$*" >>"$FAKE_LOG" ;;
  esac
}
NVM
SCRIPT
}

# make_fake_nvm <versión> [git]: un nvm ya instalado.
make_fake_nvm() {
  mkdir -p "$HOME/.nvm"
  [ "${2:-}" != git ] || mkdir -p "$HOME/.nvm/.git"
  cat >"$HOME/.nvm/nvm.sh" <<NVM
nvm() {
  case "\$1" in
    --version) echo "$1" ;;
    *) printf 'nvm %s\n' "\$*" >>"\$FAKE_LOG" ;;
  esac
}
NVM
}

@test "con el grupo node desactivado no hace nada" {
  DEV_SETUP_NODE=0
  run node_install
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -s "$FAKE_LOG" ]
}

@test "instala nvm fijado, sin tocar el perfil, y luego Node.js LTS" {
  stub_nvm_installer
  run node_install
  [ "$status" -eq 0 ]
  grep -q "^curl -fsSL -o .* https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh$" "$FAKE_LOG"
  grep -qx 'profile=/dev/null' "$FAKE_LOG"
  grep -qx 'nvm install --lts' "$FAKE_LOG"
}

@test "si falla la descarga de nvm avisa y sigue" {
  run node_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"No se pudo instalar nvm"* ]]
  [ "$(grep -c '^nvm ' "$FAKE_LOG")" -eq 0 ]
}

@test "respeta Node.js instalado fuera de nvm" {
  make_stub node <<'STUB'
echo v22.0.0
STUB
  node_path() { command -v node; }
  run node_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"v22.0.0"*"se respeta"* ]]
  [ "$(grep -c '^curl' "$FAKE_LOG")" -eq 0 ]
  [ ! -e "$HOME/.nvm" ]
}

@test "respeta otro gestor de versiones como fnm" {
  make_stub fnm <<'STUB'
exit 0
STUB
  run node_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"lo gestiona fnm"* ]]
  [ "$(grep -c '^curl' "$FAKE_LOG")" -eq 0 ]
}

@test "con nvm y sin Node.js instala la LTS" {
  make_fake_nvm 0.40.8
  run node_install
  [ "$status" -eq 0 ]
  grep -qx 'nvm install --lts' "$FAKE_LOG"
  [ "$(grep -c '^curl' "$FAKE_LOG")" -eq 0 ]
}

@test "con nvm y Node.js no instala nada" {
  make_fake_nvm 0.40.8
  mkdir -p "$HOME/.nvm/versions/node/v22.1.0"
  run node_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"v22.1.0"* ]]
  [ ! -s "$FAKE_LOG" ]
}

@test "dry-run no descarga nada" {
  DEV_SETUP_DRY_RUN=1 run node_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"*"nvm-sh/nvm/v0.40.8"* ]]
  [[ "$output" == *"nvm install --lts"* ]]
  [ ! -s "$FAKE_LOG" ]
}

@test "update actualiza un nvm antiguo instalado con su instalador" {
  make_fake_nvm 0.39.7 git
  stub_nvm_installer
  run node_update
  [ "$status" -eq 0 ]
  grep -q '^curl .*nvm-sh/nvm/v0.40.8/install.sh' "$FAKE_LOG"
}

@test "update no baja la version de nvm" {
  make_fake_nvm 0.41.0 git
  run node_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm 0.41.0"* ]]
  [ ! -s "$FAKE_LOG" ]
}

@test "update no toca un nvm instalado de otra forma" {
  make_fake_nvm 0.39.7
  run node_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"se actualiza por su cuenta"* ]]
  [ ! -s "$FAKE_LOG" ]
}

@test "version_lt compara por numero" {
  version_lt 0.39.7 0.40.8
  version_lt 0.9.0 0.10.0
  run version_lt 0.40.8 0.40.8
  [ "$status" -eq 1 ]
  run version_lt 0.41.0 0.40.8
  [ "$status" -eq 1 ]
}

@test "el bloque de zsh carga nvm solo con el grupo activo" {
  [[ "$(node_shell)" == *'nvm.sh'* ]]
  DEV_SETUP_NODE=0
  [ -z "$(node_shell)" ]
}
