# dev-setup

[![Validate](https://github.com/Hacybeyker/dev-setup/actions/workflows/validate.yml/badge.svg)](https://github.com/Hacybeyker/dev-setup/actions/workflows/validate.yml)

CLI que instala, diagnostica y actualiza un entorno de desarrollo **Android y Kotlin Multiplatform** con **agentes de IA** en macOS (Apple silicon).

## Cómo se usa

### En una Mac nueva

Una Mac limpia no tiene `git`, así que el arranque es un solo comando que descarga el instalador de una versión probada:

```bash
curl -fsSL https://raw.githubusercontent.com/Hacybeyker/dev-setup/v1.3.0/install.sh | bash
```

Instala las Command Line Tools (traen `git`), clona este repo en `~/Claude/dev-setup` en la versión del instalador y corre `dev-setup bootstrap`. Primero te pregunta qué instalar (Enter acepta lo propuesto); después instala Homebrew y lo que elegiste y deja el comando `dev-setup` en `~/.local/bin`. Tarda entre 30 y 60 minutos, casi todo en descargas. Al final muestra:

- **Resumen:** qué se instaló, actualizó o configuró, qué ya estaba y se respetó, qué omitiste, qué falló y por qué, y qué archivo del shell cambió un instalador externo.
- **Para verificar:** los comandos (`android -V`, `adb version`, `claude --version`…) para comprobarlo en una terminal nueva.
- **Lo que te toca:** los logins y demás pasos que dependen de ti.

Para elegir desde el inicio, pásalo al final: `... | bash -s -- --with node --without claude`. Para clonar en otra carpeta: `... | DEV_SETUP_DIR=~/otra/carpeta bash`. Si la carpeta ya es un clon de dev-setup, la usa tal como está; si es otra cosa, no la toca.

### En una Mac que ya tiene cosas instaladas

```bash
dev-setup doctor               # qué hay, cómo se instaló, qué falta y qué choca (no toca nada)
dev-setup bootstrap --dry-run  # lo que haría, sin hacerlo
dev-setup bootstrap            # instala solo lo que falta
```

Todas las opciones: `dev-setup --help`. Con `-y` acepta las confirmaciones sin preguntar.

### Día a día

```bash
dev-setup update   # Homebrew, Android CLI, SDK, skills, trace_processor, plugins de Claude Code, nvm y los repos que falten
```

### Pasar a una versión nueva de dev-setup

`dev-setup update` actualiza tus herramientas, no dev-setup. El instalador deja el clon fijo en la versión que instalaste, y `doctor`, `bootstrap` y `update` te avisan cuando sale una nueva, con los comandos exactos para pasar a ella. Sin conexión no dicen nada. Para pasar a otra versión (están en [Releases](https://github.com/Hacybeyker/dev-setup/releases)), cambia el clon a su tag:

```bash
git -C ~/Claude/dev-setup fetch --tags
git -C ~/Claude/dev-setup checkout vX.Y.Z
```

Usa la carpeta de `DEV_SETUP_DIR` si elegiste otra. Tu `local.env` y tu `repos.txt` no cambian: no se versionan. Si clonaste dev-setup a mano en la rama `main`, basta con `git -C ~/Claude/dev-setup pull`.

## Qué instala

### Siempre

| Herramienta | Para qué | Cómo |
| --- | --- | --- |
| Command Line Tools de Xcode | `git` y compiladores | `xcode-select --install` |
| Homebrew | Gestor de paquetes | Instalador oficial |
| `jq` | JSON; lo usa dev-setup | `Brewfile` |
| Comando `dev-setup` y bloque del shell | Usar dev-setup y cargar el entorno en cada terminal | Enlace en `~/.local/bin` y bloque en el archivo de arranque del shell |

### Lo que eliges

`bootstrap` pregunta por cada grupo la primera vez. La elección se guarda en `local.env` y se cambia con `--with <grupo>` y `--without <grupo>`. Sin terminal para preguntar, cada grupo queda con su valor por defecto.

| Grupo | Por defecto | Qué instala |
| --- | --- | --- |
| `android` | sí | Android CLI y SDK (platform-tools, cmdline-tools, build-tools y la última plataforma estable; lista en `android/sdk-packages.txt`), las skills oficiales de Android para los agentes que elijas, la memoria de Android Studio y `trace_processor` de [Perfetto](https://perfetto.dev) (analizar trazas con SQL; lo usa la skill `hb-performance`), en `~/.local/bin` y sin root |
| `emulator` | sí | El emulador de Android y su imagen de sistema (Google Play, arm64, páginas de 16 KB): unos 3 GB. Solo se pregunta con `android` |
| `ide` | sí | Temurin 21 (LTS), el JDK para la terminal (`./gradlew`, Android CLI), y JetBrains Toolbox, para instalar Android Studio y los demás IDEs de JetBrains |
| `github` | sí | GitHub CLI (`gh`) |
| `skills` | sí | Las skills propias de [agent-skills](https://github.com/Hacybeyker/agent-skills) y [testigo](https://github.com/Hacybeyker/testigo), para pruebas E2E con evidencia sobre Maestro |
| `claude` | sí | Claude Code, con los plugins de `claude/plugins.txt` y su `settings.json` |
| `node` | no | nvm, Node.js LTS y pnpm. Si ya tienes Node.js o lo gestiona otra herramienta (fnm, volta, mise, asdf), no instala nvm |
| `ios` | no | Nada: revisa Xcode para el target iOS de KMP y te dice qué falta |
| `ai-local` | no | LM Studio, para modelos locales |
| `terminal` | no | Warp |
| `dev-tools` | no | `shellcheck` y `bats-core`, para contribuir a dev-setup |

Si el instalador oficial de una herramienta falla (por ejemplo, porque la red de tu empresa bloquea su servidor), dev-setup sigue con lo demás, te dice el motivo en el resumen y, para Claude Code, te ofrece probar con Homebrew.

## Qué configura

- **Skills de agentes:** las propias, con el `install.sh` de [agent-skills](https://github.com/Hacybeyker/agent-skills), quedan enlazadas en `~/.claude/skills` (Claude Code) y `~/.agents/skills` (Copilot, Junie, Codex y Gemini en Android Studio). Las oficiales de Android seleccionadas (`android/skills.txt`) se instalan con `android skills add` para los agentes que elijas: `bootstrap` te propone los que encuentra en la máquina (`claude-code`, `github-copilot`, `junie`, `codex`, `gemini`, `cursor`, `opencode`) y lo guarda en `DEV_SETUP_ANDROID_SKILL_AGENTS`. Nunca para Android Studio, que ya las trae todas; un agente mal escrito se salta con un aviso. testigo se prepara con `testigo setup`.
- **Claude Code:** `~/.claude/settings.json` sin atribución de IA en commits ni PRs, y con permiso para leer las carpetas de skills. Solo agrega lo que falta: tus claves y valores se quedan como están. Si Claude Code no está instalado, no lo toca.
- **agent-skills:** lo clona junto a dev-setup (por ejemplo `~/Claude/agent-skills`) y corre su `install.sh`. Si la carpeta ya existe y no es un clon, no la toca.
- **Android Studio:** memoria del IDE (`-Xmx` en `studio.vmoptions`) según la RAM: 4 GB con menos de 32 GB, 6 GB desde 32 GB y 8 GB desde 64 GB, o el valor de `DEV_SETUP_STUDIO_XMX` en `local.env`. Si ya tiene uno (por ejemplo, puesto desde *Settings → Memory Settings*), lo respeta. Hace falta haber abierto Android Studio una vez.
- **Shell:** un único bloque marcado `# >>> dev-setup >>>` en `~/.zshrc` (o `$ZDOTDIR/.zshrc`) con zsh, o en `~/.bash_profile` con bash, con `~/.local/bin` en el `PATH`, Homebrew, `JAVA_HOME`, `ANDROID_HOME`, las herramientas del SDK (`adb`, `emulator`, cada una por separado) y nvm si el grupo `node` está activo. Cada línea respeta lo que ya tengas definido.
- **Repos (opcional):** clona los repos de `repos.txt` que falten. Nunca hace pull ni toca una carpeta que ya existe: tus repos pueden tener trabajo en curso.

## Qué no hace, y por qué

| No hace | Por qué | Qué hacer |
| --- | --- | --- |
| Instalar Android Studio | Se gestiona desde JetBrains Toolbox junto con los demás IDEs; dos vías de instalación se pisan | Instalarlo desde Toolbox mientras corre `bootstrap` |
| Iniciar sesión en nada | Las credenciales nunca pasan por un script | Al final, `bootstrap` y `update` te listan solo los logins pendientes: `gh auth login` y `claude auth login`. `doctor` muestra el estado de cada sesión, incluida la opcional del Android CLI (`android auth login`) |
| Aceptar las licencias del SDK | Las aceptas tú | Se muestran durante `bootstrap` |
| Restaurar secretos (keystores, `google-services.json`, tokens) | No van en un repo público | Desde tu gestor de contraseñas |
| Gestionar lo que sincroniza tu cuenta de claude.ai (skills y plugins de Anthropic) | Llega desde tu cuenta, no desde esta máquina | Para no cargarlo en Claude Code: `"syncClaudeAiSkills": false` o `"syncClaudeAiPlugins": false` en `~/.claude/settings.json` |
| Instalar Xcode | Pide Apple ID y pesa unos 15 GB | Desde la App Store; con el grupo `ios`, `doctor` te dice qué falta |
| Configurar Gradle en `~/.gradle/gradle.properties` | Ese archivo pisa el `gradle.properties` de cada proyecto y no existe en el CI: el mismo repo compilaría distinto en cada lado | La memoria, la caché y el configuration cache van en el `gradle.properties` de cada repo |
| Cambiar tu versión de Node.js | Cada proyecto decide la suya | `nvm install --lts` cuando lo decidas |
| Dar permisos de macOS (accesibilidad y similares) | Solo se dan desde Ajustes del Sistema | Ajustes del Sistema |
| Configurar proyectos (dependencias, lint, tests, R8) | Viaja en cada repo, para que compile igual en cualquier máquina y en CI | Usar las plantillas de proyecto |

## Qué garantiza

dev-setup **no rompe lo que ya funciona**:

- Si algo ya está instalado, se haya instalado como se haya instalado, no lo reinstala, no lo mueve ni lo reemplaza: solo lo reporta. Antes de instalar cada herramienta del `Brewfile` busca el comando en el `PATH`, la app en `/Applications` o el JDK.
- `update` solo actualiza lo que dev-setup gestiona: lo que Homebrew instaló del `Brewfile`, el Android CLI, los paquetes del SDK de `android/sdk-packages.txt`, las skills de `android/skills.txt` (para los agentes donde ya están), el `trace_processor` que instaló dev-setup y nvm, si lo instaló su instalador y es más antiguo (nunca baja de versión). Lo instalado de otra forma se actualiza por su cuenta.
- Si una skill que trae Android Studio también está copiada en `~/.agents/skills` (suele dejarla `android init`), `doctor` avisa que Android Studio la ve dos veces, si esa copia está desactualizada y cómo quitarla. No la borra: `~/.agents/skills` también lo leen otros agentes.
- Nunca desinstala, nunca borra archivos, nunca usa `--force` y nunca llama a `sudo`: si algo lo necesita, te dice el comando.
- Respeta tus valores de `JAVA_HOME`, `ANDROID_HOME` y `git config`.
- En los archivos de configuración solo agrega lo que falta: antes hace un respaldo con fecha, te muestra el diff y te pide confirmación.
- Todo lo que hace queda en `~/Library/Logs/dev-setup/`.

## Configuración por máquina

No se versiona (está en `.gitignore`):

- `local.env`: lo que elegiste instalar y ajustes propios de la máquina. Formato en `local.env.example`.
- `repos.txt`: repos que se clonan, que pueden ser privados. Formato en `repos.txt.example`.

## Desarrollo

Reglas, arquitectura y DoD en [AGENTS.md](AGENTS.md). Historial de cambios en [CHANGELOG.md](CHANGELOG.md).

## Licencia

[MIT](LICENSE)
