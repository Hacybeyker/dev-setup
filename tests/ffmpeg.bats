#!/usr/bin/env bats

setup() {
  load test_helper
  setup_env
  load_libs
  # Aquí ffmpeg no está instalado: se quita el falso que setup_env deja en el PATH.
  rm "$STUBS/ffmpeg"
  hash -r
  DEST="$HOME/.local/bin/ffmpeg"
  MARKER="$HOME/.local/share/dev-setup/ffmpeg.version"
  export DEV_SETUP_FFMPEG_DATA="$BATS_TEST_TMPDIR/ffmpeg-data"
  mkdir -p "$DEV_SETUP_FFMPEG_DATA"
  # shasum falso: 64 caracteres que dependen del contenido, igual en macOS y en Linux.
  make_stub shasum <<'STUB'
printf '%064d  %s\n' "$(cksum <"$3" | awk '{ print $1 }')" "$3"
STUB
  # unzip falso: el "zip" de prueba es el propio binario, que se copia como ffmpeg en la carpeta de -d.
  make_stub unzip <<'STUB'
printf 'unzip %s\n' "$*" >>"$FAKE_LOG"
zip="" dir=""
while [ $# -gt 0 ]; do
  case "$1" in
    -d) dir="$2"; shift ;;
    -*) ;;
    *) [ -n "$zip" ] || zip="$1" ;;
  esac
  shift
done
[ "${FAKE_ZIP_EMPTY:-0}" = 1 ] || cp "$zip" "$dir/ffmpeg"
STUB
  # xattr falso: sin FAKE_QUARANTINE, nada está en cuarentena.
  make_stub xattr <<'STUB'
[ "${FAKE_QUARANTINE:-0}" = 1 ] && [ "$1" = -p ] && { echo "0081;00000000;curl;"; exit 0; }
exit 1
STUB
}

fake_sha() { "$STUBS/shasum" -a 256 "$1" | awk '{ print $1 }'; }

# fake_build <versión> [con drawtext: 1 o 0]: un ffmpeg falso, que deja registrado cuándo lo ejecutan, y su
# línea en builds.txt para la arquitectura de esta máquina. curl "descarga" ese mismo archivo.
fake_build() {
  export FAKE_INSTALLER_SCRIPT="$BATS_TEST_TMPDIR/ffmpeg-$1.zip"
  cat >"$FAKE_INSTALLER_SCRIPT" <<SCRIPT
#!/usr/bin/env bash
printf 'ffmpeg %s\n' "\$*" >>"\$FAKE_LOG"
case "\$*" in
  *-filters*)
    echo " .. pad               V->V       Pad the input video."
    [ "${2:-1}" = 0 ] || echo " T. drawtext          V->V       Draw text on top of video frames using libfreetype library."
    ;;
  *) echo "ffmpeg version $1-fake Copyright (c) 2000-2026 the FFmpeg developers" ;;
esac
SCRIPT
  printf '%s %s https://ffmpeg.example/%s/ffmpeg.zip %s\n' "$(uname -m)" "$1" "$1" \
    "$(fake_sha "$FAKE_INSTALLER_SCRIPT")" >"$DEV_SETUP_FFMPEG_DATA/builds.txt"
}

downloads() { grep -c '^curl' "$FAKE_LOG" || true; }

@test "instala ffmpeg si falta, verifica el SHA256 y que tenga drawtext" {
  fake_build 9.0.2
  run ffmpeg_install
  [ "$status" -eq 0 ]
  [ -x "$DEST" ]
  cmp "$DEST" "$FAKE_INSTALLER_SCRIPT"
  grep -qx 'version=9.0.2' "$MARKER"
  grep -qx "sha256=$(fake_sha "$DEST")" "$MARKER"
  grep -q '^curl -fsSL -o .* https://ffmpeg.example/9.0.2/ffmpeg.zip$' "$FAKE_LOG"
  grep -qx 'ffmpeg -hide_banner -version' "$FAKE_LOG"
  [[ "$output" == *"ffmpeg 9.0.2 instalado en ~/.local/bin/ffmpeg"* ]]
  [[ "$output" == *"ffmpeg -version: ffmpeg version 9.0.2-fake"* ]]
  [[ "$output" == *"ffmpeg tiene el filtro drawtext"* ]]
  [ "$(ffmpeg_state)" = propio ]
}

