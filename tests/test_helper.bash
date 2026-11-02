# Aísla cada test de la máquina: HOME, local.env y Brewfile de prueba, PATH mínimo con comandos
# falsos (brew, xcode-select, java_home) que registran sus llamadas, sin colores y sin preguntas.
setup_env() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  DEV_SETUP="$REPO_ROOT/bin/dev-setup"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset ZDOTDIR
  export SHELL=/bin/zsh
  export PATH="$STUBS:/usr/bin:/bin"
  export NO_COLOR=1
  export DEV_SETUP_NONINTERACTIVE=1
  export DEV_SETUP_LOCAL_ENV="$BATS_TEST_TMPDIR/local.env"
  export DEV_SETUP_BREWFILE="$REPO_ROOT/tests/fixtures/Brewfile"
  export DEV_SETUP_HOMEBREW_PREFIX="$BATS_TEST_TMPDIR/no-homebrew"
  export DEV_SETUP_JAVA_HOME_CMD="$STUBS/java_home"
  export DEV_SETUP_ANDROID_DATA="$REPO_ROOT/tests/fixtures/android"
  export DEV_SETUP_CLAUDE_DATA="$REPO_ROOT/tests/fixtures/claude"
  export DEV_SETUP_AGENT_SKILLS_DIR="$BATS_TEST_TMPDIR/agent-skills"
  export DEV_SETUP_AGENT_SKILLS_REPO="$BATS_TEST_TMPDIR/agent-skills-origin"
  export DEV_SETUP_REPOS="$BATS_TEST_TMPDIR/repos.txt"
  export DEV_SETUP_RAM_GIB=16
  export DEV_SETUP_XCODE_APP="$BATS_TEST_TMPDIR/Xcode.app"
  unset CLAUDE_CONFIG_DIR JAVA_HOME ANDROID_HOME NVM_DIR DEV_SETUP_STUDIO_XMX
  export FAKE_LOG="$BATS_TEST_TMPDIR/calls.log"
  : >"$FAKE_LOG"

  # Estado simulado: tool-managed está en Homebrew; tool-external, App External y el JDK 17, fuera.
  export FAKE_BREW_FORMULAE="tool-managed"
  export FAKE_BREW_CASKS=""
  export FAKE_JDKS="17"
  # Android: pkg-installed está en el SDK y skill-installed, instalada para Claude Code (agente:skill).
  export FAKE_SDK_INSTALLED="pkg-installed"
  export FAKE_ANDROID_SKILLS="claude-code:skill-installed"
  mkdir -p "$HOME/.claude/skills/skill-installed"
  printf -- '---\nname: skill-installed\n---\n' >"$HOME/.claude/skills/skill-installed/SKILL.md"
  make_stub brew <<'STUB'
printf 'brew %s\n' "$*" >>"$FAKE_LOG"
case "$1" in
  list)
    case "$2" in --formula) installed="$FAKE_BREW_FORMULAE" ;; *) installed="$FAKE_BREW_CASKS" ;; esac
    case " $installed " in *" $4 "*) echo "$4 1.0"; exit 0 ;; esac
    exit 1
    ;;
  --version) echo "Homebrew 9.9.9" ;;
  shellenv) echo ":" ;;
esac
exit 0
STUB
  make_stub xcode-select <<'STUB'
printf 'xcode-select %s\n' "$*" >>"$FAKE_LOG"
if [ "$1" = -p ]; then
  [ "${FAKE_NO_CLT:-0}" != 1 ] || exit 2
  echo /Library/Developer/CommandLineTools
fi
exit 0
STUB
  make_stub java_home <<'STUB'
[ "$1" = -v ] || exit 1
case " $FAKE_JDKS " in *" $2 "*) echo "/fake/jdk-$2"; exit 0 ;; esac
exit 1
STUB
  make_stub android <<'STUB'
printf 'android %s\n' "$*" >>"$FAKE_LOG"
if [ "$1 ${2:-}" = "sdk list" ]; then
  echo "Installed packages:"
  for package in $FAKE_SDK_INSTALLED; do printf '  %-30s 1.0.0    Paquete %s\n' "$package" "$package"; done
  echo ""
  echo "Available packages:"
  echo "  pkg/missing-1                  1.0.0    No instalado"
fi
# Como el CLI real: un agente desconocido sale con 1, y skills list da un bloque por skill instalada para
# el agente, con el nombre en la primera línea.
case "${1:-} ${3:-}" in
  "skills --agent="*)
    case " ${FAKE_ANDROID_INVALID_AGENTS:-} " in *" ${3#--agent=} "*) echo "Invalid agent: ${3#--agent=}." >&2; exit 1 ;; esac
    ;;
