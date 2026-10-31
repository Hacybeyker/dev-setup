# shellcheck shell=bash
# Claude Code: el CLI, ~/.claude/settings.json (solo agrega lo que falta) y sus plugins.

CLAUDE_INSTALL_URL="https://claude.ai/install.sh"

claude_data_dir() { printf '%s' "${DEV_SETUP_CLAUDE_DATA:-$DEV_SETUP_ROOT/claude}"; }
claude_settings_path() { printf '%s/settings.json' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }

claude_cmd() {
  if command -v claude >/dev/null 2>&1; then
    command -v claude
  elif [ -x "$HOME/.local/bin/claude" ]; then
    printf '%s' "$HOME/.local/bin/claude"
  else
    return 1
  fi
}

# Carpetas de skills que Claude Code puede leer sin preguntar: las de los agentes y aquellas
# a las que apuntan sus enlaces (por ejemplo, el clon de agent-skills).
claude_skill_dirs() {
  local dir link target
  for dir in "$(claude_skills_dir)" "$HOME/.agents/skills"; do
    [ -d "$dir" ] || continue
    printf '%s\n' "$dir"
    for link in "$dir"/*; do
      [ -L "$link" ] || continue
      target="$(readlink "$link")"
      case "$target" in /*) ;; *) target="$dir/$target" ;; esac
      dirname "$target"
    done
  done | awk '!seen[$0]++'
}

# Fusión de JSON: lo que ya existe gana, se agregan las claves que faltan y las listas se unen.
# shellcheck disable=SC2016 # programa de jq: sus variables no son de Bash
CLAUDE_JSON_MERGE='
def merge($a; $b):
  if ($a | type) == "object" and ($b | type) == "object" then
    reduce (($a + $b) | keys_unsorted[]) as $k ({};
      .[$k] = (if ($a | has($k)) and ($b | has($k)) then merge($a[$k]; $b[$k])
               elif ($a | has($k)) then $a[$k]
               else $b[$k] end))
  elif ($a | type) == "array" and ($b | type) == "array" then $a + ($b - $a)
  else $a end;
merge($cur; $want)
'

# Imprime settings.json fusionado con lo que dev-setup necesita. Falla si el actual no es JSON válido.
claude_merged_settings() {
  local file current dirs
  file="$(claude_settings_path)"
  current='{}'
  if [ -f "$file" ]; then
    current="$(jq -c . "$file" 2>/dev/null)" || return 1
  fi
  dirs="$(claude_skill_dirs | jq -R . | jq -s -c .)"
  jq -n \
    --argjson cur "$current" \
    --argjson tpl "$(jq -c . "$(claude_data_dir)/settings.json")" \
    --argjson dirs "$dirs" \
    "(\$tpl * (if (\$dirs | length) > 0 then {permissions: {additionalDirectories: \$dirs}} else {} end)) as \$want | $CLAUDE_JSON_MERGE" \
    2>/dev/null
}

# 0 si settings.json ya tiene todo (se compara el contenido, no el formato).
claude_settings_up_to_date() {
  local file merged
  file="$(claude_settings_path)"
  [ -f "$file" ] || return 1
  merged="$(claude_merged_settings)" || return 1
  [ "$(jq -S -c . "$file")" = "$(printf '%s' "$merged" | jq -S -c .)" ]
}

claude_ensure_settings() {
  local file new
  file="$(claude_settings_path)"
  if [ -f "$file" ] && ! jq -e . "$file" >/dev/null 2>&1; then
    error "$file no es JSON válido: no lo toco"
    return 0
  fi
  if claude_settings_up_to_date; then
    ok "$file ya está al día"
    return 0
  fi
  [ -d "$(dirname "$file")" ] || run_cmd mkdir -p "$(dirname "$file")"
  new="$(new_temp_file)"
  claude_merged_settings | jq . >"$new"
  apply_file_change "$file" "$new"
}

claude_ensure_cli() {
  local claude
  if claude="$(claude_cmd)"; then
    ok "Claude Code: $claude"
    return 0
  fi
  info "Instalando Claude Code con su instalador oficial (se actualiza solo)"
  run_cmd /bin/bash -c "curl -fsSL $CLAUDE_INSTALL_URL | bash"
  is_dry_run || info "La primera vez, inicia sesión con: claude"
}

# Cask de Homebrew con la que se instaló Claude Code, si fue así (no se actualiza sola).
claude_brew_cask() {
  local brew cask
  brew="$(brew_cmd)" || return 1
  for cask in claude-code claude-code@latest; do
    if "$brew" list --cask --versions "$cask" >/dev/null 2>&1; then
      printf '%s' "$cask"
      return 0
    fi
  done
  return 1
}

claude_installed_plugins() { "$1" plugin list --json 2>/dev/null | jq -r '.[] | select(.scope == "user") | .id'; }
claude_known_marketplaces() { "$1" plugin marketplace list --json 2>/dev/null | jq -r '.[].name'; }

claude_install_plugins() {
  local claude markets installed name source group id
  claude="$(claude_cmd)" || claude=claude
  markets="$(claude_known_marketplaces "$claude" || true)"
  while read -r name source group <&3; do
    [ -z "$group" ] || group_enabled "$group" || continue
    if in_lines "$name" "$markets"; then
      ok "Marketplace $name"
    else
      run_cmd "$claude" plugin marketplace add "$source" --scope user
    fi
  done 3< <(list_entries "$(claude_data_dir)/marketplaces.txt")
  installed="$(claude_installed_plugins "$claude" || true)"
  while read -r id group <&3; do
    [ -z "$group" ] || group_enabled "$group" || continue
    if in_lines "$id" "$installed"; then
      ok "$id"
    else
      run_cmd "$claude" plugin install "$id" --scope user
    fi
  done 3< <(list_entries "$(claude_data_dir)/plugins.txt")
}

claude_install() {
  section "Claude Code"
  claude_ensure_cli
  claude_ensure_settings
  section "Plugins de Claude Code"
  claude_install_plugins
}

claude_update() {
  local claude cask markets installed name source group id
  section "Claude Code"
  if ! claude="$(claude_cmd)"; then
    warn "Falta Claude Code: corre dev-setup bootstrap"
    return 0
  fi
  if cask="$(claude_brew_cask)"; then
    run_cmd "$(brew_cmd)" upgrade --cask "$cask"
  else
    run_cmd "$claude" update
  fi
  claude_ensure_settings
  section "Plugins de Claude Code"
  markets="$(claude_known_marketplaces "$claude" || true)"
  while read -r name source group <&3; do
    [ -z "$group" ] || group_enabled "$group" || continue
    if in_lines "$name" "$markets"; then
      run_cmd "$claude" plugin marketplace update "$name"
    fi
  done 3< <(list_entries "$(claude_data_dir)/marketplaces.txt")
  installed="$(claude_installed_plugins "$claude" || true)"
  while read -r id group <&3; do
    [ -z "$group" ] || group_enabled "$group" || continue
    if in_lines "$id" "$installed"; then
      run_cmd "$claude" plugin update "$id"
    else
      warn "$id: falta, corre dev-setup bootstrap"
    fi
  done 3< <(list_entries "$(claude_data_dir)/plugins.txt")
}

claude_doctor() {
  local claude file markets="" installed="" name source group id
  section "Claude Code"
  if claude="$(claude_cmd)"; then
    ok "Claude Code $("$claude" --version 2>/dev/null | head -n 1) en $claude"
    markets="$(claude_known_marketplaces "$claude" || true)"
    installed="$(claude_installed_plugins "$claude" || true)"
  else
    warn "Falta Claude Code"
  fi
  file="$(claude_settings_path)"
  if [ -f "$file" ] && ! jq -e . "$file" >/dev/null 2>&1; then
    warn "$file no es JSON válido"
  elif claude_settings_up_to_date; then
    ok "$file tiene la configuración de dev-setup"
  else
    warn "A $file le falta configuración de dev-setup: corre dev-setup bootstrap"
  fi

  section "Plugins de Claude Code"
  while read -r name source group <&3; do
    if [ -n "$group" ] && ! group_enabled "$group"; then
      info "Marketplace $name: grupo $group desactivado"
    elif in_lines "$name" "$markets"; then
      ok "Marketplace $name"
    else
      warn "Marketplace $name: falta"
    fi
  done 3< <(list_entries "$(claude_data_dir)/marketplaces.txt")
  while read -r id group <&3; do
    if [ -n "$group" ] && ! group_enabled "$group"; then
      info "$id: grupo $group desactivado"
    elif in_lines "$id" "$installed"; then
      ok "$id"
    else
      warn "$id: falta"
    fi
  done 3< <(list_entries "$(claude_data_dir)/plugins.txt")
}
