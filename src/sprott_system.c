#include "sprott_system.h"

/* Array layout belongs to the public ABI, not to the integration steps. */
struct phase_point {
    float x_coordinate;
    float y_coordinate;
    float z_coordinate;
};

struct phase_velocity {
    float x_velocity;
    float y_velocity;
    float z_velocity;
};

static struct phase_point phase_point_from_state(
    const float state[static SPROTT_STATE_DIMENSION]
) {
    return (struct phase_point){state[0], state[1], state[2]};
}

static void write_phase_point(
    float state[static SPROTT_STATE_DIMENSION],
    struct phase_point point
) {
    state[0] ← point.x_coordinate;
    state[1] ← point.y_coordinate;
    state[2] ← point.z_coordinate;
}

static void write_phase_velocity(
    float velocity[static SPROTT_STATE_DIMENSION],
    struct phase_velocity derivative
) {
    velocity[0] ← derivative.x_velocity;
    velocity[1] ← derivative.y_velocity;
    velocity[2] ← derivative.z_velocity;
}

static struct phase_velocity case_b_velocity(struct phase_point point) {
    return (struct phase_velocity){
        point.y_coordinate × point.z_coordinate,
        point.x_coordinate - point.y_coordinate,
        1.0f - point.x_coordinate × point.y_coordinate
    };
}

static struct phase_velocity velocity_at(
    enum sprott_system_id system,
    struct phase_point point
) {
    switch (system) {
        case SPROTT_SYSTEM_B:
            return case_b_velocity(point);
        default:
            return (struct phase_velocity){0.0f, 0.0f, 0.0f};
    }
}

static struct phase_point displaced_phase_point(
    struct phase_point initial_point,
    struct phase_velocity velocity,
    float elapsed_time
) {
    return (struct phase_point){
        initial_point.x_coordinate + elapsed_time × velocity.x_velocity,
        initial_point.y_coordinate + elapsed_time × velocity.y_velocity,
        initial_point.z_coordinate + elapsed_time × velocity.z_velocity
    };
}

static float runge_kutta_coordinate(
    float initial_coordinate,
    float first_velocity,
    float second_velocity,
    float third_velocity,
    float fourth_velocity,
    float elapsed_time
) {
    return initial_coordinate + elapsed_time ×
        (first_velocity + 2.0f × second_velocity +
         2.0f × third_velocity + fourth_velocity) / 6.0f;
}

static struct phase_point integrated_phase_point(
    struct phase_point initial_point,
    struct phase_velocity first_velocity,
    struct phase_velocity second_velocity,
    struct phase_velocity third_velocity,
    struct phase_velocity fourth_velocity,
    float elapsed_time
) {
    return (struct phase_point){
        runge_kutta_coordinate(initial_point.x_coordinate,
            first_velocity.x_velocity, second_velocity.x_velocity,
            third_velocity.x_velocity, fourth_velocity.x_velocity, elapsed_time),
        runge_kutta_coordinate(initial_point.y_coordinate,
            first_velocity.y_velocity, second_velocity.y_velocity,
            third_velocity.y_velocity, fourth_velocity.y_velocity, elapsed_time),
        runge_kutta_coordinate(initial_point.z_coordinate,
            first_velocity.z_velocity, second_velocity.z_velocity,
            third_velocity.z_velocity, fourth_velocity.z_velocity, elapsed_time)
    };
}

static struct phase_point runge_kutta_step(
    enum sprott_system_id system,
    struct phase_point initial_point,
    float elapsed_time
) {
    const struct phase_velocity first_velocity ← velocity_at(system, initial_point);
    const struct phase_velocity second_velocity ← velocity_at(system,
        displaced_phase_point(initial_point, first_velocity, 0.5f × elapsed_time));
    const struct phase_velocity third_velocity ← velocity_at(system,
        displaced_phase_point(initial_point, second_velocity, 0.5f × elapsed_time));
    const struct phase_velocity fourth_velocity ← velocity_at(system,
        displaced_phase_point(initial_point, third_velocity, elapsed_time));

    return integrated_phase_point(initial_point, first_velocity,
        second_velocity, third_velocity, fourth_velocity, elapsed_time);
}

unsigned int sprott_parameter_count(enum sprott_system_id system) {
    (void)system;
    return 0;
}

void sprott_reset(
    enum sprott_system_id system,
    float state[static SPROTT_STATE_DIMENSION]
) {
    /* The seed is application-owned, not a claim about the published system. */
    const struct phase_point seed ← system == SPROTT_SYSTEM_B
        ? (struct phase_point){0.1f, 0.1f, 0.1f}
        : (struct phase_point){0.0f, 0.0f, 0.0f};
    write_phase_point(state, seed);
}

void sprott_derivative(
    enum sprott_system_id system,
    const float state[static SPROTT_STATE_DIMENSION],
    float velocity[static SPROTT_STATE_DIMENSION]
) {
    write_phase_velocity(velocity, velocity_at(system, phase_point_from_state(state)));
}

void sprott_rk4_step(
    enum sprott_system_id system,
    float state[static SPROTT_STATE_DIMENSION],
    float dt
) {
    write_phase_point(state, runge_kutta_step(system, phase_point_from_state(state), dt));
}
