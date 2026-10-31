#!/usr/bin/env bats

# Con el Bash 3.2 de macOS, bats no encuentra los tests cuyo nombre lleva ciertos caracteres
# no ASCII (por ejemplo la i con tilde): los salta y la suite falla solo en macOS.
@test "los nombres de los tests usan solo ASCII" {
  run env LC_ALL=C grep -n '^@test .*[^ -~]' "$BATS_TEST_DIRNAME"/*.bats
  [ "$status" -eq 1 ]
}
