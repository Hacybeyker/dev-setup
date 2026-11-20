# shellcheck shell=bash
# Perfetto: trace_processor, para analizar trazas de rendimiento con SQL (lo usa la skill hb-performance de
# agent-skills). Es el script oficial de Python: la primera vez que corre baja el binario nativo, fijado a una
# versión y verificado por sha256, a ~/.local/share/perfetto/prebuilts. Va en ~/.local/bin, sin root; el bloque
# del shell ya pone esa carpeta en el PATH.

TRACE_PROCESSOR_URL="https://get.perfetto.dev/trace_processor"

trace_processor_path() { printf '%s' "$HOME/.local/bin/trace_processor"; }
trace_processor_cache_dir() { printf '%s' "$HOME/.local/share/perfetto/prebuilts"; }

# trace_processor_is_official <archivo>: es el script de Perfetto (Python, con sus binarios fijados), no un
# enlace ni otro programa con el mismo nombre.
trace_processor_is_official() {
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  head -n 1 "$1" | grep -q '^#!.*python3' || return 1
  grep -q 'perfetto-luci-artifacts' "$1" && grep -q 'trace_processor_shell' "$1"
}

# Versión de Perfetto fijada en el script (su línea "roll-prebuilts vX.Y"), sin ejecutarlo.
trace_processor_script_version() {
  [ -f "$1" ] || return 0
  sed -n 's/.*roll-prebuilts \(v[0-9][0-9.]*\).*/\1/p' "$1" | head -n 1
}

# El binario nativo ya está descargado.
trace_processor_binary_cached() {
  local file
  for file in "$(trace_processor_cache_dir)"/trace_processor_shell-*; do
    [ -e "$file" ] && return 0
  done
  return 1
}

# trace_processor_verify <ruta>: corre --version, que la primera vez baja el binario nativo. Muestra la línea
# "Perfetto vX.Y" (después vienen otras, como la versión de la API RPC).
trace_processor_verify() {
  local out line
  if ! trace_processor_binary_cached; then
    info "La primera vez baja el binario nativo (unos 15 MB), verificado por sha256"
  fi
  log_to_file CMD "$1 --version"
  if ! out="$("$1" --version </dev/null 2>&1)"; then
    log_to_file ERROR "falló: $1 --version"
    warn "trace_processor --version falló: revisa tu conexión y que python3 funcione"
    summary_add fallo "trace_processor --version (revisa tu conexión y python3)"
    next_step "Revisa por qué falla trace_processor --version y vuelve a correr dev-setup"
    return 0
  fi
  line="$(printf '%s\n' "$out" | grep -m 1 'Perfetto v' || true)"
  [ -n "$line" ] || line="$(printf '%s\n' "$out" | sed '/^[[:space:]]*$/d' | head -n 1)"
  ok "trace_processor --version: $line"
}

