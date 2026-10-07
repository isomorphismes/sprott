# Sprott B fixture

## Published mathematics

J. C. Sprott's simple-flow page lists Case B as

```text
dx/dt = yz
dy/dt = x - y
dz/dt = 1 - xy
```

Primary references:

- https://sprott.physics.wisc.edu/simplest.htm
- J. C. Sprott, "Some simple chaotic flows," Physical Review E 50,
  R647-R650 (1994).

The repository independently implements these equations. It does not copy
Sprott's program text.

## Application-owned numerical choices

The following choices belong to this implementation, not to the published
definition of Case B:

- initial state `(0.1, 0.1, 0.1)`;
- fixed-step fourth-order Runge-Kutta integration;
- `dt = 0.01`;
- 2048 integration steps discarded before drawing;
- 4096 displayed trail points;
- four RK4 steps between displayed points;
- orthographic projection and automatic fit;
- initial camera orientation;
- drag-to-rotate and tap-to-reset interaction.

## Compiler boundary

The Android build compiles `src/sprott_system.c` with ICK. The public boundary
uses only:

- an integer system identifier;
- Float32 scalar values;
- fixed-length Float32 arrays.

Android, GLES, JNI, Activity, DEX, C structs, and function pointers do not cross
the ICK/NDK compiler boundary.

For `armeabi-v7a`, the ICK object is explicitly Thumb-2.
