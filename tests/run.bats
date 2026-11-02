#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  load_libs
}

@test "run_cmd ejecuta el comando" {
  run_cmd touch "$HOME/archivo"
  [ -e "$HOME/archivo" ]
}

@test "run_cmd en --dry-run no ejecuta y lo anuncia" {
  DEV_SETUP_DRY_RUN=1
  run run_cmd touch "$HOME/archivo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] touch"* ]]
  [ ! -e "$HOME/archivo" ]
}

@test "run_cmd devuelve el codigo de salida del comando" {
  run run_cmd sh -c 'exit 3'
  [ "$status" -eq 3 ]
}

@test "run_cmd registra el comando y sus fallos en el log" {
  log_init prueba
  run_cmd true
  run_cmd false || true
  grep -q '\[CMD\] true' "$DEV_SETUP_LOG_FILE"
  grep -q '\[ERROR\] falló con código 1: false' "$DEV_SETUP_LOG_FILE"
}

@test "confirm sin terminal ni --yes rechaza, y con --yes acepta" {
  run confirm "¿Seguro?"
  [ "$status" -ne 0 ]
  DEV_SETUP_ASSUME_YES=1
  run confirm "¿Seguro?"
  [ "$status" -eq 0 ]
}

@test "quote_cmd cita solo lo necesario y se puede pegar en la terminal" {
  [ "$(quote_cmd brew install gh)" = "brew install gh" ]
  [ "$(quote_cmd echo 'a b' '')" = "echo 'a b' ''" ]
  eval "set -- $(quote_cmd "it's" 'x"$HOME' '~/a b' '')"
  [ "$#" -eq 4 ]
  [ "$1" = "it's" ]
  # shellcheck disable=SC2016
  [ "$2" = 'x"$HOME' ]
  [ "$3" = '~/a b' ]
  [ -z "$4" ]
}

@test "run_remote_installer descarga el instalador y lo corre con las variables indicadas" {
  export FAKE_INSTALLER_SCRIPT="$BATS_TEST_TMPDIR/instalador.sh"
  printf 'printf "corrio con X=%%s\\n" "$X" >>"$FAKE_LOG"\n' >"$FAKE_INSTALLER_SCRIPT"
  run run_remote_installer https://example.com/install.sh X=1
  [ "$status" -eq 0 ]
  grep -q '^curl -fsSL -o .* https://example.com/install.sh$' "$FAKE_LOG"
  grep -qx 'corrio con X=1' "$FAKE_LOG"
}

@test "si la descarga falla, run_remote_installer no corre nada y deja un paso pendiente" {
  run run_remote_installer https://example.com/install.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"No se pudo descargar https://example.com/install.sh"* ]]
  if run_remote_installer https://example.com/install.sh 2>/dev/null; then false; fi
  [[ "$DEV_SETUP_NEXT_STEPS" == *"no se pudo descargar https://example.com/install.sh"* ]]
}

@test "si el instalador falla, run_remote_installer devuelve su codigo" {
  export FAKE_INSTALLER_SCRIPT="$BATS_TEST_TMPDIR/instalador.sh"
  printf 'exit 3\n' >"$FAKE_INSTALLER_SCRIPT"
  run run_remote_installer https://example.com/install.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"falló (código 3)"* ]]
}

@test "en dry-run, run_remote_installer solo anuncia la descarga" {
  DEV_SETUP_DRY_RUN=1 run run_remote_installer https://example.com/install.sh X=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] curl -fsSL https://example.com/install.sh | X=1 bash"* ]]
  [ ! -s "$FAKE_LOG" ]
}
