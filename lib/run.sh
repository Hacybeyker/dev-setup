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

REMOTE_INSTALLER_ERROR=""

url_host() { printf '%s' "$1" | sed -e 's|^[a-z]*://||' -e 's|/.*||'; }

# Checksums de los archivos de arranque del shell, para saber si un instalador externo los cambió.
profile_checksums() {
  local file
  for file in .zshrc .zprofile .bash_profile .bashrc .profile; do
    printf '%s %s\n' "$file" "$({ cksum <"$HOME/$file"; } 2>/dev/null || printf 'no-existe')"
  done
}

# run_remote_installer <url> [VARIABLE=valor...]: descarga un instalador oficial a un archivo temporal y lo
# corre con bash y esas variables. Con `curl | bash`, una descarga fallida le pasa a bash un script vacío
# que termina bien; aquí, si la descarga falla no se corre nada. Si algo falla, avisa, deja el motivo en
# REMOTE_INSTALLER_ERROR y devuelve el código de error: quien lo llama decide si sigue y lo anota con
# installer_failed. Si el instalador cambió un archivo de arranque del shell, lo deja en el resumen.
run_remote_installer() {
  local url="$1" host script errors code status=0 before after file
  shift
  host="$(url_host "$url")"
  REMOTE_INSTALLER_ERROR=""
  if is_dry_run; then
    printf '  %s[dry-run]%s curl -fsSL %s | %s\n' "$C_YELLOW" "$C_RESET" "$url" "$(quote_cmd "$@" bash)"
    return 0
  fi
  script="$(new_temp_file)"
  errors="$(new_temp_file)"
  if ! run_cmd curl -fsSL -o "$script" "$url" 2>"$errors"; then
    cat "$errors" >&2
    code="$(sed -n 's/.*returned error: \([0-9][0-9]*\).*/\1/p' "$errors" | head -n 1)"
    rm -f "$script" "$errors"
    if [ -n "$code" ]; then
      REMOTE_INSTALLER_ERROR="$host rechazó la descarga (HTTP $code): puede que tu red o un proxy lo bloquee"
    else
      REMOTE_INSTALLER_ERROR="no se pudo descargar de $host: revisa tu conexión"
    fi
    error "No se pudo descargar $url: $REMOTE_INSTALLER_ERROR"
    return 1
  fi
  rm -f "$errors"
  before="$(profile_checksums)"
  run_cmd env "$@" /bin/bash "$script" || status=$?
  after="$(profile_checksums)"
  rm -f "$script"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    warn "El instalador de $host cambió ~/$file"
    summary_add externo "$(display_path "$HOME/$file") (instalador de $host)"
  done < <(awk 'NR == FNR { seen[$1] = $0; next } seen[$1] != $0 { print $1 }' \
    <(printf '%s\n' "$before") <(printf '%s\n' "$after"))
  if [ "$status" -ne 0 ]; then
    REMOTE_INSTALLER_ERROR="su instalador falló (código $status)"
    error "El instalador de $url falló (código $status)"
  fi
  return "$status"
}

# installer_failed <nombre> [motivo]: anota la falla en el resumen y en "Lo que te toca". Sin motivo, usa el
# de run_remote_installer.
installer_failed() {
  local reason="${2:-${REMOTE_INSTALLER_ERROR:-falló su instalador}}"
  summary_add fallo "$1: $reason"
  next_step "$1 no se instaló: $reason. Cuando lo resuelvas, vuelve a correr dev-setup bootstrap"
}

# run_logged <comando> [args...]: como run_cmd, pero su salida va solo al log.
run_logged() {
  if is_dry_run; then
    run_cmd "$@"
    return 0
  fi
  run_cmd "$@" >>"${DEV_SETUP_LOG_FILE:-/dev/null}" 2>&1
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
