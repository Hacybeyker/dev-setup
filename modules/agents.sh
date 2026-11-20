# shellcheck shell=bash
# Grupo skills: las skills propias de agent-skills y testigo. El install.sh de agent-skills las enlaza en
# ~/.claude/skills (Claude Code) y ~/.agents/skills (Copilot, Junie, Codex y Gemini en Android Studio).

AGENT_SKILLS_REPO_DEFAULT="https://github.com/Hacybeyker/agent-skills.git"
TESTIGO_INSTALL_URL="https://raw.githubusercontent.com/Hacybeyker/testigo/HEAD/install.sh"

# agent-skills vive junto a dev-setup (por ejemplo ~/Claude/agent-skills).
agent_skills_dir() { printf '%s' "${DEV_SETUP_AGENT_SKILLS_DIR:-$(dirname "$DEV_SETUP_ROOT")/agent-skills}"; }
agent_skills_repo() { printf '%s' "${DEV_SETUP_AGENT_SKILLS_REPO:-$AGENT_SKILLS_REPO_DEFAULT}"; }

testigo_cmd() {
  if command -v testigo >/dev/null 2>&1; then
    command -v testigo
  elif [ -x "$HOME/.local/bin/testigo" ]; then
    printf '%s' "$HOME/.local/bin/testigo"
  else
    return 1
  fi
}

# testigo instalado por su instalador oficial: ~/.local/bin/testigo apunta a ~/.testigo/cli/.
testigo_from_installer() {
  case "$(readlink "$HOME/.local/bin/testigo" 2>/dev/null)" in
    "$HOME/.testigo/cli/"*) return 0 ;;
    *) return 1 ;;
  esac
}

