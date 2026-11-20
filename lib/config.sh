# shellcheck shell=bash
# Configuración propia de cada máquina en local.env (no se versiona).

# Lo que se elige instalar, en el orden en que se pregunta. Los seis primeros vienen activados por
# defecto (group_default); los demás, desactivados.
DEV_SETUP_GROUPS="android emulator ide github skills claude node ios ai-local terminal dev-tools"
DEV_SETUP_GROUP_OVERRIDES=""
# Otras claves que preguntó un módulo (<módulo>_ask) y se guardan en local.env.
DEV_SETUP_ASKED_KEYS=""

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
    android) printf 'Android CLI, SDK, skills oficiales de Android, memoria de Android Studio y trace_processor de Perfetto' ;;
    emulator) printf 'emulador de Android y su imagen de sistema; unos 3 GB' ;;
    ide) printf 'Temurin 21, el JDK para la terminal, y JetBrains Toolbox, para instalar Android Studio' ;;
    github) printf 'GitHub CLI (gh)' ;;
    skills) printf 'skills propias de agent-skills y testigo, para pruebas E2E con Maestro' ;;
    claude) printf 'Claude Code, con sus plugins y su configuración' ;;
    node) printf 'nvm, Node.js LTS y pnpm' ;;
    ios) printf 'revisa Xcode para el target iOS de KMP, sin instalar nada' ;;
    ai-local) printf 'LM Studio, para modelos locales' ;;
    terminal) printf 'Warp' ;;
    dev-tools) printf 'shellcheck y bats-core, para contribuir a dev-setup' ;;
  esac
}

# 1 si el grupo viene activado cuando no se eligió (por ejemplo, en update con un local.env anterior).
group_default() {
  case "$1" in
    android | emulator | ide | github | skills | claude) printf 1 ;;
    *) printf 0 ;;
  esac
}

# 0 si el grupo está activado: lo elegido en local.env o --with/--without, o su valor por defecto.
group_enabled() {
  local var value
  var="$(group_var "$1")"
  value="${!var:-}"
  [ -n "$value" ] || value="$(group_default "$1")"
  [ "$value" = 1 ]
}

# Claves aceptadas en local.env y su validación.
config_valid_entry() {
  local key="$1" value="$2" group
  for group in $DEV_SETUP_GROUPS; do
    if [ "$key" = "$(group_var "$group")" ]; then
      case "$value" in 0 | 1) return 0 ;; *) return 1 ;; esac
    fi
  done
  # Agentes de las skills oficiales de Android: nombres separados por comas, sin espacios.
  if [ "$key" = DEV_SETUP_ANDROID_SKILL_AGENTS ]; then
    case "$value" in '' | ,* | *, | *,,* | *[![:lower:][:digit:],-]*) return 1 ;; esac
    return 0
  fi
  # Memoria máxima de Android Studio: un número y m o g, por ejemplo 6144m u 8g.
  if [ "$key" = DEV_SETUP_STUDIO_XMX ]; then
    case "${value%[mg]}" in '' | *[!0-9]*) return 1 ;; esac
    [ "${value%[mg]}" != "$value" ]
    return
  fi
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

# Pregunta por los grupos que aún no tienen valor, con su valor por defecto. Sin terminal, queda el valor
# por defecto. El emulador no se pregunta si no se instala Android.
config_ask_groups() {
  local group var asked=0 enabled="" default
  for group in $DEV_SETUP_GROUPS; do
    var="$(group_var "$group")"
    if [ -z "${!var:-}" ]; then
      if [ "$group" = emulator ] && ! group_enabled android; then
        printf -v "$var" '%s' 0
        continue
      fi
      asked=1
      if [ "$(group_default "$group")" = 1 ]; then default=s; else default=n; fi
      if ask_yes_no "¿Instalar '$group'? ($(group_description "$group"))" "$default"; then
        printf -v "$var" '%s' 1
      else
        printf -v "$var" '%s' 0
      fi
    fi
    if group_enabled "$group"; then enabled="$enabled${enabled:+, }$group"; fi
  done
  if [ "$asked" = 0 ]; then
    info "Activos: ${enabled:-ninguno}. Se cambian con --with <grupo> y --without <grupo>"
  elif ! can_prompt; then
    info "Sin terminal para preguntar, se usan los valores por defecto. Activos: ${enabled:-ninguno}"
  fi
}

# Anota en el resumen los grupos que no se instalan.
config_summary_skipped() {
  local group list=""
  for group in $DEV_SETUP_GROUPS; do
    group_enabled "$group" || list="$list${list:+, }$group"
  done
  [ -z "$list" ] || summary_add omitido "$list (para instalar uno: dev-setup bootstrap --with <grupo>)"
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
  ok "$key=$value guardado en $file"
  summary_add configurado "tus elecciones en $(display_path "$file")"
}

# Guarda en local.env el valor de cada grupo que ya tenga uno y lo que preguntaron los módulos.
config_save_groups() {
  local group var key
  for group in $DEV_SETUP_GROUPS; do
    var="$(group_var "$group")"
    [ -z "${!var:-}" ] || config_set "$var" "${!var}"
  done
  for key in $DEV_SETUP_ASKED_KEYS; do
    [ -z "${!key:-}" ] || config_set "$key" "${!key}"
  done
}
