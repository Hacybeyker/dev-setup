#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  load_libs
  # Sin destino, los repos se clonan junto a dev-setup: aquí, dentro del HOME temporal.
  DEV_SETUP_ROOT="$HOME/Claude/dev-setup"
  ORIGIN="$BATS_TEST_TMPDIR/origin"
  make_origin "$ORIGIN/app-a"
  make_origin "$ORIGIN/app-b"
}

# make_origin <carpeta>: un repo con un commit, para clonarlo.
make_origin() {
  mkdir -p "$1"
  git -C "$1" init --quiet
  printf 'hola\n' >"$1/README.md"
  git -C "$1" add -A
  git -C "$1" -c user.name=test -c user.email=test@example.com commit --quiet -m inicial
}

@test "sin repos.txt no hace nada" {
  run repos_install
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "clona en el destino indicado y, sin destino, junto a dev-setup" {
  printf '# mis repos\n%s ~/Projects/a\n%s\n' "$ORIGIN/app-a" "$ORIGIN/app-b" >"$DEV_SETUP_REPOS"
  run repos_install
  [ "$status" -eq 0 ]
  [ -e "$HOME/Projects/a/.git" ]
  [ -e "$HOME/Claude/app-b/.git" ]
}

@test "no toca un destino que ya existe" {
  mkdir -p "$HOME/Projects/a"
  printf 'mio\n' >"$HOME/Projects/a/notas"
  printf '%s ~/Projects/a\n' "$ORIGIN/app-a" >"$DEV_SETUP_REPOS"
  run repos_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"no es un clon: no se toca"* ]]
  [ ! -e "$HOME/Projects/a/.git" ]
  [ "$(cat "$HOME/Projects/a/notas")" = mio ]
}

@test "si no puede clonar avisa, sigue con los demas y lo deja como paso pendiente" {
  printf '%s ~/Projects/no-existe\n%s ~/Projects/b\n' "$ORIGIN/no-existe" "$ORIGIN/app-b" >"$DEV_SETUP_REPOS"
  repos_install
  [ -e "$HOME/Projects/b/.git" ]
  [ "$REPOS_FAILED" = no-existe ]
  repos_next_steps
  [[ "$DEV_SETUP_NEXT_STEPS" == *"Repos sin clonar (no-existe)"* ]]
}

@test "ignora lineas con columnas de mas, destino relativo o URL que empieza con guion" {
  printf '%s ~/a extra\n%s Projects/b\n--upload-pack=touch ~/c\n' "$ORIGIN/app-a" "$ORIGIN/app-b" >"$DEV_SETUP_REPOS"
  run repos_install
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c 'línea ignorada')" -eq 3 ]
  [ ! -e "$HOME/a" ]
  [ ! -e "$HOME/c" ]
}

@test "update nunca hace pull en un repo ya clonado" {
  printf '%s ~/Projects/a\n' "$ORIGIN/app-a" >"$DEV_SETUP_REPOS"
  repos_install >/dev/null
  before="$(git -C "$HOME/Projects/a" rev-parse HEAD)"
  printf 'cambio\n' >>"$ORIGIN/app-a/README.md"
  git -C "$ORIGIN/app-a" -c user.name=test -c user.email=test@example.com commit --quiet -am cambio
  run repos_update
  [ "$status" -eq 0 ]
  [ "$(git -C "$HOME/Projects/a" rev-parse HEAD)" = "$before" ]
}

@test "dry-run no clona" {
  printf '%s ~/Projects/a\n' "$ORIGIN/app-a" >"$DEV_SETUP_REPOS"
  DEV_SETUP_DRY_RUN=1 run repos_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"*"git clone"* ]]
  [ ! -e "$HOME/Projects/a" ]
}

@test "doctor reporta clonados, faltantes y ocupados sin cambiar nada" {
  mkdir -p "$HOME/Projects/ocupado"
  : >"$HOME/Projects/ocupado/archivo"
  printf '%s ~/Projects/a\n%s ~/Projects/b\n%s ~/Projects/ocupado\n' "$ORIGIN/app-a" "$ORIGIN/app-b" "$ORIGIN/app-a" >"$DEV_SETUP_REPOS"
  git clone --quiet "$ORIGIN/app-a" "$HOME/Projects/a"
  run repos_doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"a en $HOME/Projects/a"* ]]
  [[ "$output" == *"b: falta clonar"* ]]
  [[ "$output" == *"ocupado existe y no es un clon"* ]]
  [ ! -e "$HOME/Projects/b" ]
}

@test "el example no tiene repos activos" {
  cp "$REPO_ROOT/repos.txt.example" "$DEV_SETUP_REPOS"
  [ -z "$(list_entries "$DEV_SETUP_REPOS")" ]
}
