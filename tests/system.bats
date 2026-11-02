#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  load_libs
  export DEV_SETUP_UPDATE_CHECK=1
  ORIGIN="$BATS_TEST_TMPDIR/origin/dev-setup"
  make_released_origin "$ORIGIN"
  DEV_SETUP_ROOT="$HOME/Claude/dev-setup"
}

# Un dev-setup publicado con v1.0.0, v1.1.0 y v1.10.0, y un tag de prueba que no es una versión.
make_released_origin() {
  local tag
  mkdir -p "$1"
  git -C "$1" init --quiet
  for tag in v1.0.0 v1.1.0 v1.10.0 v2.0.0-beta.1; do
    printf '%s\n' "$tag" >"$1/VERSION"
    git -C "$1" add -A
    git -C "$1" -c user.name=test -c user.email=test@example.com commit --quiet -m "$tag"
    git -C "$1" tag "$tag"
  done
}

# clone_at <ref>: clona el origin en DEV_SETUP_ROOT, como install.sh (fijo en un tag) o en una rama.
clone_at() {
  git -c advice.detachedHead=false clone --quiet --branch "$1" "$ORIGIN" "$DEV_SETUP_ROOT"
}

@test "avisa la version nueva si el clon esta fijo en un tag mas antiguo" {
  clone_at v1.1.0
  run dev_setup_newer_release
  [ "$status" -eq 0 ]
  [ "$output" = v1.10.0 ]
  system_next_steps
  [[ "$DEV_SETUP_NEXT_STEPS" == *"(v1.10.0). Para pasar a ella: git -C ~/Claude/dev-setup fetch --tags && git -C ~/Claude/dev-setup checkout v1.10.0"* ]]
}

@test "doctor muestra el aviso de version nueva" {
  clone_at v1.0.0
  run system_doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hay una versión nueva de dev-setup (v1.10.0)"* ]]
}

@test "en la ultima version no avisa" {
  clone_at v1.10.0
  run dev_setup_newer_release
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "en una rama, como main, no avisa aunque el commit tenga un tag" {
  # -B: la rama main puede existir ya si git crea los repos con main por defecto.
  git -C "$ORIGIN" checkout --quiet -B main v1.1.0
  clone_at main
  run dev_setup_newer_release
  [ "$status" -eq 1 ]
}

@test "sin conexion no dice nada" {
  clone_at v1.1.0
  git -C "$DEV_SETUP_ROOT" remote set-url origin "$BATS_TEST_TMPDIR/no-existe"
  run dev_setup_newer_release
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "si la consulta tarda, se corta sin esperar" {
  clone_at v1.1.0
  make_stub git <<'STUB'
case " $* " in *" ls-remote "*) exec sleep 30 ;; esac
exec /usr/bin/git "$@"
STUB
  export DEV_SETUP_UPDATE_CHECK_TIMEOUT=1
  SECONDS=0
  run dev_setup_newer_release
  [ "$status" -eq 1 ]
  [ "$SECONDS" -lt 5 ]
}

@test "con DEV_SETUP_UPDATE_CHECK=0 no consulta el origin" {
  clone_at v1.1.0
  make_stub git <<'STUB'
printf 'git %s\n' "$*" >>"$FAKE_LOG"
exec /usr/bin/git "$@"
STUB
  export DEV_SETUP_UPDATE_CHECK=0
  run dev_setup_newer_release
  [ "$status" -eq 1 ]
  [ "$(grep -c 'ls-remote' "$FAKE_LOG")" -eq 0 ]
}
