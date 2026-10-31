#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
}

@test "--help lista los subcomandos y los grupos" {
  run "$DEV_SETUP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *doctor* ]]
  [[ "$output" == *bootstrap* ]]
  [[ "$output" == *update* ]]
  [[ "$output" == *ai-local* ]]
}

@test "sin subcomando muestra el uso y sale con 2" {
  run "$DEV_SETUP"
  [ "$status" -eq 2 ]
  [[ "$output" == *Uso:* ]]
}

@test "un subcomando o una opcion desconocida sale con 2" {
  run "$DEV_SETUP" frob
  [ "$status" -eq 2 ]
  run "$DEV_SETUP" doctor --frob
  [ "$status" -eq 2 ]
}

@test "dos subcomandos salen con 2" {
  run "$DEV_SETUP" doctor update
  [ "$status" -eq 2 ]
}

@test "--with rechaza un grupo inexistente o vacio" {
  run "$DEV_SETUP" doctor --with frob
  [ "$status" -eq 2 ]
  [[ "$output" == *frob* ]]
  run "$DEV_SETUP" doctor --with
  [ "$status" -eq 2 ]
}

@test "--version imprime la version" {
  run "$DEV_SETUP" --version
  [ "$status" -eq 0 ]
  [[ "$output" == "dev-setup "* ]]
}

@test "funciona invocado por un enlace simbolico" {
  mkdir -p "$HOME/.local/bin"
  ln -s "$DEV_SETUP" "$HOME/.local/bin/dev-setup"
  run "$HOME/.local/bin/dev-setup" --version
  [ "$status" -eq 0 ]
}

@test "doctor no crea ningun archivo" {
  find "$HOME" | sort >"$BATS_TEST_TMPDIR/before"
  run "$DEV_SETUP" doctor --with node
  [ "$status" -eq 0 ]
  [ ! -e "$DEV_SETUP_LOCAL_ENV" ]
  find "$HOME" | sort | cmp - "$BATS_TEST_TMPDIR/before"
}

@test "bootstrap --dry-run no crea ningun archivo" {
  find "$HOME" | sort >"$BATS_TEST_TMPDIR/before"
  run "$DEV_SETUP" bootstrap --dry-run --with node
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [ ! -e "$DEV_SETUP_LOCAL_ENV" ]
  find "$HOME" | sort | cmp - "$BATS_TEST_TMPDIR/before"
}

@test "bootstrap fuera de macOS y sin --dry-run se niega" {
  [ "$(uname -s)" != Darwin ] || skip "solo aplica fuera de macOS"
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 1 ]
  [[ "$output" == *"solo instala en macOS"* ]]
}

@test "bootstrap deja un log en ~/Library/Logs/dev-setup" {
  DEV_SETUP_SKIP_OS_CHECK=1 run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  ls "$HOME/Library/Logs/dev-setup/"dev-setup-bootstrap-*.log
}
