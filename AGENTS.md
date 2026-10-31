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

- `install.sh`: entrada remota para una Mac sin `git`, fijada a un tag (`curl -fsSL https://raw.githubusercontent.com/Hacybeyker/dev-setup/vX.Y.Z/install.sh | bash`). Instala Command Line Tools y Homebrew, clona el repo en `~/Claude/dev-setup`, enlaza `bin/dev-setup` en `~/.local/bin` y corre `dev-setup bootstrap`.
- `bin/dev-setup`: el CLI. Subcomandos `doctor`, `bootstrap` y `update`, con las banderas `--dry-run`, `--yes`, `--with` y `--without`. Códigos de salida: 0 bien, 1 error, 2 uso incorrecto.
- `lib/`: utilidades compartidas. `log.sh` (mensajes y log), `run.sh` (`run_cmd`), `prompt.sh` (preguntas, leídas de `/dev/tty`), `fs.sh` (`backup_file` y `ensure_block`) y `config.sh` (`local.env`). **Todo cambio en la máquina pasa por `run_cmd`**, que respeta `--dry-run` y lo registra en el log.
- `modules/<área>.sh`: un módulo por área (system, base, android, agents, claude, gradle, studio y grupos opcionales), registrado en `DEV_SETUP_MODULES` de `bin/dev-setup`. Cada uno define las funciones que necesite: `<módulo>_doctor`, `<módulo>_install` y `<módulo>_update`.
- Los datos van separados del código: `Brewfile` y listas de texto (paquetes del SDK, skills oficiales de Android, plugins de Claude Code). Agregar una herramienta es editar una lista, no un script.
- Lo propio de cada máquina no se versiona: `local.env` (grupos elegidos y ajustes) y `repos.txt` (repos a clonar, que pueden ser privados). Los `.example` documentan su formato.
- Lo que mantiene otro repo se instala con su propio instalador, nunca se copia aquí: las skills propias con `install.sh` de [agent-skills](https://github.com/Hacybeyker/agent-skills) y `testigo` con `testigo setup`.
- Logs en `~/Library/Logs/dev-setup/`, uno por ejecución de `bootstrap` o `update` (nunca en `doctor` ni en `--dry-run`).
- `tests/*.bats` aíslan la máquina con un `HOME` temporal y las variables `DEV_SETUP_LOCAL_ENV`, `DEV_SETUP_NONINTERACTIVE` y `DEV_SETUP_SKIP_OS_CHECK`, que existen solo para los tests. El CI los corre en Linux y en macOS con el Bash 3.2 del sistema. Los nombres de test van en ASCII, sin tildes: con el Bash 3.2 de macOS, bats no lee algunos caracteres (`tests/meta.bats` lo verifica).

## Base y grupos opcionales

- **Base:** Command Line Tools, Homebrew, `gh`, `jq`, `shellcheck`, `bats-core`, Temurin LTS, JetBrains Toolbox, Android CLI con el SDK, Claude Code.
- **Opcionales:** `ai-local` (LM Studio), `terminal` (Warp), `node` (nvm y pnpm), `ios` (aviso para instalar Xcode).
- La primera vez se pregunta por cada grupo y la respuesta se guarda en `local.env`. Sin terminal, los grupos sin elegir quedan desactivados: son opt-in. En el `Brewfile`, cada grupo opcional se condiciona con su variable `DEV_SETUP_<GRUPO>`.
- `local.env` nunca se ejecuta: se leen solo las líneas `CLAVE=valor` conocidas y válidas.

## Reglas del proyecto

**Proteger lo que ya existe** (regla principal):

- Detectar antes de instalar. Si una herramienta ya existe y funciona, se instaló como se haya instalado, no se reinstala, no se mueve ni se reemplaza: solo se reporta en `doctor`.
- Nada de `brew bundle` a ciegas: los elementos que ya existen fuera de Homebrew se saltan.
- Nunca: `--force`, `brew uninstall`, `brew bundle cleanup --force`, `android sdk remove`, ni borrar archivos.
- Si `JAVA_HOME`, `ANDROID_HOME` o `user.name`/`user.email` de git ya tienen valor válido, se respetan.
- Archivos de configuración: solo se agregan las claves que faltan, nunca se reemplazan. Antes de cualquier cambio hay un respaldo (`<archivo>.bak-<AAAAMMDD-HHMMSS>`), se muestra el diff y se pide confirmación (salvo `--yes`). En `~/.zshrc` se escribe un único bloque marcado (`# >>> dev-setup >>>`). Los JSON se combinan con `jq`.
- Android Studio solo desde Toolbox: nunca la cask `android-studio`. Los pasos que dependen del IDE se saltan con un aviso si no está instalado.

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
- El comando de instalación remota del README apunta siempre al último tag publicado.

## Seguridad

- El repo es público: nada de secretos, tokens, datos personales ni de trabajo.
- Las autenticaciones (`gh`, Claude Code, Android CLI) son siempre interactivas: ningún script guarda credenciales.
- Los secretos de los proyectos (keystores, `google-services.json`) no los gestiona dev-setup: se restauran desde un gestor de contraseñas.
- Los instaladores remotos se descargan solo de fuentes oficiales y por HTTPS.
