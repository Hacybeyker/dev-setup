# shellcheck shell=bash
# Repos propios de repos.txt (no se versiona): clona los que faltan. Nunca hace pull ni toca un
# destino que ya existe, porque tus repos pueden tener trabajo en curso.

REPOS_FAILED=""

repos_file() { printf '%s' "${DEV_SETUP_REPOS:-$DEV_SETUP_ROOT/repos.txt}"; }

# repo_dest <url> [destino]: el destino con ~/ expandido. Sin destino, junto a dev-setup.
repo_dest() {
  local url="$1" dest="${2:-}"
  [ -n "$dest" ] || dest="$(dirname "$DEV_SETUP_ROOT")/$(basename "$url" .git)"
  case "$dest" in \~/*) dest="$HOME/${dest#\~/}" ;; esac
  printf '%s' "$dest"
}

# repo_state <destino>: cloned, missing (no existe o está vacío) u occupied.
repo_state() {
  if [ -e "$1/.git" ]; then
    printf 'cloned'
  elif [ ! -e "$1" ] || { [ -d "$1" ] && [ -z "$(ls -A "$1")" ]; }; then
    printf 'missing'
  else
    printf 'occupied'
  fi
}

# repos_each <función>: llama a <función> <url> <destino> por cada línea válida de repos.txt.
repos_each() {
  local fn="$1" url dest extra
  while read -r url dest extra <&3; do
    if [ -n "$extra" ]; then
      warn "repos.txt: línea ignorada, sobran columnas: $url $dest $extra"
      continue
    fi
    case "$url" in -*)
      warn "repos.txt: línea ignorada, URL inválida: $url"
      continue
      ;;
    esac
    dest="$(repo_dest "$url" "$dest")"
    case "$dest" in /*) ;; *)
      warn "repos.txt: línea ignorada, el destino debe ser absoluto o empezar con ~/: $url $dest"
      continue
      ;;
    esac
    "$fn" "$url" "$dest"
  done 3< <(list_entries "$(repos_file)")
}

repo_clone() {
  local url="$1" dest="$2"
  case "$(repo_state "$dest")" in
    cloned) ok "$(basename "$dest") en $dest" ;;
    occupied) warn "$dest ya existe y no es un clon: no se toca" ;;
    missing)
      # Sin preguntas de usuario y contraseña: si no hay sesión, falla y queda como paso pendiente.
      if run_cmd env GIT_TERMINAL_PROMPT=0 git clone --quiet -- "$url" "$dest"; then
        is_dry_run || ok "$(basename "$dest") clonado en $dest"
      else
        warn "No se pudo clonar $url"
        REPOS_FAILED="$REPOS_FAILED${REPOS_FAILED:+, }$(basename "$dest")"
      fi
      ;;
  esac
}

repo_report() {
  case "$(repo_state "$2")" in
    cloned) ok "$(basename "$2") en $2" ;;
    missing) warn "$(basename "$2"): falta clonar $1 en $2" ;;
    occupied) warn "$2 existe y no es un clon de $1" ;;
  esac
}

repos_install() {
  [ -f "$(repos_file)" ] || return 0
  section "Repos (repos.txt)"
  repos_each repo_clone
}

repos_update() { repos_install; }

repos_doctor() {
  section "Repos (repos.txt)"
  if [ ! -f "$(repos_file)" ]; then
    info "Sin repos.txt: no hay repos que clonar (formato en repos.txt.example)"
    return 0
  fi
  repos_each repo_report
}

repos_next_steps() {
  if [ -n "$REPOS_FAILED" ]; then
    next_step "Repos sin clonar ($REPOS_FAILED): revisa tu sesión de GitHub o tu llave SSH y corre dev-setup update"
  fi
}
