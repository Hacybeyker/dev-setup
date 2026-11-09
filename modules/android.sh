# shellcheck shell=bash
# Android: Android CLI, paquetes del SDK, skills oficiales para los agentes elegidos y el entorno de la terminal.

# Agentes de las skills oficiales: DEV_SETUP_ANDROID_SKILL_AGENTS en local.env, con los nombres de
# `android skills list` (claude-code, github-copilot...). bootstrap lo pregunta la primera vez. Sin elegir,
# Claude Code si está su grupo; si no, ninguno (android-studio: Android Studio ya trae las oficiales).
android_default_agents() {
  if group_enabled claude; then printf claude-code; else printf android-studio; fi
}

android_data_dir() { printf '%s' "${DEV_SETUP_ANDROID_DATA:-$DEV_SETUP_ROOT/android}"; }
claude_skills_dir() { printf '%s/skills' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }

android_cli_install_url() {
  local arch=arm64
  [ "$(uname -m)" = arm64 ] || arch=x86_64
  printf 'https://dl.google.com/android/cli/latest/darwin_%s/install.sh' "$arch"
}

# Ruta del Android CLI, aunque ~/.local/bin aún no esté en el PATH (recién instalado).
android_cmd() {
  if command -v android >/dev/null 2>&1; then
    command -v android
  elif [ -x "$HOME/.local/bin/android" ]; then
    printf '%s' "$HOME/.local/bin/android"
  else
    return 1
  fi
}

# Paquetes instalados según `android sdk list` (primera columna de "Installed packages:").
android_installed_packages() {
  "$1" sdk list 2>/dev/null | awk '
    /^Installed packages:/ { inside = 1; next }
    /^[^ \t]/ { inside = 0 }
    inside && NF { print $1 }
  '
}

# Paquetes de sdk-packages.txt cuyo grupo (la segunda columna, si la hay) está activado.
android_sdk_packages() {
  local package group
  while read -r package group <&5; do
    [ -z "$group" ] || group_enabled "$group" || continue
    printf '%s\n' "$package"
  done 5< <(list_entries "$(android_data_dir)/sdk-packages.txt")
}

ANDROID_UNKNOWN_AGENTS=""

# Agentes elegidos, separados por comas, sin android-studio: Android Studio ya trae todas las oficiales.
android_skill_agents() {
  local agent list=""
  for agent in $(printf '%s' "${DEV_SETUP_ANDROID_SKILL_AGENTS:-$(android_default_agents)}" | tr ',' ' '); do
    [ "$agent" = android-studio ] || list="$list${list:+,}$agent"
  done
  printf '%s' "$list"
}

android_skill_agents_label() {
  local agents
  agents="$(android_skill_agents)"
  printf '%s' "${agents:-solo Android Studio, que ya las trae}"
}

# Avisa si android-studio viene junto a otros agentes; solo, significa "ninguno más".
android_warn_ignored_agents() {
  [ "${DEV_SETUP_ANDROID_SKILL_AGENTS:-}" != android-studio ] || return 0
  case ",${DEV_SETUP_ANDROID_SKILL_AGENTS:-}," in
    *,android-studio,*) warn "android-studio se omite en DEV_SETUP_ANDROID_SKILL_AGENTS: Android Studio ya trae las skills oficiales" ;;
  esac
}

# Agentes que se ven en la máquina, para proponerlos en bootstrap. Sin ninguno, android-studio.
android_detect_agents() {
  local list=""
  if group_enabled claude || [ -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ]; then list=claude-code; fi
  if [ -d "$HOME/.copilot" ] || [ -d "$HOME/.config/github-copilot" ]; then list="$list${list:+,}github-copilot"; fi
  [ ! -d "$HOME/.junie" ] || list="$list${list:+,}junie"
  [ ! -d "$HOME/.codex" ] || list="$list${list:+,}codex"
  [ ! -d "$HOME/.gemini" ] || list="$list${list:+,}gemini"
  [ ! -d "$HOME/.cursor" ] || list="$list${list:+,}cursor"
  [ ! -d "$HOME/.config/opencode" ] || list="$list${list:+,}opencode"
  printf '%s' "${list:-android-studio}"
}

android_valid_agents() { config_valid_entry DEV_SETUP_ANDROID_SKILL_AGENTS "$1"; }