# agent_skills_link_count <carpeta>: cuántas skills del clon tienen su enlace en esa carpeta,
# como "<enlazadas>/<total>".
agent_skills_link_count() {
  local dir skill total=0 linked=0
  dir="$(agent_skills_dir)"
  for skill in "$dir"/skills/*/; do
    [ -f "${skill}SKILL.md" ] || continue
    total=$((total + 1))
    [ -L "$1/$(basename "$skill")" ] && linked=$((linked + 1))
  done
  printf '%s/%s' "$linked" "$total"
}

# Cuántas skills propias están enlazadas en cada carpeta y qué agentes las leen.
agents_skills_where() {
  info "Enlazadas: $(agent_skills_link_count "$(claude_skills_dir)") en $(display_path "$(claude_skills_dir)") (Claude Code) y $(agent_skills_link_count "$HOME/.agents/skills") en ~/.agents/skills (Copilot, Junie, Codex y Gemini en Android Studio)"
}

# Los enlaces de las carpetas de skills, para saber si install.sh cambió alguno.
agents_links_snapshot() {
  local dir link
  for dir in "$(claude_skills_dir)" "$HOME/.agents/skills"; do
    for link in "$dir"/*; do
      if [ -L "$link" ]; then printf '%s -> %s\n' "$link" "$(readlink "$link")"; fi
    done
  done
  return 0
}

# agents_run_skills_installer <clon> [install|update]: corre el install.sh de agent-skills. Su salida completa
# va al log; en pantalla solo quedan sus avisos, no la línea de cada enlace. En el resumen queda como
# configurado si cambió algún enlace.
agents_run_skills_installer() {
  local dir="$1" mode="${2:-install}" out before status=0 line
  if is_dry_run; then
    run_cmd "$dir/install.sh"
    return 0
  fi
  before="$(agents_links_snapshot)"
  out="$(new_temp_file)"
  run_cmd "$dir/install.sh" >"$out" 2>&1 || status=$?
  cat "$out" >>"${DEV_SETUP_LOG_FILE:-/dev/null}"
  while IFS= read -r line; do
    case "$line" in '' | ✔*) ;; *) warn "$line" ;; esac
  done <"$out"
  rm -f "$out"
  if [ "$status" -ne 0 ]; then
    error "Falló $dir/install.sh (código $status; el detalle está en el log)"
    summary_add fallo "skills propias: falló $dir/install.sh"
    next_step "Revisa el error de $dir/install.sh en el log y vuelve a correr dev-setup"
    return 0
  fi
  agents_skills_where
  if [ "$before" != "$(agents_links_snapshot)" ]; then
    summary_add configurado "skills propias en ~/.claude/skills y ~/.agents/skills"
  elif [ "$mode" = install ]; then
    summary_add ya "skills propias enlazadas"
  fi
}

agents_ensure_agent_skills() {
  local dir
  dir="$(agent_skills_dir)"
  if [ -d "$dir/.git" ] && [ -x "$dir/install.sh" ]; then
    ok "agent-skills en $dir"
    summary_add ya "agent-skills"
  elif [ -e "$dir" ]; then
    warn "$dir ya existe y no es un clon de agent-skills: no lo toco"
    summary_add ya "$dir (no es agent-skills: no se tocó)"
    return 0
  elif run_cmd git clone "$(agent_skills_repo)" "$dir"; then
    is_dry_run || summary_add instalado "agent-skills en $dir"
  else
    error "No se pudo clonar $(agent_skills_repo)"
    summary_add fallo "agent-skills: no se pudo clonar"
    next_step "Cuando tengas acceso a $(agent_skills_repo), vuelve a correr dev-setup bootstrap"
    return 0
  fi
  agents_run_skills_installer "$dir"
}

agents_ensure_testigo() {
  local testigo
  if testigo="$(testigo_cmd)"; then
    ok "testigo: $testigo"
    summary_add ya "testigo"
    return 0
  fi
  info "Instalando testigo con su instalador oficial (sin sudo)"
  if ! run_remote_installer "$TESTIGO_INSTALL_URL"; then
    installer_failed testigo
    warn "Sin testigo se salta testigo setup"
    return 0
  fi
  if ! is_dry_run && [ ! -x "$HOME/.local/bin/testigo" ]; then
    warn "testigo no quedó instalado; revisa el mensaje de su instalador"
    installer_failed testigo "su instalador terminó sin dejar el comando testigo"
    return 0
  fi
  is_dry_run || summary_add instalado "testigo"
  info "testigo setup prepara Java, Maestro y el SDK que falten, con tu confirmación"
  if ! run_cmd "$HOME/.local/bin/testigo" setup; then
    warn "testigo setup no terminó"
    next_step "Termina de preparar testigo con: testigo setup"
  fi
}

agents_install() {
  section "Skills propias (agent-skills)"
  agents_ensure_agent_skills
  section "testigo"
  agents_ensure_testigo
}

agents_update() {
  local dir before after
  section "Skills propias (agent-skills)"
  dir="$(agent_skills_dir)"
  if [ -d "$dir/.git" ] && [ -x "$dir/install.sh" ]; then
    before="$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)"
    run_cmd git -C "$dir" pull --ff-only --quiet || warn "No se pudo actualizar $dir sin merge: revísalo a mano"
    after="$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)"
    if [ "$before" != "$after" ]; then summary_add actualizado "agent-skills"; else summary_add revisado "agent-skills"; fi
    agents_run_skills_installer "$dir" update
  else
    warn "Falta agent-skills en $dir"
    next_step "Para instalar agent-skills, corre dev-setup bootstrap"
  fi
  section "testigo"
  if testigo_from_installer; then
    before="$("$HOME/.local/bin/testigo" --version 2>/dev/null || true)"
    if run_remote_installer "$TESTIGO_INSTALL_URL"; then
      after="$("$HOME/.local/bin/testigo" --version 2>/dev/null || true)"
      if [ -n "$before" ] && [ "$before" != "$after" ]; then
        summary_add actualizado "testigo $before → $after"
      else
        summary_add revisado "testigo"
      fi
    else
      warn "No se pudo actualizar testigo"
      summary_add fallo "testigo: ${REMOTE_INSTALLER_ERROR:-falló su instalador}"
    fi
  elif testigo_cmd >/dev/null; then
    info "testigo instalado de otra forma: se actualiza por su cuenta"
    summary_add ya "testigo (se actualiza por su cuenta)"
  else
    warn "Falta testigo"
    next_step "Para instalar testigo, corre dev-setup bootstrap"
  fi
}

agents_verify() { printf '%s\n' 'testigo --version'; }

agents_doctor() {
  local dir testigo
  section "Skills propias (agent-skills)"
  dir="$(agent_skills_dir)"
  if [ -d "$dir/.git" ] && [ -x "$dir/install.sh" ]; then
    ok "agent-skills en $dir"
    agents_skills_where
  elif [ -e "$dir" ]; then
    warn "$dir existe y no es un clon de agent-skills"
  else
    warn "Falta agent-skills en $dir"
  fi
  section "testigo"
  if testigo="$(testigo_cmd)"; then
    if testigo_from_installer; then ok "testigo: $testigo (instalador oficial)"; else ok "testigo: $testigo"; fi
  else
    warn "Falta testigo"
  fi
}
