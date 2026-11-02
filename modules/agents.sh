# shellcheck shell=bash
# Agentes: las skills propias de agent-skills (enlazadas con su install.sh) y testigo.

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

# Cuántas skills del clon tienen su enlace en ~/.claude/skills: "<enlazadas>/<total>".
agent_skills_link_count() {
  local dir skill total=0 linked=0
  dir="$(agent_skills_dir)"
  for skill in "$dir"/skills/*/; do
    [ -f "${skill}SKILL.md" ] || continue
    total=$((total + 1))
    [ -L "$(claude_skills_dir)/$(basename "$skill")" ] && linked=$((linked + 1))
  done
  printf '%s/%s' "$linked" "$total"
}

agents_ensure_agent_skills() {
  local dir
  dir="$(agent_skills_dir)"
  if [ -d "$dir/.git" ] && [ -x "$dir/install.sh" ]; then
    ok "agent-skills en $dir"
  elif [ -e "$dir" ]; then
    warn "$dir ya existe y no es un clon de agent-skills: no lo toco"
    return 0
  else
    run_cmd git clone "$(agent_skills_repo)" "$dir"
  fi
  run_cmd "$dir/install.sh"
}

agents_ensure_testigo() {
  local testigo
  if testigo="$(testigo_cmd)"; then
    ok "testigo: $testigo"
    return 0
  fi
  info "Instalando testigo con su instalador oficial (sin sudo)"
  if ! run_remote_installer "$TESTIGO_INSTALL_URL"; then
    warn "Sin testigo se salta testigo setup"
    return 0
  fi
  if ! is_dry_run && [ ! -x "$HOME/.local/bin/testigo" ]; then
    warn "testigo no quedó instalado; revisa el mensaje de su instalador"
    return 0
  fi
  info "testigo setup prepara Java, Maestro y el SDK que falten, con tu confirmación"
  run_cmd "$HOME/.local/bin/testigo" setup
}

agents_install() {
  section "Skills propias (agent-skills)"
  agents_ensure_agent_skills
  section "testigo"
  agents_ensure_testigo
}

agents_update() {
  local dir
  section "Skills propias (agent-skills)"
  dir="$(agent_skills_dir)"
  if [ -d "$dir/.git" ] && [ -x "$dir/install.sh" ]; then
    run_cmd git -C "$dir" pull --ff-only || warn "No se pudo actualizar $dir sin merge: revísalo a mano"
    run_cmd "$dir/install.sh"
  else
    warn "Falta agent-skills en $dir: corre dev-setup bootstrap"
  fi
  section "testigo"
  if testigo_from_installer; then
    run_remote_installer "$TESTIGO_INSTALL_URL" || warn "No se pudo actualizar testigo"
  elif testigo_cmd >/dev/null; then
    info "testigo instalado de otra forma: se actualiza por su cuenta"
  else
    warn "Falta testigo: corre dev-setup bootstrap"
  fi
}

agents_doctor() {
  local dir testigo
  section "Skills propias (agent-skills)"
  dir="$(agent_skills_dir)"
  if [ -d "$dir/.git" ] && [ -x "$dir/install.sh" ]; then
    ok "agent-skills en $dir ($(agent_skills_link_count) skills enlazadas en Claude Code)"
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
