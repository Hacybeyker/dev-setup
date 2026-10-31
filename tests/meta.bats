#!/usr/bin/env bats

# Con el Bash 3.2 de macOS, bats no encuentra los tests cuyo nombre lleva ciertos caracteres
# no ASCII (por ejemplo la i con tilde): los salta y la suite falla solo en macOS.
@test "los nombres de los tests usan solo ASCII" {
  run env LC_ALL=C grep -n '^@test .*[^ -~]' "$BATS_TEST_DIRNAME"/*.bats
  [ "$status" -eq 1 ]
}

@test "install.sh, el README y el CHANGELOG apuntan a la misma version" {
  root="$BATS_TEST_DIRNAME/.."
  ref="$(sed -n 's/.*DEV_SETUP_REF:-\([^}]*\)}.*/\1/p' "$root/install.sh")"
  [ -n "$ref" ]
  grep -qF "raw.githubusercontent.com/Hacybeyker/dev-setup/$ref/install.sh" "$root/README.md"
  grep -qF "## [${ref#v}]" "$root/CHANGELOG.md"
}
