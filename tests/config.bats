#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  export DEV_SETUP_SKIP_OS_CHECK=1
}

@test "sin terminal, los grupos opcionales quedan desactivados" {
  run "$DEV_SETUP" bootstrap
  [ "$status" -eq 0 ]
  grep -qx 'DEV_SETUP_AI_LOCAL=0' "$DEV_SETUP_LOCAL_ENV"
  grep -qx 'DEV_SETUP_NODE=0' "$DEV_SETUP_LOCAL_ENV"
}

@test "--with y --without se guardan en local.env" {
  run "$DEV_SETUP" bootstrap --with node --without=ios
  [ "$status" -eq 0 ]
  grep -qx 'DEV_SETUP_NODE=1' "$DEV_SETUP_LOCAL_ENV"
  grep -qx 'DEV_SETUP_IOS=0' "$DEV_SETUP_LOCAL_ENV"
}

@test "update aplica --with sin preguntar por los demas grupos" {
  run "$DEV_SETUP" update --with terminal
  [ "$status" -eq 0 ]
  grep -qx 'DEV_SETUP_TERMINAL=1' "$DEV_SETUP_LOCAL_ENV"
  [ "$(grep -c 'DEV_SETUP_NODE' "$DEV_SETUP_LOCAL_ENV")" -eq 0 ]
}

@test "bootstrap dos veces no cambia local.env" {
  "$DEV_SETUP" bootstrap --with node >/dev/null
  cp "$DEV_SETUP_LOCAL_ENV" "$BATS_TEST_TMPDIR/first"
  "$DEV_SETUP" bootstrap >/dev/null
  cmp "$DEV_SETUP_LOCAL_ENV" "$BATS_TEST_TMPDIR/first"
}

@test "al actualizar local.env conserva comentarios y otras lineas" {
  printf '# mi comentario\nDEV_SETUP_NODE=0\nDEV_SETUP_IOS=1\n' >"$DEV_SETUP_LOCAL_ENV"
  run "$DEV_SETUP" update --with node
  [ "$status" -eq 0 ]
  grep -qx '# mi comentario' "$DEV_SETUP_LOCAL_ENV"
  grep -qx 'DEV_SETUP_NODE=1' "$DEV_SETUP_LOCAL_ENV"
  grep -qx 'DEV_SETUP_IOS=1' "$DEV_SETUP_LOCAL_ENV"
  [ "$(grep -c 'DEV_SETUP_NODE' "$DEV_SETUP_LOCAL_ENV")" -eq 1 ]
}

@test "local.env nunca se ejecuta y las lineas desconocidas se ignoran" {
  # shellcheck disable=SC2016
  printf '%s\n' 'touch "$HOME/hackeado"' 'DEV_SETUP_NODE=$(touch "$HOME/hackeado")' 'DEV_SETUP_ROOT=/tmp' 'DEV_SETUP_IOS=1' >"$DEV_SETUP_LOCAL_ENV"
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/hackeado" ]
  [[ "$output" == *"línea ignorada"* ]]
  [[ "$output" == *"ios: sí"* ]]
}

@test "el example es un local.env valido" {
  cp "$REPO_ROOT/local.env.example" "$DEV_SETUP_LOCAL_ENV"
  run "$DEV_SETUP" doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *"línea ignorada"* ]]
  [[ "$output" == *"node: no"* ]]
}

@test "DEV_SETUP_STUDIO_XMX acepta solo un numero con m o g" {
  load_libs
  config_valid_entry DEV_SETUP_STUDIO_XMX 6144m
  config_valid_entry DEV_SETUP_STUDIO_XMX 8g
  local bad
  for bad in "" m 6144 6144mb 6g4m '$(touch x)'; do
    run config_valid_entry DEV_SETUP_STUDIO_XMX "$bad"
    [ "$status" -eq 1 ]
  done
}

@test "local.env fija la memoria de Android Studio" {
  load_libs
  printf 'DEV_SETUP_STUDIO_XMX=5g\n' >"$DEV_SETUP_LOCAL_ENV"
  config_load
  [ "$DEV_SETUP_STUDIO_XMX" = 5g ]
}
