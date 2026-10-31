# shellcheck shell=bash
# Bloque administrado en el archivo de arranque de zsh: ~/.zshrc, o $ZDOTDIR/.zshrc si existe.

SHELL_BLOCK_ID="dev-setup"

zshrc_path() { printf '%s/.zshrc' "${ZDOTDIR:-$HOME}"; }

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

warn_if_not_zsh() {
  case "${SHELL:-}" in
    */zsh) ;;
    *) warn "Tu shell es ${SHELL:-desconocido}: dev-setup solo configura zsh" ;;
  esac
}

shell_apply() {
  section "Shell ($(zshrc_path))"
  warn_if_not_zsh
  ensure_block "$(zshrc_path)" "$SHELL_BLOCK_ID" "$(shell_block_content)"
}

shell_doctor() {
  local file current expected
  file="$(zshrc_path)"
  section "Shell ($file)"
  warn_if_not_zsh
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
    warn "Falta el bloque de dev-setup: corre dev-setup bootstrap"
  elif [ "$current" = "$expected" ]; then
    ok "Bloque de dev-setup al día"
  else
    warn "El bloque de dev-setup está desactualizado: corre dev-setup update"
  fi
}
