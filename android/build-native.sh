#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output=${1:-"$repo_root/build/android/libsprott.so"}

abi=${ANDROID_ABI:-armeabi-v7a}
api=${ANDROID_API:-21}

case "$abi" in
    armeabi-v7a)
        ndk_target=armv7a-linux-androideabi
        ick_target=arm-linux-gnueabi
        header_target=arm-linux-androideabi
        ick_flags=(-march=armv7-a -mthumb -mfpu=neon -mfloat-abi=softfp)
        ;;
    arm64-v8a)
        ndk_target=aarch64-linux-android
        ick_target=aarch64-linux-gnu
        header_target=aarch64-linux-android
        ick_flags=(-ffixed-x18)
        ;;
    x86)
        ndk_target=i686-linux-android
        ick_target=i686-linux-gnu
        header_target=i686-linux-android
        ick_flags=(
            -march=i686
            -mssse3
            -mno-sse4
            -mno-sse4.1
            -mno-sse4.2
            -mno-avx
            -mno-movbe
            -mfpmath=sse
            -mstackrealign
            -mpreferred-stack-boundary=4
            -mincoming-stack-boundary=4
        )
        ;;
    x86_64)
        ndk_target=x86_64-linux-android
        ick_target=x86_64-linux-gnu
        header_target=x86_64-linux-android
        ick_flags=(-march=x86-64-v2 -mno-avx -mno-movbe)
        ;;
    *)
        printf 'unsupported Android ABI: %s\n' "$abi" >&2
        exit 1
        ;;
esac

ick=${ICK_CC:-}
if [[ -z $ick && -n ${ICK_ROOT:-} ]]; then
    ick="$ICK_ROOT/bin/${ick_target}-gcc"
fi
[[ -n $ick && -x $ick ]] || {
    printf 'ICK compiler is required. Set ICK_CC or ICK_ROOT for %s.\n' "$ick_target" >&2
    exit 1
}

actual_ick_target=$("$ick" -dumpmachine)
[[ $actual_ick_target == "$ick_target" ]] || {
    printf 'wrong ICK target: expected %s got %s\n' "$ick_target" "$actual_ick_target" >&2
    exit 1
}

ndk=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
if [[ -z $ndk ]]; then
    android_home=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
    [[ -n $android_home ]] || {
        echo 'ANDROID_NDK_HOME or ANDROID_HOME is required' >&2
        exit 1
    }

    ndk=$(
        find "$android_home/ndk" \
            -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
            sort -V |
            tail -n 1
    )
fi

[[ -d $ndk ]] || {
    printf 'Android NDK not found: %s\n' "$ndk" >&2
    exit 1
}

toolchain=$(
    find "$ndk/toolchains/llvm/prebuilt" \
        -mindepth 1 -maxdepth 1 -type d |
        head -n 1
)

[[ -n $toolchain ]] || {
    echo 'Android NDK LLVM toolchain not found' >&2
    exit 1
}

clang="$toolchain/bin/${ndk_target}${api}-clang"
readelf="$toolchain/bin/llvm-readelf"
nm="$toolchain/bin/llvm-nm"
glue_dir="$ndk/sources/android/native_app_glue"
glue_source="$glue_dir/android_native_app_glue.c"

for required in "$clang" "$readelf" "$nm" "$glue_source"; do
    [[ -e $required ]] || {
        printf 'missing Android build input: %s\n' "$required" >&2
        exit 1
    }
done

work="$repo_root/build/android/obj-$abi"
rm -rf "$work"
mkdir -p "$work" "$(dirname -- "$output")"

core_object="$work/sprott_system.ick.o"

"$ick" \
    "${ick_flags[@]}" \
    -std=c11 \
    -O2 \
    -fPIC \
    -ffreestanding \
    -nostdinc \
    -fvisibility=hidden \
    -I "$repo_root/src" \
    -S "$repo_root/src/sprott_system.c" \
    -o "$work/sprott_system.s"

"$clang" "${ick_flags[@]}" -c "$work/sprott_system.s" -o "$core_object"

