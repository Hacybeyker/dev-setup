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

@test "avisa de las skills que Android Studio ve dos veces, sin borrarlas" {
  mkdir -p "$HOME/.agents/skills/repetida" "$HOME/.android-studio/skills/repetida" "$HOME/.android-studio/skills/enlazada"
  ln -s "$BATS_TEST_TMPDIR" "$HOME/.agents/skills/enlazada"
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"repetida está en ~/.agents/skills y en ~/.android-studio/skills"* ]]
  [[ "$output" != *"enlazada está en"* ]]
  [ -d "$HOME/.agents/skills/repetida" ]
}

@test "detecta Android Studio instalado por Toolbox en ~/Applications" {
  run "$DEV_SETUP" doctor
  [[ "$output" == *"Falta Android Studio: instálalo desde JetBrains Toolbox"* ]]
  mkdir -p "$HOME/Applications/Android Studio.app"
  run "$DEV_SETUP" doctor
  [[ "$output" == *"Android Studio: $HOME/Applications/Android Studio.app"* ]]
}

@test "respeta CLAUDE_CONFIG_DIR al buscar las skills" {
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude"
  mkdir -p "$CLAUDE_CONFIG_DIR/skills/skill-missing"
  touch "$CLAUDE_CONFIG_DIR/skills/skill-missing/SKILL.md"
  run "$DEV_SETUP" doctor
  [[ "$output" == *"✔ skill-missing"* ]]
  [[ "$output" == *"skill-installed: falta"* ]]
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
