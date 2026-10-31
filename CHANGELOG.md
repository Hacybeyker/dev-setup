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

[Unreleased]: https://github.com/Hacybeyker/dev-setup/commits/main
