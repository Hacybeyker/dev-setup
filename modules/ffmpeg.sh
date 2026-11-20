# shellcheck shell=bash
# ffmpeg: un build estático para el video de evidencia de la skill hb-performance de agent-skills, que une
# tramos grabados y les agrega rótulos (concat, pad, drawbox, drawtext y overlay; drawtext necesita
# libfreetype). Va en ~/.local/bin, sin root ni Homebrew: el bloque del shell ya pone esa carpeta en el PATH.
# La versión, la URL y el SHA256 de cada arquitectura están en ffmpeg/builds.txt. El que instaló dev-setup se
# reconoce por su marca, con la versión y el SHA256 del binario: cualquier otro se respeta.

ffmpeg_data_dir() { printf '%s' "${DEV_SETUP_FFMPEG_DATA:-$DEV_SETUP_ROOT/ffmpeg}"; }
ffmpeg_path() { printf '%s' "$HOME/.local/bin/ffmpeg"; }
ffmpeg_marker_path() { printf '%s' "$HOME/.local/share/dev-setup/ffmpeg.version"; }

ffmpeg_sha256() { shasum -a 256 "$1" | awk '{ print $1 }'; }

# ffmpeg_marker_field <clave>: un valor de la marca (version, sha256 o url), o nada si no está.
ffmpeg_marker_field() {
  [ -f "$(ffmpeg_marker_path)" ] || return 0
  sed -n "s/^$1=//p" "$(ffmpeg_marker_path)" | head -n 1
}

# El build fijado para la arquitectura de esta Mac: "<versión> <url> <sha256>". Falla si no hay uno.
ffmpeg_build() {
  local arch name version url sha
  arch="$(uname -m)"
  while read -r name version url sha <&3; do
    [ "$name" = "$arch" ] || continue
    printf '%s %s %s' "$version" "$url" "$sha"
    return 0
  done 3< <(list_entries "$(ffmpeg_data_dir)/builds.txt")
  return 1
}

# Lo que ya existe y no instaló dev-setup se respeta. Imprime "propio", "ajeno", "externo" o "falta".
ffmpeg_state() {
  local dest sha
  dest="$(ffmpeg_path)"
  if [ -L "$dest" ]; then
    printf 'ajeno'
  elif [ -e "$dest" ]; then
    sha="$(ffmpeg_marker_field sha256)"
    if [ -f "$dest" ] && [ -n "$sha" ] && [ "$(ffmpeg_sha256 "$dest")" = "$sha" ]; then
      printf 'propio'
    else
      printf 'ajeno'
    fi
  elif command -v ffmpeg >/dev/null 2>&1; then
    printf 'externo'
  else
    printf 'falta'
  fi
}

# ffmpeg_has_drawtext <ffmpeg>: tiene el filtro drawtext, que solo existe si se compiló con libfreetype.
ffmpeg_has_drawtext() {
  "$1" -hide_banner -filters </dev/null 2>/dev/null | awk '$2 == "drawtext" { found = 1 } END { exit !found }'
}

ffmpeg_quarantined() {
  command -v xattr >/dev/null 2>&1 && xattr -p com.apple.quarantine "$1" >/dev/null 2>&1
}

ffmpeg_quarantine_step() {
  next_step "macOS dejó ffmpeg en cuarentena y puede bloquearlo. El build está firmado por su autor y dev-setup verificó su SHA256; si confías en él, quita la marca con: xattr -d com.apple.quarantine ~/.local/bin/ffmpeg"
}

# ffmpeg_check <ruta>: después de instalarlo, revisa la cuarentena, la versión y que tenga drawtext.
ffmpeg_check() {
  local dest="$1" out
  if ffmpeg_quarantined "$dest"; then
    warn "macOS marcó $(display_path "$dest") en cuarentena: no se ejecuta hasta que quites la marca"
    ffmpeg_quarantine_step
    return 0
  fi
  log_to_file CMD "$dest -hide_banner -version"
  if ! out="$("$dest" -hide_banner -version </dev/null 2>&1)"; then
    log_to_file ERROR "falló: $dest -hide_banner -version"
    warn "ffmpeg -version falló"
    summary_add fallo "ffmpeg: falló ffmpeg -version"
    next_step "Revisa por qué falla ~/.local/bin/ffmpeg -hide_banner -version y vuelve a correr dev-setup"
    return 0
  fi
  ok "ffmpeg -version: $(printf '%s\n' "$out" | head -n 1 | sed 's/ Copyright.*//')"
  if ffmpeg_has_drawtext "$dest"; then
    ok "ffmpeg tiene el filtro drawtext"
  else
    warn "ffmpeg no tiene el filtro drawtext: el video de evidencia de hb-performance no tendrá rótulos"
    summary_add fallo "ffmpeg: no tiene el filtro drawtext"
    next_step "El ffmpeg de ~/.local/bin no tiene drawtext: revisa el build de ffmpeg/builds.txt y vuelve a correr dev-setup"
  fi
}

