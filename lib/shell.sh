# shellcheck shell=bash
# Bloque administrado en el archivo de arranque del shell: ~/.zshrc (o $ZDOTDIR/.zshrc) con zsh y
# ~/.bash_profile con bash, que es el que leen las terminales de macOS. Las líneas del bloque funcionan en
# los dos.

SHELL_BLOCK_ID="dev-setup"

shell_rc_path() {
  case "${SHELL:-}" in
    */bash) printf '%s/.bash_profile' "$HOME" ;;
    *) printf '%s/.zshrc' "${ZDOTDIR:-$HOME}" ;;
  esac
}

# Cabecera y las líneas que aporta cada módulo con <módulo>_shell.
shell_block_content() {
  local module
  printf '%s\n' '# Lo mantiene dev-setup (https://github.com/Hacybeyker/dev-setup): no edites dentro del bloque.'
  printf '%s\n' '# Cada línea respeta lo que ya tengas definido antes de este bloque.'
  for module in ${DEV_SETUP_MODULES:-}; do
    if declare -F "${module}_shell" >/dev/null; then
      "${module}_shell"
    fi
  done
}

warn_if_unsupported_shell() {
  case "${SHELL:-}" in
    */zsh | */bash) ;;
    *) warn "Tu shell es ${SHELL:-desconocido}: dev-setup configura zsh y bash; se usa ~/.zshrc" ;;
  esac
}

# Estado del bloque en el archivo de arranque: ok, falta o desactualizado.
shell_block_state() {
  local file current expected
  file="$(shell_rc_path)"
  expected="$(printf '# >>> %s >>>\n%s\n# <<< %s <<<' "$SHELL_BLOCK_ID" "$(shell_block_content)" "$SHELL_BLOCK_ID")"
  current=""
  if [ -f "$file" ]; then
    current="$(awk -v begin="# >>> $SHELL_BLOCK_ID >>>" -v end="# <<< $SHELL_BLOCK_ID <<<" '
      $0 == begin { inside = 1 }
      inside { print }
      inside && $0 == end { exit }
    ' "$file")"
  fi
  if [ -z "$current" ]; then
    printf 'falta'
  elif [ "$current" = "$expected" ]; then
    printf 'ok'
  else
    printf 'desactualizado'
  fi
}

shell_apply() {
  local file before after display
  file="$(shell_rc_path)"
  display="$(display_path "$file")"
  section "Shell ($file)"
  warn_if_unsupported_shell
  before="$({ cksum <"$file"; } 2>/dev/null || true)"
  ensure_block "$file" "$SHELL_BLOCK_ID" "$(shell_block_content)"
  after="$({ cksum <"$file"; } 2>/dev/null || true)"
  if [ "$before" != "$after" ]; then
    SHELL_CHANGED=1
    summary_add configurado "bloque de dev-setup en $display"
  elif [ "$(shell_block_state)" = ok ]; then
    summary_add ya "bloque de dev-setup en $display"
  else
    summary_add omitido "bloque de dev-setup en $display (no aceptaste el cambio)"
  fi
}

shell_next_steps() {
  if [ "${SHELL_CHANGED:-0}" = 1 ]; then
    next_step "Abre una terminal nueva (o corre: source $(shell_rc_path)) para cargar los cambios"
  fi
}

shell_doctor() {
  section "Shell ($(shell_rc_path))"
  warn_if_unsupported_shell
  case "$(shell_block_state)" in
    falta) warn "Falta el bloque de dev-setup: corre dev-setup bootstrap" ;;
    ok) ok "Bloque de dev-setup al día" ;;
    *) warn "El bloque de dev-setup está desactualizado: corre dev-setup update" ;;
  esac
}
