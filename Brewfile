# Herramientas que instala dev-setup con Homebrew. También funciona con `brew bundle`.
#
# dev-setup lee este archivo línea por línea y nunca instala lo que ya exista fuera de Homebrew.
# Cada entrada indica cómo detectarlo:
#   # bin: <comando>   instalado si el comando está en el PATH
#   # app: <App.app>   instalado si la app está en /Applications o ~/Applications
#   # jdk: <versión>   instalado si /usr/libexec/java_home encuentra un JDK de esa versión
# Lo que se elige instalar se condiciona con su variable DEV_SETUP_<GRUPO> de local.env. El valor por
# defecto de cada ENV.fetch es el mismo que usa dev-setup cuando no se eligió (group_default).

# Siempre: lo usan dev-setup y sus módulos
brew "jq"                 # bin: jq

# Grupo github
brew "gh" if ENV.fetch("DEV_SETUP_GITHUB", "1") == "1"  # bin: gh

# Grupo ide
# JDK 21 para la terminal: corre Gradle 8.5 en adelante. Cada proyecto fija el suyo con toolchains.
cask "temurin@21" if ENV.fetch("DEV_SETUP_IDE", "1") == "1"  # jdk: 21
# Android Studio y los demás IDEs de JetBrains se instalan desde Toolbox.
cask "jetbrains-toolbox" if ENV.fetch("DEV_SETUP_IDE", "1") == "1"  # app: JetBrains Toolbox.app

# Grupo dev-tools: para contribuir a dev-setup
brew "shellcheck" if ENV.fetch("DEV_SETUP_DEV_TOOLS", "0") == "1"  # bin: shellcheck
brew "bats-core" if ENV.fetch("DEV_SETUP_DEV_TOOLS", "0") == "1"  # bin: bats

# Grupo ai-local
cask "lm-studio" if ENV.fetch("DEV_SETUP_AI_LOCAL", "0") == "1"  # app: LM Studio.app

# Grupo terminal
cask "warp" if ENV.fetch("DEV_SETUP_TERMINAL", "0") == "1"  # app: Warp.app

# Grupo node (nvm y Node.js los instala el módulo node con el instalador oficial de nvm)
brew "pnpm" if ENV.fetch("DEV_SETUP_NODE", "0") == "1"  # bin: pnpm
