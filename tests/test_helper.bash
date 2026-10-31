# Aísla cada test de la máquina: HOME, local.env y Brewfile de prueba, PATH mínimo con comandos
# falsos (brew, xcode-select, java_home) que registran sus llamadas, sin colores y sin preguntas.
setup_env() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  DEV_SETUP="$REPO_ROOT/bin/dev-setup"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset ZDOTDIR
  export SHELL=/bin/zsh
  export PATH="$STUBS:/usr/bin:/bin"
  export NO_COLOR=1
  export DEV_SETUP_NONINTERACTIVE=1
  export DEV_SETUP_LOCAL_ENV="$BATS_TEST_TMPDIR/local.env"
  export DEV_SETUP_BREWFILE="$REPO_ROOT/tests/fixtures/Brewfile"
  export DEV_SETUP_HOMEBREW_PREFIX="$BATS_TEST_TMPDIR/no-homebrew"
  export DEV_SETUP_JAVA_HOME_CMD="$STUBS/java_home"
  export FAKE_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$FAKE_LOG"

  # Estado simulado: tool-managed está en Homebrew; tool-external, App External y el JDK 17, fuera.
  export FAKE_BREW_FORMULAE="tool-managed"
  export FAKE_BREW_CASKS=""
  export FAKE_JDKS="17"
  make_stub brew <<'STUB'
printf 'brew %s\n' "$*" >>"$FAKE_LOG"
case "$1" in
  list)
    case "$2" in --formula) installed="$FAKE_BREW_FORMULAE" ;; *) installed="$FAKE_BREW_CASKS" ;; esac
    case " $installed " in *" $4 "*) echo "$4 1.0"; exit 0 ;; esac
    exit 1
    ;;
  --version) echo "Homebrew 9.9.9" ;;
  shellenv) echo ":" ;;
esac
exit 0
STUB
  make_stub xcode-select <<'STUB'
printf 'xcode-select %s\n' "$*" >>"$FAKE_LOG"
if [ "$1" = -p ]; then
  [ "${FAKE_NO_CLT:-0}" != 1 ] || exit 2
  echo /Library/Developer/CommandLineTools
fi
exit 0
STUB
  make_stub java_home <<'STUB'
[ "$1" = -v ] || exit 1
case " $FAKE_JDKS " in *" $2 "*) echo "/fake/jdk-$2"; exit 0 ;; esac
exit 1
STUB
  make_stub tool-external-bin <<'STUB'
exit 0
STUB
  mkdir -p "$HOME/Applications/App External.app"
}

# make_stub <nombre>: crea un comando falso en $STUBS con el cuerpo que llega por stdin.
make_stub() {
  { printf '#!/usr/bin/env bash\n'; cat; } >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}

# Carga las librerías y módulos para probar sus funciones directamente.
load_libs() {
  DEV_SETUP_ROOT="$REPO_ROOT"
  local lib
  for lib in log run prompt fs config shell; do
    # shellcheck source=/dev/null
    . "$REPO_ROOT/lib/$lib.sh"
  done
  # shellcheck source=/dev/null
  . "$REPO_ROOT/modules/base.sh"
}
