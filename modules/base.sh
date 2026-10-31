# shellcheck shell=bash
# Base: Command Line Tools, Homebrew, las herramientas del Brewfile y el comando dev-setup en ~/.local/bin.

HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# Rutas que los tests reemplazan para no depender de la máquina.
brewfile_path() { printf '%s' "${DEV_SETUP_BREWFILE:-$DEV_SETUP_ROOT/Brewfile}"; }
homebrew_prefix() { printf '%s' "${DEV_SETUP_HOMEBREW_PREFIX:-/opt/homebrew}"; }
java_home_cmd() { printf '%s' "${DEV_SETUP_JAVA_HOME_CMD:-/usr/libexec/java_home}"; }
cli_link_path() { printf '%s' "$HOME/.local/bin/dev-setup"; }

# Ruta de brew, aunque todavía no esté en el PATH (recién instalado).
brew_cmd() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [ -x "$(homebrew_prefix)/bin/brew" ]; then
    printf '%s' "$(homebrew_prefix)/bin/brew"
  else
    return 1
  fi
}

has_clt() { xcode-select -p >/dev/null 2>&1; }

# Una línea por entrada del Brewfile: tipo|nombre|variable de grupo|detección|valor
brewfile_entries() {
  local line kind rest name group htype hvalue
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'brew "'* | 'cask "'*) ;;
      *) continue ;;
    esac
    kind="${line%% *}"
    rest="${line#*\"}"
    name="${rest%%\"*}"
    group=""
    case "$line" in
      *'ENV.fetch("'*)
        group="${line#*ENV.fetch(\"}"
        group="${group%%\"*}"
        ;;
    esac
    htype=""
    hvalue=""
    case "$line" in
      *'# bin: '*) htype=bin hvalue="${line##*# bin: }" ;;
      *'# app: '*) htype=app hvalue="${line##*# app: }" ;;
      *'# jdk: '*) htype=jdk hvalue="${line##*# jdk: }" ;;
    esac
    hvalue="${hvalue%"${hvalue##*[![:space:]]}"}"
    printf '%s|%s|%s|%s|%s\n' "$kind" "$name" "$group" "$htype" "$hvalue"
  done <"$(brewfile_path)"
}

# DEV_SETUP_AI_LOCAL → ai-local
group_name_from_var() { printf '%s' "${1#DEV_SETUP_}" | tr '[:upper:]_' '[:lower:]-'; }

entry_enabled() { [ -z "$1" ] || [ "${!1:-0}" = 1 ]; }

detected_outside_brew() {
  case "$1" in
    bin) command -v "$2" >/dev/null 2>&1 ;;
    app) [ -d "/Applications/$2" ] || [ -d "$HOME/Applications/$2" ] ;;
    jdk) "$(java_home_cmd)" -v "$2" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# brew_item_status <tipo> <nombre> <detección> <valor>: imprime managed, external o missing.
brew_item_status() {
  local kind="$1" name="$2" brew flag=--formula
  [ "$kind" != cask ] || flag=--cask
  if brew="$(brew_cmd)" && "$brew" list "$flag" --versions "$name" >/dev/null 2>&1; then
    printf managed
  elif detected_outside_brew "$3" "$4"; then
    printf external
  else
    printf missing
  fi
}

# Instala Homebrew si falta. Su instalador también instala las Command Line Tools.
base_ensure_homebrew() {
  local brew
  if brew="$(brew_cmd)"; then
    ok "Homebrew: $brew"
    if ! has_clt; then
      run_cmd xcode-select --install
      is_dry_run || die "Termina de instalar las Command Line Tools (se abrió una ventana) y vuelve a correr dev-setup bootstrap"
    fi
    return 0
  fi
  info "Instalando Homebrew con su instalador oficial (pide tu contraseña de macOS)"
  run_cmd /bin/bash -c "/bin/bash -c \"\$(curl -fsSL $HOMEBREW_INSTALL_URL)\""
  is_dry_run && return 0
  brew="$(brew_cmd)" || die "Homebrew no quedó instalado; revisa el mensaje de su instalador"
  eval "$("$brew" shellenv)"
  ok "Homebrew: $brew"
}

# Instala lo que falta del Brewfile. Lo que ya existe, venga de donde venga, se respeta.
base_install_brewfile() {
  local kind name group htype hvalue brew
  brew="$(brew_cmd)" || brew=brew
  while IFS='|' read -r kind name group htype hvalue <&3; do
    entry_enabled "$group" || continue
    case "$(brew_item_status "$kind" "$name" "$htype" "$hvalue")" in
      managed) ok "$name ya está (Homebrew)" ;;
      external) ok "$name ya está instalado fuera de Homebrew: se respeta" ;;
      missing)
        if [ "$kind" = cask ]; then
          run_cmd "$brew" install --cask "$name"
        else
          run_cmd "$brew" install "$name"
        fi
        ;;
    esac
  done 3< <(brewfile_entries)
}

