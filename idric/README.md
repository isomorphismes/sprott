# Sprott BASIC → Idriç

This branch carries a whole-program Idriç translation of the behavior of
J. C. Sprott's **Strange Attractor Program, BASIC Version 2.0 (1993)**.

The source program is `PROG28.BAS` from the disk accompanying *Strange
Attractors: Creating Patterns in Chaos*:

- https://sprott.physics.wisc.edu/fractals/bookdisk/PROG28.BAS
- https://sprott.physics.wisc.edu/fractals/bookdisk/

Sprott's download page identifies the program files as copyrighted and permits
non-commercial distribution with acknowledgement, while requiring permission
for commercial use.  This repository does **not** vendor the BASIC file.  The
Idriç implementation keeps the upstream attribution and independently expresses
the program's algorithms and control semantics.

## Scope

`SprottBasic.idric` carries the complete computational and control-flow surface
of the BASIC program:

| BASIC routine | Idriç implementation |
| --- | --- |
| 1300 Initialize | `new_program_state`, `empty_view` |
| 1500 Set parameters | `reset_parameters` |
| 1700 Iterate equations | `iterate_definition`, `polynomial_value` |
| 2100 Display results | `display_results` |
| 2400 Test results | `test_results` |
| 2600 Get coefficients | `generate_definition`, `decode_code` |
| 2800 Shuffle random numbers | `shuffle_random` |
| 2900 Lyapunov exponent | `lyapunov_step` |
| 3100 Resize screen | `resize_view` |
| 3500 Produce sound | `sound_event` |
| 3600 Respond to command | `apply_menu_command` |
| 3900 Fractal dimension | `fractal_dimension_step` |
| 4100 Sphere projection | `project_sphere` |
| 4200 Menu | `menu_lines` |
| 4700 Decode dimension/order | `decode_code` |
| 4900 Save attractor | `AppendDictionary` effect from `test_results` |
| 5000 Plot point | `plot_operations` |
| 5400 Background grid | `grid_lines` |
| 5600 Colors | `palette_color` plus plotting policy |
| 5800 Evaluation command | `process_evaluation_command` |
| 5900 Favorite attractor | `AppendFavorite` effect |
| 6000 Rewrite evaluation dictionary | `ReplaceEvaluationDictionary` effect |
| 6200 Special functions | `iterate_special` |
| 6600 Graphics fallback | `fallback_graphics_mode` |
| 6700 Horizontal cylinder | `project_horizontal_cylinder` |
| 6800 Vertical cylinder | `project_vertical_cylinder` |
| 6900 Torus | `project_torus` |
| 7000 Save X/Y/Z/W data | `saved_scalar`, `SaveScalar` effect |
| 1170–1240 main loop | `step_program`, `run_steps` |

The polynomial evaluator preserves the BASIC coefficient order through degree
5 and dimensions 1–4.  The special families remain present: absolute-value,
Boolean, power-law, sine, kicked, and forced-oscillator systems.  The original
compact attractor-code format is decoded and generated directly.

## DOS boundary

A source-to-source port cannot make QuickBASIC's `SCREEN`, `PSET`, `POINT`,
`SOUND`, `INKEY$`, and DOS file handles into portable Idriç primitives by
renaming them.  Removing those operations would also fail the whole-program
translation.

The translation therefore makes the device boundary explicit in
`SprottBasicTypes.idric`:

- `PlotOperation` represents drawing plus the read/modify/write cases used by
  shadows and anaglyphs;
- `Tone` represents the `SOUND` request;
- `ProgramEffect` represents text, drawing, sound, dictionary/favorite updates,
  scalar data saves, beeps, and fatal graphics-mode failure.

The program logic produces those effects at the same semantic seams as the
BASIC program.  A terminal, Android/NDK, framebuffer, or test adapter can
interpret them without changing the attractor/search logic.

This separation is intentionally narrow.  It does not replace the existing
`android/native-sprott-b` implementation and does not turn the old DOS API into
application architecture.

## Numerical compatibility

The original program declares BASIC variables as double precision.  This port
therefore uses `Double` for the compatibility lane.  That choice does not set a
new Idriç numerical default.

The Boolean special map models QuickBASIC's signed 16-bit integer bitwise
operations explicitly instead of inheriting the host integer width.

The host random generator is deterministic for tests.  Sprott's 100-entry
shuffle stage is preserved.  A platform adapter may seed the generator from a
clock to reproduce the BASIC `RANDOMIZE TIMER` behavior.

## Files

- `SprottBasicTypes.idric` — program state, modes, device/effect boundary.
- `SprottBasic.idric` — whole-program translation.
- `SprottBasicTests.idric` — semantic fixtures for code decoding, coefficient
  values/order, polynomial evaluation, special maps, projections, save policy,
  RNG-generated code size, and graphics fallback.
- `Main.idric` — small deterministic host executable proving the translated
  search loop runs independently of DOS devices.

## Build

The CI lane pins the same current Idriç compiler revision used by the Pauli
ray-tracer work:

```text
dilapidated-shed/Idric@51e3892d4de59943e42e65c60a9814aba792c5d4
```

It bootstraps Idriç, typechecks the test program through `edric`, executes the
semantic tests, then runs the deterministic host driver.

## Deliberate non-goals

This branch does not:

- replace the current Android/ICK Sprott-B viewer;
- claim the Idriç compiler already supplies a VGA/QuickBASIC compatibility
  runtime;
- silently route Idriç source through Clang or the NDK;
- alter Sprott's attractor mathematics in order to fit the current Android
  renderer.

An Android interpreter for `ProgramEffect` belongs at the Android boundary and
can use the existing NDK/GLES path.  The translated search program itself stays
Idriç.
