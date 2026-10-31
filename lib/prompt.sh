# shellcheck shell=bash
# Preguntas al usuario. Leen de /dev/tty para funcionar también con `curl ... | bash`.

# Hay terminal para preguntar (los tests fuerzan el modo no interactivo).
can_prompt() {
  [ "${DEV_SETUP_NONINTERACTIVE:-0}" != 1 ] || return 1
  { : </dev/tty; } 2>/dev/null
}

# ask_yes_no <pregunta> [s|n]: 0 si la respuesta es sí. Sin terminal devuelve el valor por defecto.
ask_yes_no() {
  local question="$1" default="${2:-n}" hint answer
  if [ "$default" = s ]; then hint="[S/n]"; else hint="[s/N]"; fi
  if ! can_prompt; then
    [ "$default" = s ]
    return
  fi
  while true; do
    printf '  ? %s %s ' "$question" "$hint" >/dev/tty
    read -r answer </dev/tty || answer=""
    case "$answer" in
      [sSyY]*) return 0 ;;
      [nN]*) return 1 ;;
      "") [ "$default" = s ]; return ;;
      *) printf '    Responde s o n.\n' >/dev/tty ;;
    esac
  done
}

# confirm <pregunta>: --yes la acepta sin preguntar; sin terminal se rechaza.
confirm() {
  [ "${DEV_SETUP_ASSUME_YES:-0}" != 1 ] || return 0
  ask_yes_no "$1" n
}
