#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output="$repo_root/build/tests/test-sprott-system"
cc=${CC:-cc}

mkdir -p "$(dirname -- "$output")"

"$cc" \
    -std=c11 \
    -O2 \
    -Wall \
    -Wextra \
    -Werror \
    -I "$repo_root/src" \
    "$repo_root/src/sprott_system.c" \
    "$repo_root/tests/test_sprott_system.c" \
    -lm \
    -o "$output"

"$output"
