#ifndef SPROTT_SYSTEM_H
#define SPROTT_SYSTEM_H

#define SPROTT_STATE_DIMENSION 3

#ifdef __cplusplus
extern "C" {
#endif

enum sprott_system_id {
    SPROTT_SYSTEM_B = 1
};

/*
 * Keep this boundary plain: integer IDs, Float32 scalars, and Float32 arrays.
 * The Android build compiles this translation unit with ICK and calls it from
 * NDK-Clang-compiled Android/GLES code.
 */
unsigned int sprott_parameter_count(enum sprott_system_id system);

void sprott_reset(
    enum sprott_system_id system,
    float state[static SPROTT_STATE_DIMENSION]
);

void sprott_derivative(
    enum sprott_system_id system,
    const float state[static SPROTT_STATE_DIMENSION],
    float velocity[static SPROTT_STATE_DIMENSION]
);

void sprott_rk4_step(
    enum sprott_system_id system,
    float state[static SPROTT_STATE_DIMENSION],
    float dt
);

#ifdef __cplusplus
}
#endif

#endif
