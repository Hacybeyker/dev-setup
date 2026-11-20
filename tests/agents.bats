#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  export DEV_SETUP_SKIP_OS_CHECK=1
}

@test "doctor muestra agent-skills y cuantas skills estan enlazadas en cada carpeta" {
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent-skills en $DEV_SETUP_AGENT_SKILLS_DIR"* ]]
  [[ "$output" == *"Enlazadas: 0/1 en ~/.claude/skills (Claude Code) y 0/1 en ~/.agents/skills"* ]]
  "$DEV_SETUP" bootstrap >/dev/null
  run "$DEV_SETUP" doctor
  [[ "$output" == *"Enlazadas: 1/1 en ~/.claude/skills (Claude Code)"* ]]
}

@test "bootstrap dice donde quedan las skills propias y solo muestra los avisos de install.sh" {
  export FAKE_SKILLS_WARNING="⚠️  algo existe y no es un enlace: no lo toco"
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  [[ "$output" == *"~/.agents/skills (Copilot, Junie, Codex y Gemini en Android Studio)"* ]]
  [[ "$output" == *"algo existe y no es un enlace"* ]]
  [[ "$output" != *"✔ $HOME/.claude/skills/hb-fake"* ]]
  grep -q "✔ $HOME/.claude/skills/hb-fake" "$HOME"/Library/Logs/dev-setup/*.log
  [[ "$output" == *"Configurado:"*"skills propias en ~/.claude/skills y ~/.agents/skills"* ]]
}

@test "si los enlaces ya estaban, las skills propias no quedan como configuradas" {
  "$DEV_SETUP" bootstrap >/dev/null
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  [[ "$output" != *"skills propias en ~/.claude/skills y ~/.agents/skills"* ]]
  [[ "$output" == *"Ya estaba (se respetó):"*"skills propias enlazadas"* ]]
}

@test "sin el grupo skills no clona agent-skills ni instala testigo" {
  rm -rf "$DEV_SETUP_AGENT_SKILLS_DIR"
  rm "$STUBS/testigo"
  run "$DEV_SETUP" bootstrap --without skills
  [ "$status" -eq 0 ]
  [ ! -e "$DEV_SETUP_AGENT_SKILLS_DIR" ]
  [ "$(grep -c '^curl' "$FAKE_LOG")" -eq 0 ]
  [[ "$output" == *"Omitido por tu elección:"*skills* ]]
}

@test "bootstrap corre install.sh del clon existente" {
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  grep -qx 'agent-skills install.sh' "$FAKE_LOG"
  [ -L "$HOME/.claude/skills/hb-fake" ]
}

@test "bootstrap clona agent-skills si falta" {
  rm -rf "$DEV_SETUP_AGENT_SKILLS_DIR"
  make_fake_agent_skills "$DEV_SETUP_AGENT_SKILLS_REPO"
  rm -rf "$DEV_SETUP_AGENT_SKILLS_REPO/.git"
  git -C "$DEV_SETUP_AGENT_SKILLS_REPO" init --quiet
  git -C "$DEV_SETUP_AGENT_SKILLS_REPO" add -A
  git -C "$DEV_SETUP_AGENT_SKILLS_REPO" -c user.name=t -c user.email=t@t commit --quiet -m init
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  [ -d "$DEV_SETUP_AGENT_SKILLS_DIR/.git" ]
  [ -L "$HOME/.claude/skills/hb-fake" ]
}

@test "no toca una carpeta agent-skills que no es un clon" {
  rm -rf "$DEV_SETUP_AGENT_SKILLS_DIR"
  mkdir -p "$DEV_SETUP_AGENT_SKILLS_DIR"
  printf 'mio\n' >"$DEV_SETUP_AGENT_SKILLS_DIR/notas.txt"
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  [[ "$output" == *"no es un clon de agent-skills: no lo toco"* ]]
  [ "$(ls "$DEV_SETUP_AGENT_SKILLS_DIR")" = notas.txt ]
}

@test "bootstrap --dry-run no clona ni enlaza" {
  rm -rf "$DEV_SETUP_AGENT_SKILLS_DIR"
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] git clone"* ]]
  [ ! -e "$DEV_SETUP_AGENT_SKILLS_DIR" ]
}

@test "sin testigo, bootstrap --dry-run muestra su instalador y testigo setup" {
  rm "$STUBS/testigo"
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"raw.githubusercontent.com/Hacybeyker/testigo/HEAD/install.sh"* ]]
  [[ "$output" == *"[dry-run]"*"testigo setup"* ]]
  [ "$(grep -c '^curl' "$FAKE_LOG")" -eq 0 ]
}

@test "update actualiza testigo solo si lo instalo su instalador oficial" {
  run "$DEV_SETUP" update
  [[ "$output" == *"testigo instalado de otra forma"* ]]
  [ "$(grep -c '^curl' "$FAKE_LOG")" -eq 0 ]
  mkdir -p "$HOME/.testigo/cli/1.0/bin" "$HOME/.local/bin"
  cp "$STUBS/testigo" "$HOME/.testigo/cli/1.0/bin/testigo"
  ln -s "$HOME/.testigo/cli/1.0/bin/testigo" "$HOME/.local/bin/testigo"
  run "$DEV_SETUP" update
  grep -q '^curl -fsSL -o .* https://raw.githubusercontent.com/Hacybeyker/testigo/HEAD/install.sh$' "$FAKE_LOG"
}

@test "update avisa si git pull no puede avanzar sin merge y vuelve a enlazar" {
  run "$DEV_SETUP" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"No se pudo actualizar $DEV_SETUP_AGENT_SKILLS_DIR sin merge"* ]]
  grep -qx 'agent-skills install.sh' "$FAKE_LOG"
}

@test "update trae los cambios del clon con git pull --ff-only" {
  rm -rf "$DEV_SETUP_AGENT_SKILLS_DIR"
  make_fake_agent_skills "$DEV_SETUP_AGENT_SKILLS_REPO"
  rm -rf "$DEV_SETUP_AGENT_SKILLS_REPO/.git"
  git -C "$DEV_SETUP_AGENT_SKILLS_REPO" init --quiet
  git -C "$DEV_SETUP_AGENT_SKILLS_REPO" add -A
  git -C "$DEV_SETUP_AGENT_SKILLS_REPO" -c user.name=t -c user.email=t@t commit --quiet -m init
  git clone --quiet "$DEV_SETUP_AGENT_SKILLS_REPO" "$DEV_SETUP_AGENT_SKILLS_DIR"
  printf 'nuevo\n' >"$DEV_SETUP_AGENT_SKILLS_REPO/NUEVO.md"
  git -C "$DEV_SETUP_AGENT_SKILLS_REPO" add -A
  git -C "$DEV_SETUP_AGENT_SKILLS_REPO" -c user.name=t -c user.email=t@t commit --quiet -m nuevo
  run "$DEV_SETUP" update
  [ "$status" -eq 0 ]
  [ -f "$DEV_SETUP_AGENT_SKILLS_DIR/NUEVO.md" ]
}

@test "si no se puede descargar testigo, no corre testigo setup y sigue" {
  rm "$STUBS/testigo"
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sin testigo se salta testigo setup"* ]]
  [ "$(grep -c 'testigo setup' "$FAKE_LOG")" -eq 0 ]
  [[ "$output" == *"==> Shell"* ]]
}