esac
if [ "$1 ${2:-}" = "skills list" ]; then
  for pair in $FAKE_ANDROID_SKILLS; do
    [ "--agent=${pair%%:*}" = "${3:-}" ] && printf '%s\nDescripcion de %s.\n\n' "${pair#*:}" "${pair#*:}"
  done
fi
[ "$1" != -V ] || echo "1.1.0"
if [ "$1 ${2:-}" = "auth status" ]; then [ "${FAKE_ANDROID_LOGGED_IN:-1}" = 1 ] || exit 1; fi
exit 0
STUB
  make_stub gh <<'STUB'
printf 'gh %s\n' "$*" >>"$FAKE_LOG"
if [ "$1 ${2:-}" = "auth status" ]; then [ "${FAKE_GH_LOGGED_IN:-1}" = 1 ] || exit 1; fi
exit 0
STUB
  # Claude Code: market-installed y plugin-installed ya están; engineering llega sincronizado de claude.ai.
  export FAKE_CLAUDE_MARKETPLACES="market-installed"
  export FAKE_CLAUDE_PLUGINS="plugin-installed@market-installed"
  make_stub claude <<'STUB'
printf 'claude %s\n' "$*" >>"$FAKE_LOG"
# Como el Claude Code real, se cae si recibe una entrada que puede leer (ver modules/claude.sh).
if [ "${FAKE_CLAUDE_STRICT_STDIN:-0}" = 1 ] && [ -s /dev/stdin ]; then echo "claude: entrada inesperada" >&2; exit 1; fi
case "$*" in
  "plugin list --json")
    printf '[{"id":"engineering@synced","scope":"synced","enabled":true}'
    for id in $FAKE_CLAUDE_PLUGINS; do printf ',{"id":"%s","scope":"user","enabled":true}' "$id"; done
    printf ']\n'
    ;;
  "auth status") [ "${FAKE_CLAUDE_LOGGED_IN:-1}" = 1 ] || exit 1 ;;
  "plugin marketplace list --json")
    printf '['; sep=""
    for name in $FAKE_CLAUDE_MARKETPLACES; do printf '%s{"name":"%s","source":"github"}' "$sep" "$name"; sep=","; done
    printf ']\n'
    ;;
  --version) echo "2.1.300 (Claude Code)" ;;
esac
exit 0
STUB
  make_stub testigo <<'STUB'
printf 'testigo %s\n' "$*" >>"$FAKE_LOG"
exit 0
STUB
  # Red de seguridad: ningún test descarga nada. Con FAKE_INSTALLER_SCRIPT, curl "descarga" ese archivo en
  # la ruta de -o; sin él, falla como sin conexión.
  make_stub curl <<'STUB'
printf 'curl %s\n' "$*" >>"$FAKE_LOG"
if [ -z "${FAKE_INSTALLER_SCRIPT:-}" ]; then echo "curl: (6) Could not resolve host" >&2; exit 6; fi
out=""
while [ $# -gt 0 ]; do
  [ "$1" != -o ] || out="$2"
  shift
done
cp "$FAKE_INSTALLER_SCRIPT" "$out"
STUB
  make_fake_agent_skills "$DEV_SETUP_AGENT_SKILLS_DIR"
  make_stub tool-external-bin <<'STUB'
exit 0
STUB
  mkdir -p "$HOME/Applications/App External.app"
}

# make_fake_agent_skills <carpeta>: un clon falso de agent-skills cuyo install.sh enlaza hb-fake.
make_fake_agent_skills() {
  mkdir -p "$1/.git" "$1/skills/hb-fake"
  printf -- '---\nname: hb-fake\n---\n' >"$1/skills/hb-fake/SKILL.md"
  cat >"$1/install.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")" && pwd -P)"
printf 'agent-skills install.sh\n' >>"$FAKE_LOG"
mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
ln -sfn "$repo/skills/hb-fake" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/hb-fake"
SCRIPT
  chmod +x "$1/install.sh"
}

# make_stub <nombre>: crea un comando falso en $STUBS con el cuerpo que llega por stdin.
make_stub() {
  { printf '#!/usr/bin/env bash\n'; cat; } >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}

# Carga las librerías y módulos para probar sus funciones directamente.
load_libs() {
  DEV_SETUP_ROOT="$REPO_ROOT"
  local lib
  for lib in log run prompt fs config shell steps; do
    # shellcheck source=/dev/null
    . "$REPO_ROOT/lib/$lib.sh"
  done
  local module
  for module in base android studio agents claude node ios accounts repos; do
    # shellcheck source=/dev/null
    . "$REPO_ROOT/modules/$module.sh"
  done
}
