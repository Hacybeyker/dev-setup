#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  export DEV_SETUP_SKIP_OS_CHECK=1
  SETTINGS="$HOME/.claude/settings.json"
}

@test "doctor muestra Claude Code, marketplaces y plugins" {
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Claude Code 2.1.300 (Claude Code)"* ]]
  [[ "$output" == *"✔ Marketplace market-installed"* ]]
  [[ "$output" == *"Marketplace market-missing: falta"* ]]
  [[ "$output" == *"Marketplace market-optional: grupo terminal desactivado"* ]]
  [[ "$output" == *"✔ plugin-installed@market-installed"* ]]
  [[ "$output" == *"plugin-missing@market-installed: falta"* ]]
  [[ "$output" == *"plugin-optional@market-optional: grupo terminal desactivado"* ]]
  [[ "$output" != *"engineering"* ]]
}

@test "bootstrap agrega solo los marketplaces y plugins que faltan, en scope user" {
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  grep -qx 'claude plugin marketplace add owner/market-missing --scope user' "$FAKE_LOG"
  grep -qx 'claude plugin install plugin-missing@market-installed --scope user' "$FAKE_LOG"
  [ "$(grep -c 'claude plugin marketplace add' "$FAKE_LOG")" -eq 1 ]
  [ "$(grep -c 'claude plugin install' "$FAKE_LOG")" -eq 1 ]
}

@test "--with terminal agrega el marketplace y el plugin del grupo" {
  run "$DEV_SETUP" bootstrap --with terminal
  [ "$status" -eq 0 ]
  grep -qx 'claude plugin marketplace add owner/market-optional --scope user' "$FAKE_LOG"
  grep -qx 'claude plugin install plugin-optional@market-optional --scope user' "$FAKE_LOG"
}

@test "bootstrap --dry-run no instala plugins" {
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"*"plugin install plugin-missing@market-installed --scope user"* ]]
  [ "$(grep -cE 'claude plugin (install|marketplace add)' "$FAKE_LOG")" -eq 0 ]
}

@test "sin Claude Code, bootstrap --dry-run muestra su instalador oficial" {
  rm "$STUBS/claude"
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude.ai/install.sh"* ]]
}

@test "update actualiza Claude Code y solo los plugins de la lista" {
  run "$DEV_SETUP" update
  [ "$status" -eq 0 ]
  grep -qx 'claude update' "$FAKE_LOG"
  grep -qx 'claude plugin marketplace update market-installed' "$FAKE_LOG"
  grep -qx 'claude plugin update plugin-installed@market-installed' "$FAKE_LOG"
  [ "$(grep -c 'claude plugin update' "$FAKE_LOG")" -eq 1 ]
  [[ "$output" == *"plugin-missing@market-installed: falta, corre dev-setup bootstrap"* ]]
}

@test "update actualiza con Homebrew un Claude Code instalado con su cask" {
  export FAKE_BREW_CASKS="claude-code"
  run "$DEV_SETUP" update
  [ "$status" -eq 0 ]
  grep -qx 'brew upgrade --cask claude-code' "$FAKE_LOG"
  [ "$(grep -c '^claude update' "$FAKE_LOG")" -eq 0 ]
}

@test "bootstrap --yes crea settings.json con la atribucion vacia y las carpetas de skills" {
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [ "$(jq -r '.attribution.commit' "$SETTINGS")" = "" ]
  [ "$(jq -r '.attribution.sessionUrl' "$SETTINGS")" = false ]
  jq -e --arg d "$HOME/.claude/skills" '.permissions.additionalDirectories | index($d)' "$SETTINGS"
  # install.sh enlaza con la ruta física (pwd -P): en macOS /var es un enlace a /private/var.
  jq -e --arg d "$(cd "$DEV_SETUP_AGENT_SKILLS_DIR" && pwd -P)/skills" '.permissions.additionalDirectories | index($d)' "$SETTINGS"
}

@test "settings.json conserva lo que ya tienes y solo agrega lo que falta" {
  mkdir -p "$HOME/.claude"
  printf '%s\n' '{"model":"opus","attribution":{"commit":"mio"},"permissions":{"allow":["Bash(ls)"],"additionalDirectories":["/otra"]}}' >"$SETTINGS"
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [ "$(jq -r '.model' "$SETTINGS")" = opus ]
  [ "$(jq -r '.attribution.commit' "$SETTINGS")" = mio ]
  [ "$(jq -r '.attribution.pr' "$SETTINGS")" = "" ]
  [ "$(jq -r '.permissions.allow[0]' "$SETTINGS")" = "Bash(ls)" ]
  [ "$(jq -r '.permissions.additionalDirectories[0]' "$SETTINGS")" = /otra ]
  jq -e --arg d "$HOME/.claude/skills" '.permissions.additionalDirectories | index($d)' "$SETTINGS"
  [ "$(find "$HOME/.claude" -name 'settings.json.bak-*' | wc -l | tr -d ' ')" -eq 1 ]
}

@test "settings.json: la segunda vez no cambia nada ni respalda" {
  "$DEV_SETUP" bootstrap --yes >/dev/null
  cp "$SETTINGS" "$BATS_TEST_TMPDIR/first"
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  cmp "$SETTINGS" "$BATS_TEST_TMPDIR/first"
  [ "$(find "$HOME/.claude" -name 'settings.json.bak-*' | wc -l | tr -d ' ')" -eq 0 ]
  run "$DEV_SETUP" doctor
  [[ "$output" == *"tiene la configuración de dev-setup"* ]]
}

@test "un settings.json con formato distinto pero el mismo contenido no se reescribe" {
  "$DEV_SETUP" bootstrap --yes >/dev/null
  jq -c . "$SETTINGS" >"$BATS_TEST_TMPDIR/compacto" && cp "$BATS_TEST_TMPDIR/compacto" "$SETTINGS"
  run "$DEV_SETUP" bootstrap --yes
  cmp "$SETTINGS" "$BATS_TEST_TMPDIR/compacto"
}

@test "un settings.json invalido no se toca y bootstrap sigue" {
  mkdir -p "$HOME/.claude"
  printf '{ roto\n' >"$SETTINGS"
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"no es JSON válido"* ]]
  [ "$(cat "$SETTINGS")" = "{ roto" ]
  grep -q 'claude plugin install' "$FAKE_LOG"
}

@test "bootstrap --dry-run no escribe settings.json" {
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$SETTINGS" ]
}

@test "respeta CLAUDE_CONFIG_DIR" {
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude-config"
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [ -f "$CLAUDE_CONFIG_DIR/settings.json" ]
  [ ! -e "$SETTINGS" ]
}

@test "las listas reales de Claude Code son validas" {
  load_libs
  while read -r id group; do
    [[ "$id" == *@* ]]
    [ -z "$group" ] || is_group "$group"
  done < <(list_entries "$REPO_ROOT/claude/plugins.txt")
  while read -r name source group; do
    [[ "$source" == */* ]]
    [ -z "$group" ] || is_group "$group"
  done < <(list_entries "$REPO_ROOT/claude/marketplaces.txt")
  jq -e . "$REPO_ROOT/claude/settings.json"
}
