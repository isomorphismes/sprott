#include <assert.h>
#include <math.h>
#include <stddef.h>

#include "sprott_system.h"

static int nearly_equal(float a, float b, float tolerance) {
    return fabsf(a - b) <= tolerance;
}

int main(void) {
    const struct sprott_system *system = sprott_case_b();

    assert(system != NULL);
    assert(system->parameter_count == 0);

    struct sprott_state state = {2.0f, 3.0f, 5.0f};
    struct sprott_state velocity = {0.0f, 0.0f, 0.0f};
    system->derivative(&state, NULL, &velocity);

    assert(nearly_equal(velocity.x, 15.0f, 1e-6f));
    assert(nearly_equal(velocity.y, -1.0f, 1e-6f));
    assert(nearly_equal(velocity.z, -5.0f, 1e-6f));

    system->reset(&state, NULL);
    assert(nearly_equal(state.x, 0.1f, 1e-6f));
    assert(nearly_equal(state.y, 0.1f, 1e-6f));
    assert(nearly_equal(state.z, 0.1f, 1e-6f));

    struct sprott_state a = state;
    struct sprott_state b = state;

    for (size_t i = 0; i < 10000; ++i) {
        sprott_rk4_step(system, &a, NULL, 0.01f);
        sprott_rk4_step(system, &b, NULL, 0.01f);

        assert(isfinite(a.x));
        assert(isfinite(a.y));
        assert(isfinite(a.z));
    }

    assert(nearly_equal(a.x, b.x, 1e-6f));
    assert(nearly_equal(a.y, b.y, 1e-6f));
    assert(nearly_equal(a.z, b.z, 1e-6f));

    return 0;
}
