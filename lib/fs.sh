# shellcheck shell=bash
# Cambios seguros en archivos del usuario: respaldo, diff, confirmación y bloque administrado.

new_temp_file() { mktemp "${TMPDIR:-/tmp}/dev-setup.XXXXXX"; }

# backup_file <archivo>: lo copia a <archivo>.bak-<AAAAMMDD-HHMMSS> sin pisar respaldos previos.
backup_file() {
  local file="$1" dest base n=1
  [ -e "$file" ] || return 0
  base="$file.bak-$(date +%Y%m%d-%H%M%S)"
  dest="$base"
  while [ -e "$dest" ]; do
    dest="$base-$n"
    n=$((n + 1))
  done
  run_cmd cp -p "$file" "$dest"
  info "Respaldo: $dest"
}

# ensure_block <archivo> <id> <contenido>: escribe o actualiza el bloque
#   # >>> <id> >>>
#   <contenido>
#   # <<< <id> <<<
# sin tocar el resto del archivo. Los cambios pasan por apply_file_change.
ensure_block() {
  local file="$1" id="$2" content="$3"
  local begin="# >>> $id >>>" end="# <<< $id <<<"
  local begins=0 ends=0 block new
  if [ -e "$file" ]; then
    begins="$(grep -cFx -- "$begin" "$file" || true)"
    ends="$(grep -cFx -- "$end" "$file" || true)"
  fi
  if [ "$begins" != "$ends" ] || [ "$begins" -gt 1 ]; then
    error "$file: el bloque '$id' está incompleto o repetido; corrígelo a mano"
    return 1
  fi

  block="$(new_temp_file)"
  new="$(new_temp_file)"
  printf '%s\n%s\n%s\n' "$begin" "$content" "$end" >"$block"
  if [ "$begins" = 1 ]; then
    awk -v begin="$begin" -v end="$end" -v block="$block" '
      $0 == begin { while ((getline line < block) > 0) print line; skipping = 1; next }
      skipping && $0 == end { skipping = 0; next }
      !skipping { print }
    ' "$file" >"$new"
  else
    if [ -s "$file" ]; then
      cat "$file" >"$new"
      [ -z "$(tail -c 1 "$file")" ] || printf '\n' >>"$new"
      printf '\n' >>"$new"
    fi
    cat "$block" >>"$new"
  fi
  rm -f "$block"
  apply_file_change "$file" "$new"
}

# apply_file_change <archivo> <nuevo>: reemplaza el archivo por el contenido de <nuevo> si cambió.
# Muestra el diff, respeta --dry-run, pide confirmación y respalda. Siempre borra <nuevo>.
# Escribe a través de enlaces simbólicos y conserva los permisos del archivo.
apply_file_change() {
  local file="$1" new="$2"
  if [ -e "$file" ] && cmp -s "$file" "$new"; then
    rm -f "$new"
    ok "$file ya está al día"
    return 0
  fi

  info "Cambios propuestos en $file:"
  if [ -e "$file" ]; then
    diff -u -L "$file (actual)" -L "$file (nuevo)" "$file" "$new" || true
  else
    diff -u -L "$file (no existe)" -L "$file (nuevo)" /dev/null "$new" || true
  fi

  if is_dry_run; then
    rm -f "$new"
    printf '  %s[dry-run]%s se actualizaría %s\n' "$C_YELLOW" "$C_RESET" "$file"
    return 0
  fi
  if ! confirm "¿Aplicar este cambio en $file?"; then
    rm -f "$new"
    warn "Sin cambios en $file"
    return 0
  fi
  backup_file "$file"
  run_cmd cp "$new" "$file"
  rm -f "$new"
  ok "$file actualizado"
}

# list_entries <archivo>: imprime las líneas útiles de una lista (sin comentarios ni líneas vacías).
list_entries() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line%"${line##*[![:space:]]}"}"
    line="${line#"${line%%[![:space:]]*}"}"
    [ -z "$line" ] || printf '%s\n' "$line"
  done <"$1"
}

# in_lines <valor> <líneas>: 0 si el valor es exactamente una de las líneas.
in_lines() { printf '%s\n' "$2" | grep -qxF -- "$1"; }