@test "la segunda vez no descarga ni cambia nada" {
  fake_build 9.0.2
  ffmpeg_install >/dev/null
  cp "$DEST" "$BATS_TEST_TMPDIR/first-bin"
  cp "$MARKER" "$BATS_TEST_TMPDIR/first-marker"
  : >"$FAKE_LOG"
  run ffmpeg_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"ffmpeg 9.0.2 ya está en ~/.local/bin/ffmpeg"* ]]
  [ ! -s "$FAKE_LOG" ]
  cmp "$DEST" "$BATS_TEST_TMPDIR/first-bin"
  cmp "$MARKER" "$BATS_TEST_TMPDIR/first-marker"
}

@test "si el SHA256 no coincide, no instala nada y lo deja pendiente" {
  fake_build 9.0.2
  sed -i.orig 's/ [0-9a-f]*$/ ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff/' \
    "$DEV_SETUP_FFMPEG_DATA/builds.txt"
  ffmpeg_install >/dev/null 2>&1
  [ ! -e "$DEST" ]
  [ ! -e "$MARKER" ]
  [[ "$DEV_SETUP_SUMMARY" == *"fallo|ffmpeg: el SHA256 de la descarga no coincide"* ]]
  [[ "$DEV_SETUP_NEXT_STEPS" == *"No se instaló ffmpeg: el SHA256 de la descarga no coincide"* ]]
  [ "$(grep -c '^unzip' "$FAKE_LOG" || true)" -eq 0 ]
  run ffmpeg_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"no es el de ffmpeg/builds.txt: no se instala"* ]]
}

@test "dry-run no descarga ni instala" {
  fake_build 9.0.2
  DEV_SETUP_DRY_RUN=1 run ffmpeg_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] curl -fsSL -o '<temporal>' https://ffmpeg.example/9.0.2/ffmpeg.zip"* ]]
  [[ "$output" == *"Si su SHA256 es el de ffmpeg/builds.txt, se copia a ~/.local/bin/ffmpeg"* ]]
  [ ! -e "$DEST" ]
  [ ! -e "$MARKER" ]
  [ ! -s "$FAKE_LOG" ]
}

@test "update instala la version nueva si cambio la fijada en builds.txt" {
  fake_build 9.0.2
  ffmpeg_install >/dev/null
  fake_build 9.1.0
  run ffmpeg_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"ffmpeg actualizado: 9.0.2 → 9.1.0"* ]]
  cmp "$DEST" "$FAKE_INSTALLER_SCRIPT"
  grep -qx 'version=9.1.0' "$MARKER"
  [ "$(ffmpeg_state)" = propio ]
}

@test "update sin version nueva no descarga y lo anota como revisado" {
  fake_build 9.0.2
  ffmpeg_install >/dev/null
  : >"$FAKE_LOG"
  DEV_SETUP_SUMMARY=""
  ffmpeg_update >/dev/null
  [[ "$DEV_SETUP_SUMMARY" == *"revisado|ffmpeg 9.0.2"* ]]
  [ ! -s "$FAKE_LOG" ]
}

@test "update no lo instala si falta" {
  fake_build 9.0.2
  run ffmpeg_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Falta ffmpeg"* ]]
  ffmpeg_update >/dev/null 2>&1
  [[ "$DEV_SETUP_NEXT_STEPS" == *"Para instalar ffmpeg, corre dev-setup bootstrap"* ]]
  [ ! -e "$DEST" ]
  [ "$(downloads)" -eq 0 ]
}

@test "distingue los estados propio, ajeno, externo y falta" {
  fake_build 9.0.2
  [ "$(ffmpeg_state)" = falta ]
  make_stub ffmpeg <<'STUB'
echo "ffmpeg de otro lugar"
STUB
  [ "$(ffmpeg_state)" = externo ]
  rm "$STUBS/ffmpeg"
  hash -r
  ffmpeg_install >/dev/null
  [ "$(ffmpeg_state)" = propio ]
  # El binario cambió después de instalarlo: ya no es el de dev-setup.
  printf '#!/bin/sh\necho mio\n' >"$DEST"
  [ "$(ffmpeg_state)" = ajeno ]
  cp "$FAKE_INSTALLER_SCRIPT" "$DEST"
  [ "$(ffmpeg_state)" = propio ]
  # Sin marca, uno en ~/.local/bin tampoco es de dev-setup.
  rm "$MARKER"
  [ "$(ffmpeg_state)" = ajeno ]
}

