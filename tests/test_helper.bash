# Aísla cada test: HOME y local.env temporales, sin colores y sin preguntas.
setup_env() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export DEV_SETUP_LOCAL_ENV="$BATS_TEST_TMPDIR/local.env"
  export DEV_SETUP_NONINTERACTIVE=1
  export NO_COLOR=1
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  DEV_SETUP="$REPO_ROOT/bin/dev-setup"
}

# Carga las librerías para probar sus funciones directamente.
load_libs() {
  DEV_SETUP_ROOT="$REPO_ROOT"
  local lib
  for lib in log run prompt fs config; do
    # shellcheck source=/dev/null
    . "$REPO_ROOT/lib/$lib.sh"
  done
}
