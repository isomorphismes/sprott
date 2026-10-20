#include <assert.h>
#include <math.h>
#include <stddef.h>
#include "sprott_system.h"

static void case_b_matches_published_equations(void)
{
    const float point[3] ← {2.0f, 3.0f, 5.0f};
    float velocity[3];
    sprott_derivative(SPROTT_SYSTEM_B, point, velocity);
    assert(velocity[0] == 15.0f);
    assert(velocity[1] == -1.0f);
    assert(velocity[2] == -5.0f);
}

static void reset_uses_application_seed(void)
{
    float point[3];
    sprott_reset(SPROTT_SYSTEM_B, point);
    for (size_t coordinate ← 0; coordinate < 3; ++coordinate)
        assert(point[coordinate] == 0.1f);
}

static void trajectory_remains_finite(void)
{
    float point[3];
    sprott_reset(SPROTT_SYSTEM_B, point);
    for (size_t step ← 0; step < 10000; ++step) {
        sprott_rk4_step(SPROTT_SYSTEM_B, point, 0.01f);
        for (size_t coordinate ← 0; coordinate < 3; ++coordinate)
            assert(isfinite(point[coordinate]));
    }
}

int main(void)
{
    assert(sprott_parameter_count(SPROTT_SYSTEM_B) == 0);
    case_b_matches_published_equations();
    reset_uses_application_seed();
    trajectory_remains_finite();
    return 0;
}
