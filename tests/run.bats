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