# bootstrap: pregunta para qué agentes instalar las skills oficiales, si aún no se eligió.
android_ask() {
  [ -z "${DEV_SETUP_ANDROID_SKILL_AGENTS:-}" ] || return 0
  can_prompt || return 0
  info "Android Studio ya trae las skills oficiales de Android. Puedes instalarlas también para otros agentes:"
  info "claude-code, github-copilot, junie, codex, gemini, cursor u opencode (separados por comas)."
  info "Con android-studio no se instalan para ningún otro."
  DEV_SETUP_ANDROID_SKILL_AGENTS="$(ask_text "¿Para qué agentes instalar las skills oficiales de Android?" \
    "$(android_detect_agents)" android_valid_agents)"
  DEV_SETUP_ASKED_KEYS="$DEV_SETUP_ASKED_KEYS DEV_SETUP_ANDROID_SKILL_AGENTS"
}

# Un agente que el CLI no reconoce se salta: no detiene bootstrap ni update.
android_warn_unknown_agent() {
  warn "Android CLI no reconoce el agente '$1' de DEV_SETUP_ANDROID_SKILL_AGENTS: se salta. Los nombres válidos salen con: android skills list --agent=$1"
  case ", $ANDROID_UNKNOWN_AGENTS," in
    *", $1,"*) ;;
    *) ANDROID_UNKNOWN_AGENTS="$ANDROID_UNKNOWN_AGENTS${ANDROID_UNKNOWN_AGENTS:+, }$1" ;;
  esac
}

# Un agente por línea.
android_skill_agent_list() {
  local agent
  for agent in $(android_skill_agents | tr ',' ' '); do printf '%s\n' "$agent"; done
}

# Salida de `android skills list --agent=<agente>`: un bloque por skill instalada, con el nombre solo en su
# primera línea. Falla si el CLI no reconoce el agente (sale con 1).
android_installed_skills() { "$1" skills list "--agent=$2" 2>/dev/null; }

# skill_in_list <skill> <salida de android_installed_skills>
skill_in_list() { printf '%s\n' "$2" | grep -qxF -- "$1"; }

android_studio_app() {
  local app
  for app in "$HOME/Applications/Android Studio.app" "/Applications/Android Studio.app"; do
    if [ -d "$app" ]; then
      printf '%s' "$app"
      return 0
    fi
  done
  return 1
}