# ffmpeg_ensure [install|update]: instala el build fijado si falta, o si el de dev-setup es de otra versión.
# Descarga a un temporal, verifica el SHA256 y solo entonces copia el binario y escribe la marca.
ffmpeg_ensure() {
  local mode="${1:-install}" dest marker build version url sha installed zip dir new_marker
  dest="$(ffmpeg_path)"
  marker="$(ffmpeg_marker_path)"
  if ! build="$(ffmpeg_build)"; then
    warn "ffmpeg/builds.txt no tiene un build para $(uname -m): no se instala ffmpeg"
    summary_add fallo "ffmpeg: no hay build para $(uname -m)"
    next_step "dev-setup no tiene un build de ffmpeg para $(uname -m): instálalo por tu cuenta, con libfreetype (para drawtext)"
    return 0
  fi
  read -r version url sha <<<"$build"
  installed=""
  [ ! -e "$dest" ] || installed="$(ffmpeg_marker_field version)"
  if [ -n "$installed" ] && [ "$installed" = "$version" ]; then
    ok "ffmpeg $version ya está en $(display_path "$dest")"
    if [ "$mode" = update ]; then
      summary_add revisado "ffmpeg $version"
    else
      summary_add ya "ffmpeg $version"
    fi
    return 0
  fi
  if is_dry_run; then
    run_cmd curl -fsSL -o '<temporal>' "$url"
    info "Si su SHA256 es el de ffmpeg/builds.txt, se copia a $(display_path "$dest") (0755) y se verifica con ffmpeg -version y -filters"
    return 0
  fi
  zip="$(new_temp_file)"
  if ! run_cmd curl -fsSL -o "$zip" "$url"; then
    rm -f "$zip"
    warn "No se pudo descargar $url"
    summary_add fallo "ffmpeg: no se pudo descargar de $(url_host "$url")"
    next_step "Cuando tengas conexión, vuelve a correr dev-setup: no se pudo descargar ffmpeg"
    return 0
  fi
  if [ "$(ffmpeg_sha256 "$zip")" != "$sha" ]; then
    rm -f "$zip"
    error "El SHA256 de lo descargado de $url no es el de ffmpeg/builds.txt: no se instala"
    summary_add fallo "ffmpeg: el SHA256 de la descarga no coincide"
    next_step "No se instaló ffmpeg: el SHA256 de la descarga no coincide. Vuelve a correr dev-setup más tarde y, si sigue igual, avisa en el repo de dev-setup"
    return 0
  fi
  dir="$(new_temp_dir)"
  if ! run_cmd unzip -q -o "$zip" ffmpeg -d "$dir" || [ ! -f "$dir/ffmpeg" ] || [ -L "$dir/ffmpeg" ]; then
    rm -rf "$zip" "$dir"
    warn "El zip de $url no trae el binario ffmpeg: no se instala"
    summary_add fallo "ffmpeg: el zip descargado no trae el binario"
    next_step "No se instaló ffmpeg: el zip de ffmpeg/builds.txt no trae el binario. Avisa en el repo de dev-setup"
    return 0
  fi
  new_marker="$(new_temp_file)"
  printf 'version=%s\nsha256=%s\nurl=%s\n' "$version" "$(ffmpeg_sha256 "$dir/ffmpeg")" "$url" >"$new_marker"
  # El binario va antes que la marca: si algo falla en medio, nunca queda una marca de un binario que no está.
  if ! run_cmd mkdir -p "$(dirname "$dest")" "$(dirname "$marker")" ||
    ! run_cmd install -m 0755 "$dir/ffmpeg" "$dest" ||
    ! run_cmd install -m 0644 "$new_marker" "$marker"; then
    rm -rf "$zip" "$dir" "$new_marker"
    warn "No se pudo instalar ffmpeg en $(display_path "$dest")"
    summary_add fallo "ffmpeg: no se pudo copiar a $(display_path "$dest")"
    return 0
  fi
  rm -rf "$zip" "$dir" "$new_marker"
  if [ -n "$installed" ]; then
    ok "ffmpeg actualizado: $installed → $version"
    summary_add actualizado "ffmpeg $installed → $version"
  else
    ok "ffmpeg $version instalado en $(display_path "$dest")"
    summary_add instalado "ffmpeg $version"
  fi
  ffmpeg_check "$dest"
}

