# Android native viewer

This lane is a small consumer of the generic Android-native architecture in:

https://github.com/isomorphisms/android-NDK

The ownership split follows `android-NDK` main at
`96f7a2cb02b4db1b61ae60f8a20222333be9cc83`.

The NativeActivity shell follows the already-working Pauli consumer shape,
inspected at `isomorphismes/pauli` main
`c1e8a687951d8fbcba2003dccbf5b43c3a7461e3`.

No Pauli orbital semantics are carried into this repository.

## Runtime shape

```text
android.app.NativeActivity
        |
        v
libsprott.so
  lifecycle / touch / EGL
        |
        v
sprott_renderer
        |
        +--> sprott_system
        |
        v
GLES line trail
```

The package has no application `classes.dex` and no Java/Kotlin application
layer. The renderer boundary contains no Activity, JNI, DEX, or
`ANativeWindow` types.

## Interaction

- launch: show a precomputed Sprott-B trajectory;
- drag: rotate the trajectory;
- tap: restore the default orientation and regenerate the deterministic trail;
- resize / rotate device: resize the GLES viewport without changing the
  mathematical model.

## Build

Run host tests first:

```sh
bash tests/run.sh
```

Build the native library:

```sh
ANDROID_ABI=armeabi-v7a bash android/build-native.sh
```

`arm64-v8a`, `x86`, and `x86_64` use the same script.

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
ANDROID_ABI=armeabi-v7a bash android/build.sh
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
