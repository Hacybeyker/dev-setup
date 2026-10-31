# shellcheck shell=bash
# Único punto por el que pasa todo cambio en la máquina: respeta --dry-run y queda en el log.

is_dry_run() { [ "${DEV_SETUP_DRY_RUN:-0}" = 1 ]; }

# Devuelve el comando citado como se escribiría en la terminal.
quote_cmd() {
  local out="" arg
  for arg in "$@"; do
    out="$out $(printf '%q' "$arg")"
  done
  printf '%s' "${out# }"
}

# run_cmd <comando> [args...]: lo ejecuta, o solo lo anuncia en --dry-run.
# Devuelve el código de salida del comando.
run_cmd() {
  local cmd status=0
  cmd="$(quote_cmd "$@")"
  if is_dry_run; then
    printf '  %s[dry-run]%s %s\n' "$C_YELLOW" "$C_RESET" "$cmd"
    return 0
  fi
  log_to_file CMD "$cmd"
  "$@" || status=$?
  if [ "$status" -ne 0 ]; then
    log_to_file ERROR "falló con código $status: $cmd"
  fi
  return "$status"
}
