# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto sigue [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

### Added

- Estructura base del repo: reglas para agentes (`AGENTS.md`), CI con `shellcheck`, Dependabot, `.editorconfig` y `.gitignore`.
- README con el alcance de `v1.0.0`: qué instala, qué configura, qué no hace y qué garantiza.
- CLI `dev-setup` con los subcomandos `doctor`, `bootstrap` y `update` y las opciones `--dry-run`, `--yes`, `--with` y `--without`. Todavía sin módulos de instalación.
- Grupos opcionales (`ai-local`, `terminal`, `node`, `ios`) guardados en `local.env`, que se lee sin ejecutarse.
- Cambios seguros en archivos: respaldo con fecha, diff, confirmación y bloque administrado.
- Tests con bats-core y CI en macOS con el Bash 3.2 del sistema.
- Módulo base: Command Line Tools, Homebrew, el comando `dev-setup` en `~/.local/bin` y las herramientas del `Brewfile` (gh, jq, shellcheck, bats-core, Temurin 21, JetBrains Toolbox, y LM Studio y Warp en sus grupos). Lo que ya existe fuera de Homebrew se detecta y se respeta.
- Bloque administrado en `~/.zshrc` con `~/.local/bin` en el `PATH`, Homebrew y `JAVA_HOME`, que respeta lo que el usuario ya tenga definido.
- `update` actualiza solo lo que Homebrew gestiona del `Brewfile`.
- Módulo android: Android CLI (instalador oficial, sin sudo), paquetes del SDK de `android/sdk-packages.txt` y skills oficiales de `android/skills.txt` para Claude Code. Avisa de las skills que Android Studio vería dos veces.
- `ANDROID_HOME`, `adb` y `emulator` en el bloque de `~/.zshrc`, respetando lo ya definido.
- Módulo agents: clona agent-skills junto a dev-setup y corre su `install.sh`; instala testigo con su instalador oficial y `testigo setup`. `update` hace `git pull --ff-only` y solo actualiza testigo si lo instaló su instalador.
- Módulo claude: Claude Code (instalador oficial; si se instaló con Homebrew, `update` lo actualiza con `brew upgrade`), marketplaces y plugins de `claude/` en scope user, y fusión de `~/.claude/settings.json` que conserva lo existente.
- Módulo studio: memoria de Android Studio (`-Xmx`) según la RAM o `DEV_SETUP_STUDIO_XMX`, solo si `studio.vmoptions` no tiene una.
- Grupo node: nvm (fijado a v0.40.8, sin tocar el perfil), Node.js LTS y pnpm. Respeta Node.js ya instalado y otros gestores (fnm, volta, mise, asdf).
- Grupo ios: revisa Xcode y `xcode-select` y dice qué falta, sin correr `sudo`.
- `--dry-run` muestra los comandos como se escriben en la terminal.

[Unreleased]: https://github.com/Hacybeyker/dev-setup/commits/main
