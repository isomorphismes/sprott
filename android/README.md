# Android native viewer

This lane is a small consumer of the generic Android-native architecture in:

https://github.com/isomorphisms/android-NDK

The ownership split follows `android-NDK` main at
`96f7a2cb02b4db1b61ae60f8a20222333be9cc83`.

The NativeActivity shell follows the already-working Pauli consumer shape,
inspected at `isomorphismes/pauli` main
`c1e8a687951d8fbcba2003dccbf5b43c3a7461e3`.

The numerical core uses ICK. The Android boundary follows ICK main at
`dilapidated-shed/ick@9f5c10a7c97ce297568190a48aaac77f450e838e`,
whose Android qualification explicitly uses ICK for header-free leaf objects
and Android NDK Clang/lld for the platform-facing objects and final link.

No Pauli orbital semantics are carried into this repository.

## Runtime and compiler shape

```text
android.app.NativeActivity
        |
        v
NDK-Clang-compiled Android / EGL / GLES boundary
        |
        | system id + Float32 scalars/arrays only
        v
ICK-compiled sprott_system.c
        |
        v
Sprott vector field + RK4
```

The package has no application `classes.dex` and no Java/Kotlin application
layer. ICK does not need Android headers or an Android sysroot for the numerical
core.

NDK Clang remains deliberately limited to:

- Android and GLES translation units;
- `android_native_app_glue.c`;
- the final Android shared-library link.

It does not compile `src/sprott_system.c`.

## ARMv7 / MIRO A1 lane

The `armeabi-v7a` core uses the flags already qualified by ICK:

```text
-march=armv7-a -mthumb -mfpu=neon -mfloat-abi=softfp
```

The build checks the ICK object for ARMv7 and Thumb-2 attributes before the
Android link. This is the phone lane.

## Interaction

- launch: show a precomputed Sprott-B trajectory;
- drag: rotate the trajectory;
- tap: restore the default orientation and regenerate the deterministic trail;
- resize / rotate device: resize the GLES viewport without changing the
  mathematical model.

## Build

Run the ordinary host semantic test first:

```sh
bash tests/run.sh
```

Supply a built ICK compiler for the selected ABI. For ARMv7:

```sh
ICK_CC=/path/to/arm-linux-gnueabi-gcc \
ANDROID_ABI=armeabi-v7a \
bash android/build-native.sh
```

Alternatively point `ICK_ROOT` at an ICK installation whose `bin/` contains
the matching target compiler.

CI builds ICK from the pinned source revision before building Sprott, so the
Android acceptance lane cannot silently fall back to stock GCC or NDK Clang for
the numerical core.

APK packaging follows the application-owned, fail-closed signing pattern used
by Pauli. Supply:

```text
SPROTT_KEYSTORE
SPROTT_KEYSTORE_TYPE
SPROTT_KEY_ALIAS
SPROTT_STORE_PASSWORD
SPROTT_KEY_PASSWORD
SPROTT_EXPECTED_CERT_SHA256
```

Then run:

```sh
ICK_CC=/path/to/arm-linux-gnueabi-gcc \
ANDROID_ABI=armeabi-v7a \
bash android/build.sh
```

The build emits an ABI-specific APK and a signing receipt.

## Acceptance

A physical-device smoke pass should establish:

- NativeActivity reaches `android_main`;
- EGL creates a surface and GLES context;
- the Sprott-B trail appears;
- dragging rotates the trail;
- tapping resets it;
- window loss/recreation does not crash;
- device resize/orientation changes preserve a usable view.

An emulator can test lifecycle/input/package behavior but does not substitute
for physical GPU evidence.