case "$abi" in
    armeabi-v7a)
        "$readelf" -A "$core_object" | tee "$work/arm.attributes"
        # GNU readelf prints these attributes on one line, while the NDK's
        # llvm-readelf prints TagName and Description on separate lines.
        grep -Eq 'Tag_CPU_arch:.*v7|Description: ARM v7' "$work/arm.attributes"
        grep -Eq 'Tag_THUMB_ISA_use:.*Thumb-2|Description: Thumb-2' "$work/arm.attributes"
        ;;
esac

"$nm" -u "$core_object" > "$work/sprott_system.undefined"
if grep -Eq '__mul(sc|dc|xc)3|__div(sc|dc|xc)3' "$work/sprott_system.undefined"; then
    echo 'unexpected complex runtime dependency from ICK core' >&2
    exit 1
fi

common_c_flags=(
    -std=c11
    -O2
    -fPIC
    -Wall
    -Wextra
    -I "$glue_dir"
    -I "$repo_root/src"
    -I "$repo_root/android/native"
)

builtin_include=$("$ick" -print-file-name=include)
[[ -d $builtin_include ]] || {
    printf 'ICK builtin headers are missing: %s\n' "$builtin_include" >&2
    exit 1
}

"$ick" "${ick_flags[@]}" "${common_c_flags[@]}" \
    -nostdinc -isystem "$builtin_include" \
    --sysroot="$toolchain/sysroot" \
    -isystem "$toolchain/sysroot/usr/include" \
    -isystem "$toolchain/sysroot/usr/include/$header_target" \
    -D__ANDROID__ -D__ANDROID_API__="$api" \
    -DBIONIC_IOCTL_NO_SIGNEDNESS_OVERLOAD \
    -S "$repo_root/android/native/sprott_android.c" \
    -o "$work/sprott_android.s"

"$ick" "${ick_flags[@]}" "${common_c_flags[@]}" \
    -nostdinc -isystem "$builtin_include" \
    --sysroot="$toolchain/sysroot" \
    -isystem "$toolchain/sysroot/usr/include" \
    -isystem "$toolchain/sysroot/usr/include/$header_target" \
    -D__ANDROID__ -D__ANDROID_API__="$api" \
    -DBIONIC_IOCTL_NO_SIGNEDNESS_OVERLOAD \
    -S "$repo_root/android/native/sprott_renderer.c" \
    -o "$work/sprott_renderer.s"

"$clang" "${ick_flags[@]}" -c "$work/sprott_android.s" \
    -o "$work/sprott_android.o"

"$clang" "${ick_flags[@]}" -c "$work/sprott_renderer.s" \
    -o "$work/sprott_renderer.o"

"$clang" "${common_c_flags[@]}" \
    -c "$glue_source" \
    -o "$work/android_native_app_glue.o"

link_alignment=()
case "$abi" in
    arm64-v8a|x86_64)
        link_alignment=(
            -Wl,-z,max-page-size=16384
            -Wl,-z,common-page-size=16384
        )
        ;;
esac

"$clang" \
    -shared \
    "$core_object" \
    "$work/sprott_android.o" \
    "$work/sprott_renderer.o" \
    "$work/android_native_app_glue.o" \
    -Wl,--no-undefined \
    -Wl,-z,defs \
    -Wl,-z,text \
    -Wl,--fatal-warnings \
    -Wl,-soname,libsprott.so \
    "${link_alignment[@]}" \
    -landroid \
    -llog \
    -lEGL \
    -lGLESv2 \
    -lm \
    -o "$output"

symbols=$("$readelf" -Ws "$output")
grep -Fq 'ANativeActivity_onCreate' <<<"$symbols"
grep -Fq 'android_main' <<<"$symbols"

printf 'native ABI              %s\n' "$abi"
printf 'native API floor        %s\n' "$api"
printf 'ICK compiler            %s\n' "$ick"
printf 'ICK target              %s\n' "$actual_ick_target"
if [[ $abi == armeabi-v7a ]]; then
    printf 'ICK instruction set     Thumb-2\n'
fi
printf 'Owned C frontend        ICK\n'
printf 'NDK glue/assembly/link  %s\n' "$clang"
printf 'native library          %s\n' "$output"
