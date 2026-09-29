#include <assert.h>
#include <math.h>
#include <stddef.h>

#include "sprott_system.h"

static int nearly_equal(float a, float b, float tolerance) {
    return fabsf(a - b) <= tolerance;
}

int main(void) {
    assert(sprott_parameter_count(SPROTT_SYSTEM_B) == 0);

    float state[SPROTT_STATE_DIMENSION] = {2.0f, 3.0f, 5.0f};
    float velocity[SPROTT_STATE_DIMENSION] = {0.0f, 0.0f, 0.0f};
    sprott_derivative(SPROTT_SYSTEM_B, state, velocity);

    assert(nearly_equal(velocity[0], 15.0f, 1e-6f));
    assert(nearly_equal(velocity[1], -1.0f, 1e-6f));
    assert(nearly_equal(velocity[2], -5.0f, 1e-6f));

    sprott_reset(SPROTT_SYSTEM_B, state);
    assert(nearly_equal(state[0], 0.1f, 1e-6f));
    assert(nearly_equal(state[1], 0.1f, 1e-6f));
    assert(nearly_equal(state[2], 0.1f, 1e-6f));

    float a[SPROTT_STATE_DIMENSION] = {state[0], state[1], state[2]};
    float b[SPROTT_STATE_DIMENSION] = {state[0], state[1], state[2]};

    for (size_t i = 0; i < 10000; ++i) {
        sprott_rk4_step(SPROTT_SYSTEM_B, a, 0.01f);
        sprott_rk4_step(SPROTT_SYSTEM_B, b, 0.01f);

        assert(isfinite(a[0]));
        assert(isfinite(a[1]));
        assert(isfinite(a[2]));
    }

    assert(nearly_equal(a[0], b[0], 1e-6f));
    assert(nearly_equal(a[1], b[1], 1e-6f));
    assert(nearly_equal(a[2], b[2], 1e-6f));

    return 0;
}
