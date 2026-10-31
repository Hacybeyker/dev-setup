# shellcheck shell=bash
# Configuración propia de cada máquina en local.env (no se versiona).

DEV_SETUP_GROUPS="ai-local terminal node ios"
DEV_SETUP_GROUP_OVERRIDES=""

local_env_path() { printf '%s' "${DEV_SETUP_LOCAL_ENV:-$DEV_SETUP_ROOT/local.env}"; }

is_group() {
  case " $DEV_SETUP_GROUPS " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# ai-local → DEV_SETUP_AI_LOCAL
group_var() { printf 'DEV_SETUP_%s' "$(printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_')"; }

group_description() {
  case "$1" in
    ai-local) printf 'LM Studio, para modelos locales' ;;
    terminal) printf 'Warp' ;;
    node) printf 'nvm, Node.js LTS y pnpm' ;;
    ios) printf 'aviso para instalar Xcode, para el target iOS de KMP' ;;
  esac
}

# 0 si el grupo está activado.
group_enabled() {
  local var
  var="$(group_var "$1")"
  [ "${!var:-0}" = 1 ]
}

# Claves aceptadas en local.env y su validación.
config_valid_entry() {
  local key="$1" value="$2" group
  for group in $DEV_SETUP_GROUPS; do
    if [ "$key" = "$(group_var "$group")" ]; then
      case "$value" in 0 | 1) return 0 ;; *) return 1 ;; esac
    fi
  done
  return 1
}

# Lee local.env sin ejecutarlo: solo acepta líneas CLAVE=valor conocidas y válidas.
config_load() {
  local file line key value
  file="$(local_env_path)"
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    key="${line%%=*}"
    value="${line#*=}"
    if [ "$key" = "$line" ] || ! config_valid_entry "$key" "$value"; then
      warn "local.env: línea ignorada: $line"
      continue
    fi
    printf -v "$key" '%s' "$value"
  done <"$file"
}

# Registra --with/--without; se aplican después de leer local.env.
config_override_group() {
  local group="$1" value="$2"
  is_group "$group" || return 1
  DEV_SETUP_GROUP_OVERRIDES="$DEV_SETUP_GROUP_OVERRIDES $group=$value"
}

config_apply_overrides() {
  local pair
  for pair in $DEV_SETUP_GROUP_OVERRIDES; do
    printf -v "$(group_var "${pair%%=*}")" '%s' "${pair#*=}"
  done
}

# Pregunta por los grupos que aún no tienen valor. Sin terminal quedan desactivados.
config_ask_groups() {
  local group var
  for group in $DEV_SETUP_GROUPS; do
    var="$(group_var "$group")"
    [ -z "${!var:-}" ] || continue
    if ask_yes_no "¿Instalar el grupo opcional '$group' ($(group_description "$group"))?" n; then
      printf -v "$var" '%s' 1
    else
      printf -v "$var" '%s' 0
    fi
  done
}

# config_set <clave> <valor>: actualiza o agrega la línea en local.env sin tocar las demás.
config_set() {
  local key="$1" value="$2" file tmp
  file="$(local_env_path)"
  if [ -f "$file" ] && grep -qFx -- "$key=$value" "$file"; then
    return 0
  fi
  if is_dry_run; then
    printf '  %s[dry-run]%s %s: %s=%s\n' "$C_YELLOW" "$C_RESET" "$file" "$key" "$value"
    return 0
  fi
  tmp="$(new_temp_file)"
  if [ -f "$file" ]; then
    awk -v key="$key" -v line="$key=$value" '
      index($0, key "=") == 1 { if (!done) print line; done = 1; next }
      { print }
      END { if (!done) print line }
    ' "$file" >"$tmp"
  else
    printf '%s\n%s\n\n%s\n' \
      '# Configuración de dev-setup para esta máquina. No se versiona.' \
      '# Formato y opciones en local.env.example.' \
      "$key=$value" >"$tmp"
  fi
  run_cmd cp "$tmp" "$file"
  rm -f "$tmp"
  log_to_file CONFIG "$key=$value"
}

# Guarda en local.env el valor de cada grupo que ya tenga uno.
config_save_groups() {
  local group var
  for group in $DEV_SETUP_GROUPS; do
    var="$(group_var "$group")"
    [ -z "${!var:-}" ] || config_set "$var" "${!var}"
  done
}