@test "no toca un ffmpeg ajeno en ~/.local/bin, ni un enlace" {
  fake_build 9.0.2
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\necho mio\n' >"$DEST"
  run ffmpeg_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"~/.local/bin/ffmpeg no lo instaló dev-setup: no se toca"* ]]
  [ "$(sed -n 2p "$DEST")" = "echo mio" ]
  rm "$DEST"
  cp "$FAKE_INSTALLER_SCRIPT" "$BATS_TEST_TMPDIR/mi-ffmpeg"
  ln -s "$BATS_TEST_TMPDIR/mi-ffmpeg" "$DEST"
  run ffmpeg_update
  [[ "$output" == *"no se toca"* ]]
  [ -L "$DEST" ]
  [ ! -e "$MARKER" ]
  [ "$(downloads)" -eq 0 ]
}

@test "respeta un ffmpeg instalado en otro lugar del PATH" {
  fake_build 9.0.2
  make_stub ffmpeg <<'STUB'
echo " T. drawtext          V->V       Draw text on top of video frames using libfreetype library."
STUB
  ffmpeg_install >/dev/null
  [ -z "$DEV_SETUP_NEXT_STEPS" ]
  run ffmpeg_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"instalado fuera de dev-setup: se respeta"* ]]
  run ffmpeg_update
  [[ "$output" == *"instalado fuera de dev-setup: se actualiza por su cuenta"* ]]
  [ ! -e "$DEST" ]
  [ "$(downloads)" -eq 0 ]
}

@test "un ffmpeg externo sin drawtext se respeta y queda como paso pendiente" {
  fake_build 9.0.2
  make_stub ffmpeg <<'STUB'
echo " .. pad               V->V       Pad the input video."
STUB
  ffmpeg_install >/dev/null 2>&1
  [[ "$DEV_SETUP_NEXT_STEPS" == *"no tiene drawtext (le falta libfreetype)"* ]]
  [[ "$DEV_SETUP_SUMMARY" == *"ya|ffmpeg (fuera de dev-setup, sin drawtext)"* ]]
  [ ! -e "$DEST" ]
  [ "$(downloads)" -eq 0 ]
  run ffmpeg_doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"instalado fuera de dev-setup, no tiene drawtext"* ]]
}

@test "si el build no tiene drawtext, lo instala pero lo anota como falla" {
  fake_build 9.0.2 0
  ffmpeg_install >/dev/null 2>&1
  [ -x "$DEST" ]
  [[ "$DEV_SETUP_SUMMARY" == *"fallo|ffmpeg: no tiene el filtro drawtext"* ]]
  [[ "$DEV_SETUP_NEXT_STEPS" == *"no tiene drawtext"* ]]
}

@test "si macOS lo deja en cuarentena, no lo ejecuta y da el comando para quitarla" {
  fake_build 9.0.2
  export FAKE_QUARANTINE=1
  ffmpeg_install >/dev/null 2>&1
  [ -x "$DEST" ]
  [[ "$DEV_SETUP_NEXT_STEPS" == *"xattr -d com.apple.quarantine ~/.local/bin/ffmpeg"* ]]
  [ "$(grep -c '^ffmpeg' "$FAKE_LOG" || true)" -eq 0 ]
  run ffmpeg_doctor
  [[ "$output" == *"en cuarentena"* ]]
}

@test "si la descarga falla, avisa, lo deja pendiente y sigue" {
  fake_build 9.0.2
  unset FAKE_INSTALLER_SCRIPT
  ffmpeg_install >/dev/null 2>&1
  [ ! -e "$DEST" ]
  [[ "$DEV_SETUP_NEXT_STEPS" == *"no se pudo descargar ffmpeg"* ]]
  run ffmpeg_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"No se pudo descargar https://ffmpeg.example/9.0.2/ffmpeg.zip"* ]]
}

@test "si el zip no trae el binario, no instala nada" {
  fake_build 9.0.2
  export FAKE_ZIP_EMPTY=1
  run ffmpeg_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"no trae el binario ffmpeg: no se instala"* ]]
  [ ! -e "$DEST" ]
  [ ! -e "$MARKER" ]
  ffmpeg_install >/dev/null 2>&1
  [[ "$DEV_SETUP_NEXT_STEPS" == *"no trae el binario"* ]]
}

