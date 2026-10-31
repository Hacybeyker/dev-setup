#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  load_libs
  DEV_SETUP_ASSUME_YES=1
  FILE="$HOME/.zshrc"
}

backups() { find "$HOME" -name '.zshrc.bak-*' | wc -l | tr -d ' '; }

@test "ensure_block crea el archivo con el bloque" {
  ensure_block "$FILE" dev-setup 'export A=1'
  [ "$(cat "$FILE")" = "$(printf '# >>> dev-setup >>>\nexport A=1\n# <<< dev-setup <<<')" ]
}

@test "ensure_block conserva el resto del archivo y respalda antes de cambiar" {
  printf 'alias ll="ls -l"\n' >"$FILE"
  ensure_block "$FILE" dev-setup 'export A=1'
  head -n 1 "$FILE" | grep -qx 'alias ll="ls -l"'
  grep -qx 'export A=1' "$FILE"
  [ "$(backups)" -eq 1 ]
}

@test "ensure_block es idempotente: la segunda vez no cambia ni respalda" {
  printf 'alias ll="ls -l"\n' >"$FILE"
  ensure_block "$FILE" dev-setup 'export A=1'
  cp "$FILE" "$BATS_TEST_TMPDIR/first"
  run ensure_block "$FILE" dev-setup 'export A=1'
  [[ "$output" == *"ya está al día"* ]]
  cmp "$FILE" "$BATS_TEST_TMPDIR/first"
  [ "$(backups)" -eq 1 ]
}

@test "ensure_block reemplaza solo el contenido del bloque" {
  printf 'antes\n# >>> dev-setup >>>\nexport A=1\n# <<< dev-setup <<<\ndespués\n' >"$FILE"
  ensure_block "$FILE" dev-setup 'export A=2'
  [ "$(cat "$FILE")" = "$(printf 'antes\n# >>> dev-setup >>>\nexport A=2\n# <<< dev-setup <<<\ndespués')" ]
}

@test "ensure_block en --dry-run no toca el archivo" {
  printf 'original\n' >"$FILE"
  DEV_SETUP_DRY_RUN=1
  run ensure_block "$FILE" dev-setup 'export A=1'
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [ "$(cat "$FILE")" = original ]
  [ "$(backups)" -eq 0 ]
}

@test "ensure_block sin confirmación no toca el archivo" {
  printf 'original\n' >"$FILE"
  DEV_SETUP_ASSUME_YES=0
  run ensure_block "$FILE" dev-setup 'export A=1'
  [ "$status" -eq 0 ]
  [ "$(cat "$FILE")" = original ]
  [ "$(backups)" -eq 0 ]
}

@test "ensure_block se niega si el bloque está incompleto o repetido" {
  printf '# >>> dev-setup >>>\nexport A=1\n' >"$FILE"
  run ensure_block "$FILE" dev-setup 'export A=2'
  [ "$status" -eq 1 ]
  grep -qx 'export A=1' "$FILE"

  printf '# >>> dev-setup >>>\nA\n# <<< dev-setup <<<\n# >>> dev-setup >>>\nB\n# <<< dev-setup <<<\n' >"$FILE"
  cp "$FILE" "$BATS_TEST_TMPDIR/repeated"
  run ensure_block "$FILE" dev-setup 'export A=2'
  [ "$status" -eq 1 ]
  cmp "$FILE" "$BATS_TEST_TMPDIR/repeated"
}

@test "ensure_block escribe a través de un enlace simbólico y conserva permisos" {
  mkdir -p "$HOME/dotfiles"
  printf 'original\n' >"$HOME/dotfiles/zshrc"
  chmod 600 "$HOME/dotfiles/zshrc"
  ln -s "$HOME/dotfiles/zshrc" "$FILE"
  ensure_block "$FILE" dev-setup 'export A=1'
  [ -L "$FILE" ]
  grep -qx 'export A=1' "$HOME/dotfiles/zshrc"
  [ "$(stat -c %a "$HOME/dotfiles/zshrc" 2>/dev/null || stat -f %Lp "$HOME/dotfiles/zshrc")" = 600 ]
}

@test "backup_file no pisa un respaldo hecho en el mismo segundo" {
  printf 'uno\n' >"$FILE"
  backup_file "$FILE"
  backup_file "$FILE"
  [ "$(backups)" -eq 2 ]
}
