# dev-setup

[![Validate](https://github.com/Hacybeyker/dev-setup/actions/workflows/validate.yml/badge.svg)](https://github.com/Hacybeyker/dev-setup/actions/workflows/validate.yml)

CLI que instala, diagnostica y actualiza un entorno de desarrollo **Android y Kotlin Multiplatform** con **agentes de IA** en macOS (Apple silicon).

> **En construcción.** Todavía no hay una versión publicada: este README describe el alcance de `v1.0.0`.

## Cómo se usa

### En una Mac nueva

Una Mac limpia no tiene `git`, así que el arranque es un solo comando que descarga el instalador de una versión probada:

```bash
curl -fsSL https://raw.githubusercontent.com/Hacybeyker/dev-setup/vX.Y.Z/install.sh | bash
```

Instala Command Line Tools y Homebrew, clona este repo en `~/Claude/dev-setup`, deja el comando `dev-setup` en `~/.local/bin` y corre `dev-setup bootstrap`. Tarda entre 30 y 60 minutos, casi todo en descargas.

### En una Mac que ya tiene cosas instaladas

```bash
dev-setup doctor               # qué hay, cómo se instaló, qué falta y qué choca (no toca nada)
dev-setup bootstrap --dry-run  # lo que haría, sin hacerlo
dev-setup bootstrap            # instala solo lo que falta
```

Todas las opciones: `dev-setup --help`. Con `-y` acepta las confirmaciones sin preguntar.

### Día a día

```bash
dev-setup update   # Homebrew, Android CLI, SDK, skills, repos y plugins de Claude Code
```

## Qué instala

### Base (siempre)

| Herramienta | Para qué | Cómo |
| --- | --- | --- |
| Command Line Tools de Xcode | `git` y compiladores | `xcode-select --install` |
| Homebrew | Gestor de paquetes | Instalador oficial |
| `gh`, `jq`, `shellcheck`, `bats-core` | GitHub, JSON, análisis y tests de shell | `Brewfile` |
| Temurin 21 (LTS) | JDK para la terminal (`./gradlew`, Android CLI). Corre Gradle 8.5 en adelante; cada proyecto fija el suyo con toolchains | `Brewfile` |
| JetBrains Toolbox | Instalar Android Studio y los demás IDEs de JetBrains | `Brewfile` |
| Android CLI y SDK | Compilar y emular: platform-tools, emulator, cmdline-tools, build-tools, la última plataforma estable y su imagen de emulador (lista en `android/sdk-packages.txt`) | Instalador oficial y `android sdk install` |
| Claude Code | Agente de IA en la terminal | Instalador oficial |

### Opcionales (se eligen la primera vez)

| Grupo | Qué instala |
| --- | --- |
| `ai-local` | LM Studio, para modelos locales |
| `terminal` | Warp |
| `node` | nvm, Node.js LTS y pnpm |
| `ios` | Nada: avisa cómo instalar Xcode para el target iOS de KMP |

La elección se guarda en `local.env` y se puede cambiar con `--with <grupo>` y `--without <grupo>`.

## Qué configura

- **Skills de agentes:** las propias con el `install.sh` de [agent-skills](https://github.com/Hacybeyker/agent-skills), las oficiales de Android seleccionadas (`android/skills.txt`) con `android skills add`, solo para Claude Code porque Android Studio ya las trae todas, y [testigo](https://github.com/Hacybeyker/testigo) con `testigo setup`.
- **Claude Code:** `~/.claude/settings.json` (sin atribución de IA en commits ni PRs) y sus plugins.
- **Gradle:** `~/.gradle/gradle.properties` con memoria y caché según la máquina.
- **Android Studio:** memoria del IDE, si ya está instalado.
- **Shell:** un único bloque marcado `# >>> dev-setup >>>` en `~/.zshrc` (o `$ZDOTDIR/.zshrc`) con `~/.local/bin` en el `PATH`, Homebrew, `JAVA_HOME`, `ANDROID_HOME` y las herramientas del SDK (`adb`, `emulator`). Cada línea respeta lo que ya tengas definido.
- **Repos (opcional):** clona tus proyectos desde `repos.txt`.

## Qué no hace, y por qué

| No hace | Por qué | Qué hacer |
| --- | --- | --- |
| Instalar Android Studio | Se gestiona desde JetBrains Toolbox junto con los demás IDEs; dos vías de instalación se pisan | Instalarlo desde Toolbox mientras corre `bootstrap` |
| Iniciar sesión en nada | Las credenciales nunca pasan por un script | Al final, `dev-setup` te pide cada login: `gh auth login`, Claude Code y `android auth login` |
| Aceptar las licencias del SDK | Las aceptas tú | Se muestran durante `bootstrap` |
| Restaurar secretos (keystores, `google-services.json`, tokens) | No van en un repo público | Desde tu gestor de contraseñas |
| Instalar Xcode | Pide Apple ID y pesa unos 15 GB | Desde la App Store |
| Dar permisos de macOS (accesibilidad y similares) | Solo se dan desde Ajustes del Sistema | Ajustes del Sistema |
| Configurar proyectos (dependencias, lint, tests, R8) | Viaja en cada repo, para que compile igual en cualquier máquina y en CI | Usar las plantillas de proyecto |

## Qué garantiza

dev-setup **no rompe lo que ya funciona**:

- Si algo ya está instalado, se haya instalado como se haya instalado, no lo reinstala, no lo mueve ni lo reemplaza: solo lo reporta. Antes de instalar cada herramienta del `Brewfile` busca el comando en el `PATH`, la app en `/Applications` o el JDK.
- `update` solo actualiza lo que dev-setup gestiona: lo que Homebrew instaló del `Brewfile`, el Android CLI, los paquetes del SDK de `android/sdk-packages.txt` y las skills de `android/skills.txt`. Lo instalado de otra forma se actualiza por su cuenta.
- Si una skill está copiada en `~/.agents/skills` y también en `~/.android-studio/skills`, `doctor` avisa que Android Studio la ve dos veces y te dice cómo quitar la copia; no la borra.
- Nunca desinstala, nunca borra archivos y nunca usa `--force`.
- Respeta tus valores de `JAVA_HOME`, `ANDROID_HOME` y `git config`.
- En los archivos de configuración solo agrega lo que falta: antes hace un respaldo con fecha, te muestra el diff y te pide confirmación.
- Todo lo que hace queda en `~/Library/Logs/dev-setup/`.

## Configuración por máquina

No se versiona (está en `.gitignore`):

- `local.env`: grupos elegidos y ajustes propios de la máquina. Formato en `local.env.example`.
- `repos.txt`: repos que se clonan, que pueden ser privados. Formato en `repos.txt.example`.

## Desarrollo

Reglas, arquitectura y DoD en [AGENTS.md](AGENTS.md). Historial de cambios en [CHANGELOG.md](CHANGELOG.md).

## Licencia

[MIT](LICENSE)
