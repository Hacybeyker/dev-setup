# shellcheck shell=bash
# Sesiones de gh, Claude Code y Android CLI. dev-setup nunca inicia sesión por ti: revisa con los
# comandos de estado oficiales (salen con 0 si hay sesión) y te dice qué falta.

gh_logged_in() { command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; }

claude_logged_in() {
  local claude
  claude="$(claude_cmd)" && "$claude" auth status </dev/null >/dev/null 2>&1
}

android_logged_in() {
  local android
  android="$(android_cmd)" && "$android" auth status >/dev/null 2>&1
}

accounts_doctor() {
  section "Sesiones"
  if ! command -v gh >/dev/null 2>&1; then
    info "GitHub (gh): gh no está instalado"
  elif gh_logged_in; then
    ok "GitHub (gh)"
  else
    warn "GitHub (gh): sin sesión. Inicia con: gh auth login"
  fi
  if ! claude_cmd >/dev/null; then
    info "Claude Code: no está instalado"
  elif claude_logged_in; then
    ok "Claude Code"
  else
    warn "Claude Code: sin sesión. Inicia con: claude auth login"
  fi
  if ! android_cmd >/dev/null; then
    info "Android CLI: no está instalado"
  elif android_logged_in; then
    ok "Android CLI (cuenta de Google)"
  else
    info "Android CLI: sin cuenta de Google (opcional: android auth login)"
  fi
}

accounts_next_steps() {
  if command -v gh >/dev/null 2>&1 && ! gh_logged_in; then
    next_step "Inicia sesión en GitHub: gh auth login"
  fi
  if claude_cmd >/dev/null && ! claude_logged_in; then
    next_step "Inicia sesión en Claude Code: claude auth login"
  fi
  if android_cmd >/dev/null && ! android_logged_in; then
    next_step "Opcional: android auth login, para las funciones del Android CLI que usan tu cuenta de Google"
  fi
}
