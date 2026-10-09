# Functorial Icky numerical core

The public system ID and three-Float32 array ABI are preserved. Within the
numerical core, phase points and phase velocities have distinct types. The
transformation is:

`phase_point_from_state → velocity_at → displaced_phase_point →
runge_kutta_step → integrated_phase_point → write_phase_point`.

The vector field remains Sprott B: `(yz, x − y, 1 − xy)`. Four RK4
velocities are sampled at the same points and combined in the same arithmetic
order. Arrays are decoded and written only at the public boundary. Mathematical
multiplication uses `×`, division uses `÷`, and initialization and assignment use `←`.
The public header remains plain C for the existing ICK/NDK boundary.

`make test` requires a real ICK compiler. The independent expanded one-step
example and 73,728 trajectory steps are checked against the frozen previous
implementation from main `e7ff723337102f189a16859b17ea52457472e675`.
The reference intentionally remains ordinary C, with symbols renamed during
compilation. Both candidate and reference are compiled by ICK. The original
10,000-step finite-trajectory test also remains.

The native scalar profile uses glibc/GCC startup/runtime dependencies and
`-fno-link-libatomic`, as recorded by the pinned shared producer. No stock
compiler compiles the core or its tests. The Android build retains its
existing header-free ICK core and NDK platform/link stages, using the newer
compiler pin required for both glyphs. Native tests do not prove Android
execution or physical-device acceptance.

This refactor covers `src/sprott_system.c` and its maintained tests. The two
Android renderer/lifecycle C units still need their own source-style and
compiler-stage qualification; the whole application is not certified here.

## Division migration, 2026-10-09

The RK4 denominator and six maintained-test divisions now use `÷` without
changing operand types or operation order. The current producer pins ICK
`c61e448251744a2f40ad743ebef1a027bdcd2f9d`. A forced native rebuild passed the
original trajectory test, independent one-step check, and all 73,728 frozen
reference comparisons. The reference source remains the comparison control.
