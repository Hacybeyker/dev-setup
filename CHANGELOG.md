# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto sigue [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

### Fixed

- Instaladores oficiales (Homebrew, Android CLI, testigo, Claude Code y nvm): una descarga fallida ya no pasa por instalación exitosa. Se descargan a un archivo antes de correrlos; si algo falla, dev-setup lo avisa, lo deja en "Lo que te toca" y, salvo con Homebrew, sigue con lo demás.

## [1.1.0] - 2026-11-01

### Added

- Android: `DEV_SETUP_ANDROID_SKILL_AGENTS` en `local.env` elige para qué agentes se instalan las skills oficiales (por defecto, `claude-code`). `android-studio` se omite con un aviso y un agente que el CLI no reconoce se salta sin detener `bootstrap` ni `update`.

### Changed

- Android: `bootstrap`, `update` y `doctor` revisan cada skill oficial por agente con `android skills list --agent`, en vez de buscarla en `~/.claude/skills`.
- Claude Code: `claude/plugins.txt` explica para qué está cada plugin y cuáles se quitaron, quedan para cuando hagan falta o se descartaron.
- README: aclara que dev-setup no gestiona lo que sincroniza la cuenta de claude.ai y cómo dejar de cargarlo en Claude Code.

## [1.0.0] - 2026-10-31

Primera versión publicada.

### Added

- CLI `dev-setup` para macOS (Apple silicon) con `doctor` (solo lectura), `bootstrap` y `update`, y las opciones `--dry-run`, `--yes`, `--with` y `--without`. Compatible con el Bash 3.2 del sistema.
- `install.sh`: instalación en una Mac nueva con un solo comando (`curl ... | bash`). Instala las Command Line Tools, clona dev-setup en el tag publicado y corre `bootstrap`.
- Base: Homebrew y las herramientas del `Brewfile` (gh, jq, shellcheck, bats-core, Temurin 21 y JetBrains Toolbox). Lo instalado fuera de Homebrew se detecta y se respeta.
- Android: Android CLI, paquetes del SDK de `android/sdk-packages.txt`, skills oficiales de `android/skills.txt` para Claude Code y memoria de Android Studio según la RAM.
- Agentes: Claude Code con los plugins y marketplaces de `claude/`, `~/.claude/settings.json` sin atribución de IA (fusionado, conserva lo existente), agent-skills y testigo con sus propios instaladores.
- Grupos opcionales guardados en `local.env`: `ai-local` (LM Studio), `terminal` (Warp y su plugin para Claude Code), `node` (nvm, Node.js LTS y pnpm) e `ios` (revisión de Xcode).
- `repos.txt`: clona los repos propios que faltan, sin pull y sin tocar carpetas que ya existen.
- Bloque administrado en `~/.zshrc` (`PATH`, Homebrew, `JAVA_HOME`, `ANDROID_HOME`, herramientas del SDK y nvm) que respeta lo ya definido.
- "Lo que te toca" al final de `bootstrap` y `update` con los pasos manuales pendientes, y estado de las sesiones en `doctor`.
- Cambios seguros: nunca desinstala, borra, usa `--force` ni `sudo`. En los archivos de configuración solo agrega lo que falta, con respaldo, diff y confirmación. Todo queda en `~/Library/Logs/dev-setup/`.
- Tests con bats-core y CI en Linux y en macOS con el Bash 3.2 del sistema.

[Unreleased]: https://github.com/Hacybeyker/dev-setup/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/Hacybeyker/dev-setup/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Hacybeyker/dev-setup/releases/tag/v1.0.0
