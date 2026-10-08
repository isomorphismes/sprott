/* Frozen main e7ff723337102f189a16859b17ea52457472e675; ordinary C is intentional. */
#include "sprott_system.h"

static void case_b_derivative(
    const float state[static SPROTT_STATE_DIMENSION],
    float velocity[static SPROTT_STATE_DIMENSION]
) {
    const float x = state[0];
    const float y = state[1];
    const float z = state[2];

    velocity[0] = y * z;
    velocity[1] = x - y;
    velocity[2] = 1.0f - x * y;
}

unsigned int sprott_parameter_count(enum sprott_system_id system) {
    switch (system) {
        case SPROTT_SYSTEM_B:
            return 0;
        default:
            return 0;
    }
}

void sprott_reset(
    enum sprott_system_id system,
    float state[static SPROTT_STATE_DIMENSION]
) {
    switch (system) {
        case SPROTT_SYSTEM_B:
            /*
             * Application-owned seed. The published system supplies the
             * vector field; this seed is not claimed as a published value.
             */
            state[0] = 0.1f;
            state[1] = 0.1f;
            state[2] = 0.1f;
            return;

        default:
            state[0] = 0.0f;
            state[1] = 0.0f;
            state[2] = 0.0f;
            return;
    }
}

void sprott_derivative(
    enum sprott_system_id system,
    const float state[static SPROTT_STATE_DIMENSION],
    float velocity[static SPROTT_STATE_DIMENSION]
) {
    switch (system) {
        case SPROTT_SYSTEM_B:
            case_b_derivative(state, velocity);
            return;

        default:
            velocity[0] = 0.0f;
            velocity[1] = 0.0f;
            velocity[2] = 0.0f;
            return;
    }
}

static void add_scaled(
    float out[static SPROTT_STATE_DIMENSION],
    const float a[static SPROTT_STATE_DIMENSION],
    const float b[static SPROTT_STATE_DIMENSION],
    float scale
) {
    out[0] = a[0] + scale * b[0];
    out[1] = a[1] + scale * b[1];
    out[2] = a[2] + scale * b[2];
}

void sprott_rk4_step(
    enum sprott_system_id system,
    float state[static SPROTT_STATE_DIMENSION],
    float dt
) {
    float k1[SPROTT_STATE_DIMENSION];
    float k2[SPROTT_STATE_DIMENSION];
    float k3[SPROTT_STATE_DIMENSION];
    float k4[SPROTT_STATE_DIMENSION];
    float sample[SPROTT_STATE_DIMENSION];

    sprott_derivative(system, state, k1);

    add_scaled(sample, state, k1, 0.5f * dt);
    sprott_derivative(system, sample, k2);

    add_scaled(sample, state, k2, 0.5f * dt);
    sprott_derivative(system, sample, k3);

    add_scaled(sample, state, k3, dt);
    sprott_derivative(system, sample, k4);

    state[0] += dt * (k1[0] + 2.0f * k2[0] + 2.0f * k3[0] + k4[0]) / 6.0f;
    state[1] += dt * (k1[1] + 2.0f * k2[1] + 2.0f * k3[1] + k4[1]) / 6.0f;
    state[2] += dt * (k1[2] + 2.0f * k2[2] + 2.0f * k3[2] + k4[2]) / 6.0f;
}
