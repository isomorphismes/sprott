# D translation of Sprott's full BASIC program

## Source target

This branch targets J. C. Sprott's `PROG28.BAS`, the 1993 final BASIC program from the disk accompanying *Strange Attractors: Creating Patterns in Chaos*.

Official source index:

- https://sprott.physics.wisc.edu/fractals/bookdisk/
- https://sprott.physics.wisc.edu/fractals/bookdisk/PROG28.BAS

The book-disk page identifies the program files as copyrighted by J. C. Sprott and permits personal download and noncommercial redistribution with source acknowledgement. It does not state a general modification license. This branch therefore does not vendor the BASIC file or preserve its line-oriented program text. The D implementation independently expresses the published algorithms and observable program behavior in a different program structure.

## Whole-program scope

The D implementation covers the complete computational scope of `PROG28.BAS`:

- random search for attractors;
- encoded attractor strings and coefficient decoding;
- polynomial maps in dimensions 1 through 4;
- polynomial ODEs in the original 3-D and 4-D modes;
- polynomial orders 2 through 5;
- all six special-system families selected by codes `Y` through `^`;
- shuffled random coefficient generation;
- Lyapunov-exponent estimation;
- fractal-dimension estimation;
- transient bounds and dynamic plotting window;
- delayed-coordinate display for 1-D maps;
- planar, spherical, horizontal-cylinder, vertical-cylinder, and torus projections;
- all seven third-dimension display modes: projection, shadow, bands, colors, anaglyph, stereogram, and slices;
- all three fourth-dimension display modes: projection, bands, and colors;
- the original pitch and duration formulas for sound events;
- `SA.DIC` attractor logging;
- dictionary evaluation with favorite/discard/exit actions;
- `FAVORITE.DIC` output;
- X/Y/Z/W data-file output for the original iteration interval.

## Host adaptation

The original program binds directly to IBM PC BASIC graphics, keyboard polling, palette state, and `SOUND`. D separates those effects from the dynamical-system logic.

The current host implementation uses:

- a 640×480 software raster with an EGA-like 16-color palette;
- binary PPM output for graphics;
- TSV tone events for the original frequency/duration requests rather than PC-speaker playback;
- `search`, `code`, and `evaluate` command modes in place of the DOS menu;
- command-line options for projection, dimension rendering, sound, iteration count, and coordinate-data saving;
- an interactive evaluation prompt preserving favorite/discard/exit plus the original C/H/N/P/R/S/V display and output controls; the host re-renders the code when a display control changes.

The numerical and display-mode branches remain present. The host adaptation does not attempt cycle-exact emulation of QuickBASIC's VGA, PC speaker, `INKEY$`, or `RND` implementation. The D search keeps Sprott's 100-entry shuffle strategy but uses a deterministic modern PRNG underneath it, so a given timer seed does not reproduce QuickBASIC's candidate sequence bit-for-bit.

## Build policy

`tools/build.sh` refuses to build unless the caller identifies the pinned ICK GDC source commit:

`dilapidated-shed/ick@72b28ef09d2f4bcddf0718bb43d45a231878f5dc`

That ICK branch includes the imported GDC frontend, druntime, and Phobos. The workflow builds that compiler from source, then compiles and tests this D program with the resulting ICK GDC driver.

The current capability gap is packaging, not D language coverage: ICK's GDC line has a proved native full-stack build, but the Sprott repository cannot consume a small prebuilt ICK D toolchain artifact yet. CI therefore rebuilds ICK GDC before building Sprott. Stock GDC, DMD, and LDC do not satisfy this branch's build script.
