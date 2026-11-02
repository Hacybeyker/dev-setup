# shellcheck shell=bash
# Único punto por el que pasa todo cambio en la máquina: respeta --dry-run y queda en el log.

is_dry_run() { [ "${DEV_SETUP_DRY_RUN:-0}" = 1 ]; }

# Devuelve el comando citado como se escribiría en la terminal: entre comillas simples solo
# los argumentos que lo necesitan.
quote_cmd() {
  local out="" arg escaped q="'\\''"
  for arg in "$@"; do
    case "$arg" in
      '') arg="''" ;;
      *[!A-Za-z0-9_./:=@%+,-]*)
        # Sin comillas dobles: así el Bash 3.2 de macOS trata la comilla del patrón igual que Bash 5.
        escaped=${arg//\'/$q}
        arg="'$escaped'"
        ;;
    esac
    out="$out $arg"
  done
  printf '%s' "${out# }"
}

# run_remote_installer <url> [VARIABLE=valor...]: descarga un instalador oficial a un archivo temporal y lo
# corre con bash y esas variables. Con `curl | bash`, una descarga fallida le pasa a bash un script vacío
# que termina bien; aquí, si la descarga falla no se corre nada. Si algo falla, avisa, deja un paso
# pendiente y devuelve el código de error: quien lo llama decide si sigue.
run_remote_installer() {
  local url="$1" script status=0
  shift
  if is_dry_run; then
    printf '  %s[dry-run]%s curl -fsSL %s | %s\n' "$C_YELLOW" "$C_RESET" "$url" "$(quote_cmd "$@" bash)"
    return 0
  fi
  script="$(new_temp_file)"
  if ! run_cmd curl -fsSL -o "$script" "$url"; then
    rm -f "$script"
    error "No se pudo descargar $url"
    next_step "Cuando tengas conexión, vuelve a correr dev-setup: no se pudo descargar $url"
    return 1
  fi
  run_cmd env "$@" /bin/bash "$script" || status=$?
  rm -f "$script"
  if [ "$status" -ne 0 ]; then
    error "El instalador de $url falló (código $status)"
    next_step "Revisa el error del instalador de $url y vuelve a correr dev-setup"
  fi
  return "$status"
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
