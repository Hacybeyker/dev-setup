# shellcheck shell=bash
# Mensajes en la terminal y en el log de la ejecución.

# Colores solo en una terminal y si el usuario no pidió lo contrario (https://no-color.org).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RESET=$'\033[0m'
else
  C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_RESET=''
fi

# Escribe en el log si la ejecución tiene uno (bootstrap y update; nunca doctor ni --dry-run).
log_to_file() {
  [ -n "${DEV_SETUP_LOG_FILE:-}" ] || return 0
  printf '%s [%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$2" >>"$DEV_SETUP_LOG_FILE"
}

section() { printf '\n%s==> %s%s\n' "$C_BOLD" "$1" "$C_RESET"; log_to_file SECTION "$1"; }
info() { printf '  · %s\n' "$1"; log_to_file INFO "$1"; }
ok() { printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "$1"; log_to_file OK "$1"; }
warn() { printf '  %s⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$1" >&2; log_to_file WARN "$1"; }
error() { printf '  %s✖%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; log_to_file ERROR "$1"; }
die() { error "$1"; exit 1; }
dim() { printf '%s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# Crea el log de la ejecución en ~/Library/Logs/dev-setup/.
log_init() {
  local dir="$HOME/Library/Logs/dev-setup"
  mkdir -p "$dir"
  DEV_SETUP_LOG_FILE="$dir/dev-setup-$1-$(date +%Y%m%d-%H%M%S).log"
  : >"$DEV_SETUP_LOG_FILE"
  log_to_file START "dev-setup $1"
}
