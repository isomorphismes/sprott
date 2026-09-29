#!/bin/sh
set -eu

pinned_ick_sha=72b28ef09d2f4bcddf0718bb43d45a231878f5dc

: "${ICK_GDC:?set ICK_GDC to the gdc executable built from the pinned ICK source}"
: "${ICK_GDC_SOURCE_SHA:?set ICK_GDC_SOURCE_SHA to the ICK source commit used to build it}"

if [ "$ICK_GDC_SOURCE_SHA" != "$pinned_ick_sha" ]; then
    echo "refusing non-pinned D compiler: expected ICK $pinned_ick_sha, got $ICK_GDC_SOURCE_SHA" >&2
    exit 2
fi

mkdir -p build
"$ICK_GDC" --version
modules="src/sprott_core.d src/sprott_raster.d src/sprott_engine_base.d src/sprott_engine.d src/sprott_io.d src/sprott.d"
"$ICK_GDC" -O2 -frelease -Isrc $modules src/main.d -o build/sprott-d
"$ICK_GDC" -O0 -g -Isrc $modules tests/test_sprott.d -o build/sprott-d-tests
./build/sprott-d-tests
