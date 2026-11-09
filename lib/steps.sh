# shellcheck shell=bash
# Cierre de bootstrap y update: el resumen de lo que pasó, los comandos para verificar y los pasos que
# le tocan al usuario (logins, apps de la App Store, abrir una terminal nueva). Los módulos anotan el
# resumen con summary_add, los pasos con next_step (desde <módulo>_next_steps) y los comandos de
# verificación imprimiéndolos desde <módulo>_verify.

DEV_SETUP_NEXT_STEPS=""

next_step() {
  DEV_SETUP_NEXT_STEPS="$DEV_SETUP_NEXT_STEPS$1
"
}

print_next_steps() {
  local step n=0
  section "Lo que te toca"
  if [ -z "$DEV_SETUP_NEXT_STEPS" ]; then
    ok "Nada pendiente"
    return 0
  fi
  while IFS= read -r step; do
    [ -n "$step" ] || continue
    n=$((n + 1))
    printf '  %d. %s\n' "$n" "$step"
    log_to_file STEP "$step"
  done <<STEPS
$DEV_SETUP_NEXT_STEPS
STEPS
}

DEV_SETUP_SUMMARY=""

# summary_add <categoría> <texto>. Categorías: instalado, actualizado, revisado, configurado, ya,
# omitido, fallo y externo.
summary_add() {
  DEV_SETUP_SUMMARY="$DEV_SETUP_SUMMARY$1|$2
"
}

summary_label() {
  case "$1" in
    instalado) printf 'Instalado' ;;
    actualizado) printf 'Actualizado' ;;
    revisado) printf 'Revisado (se actualizó si había versión nueva)' ;;
    configurado) printf 'Configurado' ;;
    ya) printf 'Ya estaba (se respetó)' ;;
    omitido) printf 'Omitido por tu elección' ;;
    fallo) printf 'Falló' ;;
    externo) printf 'Cambiado por un instalador externo' ;;
  esac
}

# Los textos de una categoría, uno por línea y sin repetir.
summary_items() {
  printf '%s' "$DEV_SETUP_SUMMARY" | awk -F'|' -v category="$1" '
    $1 == category { sub(/^[^|]*\|/, ""); if (!seen[$0]++) print }
  '
}

# Una categoría por bloque: su título con el ícono de su tipo y debajo, un elemento por línea.
print_summary() {
  local category items label item
  section "Resumen"
  if [ -z "$DEV_SETUP_SUMMARY" ]; then
    info "Sin cambios"
    return 0
  fi
  for category in instalado actualizado revisado configurado ya omitido fallo externo; do
    items="$(summary_items "$category")"
    [ -n "$items" ] || continue
    label="$(summary_label "$category"):"
    case "$category" in
      fallo) error "$label" ;;
      externo) warn "$label" ;;
      ya | omitido) info "$label" ;;
      *) ok "$label" ;;
    esac
    while IFS= read -r item; do
      printf '      %s\n' "$item"
      log_to_file INFO "  $item"
    done <<ITEMS
$items
ITEMS
  done
}

# print_verify <comandos>: los comandos de <módulo>_verify, más dev-setup doctor.
print_verify() {
  local cmd
  section "Para verificar (en una terminal nueva)"
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    printf '  %s\n' "$cmd"
  done <<VERIFY
$1
dev-setup doctor
VERIFY
}
