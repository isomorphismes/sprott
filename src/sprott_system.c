#include "sprott_system.h"

static struct sprott_state add_scaled(
    const struct sprott_state *a,
    const struct sprott_state *b,
    float scale
) {
    struct sprott_state out = {
        .x = a->x + scale * b->x,
        .y = a->y + scale * b->y,
        .z = a->z + scale * b->z,
    };
    return out;
}

static void case_b_derivative(
    const struct sprott_state *state,
    const float *parameters,
    struct sprott_state *velocity
) {
    (void)parameters;

    velocity->x = state->y * state->z;
    velocity->y = state->x - state->y;
    velocity->z = 1.0f - state->x * state->y;
}

static void case_b_reset(
    struct sprott_state *state,
    float *parameters
) {
    (void)parameters;

    /*
     * Application-owned seed. The published system supplies the vector field;
     * this implementation does not claim this seed as a published parameter.
     */
    state->x = 0.1f;
    state->y = 0.1f;
    state->z = 0.1f;
}

static const struct sprott_system case_b = {
    .id = "sprott-b",
    .name = "Sprott B",
    .parameter_count = 0,
    .derivative = case_b_derivative,
    .reset = case_b_reset,
};

const struct sprott_system *sprott_case_b(void) {
    return &case_b;
}

void sprott_rk4_step(
    const struct sprott_system *system,
    struct sprott_state *state,
    const float *parameters,
    float dt
) {
    struct sprott_state k1;
    struct sprott_state k2;
    struct sprott_state k3;
    struct sprott_state k4;

    system->derivative(state, parameters, &k1);

    struct sprott_state sample = add_scaled(state, &k1, 0.5f * dt);
    system->derivative(&sample, parameters, &k2);

    sample = add_scaled(state, &k2, 0.5f * dt);
    system->derivative(&sample, parameters, &k3);

    sample = add_scaled(state, &k3, dt);
    system->derivative(&sample, parameters, &k4);

    state->x += dt * (k1.x + 2.0f * k2.x + 2.0f * k3.x + k4.x) / 6.0f;
    state->y += dt * (k1.y + 2.0f * k2.y + 2.0f * k3.y + k4.y) / 6.0f;
    state->z += dt * (k1.z + 2.0f * k2.z + 2.0f * k3.z + k4.z) / 6.0f;
}
