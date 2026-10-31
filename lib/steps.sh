# shellcheck shell=bash
# Pasos que le tocan al usuario (logins, apps de la App Store, abrir una terminal nueva).
# Cada módulo los anota con next_step desde <módulo>_next_steps y se muestran al final de
# bootstrap y update.

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
