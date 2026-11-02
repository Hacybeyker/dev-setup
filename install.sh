#!/usr/bin/env bash
# Entrada remota de dev-setup para una Mac nueva, sin git ni Homebrew:
#
#   curl -fsSL https://raw.githubusercontent.com/Hacybeyker/dev-setup/vX.Y.Z/install.sh | bash
#
# Instala las Command Line Tools (traen git), clona dev-setup en la versión de este instalador y
# corre `dev-setup bootstrap`, que instala Homebrew y todo lo demás. Los argumentos pasan a
# bootstrap: ... | bash -s -- --with node
#
# Opciones por variable de entorno:
#   DEV_SETUP_DIR       carpeta del clon (por defecto ~/Claude/dev-setup)
#   DEV_SETUP_REF       tag o rama que se clona (por defecto, la de este instalador)
#   DEV_SETUP_REPO_URL  repo que se clona (por defecto, el oficial)
#
# Compatible con el Bash 3.2 de macOS. Todo va dentro de main: si la descarga se corta a medias,
# no se ejecuta nada.
set -euo pipefail

main() {
  # El release fija aquí el tag publicado.
  local ref="${DEV_SETUP_REF:-v1.1.0}"
  local repo_url="${DEV_SETUP_REPO_URL:-https://github.com/Hacybeyker/dev-setup.git}"
  local dir="${DEV_SETUP_DIR:-$HOME/Claude/dev-setup}"

  say "dev-setup: instalación inicial ($ref)"
  check_macos
  ensure_clt
  ensure_clone "$repo_url" "$ref" "$dir"
  run_bootstrap "$dir" "$@"
}

say() { printf '\n==> %s\n' "$1"; }
ok() { printf '  ✔ %s\n' "$1"; }
info() { printf '  · %s\n' "$1"; }
die() {
  printf '  ✖ %s\n' "$1" >&2
  exit 1
}

# Los tests lo saltan con DEV_SETUP_SKIP_OS_CHECK=1.
check_macos() {
  if [ "${DEV_SETUP_SKIP_OS_CHECK:-0}" != 1 ] && [ "$(uname -s)" != Darwin ]; then
    die "dev-setup solo instala en macOS"
  fi
  if [ "$(uname -m)" != arm64 ]; then
    info "Está pensado para Apple silicon (arm64); en $(uname -m) puede faltar algo"
  fi
}

# Abre la ventana de macOS para instalar las Command Line Tools y espera hasta una hora.
ensure_clt() {
  local waited=0 poll=15 limit=3600
  if xcode-select -p >/dev/null 2>&1; then
    ok "Command Line Tools: $(xcode-select -p)"
    return 0
  fi
  info "Instalando las Command Line Tools: acepta la ventana que abre macOS"
  xcode-select --install >/dev/null 2>&1 || true
  until xcode-select -p >/dev/null 2>&1; do
    if [ "$waited" -ge "$limit" ]; then
      die "Las Command Line Tools no terminaron de instalarse. Cuando terminen, vuelve a correr este comando."
    fi
    sleep "$poll"
    waited=$((waited + poll))
  done
  ok "Command Line Tools instaladas"
}

# Clona dev-setup. Si la carpeta ya es un clon de dev-setup, la usa tal como está; si es otra
# cosa, no la toca.
ensure_clone() {
  local repo_url="$1" ref="$2" dir="$3" origin
  if [ -e "$dir/.git" ]; then
    origin="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
    case "$origin" in
      */dev-setup | */dev-setup.git | "$repo_url")
        ok "dev-setup ya está en $dir: se usa tal como está"
        return 0
        ;;
    esac
    die "$dir es otro repo (${origin:-sin origin}): no se toca. Elige otra carpeta con DEV_SETUP_DIR"
  fi
  if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
    die "$dir ya existe y no es un clon de dev-setup: no se toca. Elige otra carpeta con DEV_SETUP_DIR"
  fi
  info "Clonando dev-setup ($ref) en $dir"
  git -c advice.detachedHead=false clone --quiet --branch "$ref" -- "$repo_url" "$dir"
  ok "dev-setup clonado en $dir"
}

# bootstrap lee de la terminal aunque este script llegue por un pipe.
run_bootstrap() {
  local cli="$1/bin/dev-setup"
  shift
  if (exec </dev/tty) 2>/dev/null; then
    exec "$cli" bootstrap "$@" </dev/tty
  fi
  exec "$cli" bootstrap "$@"
}

main "$@"
