#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  load_libs
  DEV_SETUP_ASSUME_YES=1
  CONFIG="$HOME/Library/Application Support/Google/AndroidStudio2026.1"
  VMOPTIONS="$CONFIG/studio.vmoptions"
  mkdir -p "$HOME/Applications/Android Studio.app"
}

@test "sin Android Studio no toca nada" {
  rmdir "$HOME/Applications/Android Studio.app"
  run studio_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"no está instalado"* ]]
  [ ! -e "$HOME/Library" ]
}

@test "sin configuracion pide abrir Android Studio una vez" {
  run studio_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"ábrelo una vez"* ]]
  [ ! -e "$HOME/Library" ]
}

@test "la memoria propuesta depende de la RAM o de local.env" {
  [ "$(DEV_SETUP_RAM_GIB=16 studio_desired_xmx)" = 4096m ]
  [ "$(DEV_SETUP_RAM_GIB=32 studio_desired_xmx)" = 6144m ]
  [ "$(DEV_SETUP_RAM_GIB=64 studio_desired_xmx)" = 8192m ]
  [ "$(DEV_SETUP_STUDIO_XMX=5g studio_desired_xmx)" = 5g ]
}

@test "agrega -Xmx sin tocar las demas lineas y con respaldo" {
  mkdir -p "$CONFIG"
  printf -- '-Dmi.opcion=1\n' >"$VMOPTIONS"
  DEV_SETUP_RAM_GIB=36
  run studio_install
  [ "$status" -eq 0 ]
  grep -qx -- '-Dmi.opcion=1' "$VMOPTIONS"
  grep -qx -- '-Xmx6144m' "$VMOPTIONS"
  [ "$(find "$CONFIG" -name 'studio.vmoptions.bak-*' | wc -l | tr -d ' ')" -eq 1 ]
}

@test "crea studio.vmoptions si no existe" {
  mkdir -p "$CONFIG"
  run studio_install
  [ "$status" -eq 0 ]
  [ "$(cat "$VMOPTIONS")" = "-Xmx4096m" ]
}

@test "respeta un -Xmx que ya existe" {
  mkdir -p "$CONFIG"
  printf -- '-Xmx2048m\n' >"$VMOPTIONS"
  cp "$VMOPTIONS" "$BATS_TEST_TMPDIR/before"
  run studio_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"-Xmx2048m (se respeta)"* ]]
  cmp "$VMOPTIONS" "$BATS_TEST_TMPDIR/before"
}

@test "dos veces seguidas: la segunda no cambia nada" {
  mkdir -p "$CONFIG"
  studio_install >/dev/null
  cp "$VMOPTIONS" "$BATS_TEST_TMPDIR/first"
  run studio_update
  [ "$status" -eq 0 ]
  cmp "$VMOPTIONS" "$BATS_TEST_TMPDIR/first"
}

@test "usa la version mas reciente y no las Preview" {
  mkdir -p "$HOME/Library/Application Support/Google/AndroidStudio2025.3" "$CONFIG" \
    "$HOME/Library/Application Support/Google/AndroidStudioPreview2026.2"
  [ "$(studio_config_dir)" = "$CONFIG" ]
}

@test "dry-run y doctor no crean el archivo" {
  mkdir -p "$CONFIG"
  DEV_SETUP_DRY_RUN=1 run studio_install
  [ "$status" -eq 0 ]
  [ ! -e "$VMOPTIONS" ]
  run studio_doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"propone -Xmx4096m"* ]]
  [ ! -e "$VMOPTIONS" ]
}