# Skills que Android Studio vería dos veces: en ~/.agents/skills (copia, no enlace) y en ~/.android-studio/skills.
android_duplicated_skills() {
  local dir name
  [ -d "$HOME/.agents/skills" ] && [ -d "$HOME/.android-studio/skills" ] || return 0
  for dir in "$HOME/.agents/skills"/*/; do
    dir="${dir%/}"
    name="$(basename "$dir")"
    [ -L "$dir" ] && continue
    [ -d "$HOME/.android-studio/skills/$name" ] && printf '%s\n' "$name"
  done
  return 0
}

android_ensure_cli() {
  local android
  if android="$(android_cmd)"; then
    ok "Android CLI: $android"
    summary_add ya "Android CLI"
    return 0
  fi
  info "Instalando Android CLI con su instalador oficial (sin sudo, en ~/.local/bin)"
  if ! run_remote_installer "$(android_cli_install_url)"; then
    installer_failed "Android CLI"
    return 1
  fi
  is_dry_run && return 0
  if ! android="$(android_cmd)"; then
    warn "Android CLI no quedó instalado; revisa el mensaje de su instalador"
    installer_failed "Android CLI" "su instalador terminó sin dejar el comando android"
    return 1
  fi
  ok "Android CLI: $android"
  summary_add instalado "Android CLI"
}

android_install_sdk() {
  local android installed package missing="" present=0
  android="$(android_cmd)" || android=android
  installed="$(android_installed_packages "$android" || true)"
  while IFS= read -r package <&3; do
    if printf '%s\n' "$installed" | grep -qxF -- "$package"; then
      ok "$package ya está"
      present=$((present + 1))
    else
      missing="$missing $package"
    fi
  done 3< <(android_sdk_packages)
  [ "$present" -eq 0 ] || summary_add ya "paquetes del SDK de Android ($present)"
  [ -n "$missing" ] || return 0
  info "Si es la primera vez, el SDK te pide aceptar sus licencias"
  # Las rutas de paquetes no tienen espacios: la separación en palabras es intencional.
  # shellcheck disable=SC2086
  if run_cmd "$android" sdk install $missing; then
    is_dry_run || summary_add instalado "SDK de Android: $(printf '%s' "${missing# }" | sed 's/ /, /g')"
  else
    error "No se pudo instalar el SDK de Android"
    summary_add fallo "SDK de Android: falló android sdk install"
    next_step "Revisa el error de android sdk install y vuelve a correr dev-setup bootstrap"
  fi
}

android_install_skills() {
  local android agent agent_skills skill added present
  # Sin CLI (solo pasa en --dry-run, antes de instalarlo) todas las skills faltan.
  android="$(android_cmd)" || android=""
  android_warn_ignored_agents
  while IFS= read -r agent <&4; do
    agent_skills=""
    if [ -n "$android" ] && ! agent_skills="$(android_installed_skills "$android" "$agent")"; then
      android_warn_unknown_agent "$agent"
      continue
    fi
    added=0 present=0
    while IFS= read -r skill <&3; do
      if skill_in_list "$skill" "$agent_skills"; then
        ok "$skill ya está para $agent"
        present=$((present + 1))
      elif run_cmd "${android:-android}" skills add "--agent=$agent" "$skill"; then
        added=$((added + 1))
      else
        error "No se pudo instalar la skill $skill para $agent"
        summary_add fallo "skill oficial $skill para $agent"
      fi
    done 3< <(list_entries "$(android_data_dir)/skills.txt")
    [ "$present" -eq 0 ] || summary_add ya "skills oficiales de Android para $agent ($present)"
    [ "$added" -eq 0 ] || is_dry_run || summary_add instalado "skills oficiales de Android para $agent ($added)"
  done 4< <(android_skill_agent_list)
}

android_install() {
  section "Android"
  if ! android_ensure_cli; then
    warn "Sin Android CLI se saltan el SDK y las skills oficiales"
    return 0
  fi
  section "SDK de Android"
  android_install_sdk
  section "Skills oficiales de Android ($(android_skill_agents_label))"
  android_install_skills
  android_warn_duplicates
}

android_update() {
  local android installed package agent agent_skills skill missing="" checked
  section "Android"
  if ! android="$(android_cmd)"; then
    warn "Falta Android CLI: corre dev-setup bootstrap"
    return 0
  fi
  run_cmd "$android" update || warn "android update falló"
  installed="$(android_installed_packages "$android" || true)"
  while IFS= read -r package <&3; do
    if printf '%s\n' "$installed" | grep -qxF -- "$package"; then
      run_cmd "$android" sdk update "$package" || warn "No se pudo actualizar $package"
    else
      warn "$package: falta"
      missing="$missing $package"
    fi
  done 3< <(android_sdk_packages)
  [ -z "$missing" ] || next_step "Para instalar lo que falta del SDK de Android (${missing# }), corre dev-setup bootstrap"
  android_warn_ignored_agents
  while IFS= read -r agent <&4; do
    if ! agent_skills="$(android_installed_skills "$android" "$agent")"; then
      android_warn_unknown_agent "$agent"
      continue
    fi
    checked=0
    while IFS= read -r skill <&3; do
      skill_in_list "$skill" "$agent_skills" || continue
      # Su salida (una línea por skill) va al log: en pantalla queda una línea por agente.
      if run_logged "$android" skills update "--agent=$agent" "$skill"; then
        checked=$((checked + 1))
      else
        warn "No se pudo actualizar $skill para $agent: el detalle está en el log"
      fi
    done 3< <(list_entries "$(android_data_dir)/skills.txt")
    [ "$checked" -eq 0 ] || ok "Skills oficiales de Android revisadas para $agent ($checked)"
  done 4< <(android_skill_agent_list)
  summary_add revisado "Android CLI, SDK de Android y skills oficiales de Android"
}

# Copias reales (no enlaces) en ~/.agents/skills de skills que Android Studio ya trae. Suele dejarlas
# android init. Android Studio ve las dos y la de ~/.agents/skills no la actualiza nadie. Nunca se
# borran: ~/.agents/skills también lo leen otros agentes.
android_warn_duplicates() {
  local name hint
  # Con common, las copias de ~/.agents/skills son una elección: un solo aviso, sin sugerir borrarlas.
  case ",$(android_skill_agents)," in
    *,common,*)
      if [ -n "$(android_duplicated_skills)" ]; then
        info "Con common, Android Studio ve dos veces las skills oficiales de ~/.agents/skills"
      fi
      return 0
      ;;
  esac
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    hint="Si ningún otro agente usa ~/.agents/skills, quítala con: rm -rf ~/.agents/skills/$name"
    if diff -rq "$HOME/.agents/skills/$name" "$HOME/.android-studio/skills/$name" >/dev/null 2>&1; then
      info "$name también está copiada en ~/.agents/skills: Android Studio la ve dos veces y esa copia no se actualiza. $hint"
    else
      warn "$name en ~/.agents/skills es distinta de la que trae Android Studio, probablemente desactualizada, y Android Studio ve las dos. $hint"
    fi
  done <<EOF_DUP
$(android_duplicated_skills)
EOF_DUP
}

android_next_steps() {
  if [ -n "$ANDROID_UNKNOWN_AGENTS" ]; then
    next_step "Corrige DEV_SETUP_ANDROID_SKILL_AGENTS en local.env: Android CLI no reconoce $ANDROID_UNKNOWN_AGENTS"
  fi
  if android_studio_app >/dev/null; then
    :
  elif group_enabled ide; then
    next_step "Instala Android Studio desde JetBrains Toolbox, ábrelo una vez y corre dev-setup update para ajustar su memoria"
  else
    next_step "Instala Android Studio, ábrelo una vez y corre dev-setup update para ajustar su memoria"
  fi
}

android_verify() {
  printf '%s\n' 'android -V' 'adb version'
  if group_enabled emulator; then printf '%s\n' 'emulator -version'; fi
}

android_doctor() {
  local android installed package agent agent_skills skill app version
  section "Android"
  if android="$(android_cmd)"; then
    version="$("$android" -V 2>/dev/null | head -n 1 || true)"
    ok "Android CLI ${version:-} en $android"
  else
    warn "Falta Android CLI"
  fi
  if app="$(android_studio_app)"; then
    ok "Android Studio: $app"
  else
    warn "Falta Android Studio: instálalo desde JetBrains Toolbox"
  fi
  if [ -n "${JAVA_HOME:-}" ]; then
    info "JAVA_HOME: $JAVA_HOME"
  else
    info "JAVA_HOME sin definir en esta terminal"
  fi
  info "ANDROID_HOME: ${ANDROID_HOME:-sin definir en esta terminal}"

  section "SDK de Android"
  if [ -n "${android:-}" ]; then
    installed="$(android_installed_packages "$android" || true)"
  else
    installed=""
  fi
  while IFS= read -r package <&3; do
    if printf '%s\n' "$installed" | grep -qxF -- "$package"; then ok "$package"; else warn "$package: falta"; fi
  done 3< <(android_sdk_packages)

  section "Skills oficiales de Android ($(android_skill_agents_label))"
  if [ -z "${android:-}" ]; then
    warn "Sin Android CLI no se pueden revisar"
  else
    android_warn_ignored_agents
    while IFS= read -r agent <&4; do
      if ! agent_skills="$(android_installed_skills "$android" "$agent")"; then
        android_warn_unknown_agent "$agent"
        continue
      fi
      while IFS= read -r skill <&3; do
        if skill_in_list "$skill" "$agent_skills"; then ok "$skill ($agent)"; else warn "$skill: falta para $agent"; fi
      done 3< <(list_entries "$(android_data_dir)/skills.txt")
    done 4< <(android_skill_agent_list)
  fi
  android_warn_duplicates
}

# Líneas del bloque del shell: SDK por defecto de Android Studio y sus herramientas en el PATH. Cada carpeta
# se revisa por separado: si ya tienes platform-tools en el PATH, igual se agrega emulator.
android_shell() {
  # shellcheck disable=SC2016
  printf '%s\n' \
    'if [ -z "${ANDROID_HOME:-}" ] && [ -d "$HOME/Library/Android/sdk" ]; then export ANDROID_HOME="$HOME/Library/Android/sdk"; fi' \
    'if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/platform-tools" ]; then case ":$PATH:" in *":$ANDROID_HOME/platform-tools:"*) ;; *) export PATH="$PATH:$ANDROID_HOME/platform-tools" ;; esac; fi' \
    'if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/emulator" ]; then case ":$PATH:" in *":$ANDROID_HOME/emulator:"*) ;; *) export PATH="$PATH:$ANDROID_HOME/emulator" ;; esac; fi'
}
