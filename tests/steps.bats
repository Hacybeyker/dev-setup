#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  load_libs
}

@test "sin pasos pendientes lo dice" {
  run print_next_steps
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nada pendiente"* ]]
}

@test "numera los pasos en orden" {
  next_step "primero"
  next_step "segundo"
  run print_next_steps
  [[ "$output" == *"1. primero"*"2. segundo"* ]]
}

@test "pide solo los logins que faltan" {
  export FAKE_GH_LOGGED_IN=0 FAKE_CLAUDE_LOGGED_IN=1 FAKE_ANDROID_LOGGED_IN=0
  accounts_next_steps
  [[ "$DEV_SETUP_NEXT_STEPS" == *"gh auth login"* ]]
  [[ "$DEV_SETUP_NEXT_STEPS" != *"claude auth login"* ]]
  [[ "$DEV_SETUP_NEXT_STEPS" != *"android auth login"* ]]
}

@test "doctor muestra el estado de las sesiones" {
  export FAKE_CLAUDE_LOGGED_IN=0
  run accounts_doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"GitHub (gh)"* ]]
  [[ "$output" == *"Claude Code: sin sesión"* ]]
  FAKE_ANDROID_LOGGED_IN=0 run accounts_doctor
  [[ "$output" == *"opcional: android auth login"* ]]
}

@test "bootstrap termina con lo que te toca y la segunda vez ya no pide abrir otra terminal" {
  export DEV_SETUP_SKIP_OS_CHECK=1 FAKE_GH_LOGGED_IN=0
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Lo que te toca"*"gh auth login"* ]]
  [[ "$output" == *"Android Studio desde JetBrains Toolbox"* ]]
  [[ "$output" == *"Abre una terminal nueva"* ]]
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [[ "$output" != *"Abre una terminal nueva"* ]]
}

@test "bootstrap termina con el resumen y los comandos para verificar" {
  export DEV_SETUP_SKIP_OS_CHECK=1
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"==> Resumen"*"==> Para verificar (en una terminal nueva)"*"==> Lo que te toca"*"==> Listo"* ]]
  [[ "$output" == *"Ya estaba (se respetó):"*"      tool-managed"* ]]
  [[ "$output" == *"Instalado:"*"      tool-missing"* ]]
  [[ "$output" == *"Configurado:"*"      bloque de dev-setup en ~/.zshrc"* ]]
  [[ "$output" == *"Omitido por tu elección:"$'\n'"      node, ios, ai-local, terminal, dev-tools"* ]]
  [[ "$output" == *"  android -V"*"  claude --version"*"  dev-setup doctor"* ]]
  [[ "$output" != *"  node --version"* ]]
}

@test "print_summary agrupa por categoria sin repetir" {
  load_libs
  summary_add instalado "uno"
  summary_add ya "dos"
  summary_add instalado "tres"
  summary_add instalado "uno"
  run print_summary
  [[ "$output" == *"Instalado:"$'\n'"      uno"$'\n'"      tres"$'\n'* ]]
  [ "$(grep -c '^      uno$' <<<"$output")" -eq 1 ]
  [[ "$output" == *"Ya estaba (se respetó):"$'\n'"      dos"* ]]
  [[ "$output" != *"Falló"* ]]
}

@test "dry-run no muestra resumen ni comandos para verificar" {
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"==> Resumen"* ]]
  [[ "$output" != *"Para verificar"* ]]
}

@test "dry-run no muestra pasos pendientes" {
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"Lo que te toca"* ]]
}