ffmpeg_respect_foreign() {
  warn "$(display_path "$(ffmpeg_path)") no lo instaló dev-setup: no se toca"
  summary_add ya "$(display_path "$(ffmpeg_path)") (no lo instaló dev-setup: no se tocó)"
}

# ffmpeg_respect_external [install|update]: uno instalado fuera de dev-setup se respeta aunque le falte
# drawtext; en ese caso, se avisa y queda como paso pendiente.
ffmpeg_respect_external() {
  local path
  path="$(command -v ffmpeg)"
  if [ "${1:-install}" = update ]; then
    info "ffmpeg en $(display_path "$path"), instalado fuera de dev-setup: se actualiza por su cuenta"
  else
    ok "ffmpeg en $(display_path "$path"), instalado fuera de dev-setup: se respeta"
  fi
  if ffmpeg_has_drawtext "$path"; then
    summary_add ya "ffmpeg (fuera de dev-setup)"
  else
    warn "Ese ffmpeg no tiene el filtro drawtext: el video de evidencia de hb-performance no tendrá rótulos"
    summary_add ya "ffmpeg (fuera de dev-setup, sin drawtext)"
    next_step "El ffmpeg de $(display_path "$path") no tiene drawtext (le falta libfreetype), que usa hb-performance para el video de evidencia. dev-setup no lo toca: cámbialo por uno con libfreetype, o quítalo y corre dev-setup bootstrap para instalar el de dev-setup"
  fi
}

ffmpeg_install() {
  section "ffmpeg"
  case "$(ffmpeg_state)" in
    ajeno) ffmpeg_respect_foreign ;;
    externo) ffmpeg_respect_external install ;;
    *) ffmpeg_ensure install ;;
  esac
}

# update solo actualiza el que instaló dev-setup, y solo si cambió la versión de ffmpeg/builds.txt.
ffmpeg_update() {
  section "ffmpeg"
  case "$(ffmpeg_state)" in
    propio) ffmpeg_ensure update ;;
    ajeno) ffmpeg_respect_foreign ;;
    externo) ffmpeg_respect_external update ;;
    falta)
      warn "Falta ffmpeg"
      next_step "Para instalar ffmpeg, corre dev-setup bootstrap"
      ;;
  esac
}

ffmpeg_verify() {
  printf '%s\n' 'ffmpeg -hide_banner -version' 'ffmpeg -hide_banner -filters | grep drawtext'
}

# Solo lectura y sin red: el de dev-setup no se ejecuta (su versión sale de la marca); a uno de fuera solo se
# le pide la lista de filtros, para saber si tiene drawtext.
ffmpeg_doctor() {
  local dest path version build pinned
  section "ffmpeg"
  dest="$(ffmpeg_path)"
  case "$(ffmpeg_state)" in
    propio)
      version="$(ffmpeg_marker_field version)"
      ok "ffmpeg ${version:-} en $(display_path "$dest"), instalado por dev-setup"
      if build="$(ffmpeg_build)"; then
        pinned="${build%% *}"
        [ "$pinned" = "$version" ] || info "dev-setup fija ffmpeg $pinned: corre dev-setup update"
      fi
      if ffmpeg_quarantined "$dest"; then
        warn "macOS lo marcó en cuarentena: quita la marca con xattr -d com.apple.quarantine ~/.local/bin/ffmpeg"
      fi
      ;;
    ajeno) warn "$(display_path "$dest") no lo instaló dev-setup: no se toca" ;;
    externo)
      path="$(command -v ffmpeg)"
      if ffmpeg_has_drawtext "$path"; then
        ok "ffmpeg en $(display_path "$path"), instalado fuera de dev-setup"
      else
        warn "ffmpeg en $(display_path "$path"), instalado fuera de dev-setup, no tiene drawtext (lo usa hb-performance)"
      fi
      ;;
    falta) warn "Falta ffmpeg: corre dev-setup bootstrap" ;;
  esac
}
