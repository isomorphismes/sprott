#include <GLES2/gl2.h>

#include <math.h>
#include <stddef.h>

#include "sprott_renderer.h"
#include "sprott_system.h"

enum {
    SPROTT_TRAIL_POINTS = 4096,
    SPROTT_BURN_IN_STEPS = 2048,
    SPROTT_STEPS_PER_POINT = 4,
};

static const float sprott_dt = 0.01f;

static int current_width = 1;
static int current_height = 1;
static float yaw = 0.35f;
static float pitch = -0.20f;

static float trail[SPROTT_TRAIL_POINTS][SPROTT_STATE_DIMENSION];
static GLfloat projected[SPROTT_TRAIL_POINTS * 2];

static float trail_center[SPROTT_STATE_DIMENSION];
static float trail_radius = 1.0f;

static GLuint program = 0;
static GLuint vertex_buffer = 0;
static GLint position_location = -1;
static GLint color_location = -1;

static GLuint compile_shader(GLenum type, const char *source) {
    GLuint shader = glCreateShader(type);
    if (shader == 0) {
        return 0;
    }

    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint compiled = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (compiled != GL_TRUE) {
        glDeleteShader(shader);
        return 0;
    }

    return shader;
}

static GLuint build_program(void) {
    static const char vertex_source[] =
        "attribute vec2 a_position;\n"
        "void main() {\n"
        "  gl_Position = vec4(a_position, 0.0, 1.0);\n"
        "}\n";

    static const char fragment_source[] =
        "precision mediump float;\n"
        "uniform vec4 u_color;\n"
        "void main() {\n"
        "  gl_FragColor = u_color;\n"
        "}\n";

    GLuint vertex = compile_shader(GL_VERTEX_SHADER, vertex_source);
    if (vertex == 0) {
        return 0;
    }

    GLuint fragment = compile_shader(GL_FRAGMENT_SHADER, fragment_source);
    if (fragment == 0) {
        glDeleteShader(vertex);
        return 0;
    }

    GLuint linked = glCreateProgram();
    if (linked == 0) {
        glDeleteShader(vertex);
        glDeleteShader(fragment);
        return 0;
    }

    glAttachShader(linked, vertex);
    glAttachShader(linked, fragment);
    glLinkProgram(linked);

    glDeleteShader(vertex);
    glDeleteShader(fragment);

    GLint ok = GL_FALSE;
    glGetProgramiv(linked, GL_LINK_STATUS, &ok);
    if (ok != GL_TRUE) {
        glDeleteProgram(linked);
        return 0;
    }

    return linked;
}

static void build_trail(void) {
    float state[SPROTT_STATE_DIMENSION];
    sprott_reset(SPROTT_SYSTEM_B, state);

    for (int i = 0; i < SPROTT_BURN_IN_STEPS; ++i) {
        sprott_rk4_step(SPROTT_SYSTEM_B, state, sprott_dt);
    }

    float minimum[SPROTT_STATE_DIMENSION] = {
        state[0], state[1], state[2]
    };
    float maximum[SPROTT_STATE_DIMENSION] = {
        state[0], state[1], state[2]
    };

    for (int i = 0; i < SPROTT_TRAIL_POINTS; ++i) {
        for (int step = 0; step < SPROTT_STEPS_PER_POINT; ++step) {
            sprott_rk4_step(SPROTT_SYSTEM_B, state, sprott_dt);
        }

        for (int axis = 0; axis < SPROTT_STATE_DIMENSION; ++axis) {
            trail[i][axis] = state[axis];
            if (state[axis] < minimum[axis]) minimum[axis] = state[axis];
            if (state[axis] > maximum[axis]) maximum[axis] = state[axis];
        }
    }

    for (int axis = 0; axis < SPROTT_STATE_DIMENSION; ++axis) {
        trail_center[axis] = 0.5f * (minimum[axis] + maximum[axis]);
    }

    trail_radius = 0.0f;
    for (int i = 0; i < SPROTT_TRAIL_POINTS; ++i) {
        const float x = trail[i][0] - trail_center[0];
        const float y = trail[i][1] - trail_center[1];
        const float z = trail[i][2] - trail_center[2];
        const float radius = sqrtf(x * x + y * y + z * z);
        if (radius > trail_radius) {
            trail_radius = radius;
        }
    }

    if (!(trail_radius > 0.0f) || !isfinite(trail_radius)) {
        trail_radius = 1.0f;
    }
}

