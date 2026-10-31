#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  load_libs
  DEV_SETUP_IOS=1
}

@test "con el grupo ios desactivado no revisa nada" {
  DEV_SETUP_IOS=0
  run ios_install
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sin Xcode avisa como instalarlo" {
  run ios_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"App Store"* ]]
}

@test "con Xcode sin seleccionar sugiere xcode-select y no corre sudo" {
  mkdir -p "$DEV_SETUP_XCODE_APP"
  run ios_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"sudo xcode-select -s $DEV_SETUP_XCODE_APP/Contents/Developer"* ]]
  [ "$(grep -c 'xcode-select -s' "$FAKE_LOG")" -eq 0 ]
}

@test "con Xcode seleccionado no avisa nada" {
  mkdir -p "$DEV_SETUP_XCODE_APP"
  make_stub xcode-select <<'STUB'
echo "$DEV_SETUP_XCODE_APP/Contents/Developer"
STUB
  run ios_doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"xcode-select usa ese Xcode"* ]]
  [[ "$output" != *"sudo"* ]]
}