# Deja el comando dev-setup en ~/.local/bin sin pisar un archivo ajeno.
base_ensure_cli_link() {
  local link target
  link="$(cli_link_path)"
  target="$DEV_SETUP_ROOT/bin/dev-setup"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    ok "Comando dev-setup en $link"
  elif [ -e "$link" ] || [ -L "$link" ]; then
    warn "$link ya existe y no apunta a este repo: no lo toco"
  else
    run_cmd mkdir -p "$(dirname "$link")"
    run_cmd ln -s "$target" "$link"
  fi
}

base_doctor() {
  local brew kind name group htype hvalue link
  section "Base"
  if has_clt; then
    case "$(xcode-select -p)" in
      *Xcode*.app/*) ok "Xcode (incluye las Command Line Tools): $(xcode-select -p)" ;;
      *) ok "Command Line Tools: $(xcode-select -p)" ;;
    esac
  else
    warn "Faltan las Command Line Tools de Xcode"
  fi
  if brew="$(brew_cmd)"; then
    ok "$("$brew" --version | head -n 1) en $brew"
  else
    warn "Falta Homebrew"
  fi
  link="$(cli_link_path)"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$DEV_SETUP_ROOT/bin/dev-setup" ]; then
    ok "Comando dev-setup en $link"
  elif [ -e "$link" ] || [ -L "$link" ]; then
    warn "$link existe y no apunta a este repo"
  else
    warn "Falta el comando dev-setup en $link"
  fi

  section "Herramientas (Brewfile)"
  while IFS='|' read -r kind name group htype hvalue <&3; do
    if ! entry_enabled "$group"; then
      info "$name: grupo $(group_name_from_var "$group") desactivado"
      continue
    fi
    case "$(brew_item_status "$kind" "$name" "$htype" "$hvalue")" in
      managed) ok "$name (Homebrew)" ;;
      external) ok "$name: instalado fuera de Homebrew, se respeta" ;;
      missing) warn "$name: falta" ;;
    esac
  done 3< <(brewfile_entries)
}

base_install() {
  section "Base"
  base_ensure_homebrew
  base_ensure_cli_link
  section "Herramientas (Brewfile)"
  base_install_brewfile
}

# Actualiza solo lo que Homebrew gestiona y está en el Brewfile.
base_update() {
  local brew kind name group htype hvalue formulae="" casks=""
  section "Herramientas (Brewfile)"
  if ! brew="$(brew_cmd)"; then
    warn "Falta Homebrew: corre dev-setup bootstrap"
    return 0
  fi
  run_cmd "$brew" update
  while IFS='|' read -r kind name group htype hvalue <&3; do
    entry_enabled "$group" || continue
    case "$(brew_item_status "$kind" "$name" "$htype" "$hvalue")" in
      managed) if [ "$kind" = cask ]; then casks="$casks $name"; else formulae="$formulae $name"; fi ;;
      external) info "$name: instalado fuera de Homebrew, se actualiza por su cuenta" ;;
      missing) warn "$name: falta, corre dev-setup bootstrap" ;;
    esac
  done 3< <(brewfile_entries)
  # Los nombres de Homebrew no tienen espacios: la separación en palabras es intencional.
  # shellcheck disable=SC2086
  [ -z "$formulae" ] || run_cmd "$brew" upgrade --formula $formulae
  # Las casks que se actualizan solas (como Toolbox) las salta Homebrew.
  # shellcheck disable=SC2086
  [ -z "$casks" ] || run_cmd "$brew" upgrade --cask $casks
}

# Líneas del bloque de ~/.zshrc. Cada una respeta lo que el usuario ya tenga definido.
base_shell() {
  local jdk
  # shellcheck disable=SC2016
  printf '%s\n' 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
  # shellcheck disable=SC2016
  printf '%s\n' 'if ! command -v brew >/dev/null 2>&1 && [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi'
  jdk="$(brewfile_entries | awk -F'|' '$4 == "jdk" { print $5; exit }')"
  [ -n "$jdk" ] || return 0
  # shellcheck disable=SC2016
  printf 'if [ -z "${JAVA_HOME:-}" ] && /usr/libexec/java_home -v %s >/dev/null 2>&1; then export JAVA_HOME="$(/usr/libexec/java_home -v %s)"; fi\n' "$jdk" "$jdk"
}
