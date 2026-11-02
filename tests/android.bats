#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  export DEV_SETUP_SKIP_OS_CHECK=1
}

@test "doctor clasifica los paquetes del SDK y las skills" {
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Android CLI 1.1.0"* ]]
  [[ "$output" == *"✔ pkg-installed"* ]]
  [[ "$output" == *"pkg/missing-1: falta"* ]]
  [[ "$output" == *"✔ skill-installed"* ]]
  [[ "$output" == *"skill-missing: falta"* ]]
  [ "$(grep -cE 'android (sdk install|skills add)' "$FAKE_LOG")" -eq 0 ]
}

@test "bootstrap instala solo los paquetes y las skills que faltan" {
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  grep -qx 'android sdk install pkg/missing-1 pkg/missing-2' "$FAKE_LOG"
  grep -qx 'android skills add --agent=claude-code skill-missing' "$FAKE_LOG"
  [ "$(grep -c 'android skills add' "$FAKE_LOG")" -eq 1 ]
}

@test "con varios agentes en local.env, bootstrap instala solo para los que faltan" {
  printf 'DEV_SETUP_ANDROID_SKILL_AGENTS=claude-code,github-copilot\n' >"$DEV_SETUP_LOCAL_ENV"
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  grep -qx 'android skills add --agent=claude-code skill-missing' "$FAKE_LOG"
  grep -qx 'android skills add --agent=github-copilot skill-installed' "$FAKE_LOG"
  grep -qx 'android skills add --agent=github-copilot skill-missing' "$FAKE_LOG"
  [ "$(grep -c 'android skills add' "$FAKE_LOG")" -eq 3 ]
}

@test "update actualiza cada skill solo para los agentes donde ya esta" {
  printf 'DEV_SETUP_ANDROID_SKILL_AGENTS=claude-code,github-copilot\n' >"$DEV_SETUP_LOCAL_ENV"
  export FAKE_ANDROID_SKILLS="claude-code:skill-installed github-copilot:skill-missing"
  run "$DEV_SETUP" update
  [ "$status" -eq 0 ]
  grep -qx 'android skills update --agent=claude-code skill-installed' "$FAKE_LOG"
  grep -qx 'android skills update --agent=github-copilot skill-missing' "$FAKE_LOG"
  [ "$(grep -c 'android skills update' "$FAKE_LOG")" -eq 2 ]
}

@test "doctor muestra para que agente falta cada skill" {
  printf 'DEV_SETUP_ANDROID_SKILL_AGENTS=claude-code,github-copilot\n' >"$DEV_SETUP_LOCAL_ENV"
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skills oficiales de Android (claude-code,github-copilot)"* ]]
  [[ "$output" == *"✔ skill-installed (claude-code)"* ]]
  [[ "$output" == *"skill-installed: falta para github-copilot"* ]]
  [ "$(grep -c 'android skills add' "$FAKE_LOG")" -eq 0 ]
}

@test "bootstrap nunca usa android init, que instala la skill en todos los agentes" {
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  [ "$(grep -c 'android init' "$FAKE_LOG")" -eq 0 ]
}

@test "bootstrap --dry-run anuncia los cambios de Android sin hacerlos" {
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"*"sdk install pkg/missing-1 pkg/missing-2"* ]]
  [[ "$output" == *"[dry-run]"*"skills add --agent=claude-code skill-missing"* ]]
  [ "$(grep -cE 'android (sdk install|skills add)' "$FAKE_LOG")" -eq 0 ]
}

@test "sin Android CLI, bootstrap --dry-run muestra su instalador oficial" {
  rm "$STUBS/android"
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dl.google.com/android/cli/latest/darwin_"*"/install.sh"* ]]
}

@test "update actualiza el CLI y solo lo que dev-setup instala" {
  run "$DEV_SETUP" update
  [ "$status" -eq 0 ]
  grep -qx 'android update' "$FAKE_LOG"
  grep -qx 'android sdk update pkg-installed' "$FAKE_LOG"
  [ "$(grep -c 'android sdk update' "$FAKE_LOG")" -eq 1 ]
  grep -qx 'android skills update --agent=claude-code skill-installed' "$FAKE_LOG"
  [ "$(grep -c 'android skills update' "$FAKE_LOG")" -eq 1 ]
  [[ "$output" == *"pkg/missing-1: falta, corre dev-setup bootstrap"* ]]
}

@test "avisa de las copias de skills que Android Studio ve dos veces, sin borrarlas" {
  mkdir -p "$HOME/.agents/skills/repetida" "$HOME/.android-studio/skills/repetida" "$HOME/.android-studio/skills/enlazada"
  printf 'v1\n' | tee "$HOME/.agents/skills/repetida/SKILL.md" >"$HOME/.android-studio/skills/repetida/SKILL.md"
  ln -s "$BATS_TEST_TMPDIR" "$HOME/.agents/skills/enlazada"
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"repetida también está copiada en ~/.agents/skills"*"rm -rf ~/.agents/skills/repetida"* ]]
  [[ "$output" != *"enlazada"*"~/.agents/skills"* ]]
  [ -d "$HOME/.agents/skills/repetida" ]
}

@test "si la copia de ~/.agents/skills es distinta, avisa que puede estar desactualizada" {
  mkdir -p "$HOME/.agents/skills/repetida" "$HOME/.android-studio/skills/repetida"
  printf 'v1\n' >"$HOME/.agents/skills/repetida/SKILL.md"
  printf 'v2\n' >"$HOME/.android-studio/skills/repetida/SKILL.md"
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"⚠ repetida en ~/.agents/skills es distinta"*"probablemente desactualizada"* ]]
  [ "$(cat "$HOME/.agents/skills/repetida/SKILL.md")" = v1 ]
}

@test "detecta Android Studio instalado por Toolbox en ~/Applications" {
  run "$DEV_SETUP" doctor
  [[ "$output" == *"Falta Android Studio: instálalo desde JetBrains Toolbox"* ]]
  mkdir -p "$HOME/Applications/Android Studio.app"
  run "$DEV_SETUP" doctor
  [[ "$output" == *"Android Studio: $HOME/Applications/Android Studio.app"* ]]
}

@test "las skills se revisan con android skills list, no buscando carpetas" {
  mkdir -p "$HOME/.claude/skills/skill-missing"
  touch "$HOME/.claude/skills/skill-missing/SKILL.md"
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  grep -qx 'android skills list --agent=claude-code' "$FAKE_LOG"
  [[ "$output" == *"✔ skill-installed (claude-code)"* ]]
  [[ "$output" == *"skill-missing: falta para claude-code"* ]]
}

@test "las listas reales de Android son validas" {
  load_libs
  run list_entries "$REPO_ROOT/android/sdk-packages.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *platform-tools* ]]
  [[ "$output" != *" "* ]]
  run list_entries "$REPO_ROOT/android/skills.txt"
  [[ "$output" == *android-cli* ]]
  [[ "$output" != *testing-setup* ]]
}

@test "list_entries ignora comentarios, espacios y lineas vacias" {
  load_libs
  printf '# comentario\n\n  uno  \ndos # al final\n' >"$BATS_TEST_TMPDIR/lista"
  run list_entries "$BATS_TEST_TMPDIR/lista"
  [ "$output" = "$(printf 'uno\ndos')" ]
}
