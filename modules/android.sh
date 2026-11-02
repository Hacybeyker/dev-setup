# shellcheck shell=bash
# Android: Android CLI, paquetes del SDK, skills oficiales para los agentes elegidos y el entorno de la terminal.

# Agentes de las skills oficiales: DEV_SETUP_ANDROID_SKILL_AGENTS en local.env, con los nombres de
# `android skills list` (claude-code, github-copilot...). Por defecto solo Claude Code, que es parte de la base.
ANDROID_SKILL_AGENTS_DEFAULT="claude-code"

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

android_skill_agents() { printf '%s' "${DEV_SETUP_ANDROID_SKILL_AGENTS:-$ANDROID_SKILL_AGENTS_DEFAULT}"; }

# Un agente por línea.
android_skill_agent_list() { printf '%s\n' "$(android_skill_agents)" | tr ',' '\n'; }

# Salida de `android skills list --agent=<agente>`: un bloque por skill instalada, con el nombre solo en su
# primera línea. Vacía si el CLI falta o falla.
android_installed_skills() { "$1" skills list "--agent=$2" 2>/dev/null || true; }

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
    return 0
  fi
  info "Instalando Android CLI con su instalador oficial (sin sudo, en ~/.local/bin)"
  run_cmd /bin/bash -c "curl -fsSL $(android_cli_install_url) | bash"
  is_dry_run && return 0
  android="$(android_cmd)" || die "Android CLI no quedó instalado; revisa el mensaje de su instalador"
  ok "Android CLI: $android"
}

android_install_sdk() {
  local android installed package missing=""
  android="$(android_cmd)" || android=android
  installed="$(android_installed_packages "$android" || true)"
  while IFS= read -r package <&3; do
    if printf '%s\n' "$installed" | grep -qxF -- "$package"; then
      ok "$package ya está"
    else
      missing="$missing $package"
    fi
  done 3< <(list_entries "$(android_data_dir)/sdk-packages.txt")
  [ -n "$missing" ] || return 0
  info "Si es la primera vez, el SDK te pide aceptar sus licencias"
  # Las rutas de paquetes no tienen espacios: la separación en palabras es intencional.
  # shellcheck disable=SC2086
  run_cmd "$android" sdk install $missing
}

android_install_skills() {
  local android agent agent_skills skill
  android="$(android_cmd)" || android=android
  while IFS= read -r agent <&4; do
    agent_skills="$(android_installed_skills "$android" "$agent")"
    while IFS= read -r skill <&3; do
      if skill_in_list "$skill" "$agent_skills"; then
        ok "$skill ya está para $agent"
      else
        run_cmd "$android" skills add "--agent=$agent" "$skill"
      fi
    done 3< <(list_entries "$(android_data_dir)/skills.txt")
  done 4< <(android_skill_agent_list)
}

android_install() {
  section "Android"
  android_ensure_cli
  section "SDK de Android"
  android_install_sdk
  section "Skills oficiales de Android ($(android_skill_agents))"
  android_install_skills
  android_warn_duplicates
}

android_update() {
  local android installed package agent agent_skills skill
  section "Android"
  if ! android="$(android_cmd)"; then
    warn "Falta Android CLI: corre dev-setup bootstrap"
    return 0
  fi
  run_cmd "$android" update
  installed="$(android_installed_packages "$android" || true)"
  while IFS= read -r package <&3; do
    if printf '%s\n' "$installed" | grep -qxF -- "$package"; then
      run_cmd "$android" sdk update "$package"
    else
      warn "$package: falta, corre dev-setup bootstrap"
    fi
  done 3< <(list_entries "$(android_data_dir)/sdk-packages.txt")
  while IFS= read -r agent <&4; do
    agent_skills="$(android_installed_skills "$android" "$agent")"
    while IFS= read -r skill <&3; do
      skill_in_list "$skill" "$agent_skills" || continue
      run_cmd "$android" skills update "--agent=$agent" "$skill"
    done 3< <(list_entries "$(android_data_dir)/skills.txt")
  done 4< <(android_skill_agent_list)
}

# Copias reales (no enlaces) en ~/.agents/skills de skills que Android Studio ya trae. Suele dejarlas
# android init. Android Studio ve las dos y la de ~/.agents/skills no la actualiza nadie. Nunca se
# borran: ~/.agents/skills también lo leen otros agentes.
android_warn_duplicates() {
  local name hint
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
  if ! android_studio_app >/dev/null; then
    next_step "Instala Android Studio desde JetBrains Toolbox, ábrelo una vez y corre dev-setup update para ajustar su memoria"
  fi
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
  done 3< <(list_entries "$(android_data_dir)/sdk-packages.txt")

  section "Skills oficiales de Android ($(android_skill_agents))"
  if [ -z "${android:-}" ]; then
    warn "Sin Android CLI no se pueden revisar"
  else
    while IFS= read -r agent <&4; do
      agent_skills="$(android_installed_skills "$android" "$agent")"
      while IFS= read -r skill <&3; do
        if skill_in_list "$skill" "$agent_skills"; then ok "$skill ($agent)"; else warn "$skill: falta para $agent"; fi
      done 3< <(list_entries "$(android_data_dir)/skills.txt")
    done 4< <(android_skill_agent_list)
  fi
  android_warn_duplicates
}

# Líneas del bloque de ~/.zshrc: SDK por defecto de Android Studio y sus herramientas en el PATH.
android_shell() {
  # shellcheck disable=SC2016
  printf '%s\n' \
    'if [ -z "${ANDROID_HOME:-}" ] && [ -d "$HOME/Library/Android/sdk" ]; then export ANDROID_HOME="$HOME/Library/Android/sdk"; fi' \
    'if [ -n "${ANDROID_HOME:-}" ]; then case ":$PATH:" in *":$ANDROID_HOME/platform-tools:"*) ;; *) export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator" ;; esac; fi'
}
