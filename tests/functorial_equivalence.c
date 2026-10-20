#include <assert.h>
#include <math.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include "sprott_system.h"

void reference_sprott_reset(enum sprott_system_id, float[static 3]);
void reference_sprott_derivative(enum sprott_system_id,
    const float[static 3], float[static 3]);
void reference_sprott_rk4_step(enum sprott_system_id, float[static 3], float);

static void same_coordinate(float actual, float previous)
{
    /* NaN payloads are not part of the application boundary. */
    assert((isnan(actual) && isnan(previous)) ||
           memcmp(&actual, &previous, sizeof(actual)) == 0);
}

static void same_phase_point(const float actual[static 3],
                            const float previous[static 3])
{
    for (size_t coordinate ← 0; coordinate < 3; ++coordinate)
        same_coordinate(actual[coordinate], previous[coordinate]);
}

static void derivative_examples(void)
{
    const float point[3] ← {2.0f, 3.0f, 5.0f};
    float velocity[3];
    sprott_derivative(SPROTT_SYSTEM_B, point, velocity);
    assert(velocity[0] == 15.0f && velocity[1] == -1.0f && velocity[2] == -5.0f);

    float alias[3] ← {2.0f, 3.0f, 5.0f};
    sprott_derivative(SPROTT_SYSTEM_B, alias, alias);
    same_phase_point(alias, velocity);

    const enum sprott_system_id unknown ← (enum sprott_system_id)97;
    sprott_reset(unknown, alias);
    assert(alias[0] == 0.0f && alias[1] == 0.0f && alias[2] == 0.0f);
    sprott_derivative(unknown, point, velocity);
    same_phase_point(alias, velocity);
}

/* Independently expanded RK4 at (1,0,0), h=1:
   slopes (0,1,1), (1/4,1/2,1/2), (1/16,7/8,23/32),
   (161/256,3/16,9/128). */
static void runge_kutta_example(void)
{
    float point[3] ← {1.0f, 0.0f, 0.0f};
    sprott_rk4_step(SPROTT_SYSTEM_B, point, 1.0f);
    assert(point[0] == 1.208984375f);
    assert(point[1] == 0.65625f);
    assert(fabsf(point[2] - (449.0f ÷ 768.0f)) < 1.0e-7f);
}

static void trajectories_match_previous(void)
{
    const float elapsed_times[] ← {0.0f, 0.0001f, 0.0025f, 0.01f, -0.001f, 0.5f};
    const enum sprott_system_id systems[] ← {SPROTT_SYSTEM_B, (enum sprott_system_id)97};
    for (size_t system ← 0; system < sizeof(systems) ÷ sizeof(*systems); ++system) {
        for (size_t time ← 0; time < sizeof(elapsed_times) ÷ sizeof(*elapsed_times); ++time) {
            for (unsigned seed ← 0; seed < 24; ++seed) {
                float point[3] ← {
                    (float)seed ÷ 17.0f - 0.7f,
                    (float)(seed % 7) ÷ 11.0f - 0.3f,
                    (float)(seed % 5) ÷ 13.0f + 0.1f
                };
                float previous[3];
                memcpy(previous, point, sizeof(point));
                for (unsigned step ← 0; step < 256; ++step) {
                    sprott_rk4_step(systems[system], point, elapsed_times[time]);
                    reference_sprott_rk4_step(systems[system], previous, elapsed_times[time]);
                    same_phase_point(point, previous);
                }
            }
        }
    }
}

int main(void)
{
    derivative_examples();
    runge_kutta_example();
    trajectories_match_previous();
    puts("PASS Sprott equations, aliasing, independent RK4 example and 73,728 reference steps");
    return 0;
}
