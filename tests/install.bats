#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  INSTALL="$REPO_ROOT/install.sh"
  export DEV_SETUP_SKIP_OS_CHECK=1
  export DEV_SETUP_DIR="$HOME/Claude/dev-setup"
  export DEV_SETUP_REF=v9.9.9
  export DEV_SETUP_REPO_URL="$BATS_TEST_TMPDIR/origin/dev-setup"
  make_fake_dev_setup_origin "$DEV_SETUP_REPO_URL"
  make_stub sleep <<'STUB'
exit 0
STUB
}

# Un repo dev-setup falso con el tag v9.9.9, cuyo bin/dev-setup solo registra sus argumentos.
make_fake_dev_setup_origin() {
  mkdir -p "$1/bin"
  printf '#!/usr/bin/env bash\nprintf "dev-setup %%s\\n" "$*" >>"$FAKE_LOG"\n' >"$1/bin/dev-setup"
  chmod +x "$1/bin/dev-setup"
  git -C "$1" init --quiet
  git -C "$1" add -A
  git -C "$1" -c user.name=test -c user.email=test@example.com commit --quiet -m inicial
  git -C "$1" tag v9.9.9
}

@test "clona la version fijada y corre bootstrap con los argumentos" {
  run bash "$INSTALL" --with node
  [ "$status" -eq 0 ]
  [ "$(git -C "$DEV_SETUP_DIR" describe --tags)" = v9.9.9 ]
  grep -qx 'dev-setup bootstrap --with node' "$FAKE_LOG"
}

@test "funciona llegando por un pipe" {
  run bash -c 'cat "$1" | bash -s -- --yes' _ "$INSTALL"
  [ "$status" -eq 0 ]
  grep -qx 'dev-setup bootstrap --yes' "$FAKE_LOG"
}

@test "sin Command Line Tools las instala y espera a que terminen" {
  make_stub xcode-select <<'STUB'
printf 'xcode-select %s\n' "$*" >>"$FAKE_LOG"
case "$1" in
  --install) : >"$HOME/.clt-pedidas" ;;
  -p)
    [ -e "$HOME/.clt-pedidas" ] || exit 2
    printf x >>"$HOME/.clt-esperas"
    [ "$(wc -c <"$HOME/.clt-esperas" | tr -d ' ')" -ge 3 ] || exit 2
    echo /Library/Developer/CommandLineTools
    ;;
esac
STUB
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  grep -qx 'xcode-select --install' "$FAKE_LOG"
  grep -qx 'dev-setup bootstrap' "$FAKE_LOG"
}

@test "si las Command Line Tools no terminan, se detiene sin clonar" {
  export FAKE_NO_CLT=1
  run bash "$INSTALL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"vuelve a correr este comando"* ]]
  [ ! -e "$DEV_SETUP_DIR" ]
}

@test "si la carpeta ya es un clon de dev-setup la usa sin tocarla" {
  git clone --quiet "$DEV_SETUP_REPO_URL" "$DEV_SETUP_DIR"
  printf 'mio\n' >"$DEV_SETUP_DIR/cambio-local"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"se usa tal como está"* ]]
  [ -e "$DEV_SETUP_DIR/cambio-local" ]
  grep -qx 'dev-setup bootstrap' "$FAKE_LOG"
}

@test "si la carpeta existe y no es dev-setup no la toca" {
  mkdir -p "$DEV_SETUP_DIR"
  printf 'mio\n' >"$DEV_SETUP_DIR/archivo"
  run bash "$INSTALL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no se toca"* ]]
  [ "$(cat "$DEV_SETUP_DIR/archivo")" = mio ]
  [ "$(grep -c '^dev-setup' "$FAKE_LOG")" -eq 0 ]
}

@test "fuera de macOS se niega" {
  unset DEV_SETUP_SKIP_OS_CHECK
  make_stub uname <<'STUB'
echo Linux
STUB
  run bash "$INSTALL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"solo instala en macOS"* ]]
  [ ! -e "$DEV_SETUP_DIR" ]
}
