#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  export DEV_SETUP_SKIP_OS_CHECK=1
}

@test "bootstrap --yes escribe el bloque en ~/.zshrc y la segunda vez no cambia nada" {
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  grep -qx '# >>> dev-setup >>>' "$HOME/.zshrc"
  grep -q 'HOME/.local/bin' "$HOME/.zshrc"
  grep -q 'java_home -v 17' "$HOME/.zshrc"
  cp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/first"
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  cmp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/first"
  [ "$(find "$HOME" -name '.zshrc.bak-*' | wc -l | tr -d ' ')" -eq 0 ]
}

@test "sin --yes ni terminal, bootstrap no toca ~/.zshrc" {
  printf 'alias ll="ls -l"\n' >"$HOME/.zshrc"
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.zshrc")" = 'alias ll="ls -l"' ]
  [[ "$output" == *"Sin cambios en $HOME/.zshrc"* ]]
}

@test "doctor avisa si falta el bloque y lo da por bueno despues de bootstrap" {
  run "$DEV_SETUP" doctor
  [[ "$output" == *"Falta el bloque de dev-setup"* ]]
  "$DEV_SETUP" bootstrap --yes >/dev/null
  run "$DEV_SETUP" doctor
  [[ "$output" == *"Bloque de dev-setup al día"* ]]
}

@test "doctor detecta un bloque desactualizado" {
  printf '# >>> dev-setup >>>\nexport VIEJO=1\n# <<< dev-setup <<<\n' >"$HOME/.zshrc"
  run "$DEV_SETUP" doctor
  [[ "$output" == *"desactualizado"* ]]
}

@test "respeta ZDOTDIR" {
  export ZDOTDIR="$BATS_TEST_TMPDIR/zdot"
  mkdir -p "$ZDOTDIR"
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  grep -qx '# >>> dev-setup >>>' "$ZDOTDIR/.zshrc"
  [ ! -e "$HOME/.zshrc" ]
}

@test "el bloque es valido para zsh y bash" {
  "$DEV_SETUP" bootstrap --yes >/dev/null
  bash -n "$HOME/.zshrc"
  if command -v zsh >/dev/null; then zsh -n "$HOME/.zshrc"; fi
}

@test "avisa si el shell no es zsh" {
  export SHELL=/bin/bash
  run "$DEV_SETUP" doctor
  [[ "$output" == *"solo configura zsh"* ]]
}
