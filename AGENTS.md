# dev-setup

CLI que instala, diagnostica y actualiza el entorno de desarrollo en macOS (Apple silicon): Android y KMP, Android CLI y agentes de IA. El repo es público: cualquiera puede usarlo.

## Stack

- Perfil: ninguno. No es una app: es un CLI en Bash compatible con el Bash 3.2 de macOS (`#!/usr/bin/env bash`, `set -euo pipefail`).
- Homebrew (`Brewfile`) para herramientas y apps. Android Studio y los IDEs de JetBrains se instalan desde JetBrains Toolbox.
- Tests con `bats-core`. CI con GitHub Actions (`.github/workflows/validate.yml`) y Dependabot para las actions.

## Comandos

| Para | Comando |
| --- | --- |
| Diagnosticar la máquina (solo lectura) | `dev-setup doctor` |
| Ver qué haría, sin tocar nada | `dev-setup bootstrap --dry-run` |
| Instalar lo que falta | `dev-setup bootstrap` |
| Actualizar lo que gestiona dev-setup | `dev-setup update` |
| Elegir grupos opcionales | `--with <grupo>` / `--without <grupo>` |
| Analizar los scripts | `git ls-files -z '*.sh' 'bin/*' \| xargs -0 shellcheck` (`brew install shellcheck`) |
| Correr los tests | `bats tests` (`brew install bats-core`) |

## DoD

Antes de dar una tarea por terminada:

1. `git ls-files -z '*.sh' 'bin/*' | xargs -0 shellcheck` sin advertencias.
2. `bats tests` en verde. Todo comportamiento nuevo llega con su test, que corre en un `HOME` temporal.
3. Correr dos veces seguidas el comando modificado: la segunda vez no debe cambiar nada.

## Arquitectura