@test "bootstrap y update con --dry-run no descargan ni instalan ffmpeg" {
  fake_build 9.0.2
  export DEV_SETUP_SKIP_OS_CHECK=1
  run "$DEV_SETUP" bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] curl -fsSL -o '<temporal>' https://ffmpeg.example/9.0.2/ffmpeg.zip"* ]]
  [ ! -e "$DEST" ]
  [ ! -e "$MARKER" ]
  [ "$(grep -c 'ffmpeg.example' "$FAKE_LOG" || true)" -eq 0 ]
  ffmpeg_install >/dev/null
  fake_build 9.1.0
  cp "$DEST" "$BATS_TEST_TMPDIR/first-bin"
  : >"$FAKE_LOG"
  run "$DEV_SETUP" update --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] curl -fsSL -o '<temporal>' https://ffmpeg.example/9.1.0/ffmpeg.zip"* ]]
  cmp "$DEST" "$BATS_TEST_TMPDIR/first-bin"
  grep -qx 'version=9.0.2' "$MARKER"
  [ "$(grep -c 'ffmpeg.example' "$FAKE_LOG" || true)" -eq 0 ]
}

@test "sin build para la arquitectura de la Mac no instala nada" {
  printf 'otra-arquitectura 9.0.2 https://ffmpeg.example/ffmpeg.zip %064d\n' 0 >"$DEV_SETUP_FFMPEG_DATA/builds.txt"
  run ffmpeg_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"no tiene un build para $(uname -m)"* ]]
  [ ! -e "$DEST" ]
  [ ! -s "$FAKE_LOG" ]
}

@test "doctor muestra la version sin ejecutarlo ni usar la red" {
  fake_build 9.0.2
  run ffmpeg_doctor
  [[ "$output" == *"Falta ffmpeg: corre dev-setup bootstrap"* ]]
  ffmpeg_install >/dev/null
  : >"$FAKE_LOG"
  run ffmpeg_doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ffmpeg 9.0.2 en ~/.local/bin/ffmpeg, instalado por dev-setup"* ]]
  [[ "$output" != *"corre dev-setup update"* ]]
  [ ! -s "$FAKE_LOG" ]
  fake_build 9.1.0
  run ffmpeg_doctor
  [[ "$output" == *"dev-setup fija ffmpeg 9.1.0: corre dev-setup update"* ]]
  [ ! -s "$FAKE_LOG" ]
}

@test "bootstrap instala ffmpeg y la segunda vez no cambia nada" {
  fake_build 9.0.2
  export DEV_SETUP_SKIP_OS_CHECK=1
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"==> ffmpeg"*"ffmpeg 9.0.2 instalado en ~/.local/bin/ffmpeg"* ]]
  [[ "$output" == *"ffmpeg -hide_banner -filters | grep drawtext"* ]]
  cp "$DEST" "$BATS_TEST_TMPDIR/first-bin"
  cp "$MARKER" "$BATS_TEST_TMPDIR/first-marker"
  : >"$FAKE_LOG"
  run "$DEV_SETUP" bootstrap --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"ffmpeg 9.0.2 ya está"* ]]
  [ "$(grep -c 'ffmpeg.example' "$FAKE_LOG" || true)" -eq 0 ]
  cmp "$DEST" "$BATS_TEST_TMPDIR/first-bin"
  cmp "$MARKER" "$BATS_TEST_TMPDIR/first-marker"
}

@test "sin el grupo android no corre nada de ffmpeg" {
  fake_build 9.0.2
  export DEV_SETUP_SKIP_OS_CHECK=1
  run "$DEV_SETUP" bootstrap --yes --without android
  [ "$status" -eq 0 ]
  [[ "$output" != *"==> ffmpeg"* ]]
  [[ "$output" != *"ffmpeg -hide_banner"* ]]
  [ ! -e "$DEST" ]
  [ "$(grep -c 'ffmpeg.example' "$FAKE_LOG" || true)" -eq 0 ]
  run "$DEV_SETUP" doctor
  [[ "$output" != *"==> ffmpeg"* ]]
}
