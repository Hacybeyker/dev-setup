# shellcheck shell=bash
# Android: Android CLI, paquetes del SDK, skills oficiales para Claude Code y el entorno de la terminal.

ANDROID_SKILL_AGENTS="claude-code"

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

skill_installed_for_claude() { [ -f "$(claude_skills_dir)/$1/SKILL.md" ]; }

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
  local android skill
  android="$(android_cmd)" || android=android
  while IFS= read -r skill <&3; do
    if skill_installed_for_claude "$skill"; then
      ok "$skill ya está para Claude Code"
    else
      run_cmd "$android" skills add "--agent=$ANDROID_SKILL_AGENTS" "$skill"
    fi
  done 3< <(list_entries "$(android_data_dir)/skills.txt")
}

android_install() {
  section "Android"
  android_ensure_cli
  section "SDK de Android"
  android_install_sdk
  section "Skills oficiales de Android (Claude Code)"
  android_install_skills
  android_warn_duplicates
}

android_update() {
  local android installed package skill
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
  while IFS= read -r skill <&3; do
    skill_installed_for_claude "$skill" || continue
    run_cmd "$android" skills update "--agent=$ANDROID_SKILL_AGENTS" "$skill"
  done 3< <(list_entries "$(android_data_dir)/skills.txt")
}

android_warn_duplicates() {
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    warn "$name está en ~/.agents/skills y en ~/.android-studio/skills: Android Studio la ve dos veces. Para quitar la copia: rm -rf ~/.agents/skills/$name"
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
  local android installed package skill app version
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

  section "Skills oficiales de Android (Claude Code)"
  while IFS= read -r skill <&3; do
    if skill_installed_for_claude "$skill"; then ok "$skill"; else warn "$skill: falta"; fi
  done 3< <(list_entries "$(android_data_dir)/skills.txt")
  android_warn_duplicates
}

# Líneas del bloque de ~/.zshrc: SDK por defecto de Android Studio y sus herramientas en el PATH.
android_shell() {
  # shellcheck disable=SC2016
  printf '%s\n' \
    'if [ -z "${ANDROID_HOME:-}" ] && [ -d "$HOME/Library/Android/sdk" ]; then export ANDROID_HOME="$HOME/Library/Android/sdk"; fi' \
    'if [ -n "${ANDROID_HOME:-}" ]; then case ":$PATH:" in *":$ANDROID_HOME/platform-tools:"*) ;; *) export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator" ;; esac; fi'
}
