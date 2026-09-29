#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

native_library=${1:-"$repo_root/build/android/libsprott.so"}
output=${2:-"$repo_root/build/android/sprott.apk"}

abi=${ANDROID_ABI:-armeabi-v7a}
compile_sdk=${ANDROID_COMPILE_SDK:-36}

case "$abi" in
    armeabi-v7a|arm64-v8a|x86|x86_64) ;;
    *)
        printf 'unsupported Android ABI: %s\n' "$abi" >&2
        exit 1
        ;;
esac

fail() {
    printf 'Sprott APK signing failed: %s\n' "$*" >&2
    exit 1
}

require_value() {
    local name=$1
    [[ -n ${!name:-} ]] || fail "required signing value is unset: $name"
}

[[ -f $native_library ]] || fail "missing native library: $native_library"

android_home=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
[[ -n $android_home ]] || fail 'ANDROID_HOME or ANDROID_SDK_ROOT is required'

build_tools=${ANDROID_BUILD_TOOLS:-}
if [[ -z $build_tools ]]; then
    build_tools=$(
        find "$android_home/build-tools" \
            -mindepth 1 -maxdepth 1 -type d |
            sort -V |
            tail -n 1
    )
fi

aapt2="$build_tools/aapt2"
zipalign="$build_tools/zipalign"
apksigner="$build_tools/apksigner"
android_jar="$android_home/platforms/android-$compile_sdk/android.jar"

for required in "$aapt2" "$zipalign" "$apksigner" "$android_jar"; do
    [[ -e $required ]] || fail "missing Android packaging input: $required"
done
command -v keytool >/dev/null 2>&1 || fail 'keytool is required'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required'

for name in \
    SPROTT_KEYSTORE \
    SPROTT_KEYSTORE_TYPE \
    SPROTT_KEY_ALIAS \
    SPROTT_STORE_PASSWORD \
    SPROTT_KEY_PASSWORD \
    SPROTT_EXPECTED_CERT_SHA256
do
    require_value "$name"
done

keystore=$SPROTT_KEYSTORE
keystore_type=$SPROTT_KEYSTORE_TYPE
key_alias=$SPROTT_KEY_ALIAS
store_password=$SPROTT_STORE_PASSWORD
key_password=$SPROTT_KEY_PASSWORD
expected_cert_sha256=$(
    printf '%s' "$SPROTT_EXPECTED_CERT_SHA256" |
        tr '[:upper:]' '[:lower:]' |
        tr -d ':[:space:]'
)

[[ $expected_cert_sha256 =~ ^[0-9a-f]{64}$ ]] ||
    fail 'SPROTT_EXPECTED_CERT_SHA256 is not a SHA-256 certificate digest'
[[ -f $keystore ]] || fail "required keystore is missing: $keystore"

keystore_cert_sha256=$(
    keytool -exportcert \
        -keystore "$keystore" \
        -storetype "$keystore_type" \
        -storepass "$store_password" \
        -alias "$key_alias" \
        2>/dev/null |
    sha256sum |
    awk '{print $1}'
)

[[ $keystore_cert_sha256 == "$expected_cert_sha256" ]] ||
    fail "keystore certificate changed: expected $expected_cert_sha256 got $keystore_cert_sha256"

work="$repo_root/build/android/apk-work-$abi"
rm -rf "$work"
mkdir -p "$work/lib/$abi" "$(dirname -- "$output")"

cp "$native_library" "$work/lib/$abi/libsprott.so"

manifest_apk="$work/manifest.apk"
unaligned="$work/unaligned.apk"
aligned="$work/aligned.apk"

"$aapt2" link \
    -I "$android_jar" \
    --manifest "$repo_root/android/AndroidManifest.xml" \
    --min-sdk-version 21 \
    --target-sdk-version 36 \
    -o "$manifest_apk"

cp "$manifest_apk" "$unaligned"
(
    cd "$work"
    zip -q -u "$unaligned" "lib/$abi/libsprott.so"
)

"$zipalign" -f 4 "$unaligned" "$aligned"

receipt="${output%.apk}.signing.tsv"
rm -f "$output" "$receipt"

"$apksigner" sign \
    --ks "$keystore" \
    --ks-type "$keystore_type" \
    --ks-pass "pass:$store_password" \
    --key-pass "pass:$key_password" \
    --ks-key-alias "$key_alias" \
    --out "$output" \
    "$aligned"

cert_report=$("$apksigner" verify --verbose --print-certs "$output" 2>&1)
printf '%s\n' "$cert_report"

apk_cert_sha256=$(
    printf '%s\n' "$cert_report" |
        sed -n 's/^.*certificate SHA-256 digest:[[:space:]]*//p' |
        tr '[:upper:]' '[:lower:]' |
        tr -d ':[:space:]' |
        sort -u
)

[[ $apk_cert_sha256 == "$expected_cert_sha256" ]] ||
    fail "finished APK signer changed: expected $expected_cert_sha256 got ${apk_cert_sha256:-missing}"

apk_sha256=$(sha256sum "$output" | awk '{print $1}')

{
    printf 'schema\tandroid-signing-v1\n'
    printf 'package\torg.isomorphisms.sprott\n'
    printf 'abi\t%s\n' "$abi"
    printf 'apk_sha256\t%s\n' "$apk_sha256"
    printf 'signer_cert_sha256\t%s\n' "$apk_cert_sha256"
    printf 'expected_signer_cert_sha256\t%s\n' "$expected_cert_sha256"
    printf 'key_alias\t%s\n' "$key_alias"
    printf 'source_commit\t%s\n' "${GITHUB_SHA:-local}"
} > "$receipt"

printf 'APK ABI                 %s\n' "$abi"
printf 'APK target API          %s\n' 36
printf 'APK                     %s\n' "$output"
printf 'APK SHA-256             %s\n' "$apk_sha256"
printf 'signer certificate      %s\n' "$apk_cert_sha256"
printf 'signing receipt         %s\n' "$receipt"
