#ifndef SPROTT_SYSTEM_H
#define SPROTT_SYSTEM_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sprott_state {
    float x;
    float y;
    float z;
};

struct sprott_system {
    const char *id;
    const char *name;
    size_t parameter_count;

    void (*derivative)(
        const struct sprott_state *state,
        const float *parameters,
        struct sprott_state *velocity
    );

    void (*reset)(
        struct sprott_state *state,
        float *parameters
    );
};

const struct sprott_system *sprott_case_b(void);

void sprott_rk4_step(
    const struct sprott_system *system,
    struct sprott_state *state,
    const float *parameters,
    float dt
);

#ifdef __cplusplus
}
#endif

#endif