# Descarga el script oficial y lo instala o actualiza en ~/.local/bin. Si ya está igual, no cambia nada.
# perfetto_ensure_trace_processor [install|update]: solo cambia cómo queda en el resumen si ya estaba al día.
perfetto_ensure_trace_processor() {
  local mode="${1:-install}" dest new before after
  dest="$(trace_processor_path)"
  if ! command -v python3 >/dev/null 2>&1; then
    warn "Falta python3 (viene con las Command Line Tools): no se instala trace_processor"
    summary_add fallo "trace_processor: falta python3"
    return 0
  fi
  if is_dry_run; then
    run_cmd curl -fsSL -o '<temporal>' "$TRACE_PROCESSOR_URL"
    info "Si es distinto del instalado, se copia a $dest (0755) y se verifica con trace_processor --version"
    return 0
  fi
  new="$(new_temp_file)"
  if ! run_cmd curl -fsSL -o "$new" "$TRACE_PROCESSOR_URL"; then
    rm -f "$new"
    warn "No se pudo descargar $TRACE_PROCESSOR_URL"
    summary_add fallo "trace_processor: no se pudo descargar de $(url_host "$TRACE_PROCESSOR_URL")"
    next_step "Cuando tengas conexión, vuelve a correr dev-setup: no se pudo descargar trace_processor"
    return 0
  fi
  if ! trace_processor_is_official "$new"; then
    rm -f "$new"
    warn "Lo descargado de $TRACE_PROCESSOR_URL no es el script de Perfetto: no se instala"
    summary_add fallo "trace_processor: lo descargado no es el script de Perfetto"
    next_step "Revisa $TRACE_PROCESSOR_URL y vuelve a correr dev-setup: no se instaló trace_processor"
    return 0
  fi
  after="$(trace_processor_script_version "$new")"
  if [ -f "$dest" ] && cmp -s "$new" "$dest"; then
    rm -f "$new"
    ok "trace_processor ${after:-} ya está al día en $dest"
    if [ "$mode" = update ]; then
      summary_add revisado "trace_processor ${after:-}"
    else
      summary_add ya "trace_processor ${after:-}"
    fi
  else
    before="$(trace_processor_script_version "$dest")"
    if ! run_cmd mkdir -p "$(dirname "$dest")" || ! run_cmd install -m 0755 "$new" "$dest"; then
      rm -f "$new"
      warn "No se pudo instalar trace_processor en $dest"
      summary_add fallo "trace_processor: no se pudo copiar a $dest"
      return 0
    fi
    rm -f "$new"
    if [ -n "$before" ]; then
      ok "trace_processor actualizado: $before → ${after:-?}"
      summary_add actualizado "trace_processor $before → ${after:-?}"
    else
      ok "trace_processor ${after:-} instalado en $dest"
      summary_add instalado "trace_processor ${after:-}"
    fi
  fi
  trace_processor_verify "$dest"
}

# Lo que ya existe y no instaló dev-setup se respeta. Imprime "propio", "ajeno", "externo" o "falta".
trace_processor_state() {
  local dest
  dest="$(trace_processor_path)"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if trace_processor_is_official "$dest"; then printf 'propio'; else printf 'ajeno'; fi
  elif command -v trace_processor >/dev/null 2>&1; then
    printf 'externo'
  else
    printf 'falta'
  fi
}

perfetto_respect_foreign() {
  warn "$(trace_processor_path) no es el trace_processor oficial de Perfetto: no se toca"
  summary_add ya "$(trace_processor_path) (no es el de Perfetto: no se tocó)"
}

perfetto_install() {
  section "Perfetto (trace_processor)"
  case "$(trace_processor_state)" in
    ajeno) perfetto_respect_foreign ;;
    externo)
      ok "trace_processor en $(command -v trace_processor), instalado fuera de dev-setup: se respeta"
      summary_add ya "trace_processor (fuera de dev-setup)"
      ;;
    *) perfetto_ensure_trace_processor install ;;
  esac
}

# update solo actualiza el que instaló dev-setup.
perfetto_update() {
  section "Perfetto (trace_processor)"
  case "$(trace_processor_state)" in
    propio) perfetto_ensure_trace_processor update ;;
    ajeno) perfetto_respect_foreign ;;
    externo)
      info "trace_processor instalado fuera de dev-setup: se actualiza por su cuenta"
      summary_add ya "trace_processor (fuera de dev-setup, se actualiza por su cuenta)"
      ;;
    falta)
      warn "Falta trace_processor"
      next_step "Para instalar trace_processor, corre dev-setup bootstrap"
      ;;
  esac
}

perfetto_verify() { printf '%s\n' 'trace_processor --version'; }

# Solo lectura: no lo ejecuta, porque la primera vez descargaría el binario.
perfetto_doctor() {
  local dest version
  section "Perfetto (trace_processor)"
  dest="$(trace_processor_path)"
  case "$(trace_processor_state)" in
    propio)
      version="$(trace_processor_script_version "$dest")"
      ok "trace_processor ${version:-} en $dest"
      if trace_processor_binary_cached; then
        ok "Binario nativo descargado en $(trace_processor_cache_dir)"
      else
        info "El binario nativo se descarga la primera vez que corre trace_processor"
      fi
      ;;
    ajeno) warn "$dest no es el trace_processor oficial de Perfetto" ;;
    externo) ok "trace_processor en $(command -v trace_processor), instalado fuera de dev-setup" ;;
    falta) warn "Falta trace_processor: corre dev-setup bootstrap" ;;
  esac
}