static void project_trail(void) {
    const float cy = cosf(yaw);
    const float sy = sinf(yaw);
    const float cp = cosf(pitch);
    const float sp = sinf(pitch);

    const float aspect =
        current_height > 0 ? (float)current_width / (float)current_height : 1.0f;

    float x_scale = 0.90f / trail_radius;
    float y_scale = 0.90f / trail_radius;

    if (aspect > 1.0f) {
        x_scale /= aspect;
    } else if (aspect > 0.0f) {
        y_scale *= aspect;
    }

    for (int i = 0; i < SPROTT_TRAIL_POINTS; ++i) {
        const float x = trail[i][0] - trail_center[0];
        const float y = trail[i][1] - trail_center[1];
        const float z = trail[i][2] - trail_center[2];

        const float rx = cy * x + sy * z;
        const float rz = -sy * x + cy * z;
        const float ry = cp * y - sp * rz;

        projected[2 * i] = rx * x_scale;
        projected[2 * i + 1] = ry * y_scale;
    }
}

int sprott_renderer_start(int width, int height, int gles_major) {
    if (gles_major < 2) {
        return 0;
    }

    current_width = width > 0 ? width : 1;
    current_height = height > 0 ? height : 1;

    program = build_program();
    if (program == 0) {
        return 0;
    }

    position_location = glGetAttribLocation(program, "a_position");
    color_location = glGetUniformLocation(program, "u_color");
    if (position_location < 0 || color_location < 0) {
        sprott_renderer_stop();
        return 0;
    }

    glGenBuffers(1, &vertex_buffer);
    if (vertex_buffer == 0) {
        sprott_renderer_stop();
        return 0;
    }

    build_trail();
    glViewport(0, 0, current_width, current_height);
    return 1;
}

void sprott_renderer_resize(int width, int height) {
    current_width = width > 0 ? width : 1;
    current_height = height > 0 ? height : 1;
    glViewport(0, 0, current_width, current_height);
}

void sprott_renderer_drag(float delta_x, float delta_y) {
    yaw += 3.0f * delta_x;
    pitch += 3.0f * delta_y;

    const float limit = 1.50f;
    if (pitch > limit) pitch = limit;
    if (pitch < -limit) pitch = -limit;
}

void sprott_renderer_reset(void) {
    yaw = 0.35f;
    pitch = -0.20f;
    build_trail();
}

void sprott_renderer_draw(void) {
    project_trail();

    glViewport(0, 0, current_width, current_height);
    glClearColor(0.015f, 0.018f, 0.022f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(program);
    glUniform4f(color_location, 0.88f, 0.92f, 0.96f, 1.0f);

    glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);
    glBufferData(
        GL_ARRAY_BUFFER,
        sizeof(projected),
        projected,
        GL_DYNAMIC_DRAW
    );

    glEnableVertexAttribArray((GLuint)position_location);
    glVertexAttribPointer(
        (GLuint)position_location,
        2,
        GL_FLOAT,
        GL_FALSE,
        2 * (GLsizei)sizeof(GLfloat),
        (const void *)0
    );

    glDrawArrays(GL_LINE_STRIP, 0, SPROTT_TRAIL_POINTS);

    glDisableVertexAttribArray((GLuint)position_location);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

void sprott_renderer_stop(void) {
    if (vertex_buffer != 0) {
        glDeleteBuffers(1, &vertex_buffer);
        vertex_buffer = 0;
    }

    if (program != 0) {
        glDeleteProgram(program);
        program = 0;
    }

    position_location = -1;
    color_location = -1;
}
