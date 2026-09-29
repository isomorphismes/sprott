# Agda translation

\`Sprott.Prog06\` is an independent Agda reconstruction of the behavior of J. C. Sprott's freeware \`PROG06.BAS\` strange-attractor search program.

It covers the complete computational seam of that program:

- 2-D quadratic-map coefficient generation;
- the 100-slot shuffled random-number scheme;
- iteration of the map;
- the nearby-orbit Lyapunov estimate;
- rejection of unbounded, fixed, and low-Lyapunov candidates;
- the 11,000-iteration search horizon;
- history buffering and viewport fitting;
- plot, border, clear-screen, and tone events;
- sound toggling, restart, and quit control flow.

The Agda code does **not** copy the BASIC program text. The repository policy requires independent implementation of published algorithms rather than a source-text derivative. Sprott's software page identifies the BASIC program as copyrighted freeware and permits redistribution subject to its stated restrictions. The Agda module therefore reconstructs behavior while retaining provenance links instead of vendoring the BASIC file.

Primary references:

- https://sprott.physics.wisc.edu/SOFTWARE.HTM
- https://sprott.physics.wisc.edu/software/PROG06.BAS
- https://sprott.physics.wisc.edu/SA.HTM

## Runtime boundary

The DOS graphics and \`SOUND\` effects become explicit \`Event\` values. A host can interpret those events with an Android/NDK, desktop, or notebook frontend without putting platform effects into the numerical search core.

BASIC's primitive \`RND\` stream depended on its runtime. This translation preserves Sprott's 100-slot shuffle but supplies a deterministic 16-bit LCG underneath it, so an Agda run is reproducible without claiming bit-identical output to a particular historical BASIC runtime.

## Typecheck

From the repository root with Agda installed:

\`\`\`sh
agda -i agda agda/Sprott/Prog06.agda
agda -i agda agda/Sprott/Smoke.agda
\`\`\`

The module depends only on Agda builtins, not the standard library.