- `install.sh`: entrada remota para una Mac sin `git`, fijada a un tag (`curl -fsSL https://raw.githubusercontent.com/Hacybeyker/dev-setup/vX.Y.Z/install.sh | bash`). Instala las Command Line Tools, clona el repo en `~/Claude/dev-setup` en el tag de `DEV_SETUP_REF` y corre `dev-setup bootstrap` leyendo de `/dev/tty`; Homebrew y el enlace en `~/.local/bin` los pone el módulo base. Es autónomo: no usa `lib/`. Opciones: `DEV_SETUP_DIR`, `DEV_SETUP_REF` y `DEV_SETUP_REPO_URL`.
- `bin/dev-setup`: el CLI. Subcomandos `doctor`, `bootstrap` y `update`, con las banderas `--dry-run`, `--yes`, `--with` y `--without`. Códigos de salida: 0 bien, 1 error, 2 uso incorrecto.
- `lib/`: utilidades compartidas. `log.sh` (mensajes y log), `run.sh` (`run_cmd`), `prompt.sh` (preguntas, leídas de `/dev/tty`), `fs.sh` (`backup_file` y `ensure_block`), `config.sh` (`local.env`), `shell.sh` (el bloque de `~/.zshrc`) y `steps.sh` (`next_step`: lo que le toca al usuario, que se muestra al final de `bootstrap` y `update`). **Todo cambio en la máquina pasa por `run_cmd`**, que respeta `--dry-run` y lo registra en el log.
- `modules/<área>.sh`: un módulo por área (system, base, android, studio, agents, claude, node, ios, accounts, repos), registrado en `DEV_SETUP_MODULES` de `bin/dev-setup`. Cada uno define las funciones que necesite: `<módulo>_doctor`, `<módulo>_install`, `<módulo>_update` `<módulo>_shell` (líneas para el bloque de `~/.zshrc`, que deben respetar lo que el usuario ya tenga definido) y `<módulo>_next_steps` (pasos manuales pendientes, con `next_step`).
- Los datos van separados del código: `Brewfile` y listas de texto (paquetes del SDK, skills oficiales de Android, plugins de Claude Code). Agregar una herramienta es editar una lista, no un script.
- Android: `android/sdk-packages.txt` y `android/skills.txt`. Las skills oficiales se instalan para los agentes de `DEV_SETUP_ANDROID_SKILL_AGENTS` en `local.env` (por defecto `claude-code`) y se revisan por agente con `android skills list --agent=<agente>`. `android-studio` se omite con un aviso: Android Studio ya las trae en `~/.android-studio/skills`. `common` (`~/.agents/skills`, que Android Studio también lee) se acepta solo para agentes sin nombre propio. Un agente que el CLI no reconoce (`skills list` sale con 1) se salta con un aviso y queda como paso pendiente: nunca detiene `bootstrap` ni `update`. Nunca se usa `android init`, que instala su skill en todos los agentes que detecta.
- Claude Code: `claude/plugins.txt`, `claude/marketplaces.txt` (una tercera columna opcional ata la entrada a un grupo) y `claude/settings.json`, que se fusiona con `~/.claude/settings.json` con `jq`: lo existente gana, se agregan las claves que faltan y las listas se unen. Las carpetas de skills de `permissions.additionalDirectories` se calculan a partir de los enlaces de `~/.claude/skills` y `~/.agents/skills`. Todos los comandos de `claude` van con `</dev/null`: Claude Code se cae si su entrada es `/dev/tty`, que es como `install.sh` deja a `bootstrap`.
- Cada entrada del `Brewfile` lleva `# bin: <comando>`, `# app: <App.app>` o `# jdk: <versión>` para detectar si ya existe fuera de Homebrew; un test lo exige.
- Lo propio de cada máquina no se versiona: `local.env` (grupos elegidos y ajustes) y `repos.txt` (repos a clonar, que pueden ser privados). Los `.example` documentan su formato.
- Lo que mantiene otro repo se instala con su propio instalador, nunca se copia aquí: las skills propias con `install.sh` de [agent-skills](https://github.com/Hacybeyker/agent-skills) y `testigo` con `testigo setup`.
- Logs en `~/Library/Logs/dev-setup/`, uno por ejecución de `bootstrap` o `update` (nunca en `doctor` ni en `--dry-run`).
- `tests/*.bats` aíslan la máquina con un `HOME` temporal y las variables `DEV_SETUP_LOCAL_ENV`, `DEV_SETUP_NONINTERACTIVE`, `DEV_SETUP_SKIP_OS_CHECK`, `DEV_SETUP_BREWFILE`, `DEV_SETUP_HOMEBREW_PREFIX`, `DEV_SETUP_JAVA_HOME_CMD`, `DEV_SETUP_ANDROID_DATA`, `DEV_SETUP_CLAUDE_DATA`, `DEV_SETUP_AGENT_SKILLS_DIR`, `DEV_SETUP_AGENT_SKILLS_REPO`, `DEV_SETUP_REPOS`, `DEV_SETUP_RAM_GIB` y `DEV_SETUP_XCODE_APP`, que existen solo para los tests. Corren con un `PATH` mínimo y comandos falsos (`tests/test_helper.bash`): nunca llaman a `brew`, `android`, `claude`, `gh`, `testigo` ni `curl` reales. El CI los corre en Linux y en macOS con el Bash 3.2 del sistema. Los nombres de test van en ASCII, sin tildes: con el Bash 3.2 de macOS, bats no lee algunos caracteres (`tests/meta.bats` lo verifica).

## Base y grupos opcionales

- **Base:** Command Line Tools, Homebrew, `gh`, `jq`, `shellcheck`, `bats-core`, Temurin 21, JetBrains Toolbox, Android CLI con el SDK, Claude Code.
- **Opcionales:** `ai-local` (LM Studio), `terminal` (Warp), `node` (nvm, Node.js LTS y pnpm), `ios` (revisa Xcode, sin instalar nada).
- La primera vez se pregunta por cada grupo y la respuesta se guarda en `local.env`. Sin terminal, los grupos sin elegir quedan desactivados: son opt-in. En el `Brewfile`, cada grupo opcional se condiciona con su variable `DEV_SETUP_<GRUPO>`.
- `local.env` nunca se ejecuta: se leen solo las líneas `CLAVE=valor` conocidas y válidas.

## Reglas del proyecto

**Proteger lo que ya existe** (regla principal):

- Detectar antes de instalar. Si una herramienta ya existe y funciona, se instaló como se haya instalado, no se reinstala, no se mueve ni se reemplaza: solo se reporta en `doctor`.
- Nada de `brew bundle` a ciegas: los elementos que ya existen fuera de Homebrew se saltan.
- Nunca: `--force`, `brew uninstall`, `brew bundle cleanup --force`, `android sdk remove`, ni borrar archivos.
- Si `JAVA_HOME`, `ANDROID_HOME` o `user.name`/`user.email` de git ya tienen valor válido, se respetan.
- Archivos de configuración: solo se agregan las claves que faltan, nunca se reemplazan. Antes de cualquier cambio hay un respaldo (`<archivo>.bak-<AAAAMMDD-HHMMSS>`), se muestra el diff y se pide confirmación (salvo `--yes`). En `~/.zshrc` se escribe un único bloque marcado (`# >>> dev-setup >>>`). Los JSON se combinan con `jq`.
- Android Studio solo desde Toolbox: nunca la cask `android-studio`. Los pasos que dependen del IDE se saltan con un aviso si no está instalado. Su memoria (`-Xmx`) solo se agrega si `studio.vmoptions` no tiene una.
- Node.js: si ya existe, o lo gestiona otra herramienta (fnm, volta, mise, asdf), no se instala nvm. nvm se instala fijado a una versión y con `PROFILE=/dev/null`, para que no toque `~/.zshrc`; `update` nunca cambia la versión de Node.js ni baja la de nvm.
- Sin `sudo`: si un paso lo necesita (por ejemplo, `xcode-select -s`), se muestra el comando para que lo corra el usuario.
- No se toca `~/.gradle/gradle.properties`: pisa la configuración de cada proyecto, que es la que también corre en el CI.
- `repos.txt`: solo se clonan los repos que faltan. Nunca se hace pull ni se toca una carpeta que ya existe.
- Sesiones: dev-setup nunca inicia sesión. Revisa con `gh auth status`, `claude auth status` y `android auth status`; los pasos pendientes listan solo los logins necesarios (gh y Claude Code), y la sesión opcional del Android CLI aparece solo en `doctor`.

**Código:**

- Idempotencia: cada paso verifica el estado antes de actuar.
- Compatible con el Bash 3.2 de macOS: sin arrays asociativos, `mapfile` ni `${var,,}`, porque `install.sh` corre antes de que exista Homebrew.
- Rutas con `$HOME`, nunca rutas absolutas de un usuario.
- Estilo de la guía de shell de Google: sangría de 2 espacios, funciones en `snake_case` y variables entre comillas.
- La interfaz de `agent-skills/install.sh` es un contrato que protege el CI de ese repo: si hace falta cambiarla, se coordina allá.

## Git

- Commits: Conventional Commits, en español, sin emoji. El módulo va como scope (`feat(android): ...`).
- Rama principal: `main`, protegida. Se trabaja en ramas cortas `<tipo>/<descripción>` y se integra por PR con squash.
- La IA commitea solo cuando se le pide y nunca agrega atribución de IA.
- Pide aprobación antes de `git push`, de crear un release y de publicar.

## Versionado y release

- SemVer con tags `vX.Y.Z` y `CHANGELOG.md` según Keep a Changelog. Cada cambio agrega su entrada en `[Unreleased]`.
- El comando de instalación remota del README y `DEV_SETUP_REF` de `install.sh` apuntan siempre al último tag publicado (`tests/meta.bats` lo verifica).
- Release: un PR `chore(release): vX.Y.Z` que pasa `[Unreleased]` a la nueva versión del CHANGELOG y fija el tag en el README y en `install.sh`. Al mergearlo, tag anotado sobre ese commit y release de GitHub con las notas de esa versión.

## Seguridad

- El repo es público: nada de secretos, tokens, datos personales ni de trabajo.
- Las autenticaciones (`gh`, Claude Code, Android CLI) son siempre interactivas: ningún script guarda credenciales.
- Los secretos de los proyectos (keystores, `google-services.json`) no los gestiona dev-setup: se restauran desde un gestor de contraseñas.
- Los instaladores remotos se descargan solo de fuentes oficiales y por HTTPS.
