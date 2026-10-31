# Herramientas que instala dev-setup con Homebrew. También funciona con `brew bundle`.
#
# dev-setup lee este archivo línea por línea y nunca instala lo que ya exista fuera de Homebrew.
# Cada entrada indica cómo detectarlo:
#   # bin: <comando>   instalado si el comando está en el PATH
#   # app: <App.app>   instalado si la app está en /Applications o ~/Applications
#   # jdk: <versión>   instalado si /usr/libexec/java_home encuentra un JDK de esa versión
# Los grupos opcionales se condicionan con su variable DEV_SETUP_<GRUPO> de local.env.

# Base
brew "gh"                 # bin: gh
brew "jq"                 # bin: jq
brew "shellcheck"         # bin: shellcheck
brew "bats-core"          # bin: bats
# JDK 21 para la terminal: corre Gradle 8.5 en adelante. Cada proyecto fija el suyo con toolchains.
cask "temurin@21"         # jdk: 21
# Android Studio y los demás IDEs de JetBrains se instalan desde Toolbox.
cask "jetbrains-toolbox"  # app: JetBrains Toolbox.app

# Grupo ai-local
cask "lm-studio" if ENV.fetch("DEV_SETUP_AI_LOCAL", "0") == "1"  # app: LM Studio.app

# Grupo terminal
cask "warp" if ENV.fetch("DEV_SETUP_TERMINAL", "0") == "1"  # app: Warp.app
