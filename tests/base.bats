#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  export DEV_SETUP_SKIP_OS_CHECK=1
}

@test "doctor clasifica cada herramienta del Brewfile" {
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"tool-managed (Homebrew)"* ]]
  [[ "$output" == *"tool-external: instalado fuera de Homebrew"* ]]
  [[ "$output" == *"tool-missing: falta"* ]]
  [[ "$output" == *"app-external: instalado fuera de Homebrew"* ]]
  [[ "$output" == *"jdk-external: instalado fuera de Homebrew"* ]]
  [[ "$output" == *"app-optional: grupo ai-local desactivado"* ]]
  [ "$(grep -c 'brew install' "$FAKE_LOG")" -eq 0 ]
}

@test "bootstrap instala solo lo que falta y respeta lo que existe fuera de Homebrew" {
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  grep -qx 'brew install tool-missing' "$FAKE_LOG"
  [ "$(grep -c 'brew install' "$FAKE_LOG")" -eq 1 ]
}

@test "--with instala las herramientas del grupo" {
  run "$DEV_SETUP" bootstrap --with ai-local
  [ "$status" -eq 0 ]
  grep -qx 'brew install --cask app-optional' "$FAKE_LOG"
}

@test "bootstrap --dry-run anuncia la instalacion sin hacerla" {
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"*"install tool-missing"* ]]
  [ "$(grep -c 'brew install' "$FAKE_LOG")" -eq 0 ]
}

@test "update solo actualiza lo que gestiona Homebrew" {
  export FAKE_BREW_CASKS="app-managed"
  run "$DEV_SETUP" update
  [ "$status" -eq 0 ]
  grep -qx 'brew update' "$FAKE_LOG"
  grep -qx 'brew upgrade --formula tool-managed' "$FAKE_LOG"
  [ "$(grep -c 'brew upgrade --cask' "$FAKE_LOG")" -eq 0 ]
  [ "$(grep -c 'brew install' "$FAKE_LOG")" -eq 0 ]
  [[ "$output" == *"tool-missing: falta, corre dev-setup bootstrap"* ]]
}

@test "sin Homebrew, bootstrap --dry-run muestra su instalador oficial" {
  rm "$STUBS/brew"
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"* ]]
  [[ "$output" == *"brew install tool-missing"* ]]
}

@test "con Homebrew pero sin Command Line Tools, bootstrap las pide y se detiene" {
  export FAKE_NO_CLT=1
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 1 ]
  grep -qx 'xcode-select --install' "$FAKE_LOG"
  [ "$(grep -c 'brew install' "$FAKE_LOG")" -eq 0 ]
}

@test "bootstrap enlaza dev-setup en ~/.local/bin" {
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.local/bin/dev-setup")" = "$REPO_ROOT/bin/dev-setup" ]
  run "$DEV_SETUP" doctor
  [[ "$output" == *"Comando dev-setup en $HOME/.local/bin/dev-setup"* ]]
}

@test "bootstrap no reemplaza un ~/.local/bin/dev-setup ajeno" {
  mkdir -p "$HOME/.local/bin"
  printf 'mio\n' >"$HOME/.local/bin/dev-setup"
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.local/bin/dev-setup")" = mio ]
  [[ "$output" == *"no apunta a este repo"* ]]
}

@test "cada entrada del Brewfile real indica como detectarla fuera de Homebrew" {
  load_libs
  DEV_SETUP_BREWFILE="$REPO_ROOT/Brewfile"
  run brewfile_entries
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  while IFS='|' read -r kind name group htype hvalue; do
    [ -n "$name" ]
    case "$htype" in bin | app | jdk) ;; *) echo "sin detección: $name" >&2; return 1 ;; esac
    [ -n "$hvalue" ]
  done <<<"$output"
}

@test "el Brewfile real usa solo grupos que existen" {
  load_libs
  DEV_SETUP_BREWFILE="$REPO_ROOT/Brewfile"
  while IFS='|' read -r kind name group htype hvalue; do
    [ -z "$group" ] || is_group "$(group_name_from_var "$group")"
  done < <(brewfile_entries)
}
