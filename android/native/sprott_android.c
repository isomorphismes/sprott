#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <android/input.h>
#include <android/log.h>
#include <android/native_window.h>
#include <android_native_app_glue.h>

#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "sprott_renderer.h"

#define SPROTT_LOG_TAG "SprottNative"
#define SPROTT_LOG(...) __android_log_print(ANDROID_LOG_INFO, SPROTT_LOG_TAG, __VA_ARGS__)

struct sprott_android_state {
    struct android_app *app;

    EGLDisplay display;
    EGLSurface surface;
    EGLContext context;

    int gles_major;
    int width;
    int height;

    bool renderer_started;
    bool redraw;
    bool touching;
    bool moved;

    float previous_x;
    float previous_y;
};

static void sprott_stop_surface(struct sprott_android_state *state) {
    if (state->renderer_started) {
        sprott_renderer_stop();
        state->renderer_started = false;
    }

    if (state->display != EGL_NO_DISPLAY) {
        eglMakeCurrent(
            state->display,
            EGL_NO_SURFACE,
            EGL_NO_SURFACE,
            EGL_NO_CONTEXT
        );

        if (state->context != EGL_NO_CONTEXT) {
            eglDestroyContext(state->display, state->context);
        }
        if (state->surface != EGL_NO_SURFACE) {
            eglDestroySurface(state->display, state->surface);
        }

        eglTerminate(state->display);
    }

    state->display = EGL_NO_DISPLAY;
    state->surface = EGL_NO_SURFACE;
    state->context = EGL_NO_CONTEXT;
    state->gles_major = 0;
    state->width = 0;
    state->height = 0;
    state->redraw = false;
}

static bool sprott_choose_config(
    EGLDisplay display,
    int gles_major,
    EGLConfig *config
) {
    const EGLint renderable =
        gles_major >= 3 ? EGL_OPENGL_ES3_BIT_KHR : EGL_OPENGL_ES2_BIT;

    const EGLint attributes[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, renderable,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_NONE
    };

    EGLint count = 0;
    return eglChooseConfig(display, attributes, config, 1, &count) == EGL_TRUE
        && count == 1;
}

static bool sprott_start_surface(struct sprott_android_state *state) {
    if (state->app->window == NULL) {
        return false;
    }

    sprott_stop_surface(state);

    state->display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (state->display == EGL_NO_DISPLAY) {
        return false;
    }

    if (eglInitialize(state->display, NULL, NULL) != EGL_TRUE) {
        sprott_stop_surface(state);
        return false;
    }

    if (eglBindAPI(EGL_OPENGL_ES_API) != EGL_TRUE) {
        sprott_stop_surface(state);
        return false;
    }

    EGLConfig config = NULL;
    int gles_major = 3;

    if (!sprott_choose_config(state->display, gles_major, &config)) {
        gles_major = 2;
        if (!sprott_choose_config(state->display, gles_major, &config)) {
            sprott_stop_surface(state);
            return false;
        }
    }

    EGLint native_format = 0;
    if (eglGetConfigAttrib(
            state->display,
            config,
            EGL_NATIVE_VISUAL_ID,
            &native_format
        ) != EGL_TRUE) {
        sprott_stop_surface(state);
        return false;
    }

    ANativeWindow_setBuffersGeometry(
        state->app->window,
        0,
        0,
        native_format
    );

    const EGLint context_attributes[] = {
        EGL_CONTEXT_CLIENT_VERSION, gles_major,
        EGL_NONE
    };

    state->context = eglCreateContext(
        state->display,
        config,
        EGL_NO_CONTEXT,
        context_attributes
    );
    if (state->context == EGL_NO_CONTEXT) {
        sprott_stop_surface(state);
        return false;
    }

    state->surface = eglCreateWindowSurface(
        state->display,
        config,
        state->app->window,
        NULL
    );
    if (state->surface == EGL_NO_SURFACE) {
        sprott_stop_surface(state);
        return false;
    }

    if (eglMakeCurrent(
            state->display,
            state->surface,
            state->surface,
            state->context
        ) != EGL_TRUE) {
        sprott_stop_surface(state);
        return false;
    }

    EGLint width = 0;
    EGLint height = 0;
    eglQuerySurface(state->display, state->surface, EGL_WIDTH, &width);
    eglQuerySurface(state->display, state->surface, EGL_HEIGHT, &height);

    state->gles_major = gles_major;
    state->width = width;
    state->height = height;

    if (!sprott_renderer_start(width, height, gles_major)) {
        sprott_stop_surface(state);
        return false;
    }

    state->renderer_started = true;
    state->redraw = true;
    SPROTT_LOG("EGL surface ready: %dx%d GLES %d", width, height, gles_major);
    return true;
}

static void sprott_resize(struct sprott_android_state *state) {
    if (!state->renderer_started || state->surface == EGL_NO_SURFACE) {
        return;
    }

    EGLint width = 0;
    EGLint height = 0;
    eglQuerySurface(state->display, state->surface, EGL_WIDTH, &width);
    eglQuerySurface(state->display, state->surface, EGL_HEIGHT, &height);

    if (width > 0 && height > 0) {
        state->width = width;
        state->height = height;
        sprott_renderer_resize(width, height);
        state->redraw = true;
    }
}

static void sprott_handle_command(struct android_app *app, int32_t command) {
    struct sprott_android_state *state =
        (struct sprott_android_state *)app->userData;

    switch (command) {
        case APP_CMD_INIT_WINDOW:
            (void)sprott_start_surface(state);
            break;

        case APP_CMD_TERM_WINDOW:
            sprott_stop_surface(state);
            break;

        case APP_CMD_WINDOW_RESIZED:
        case APP_CMD_CONFIG_CHANGED:
            sprott_resize(state);
            break;

        case APP_CMD_GAINED_FOCUS:
            state->redraw = true;
            break;

        default:
            break;
    }
}

static int32_t sprott_handle_input(
    struct android_app *app,
    AInputEvent *event
) {
    struct sprott_android_state *state =
        (struct sprott_android_state *)app->userData;

    if (AInputEvent_getType(event) != AINPUT_EVENT_TYPE_MOTION) {
        return 0;
    }

    const int32_t action =
        AMotionEvent_getAction(event) & AMOTION_EVENT_ACTION_MASK;
    const float x = AMotionEvent_getX(event, 0);
    const float y = AMotionEvent_getY(event, 0);

    if (action == AMOTION_EVENT_ACTION_DOWN) {
        state->touching = true;
        state->moved = false;
        state->previous_x = x;
        state->previous_y = y;
        return 1;
    }

    if (action == AMOTION_EVENT_ACTION_MOVE && state->touching) {
        const int short_side_pixels =
            state->width > 0 && state->height > 0
                ? (state->width < state->height
                    ? state->width
                    : state->height)
                : 1;

        const float short_side = (float)short_side_pixels;
        const float delta_x = (x - state->previous_x) / short_side;
        const float delta_y = (y - state->previous_y) / short_side;

        if (fabsf(delta_x) + fabsf(delta_y) > 0.001f) {
            state->moved = true;
            sprott_renderer_drag(delta_x, delta_y);
            state->redraw = true;
        }

        state->previous_x = x;
        state->previous_y = y;
        return 1;
    }

    if ((action == AMOTION_EVENT_ACTION_UP
         || action == AMOTION_EVENT_ACTION_CANCEL)
        && state->touching) {
        if (action == AMOTION_EVENT_ACTION_UP && !state->moved) {
            sprott_renderer_reset();
            state->redraw = true;
        }

        state->touching = false;
        state->moved = false;
        return 1;
    }

    return 0;
}

void android_main(struct android_app *app) {
    app_dummy();
    SPROTT_LOG("native entry");

    struct sprott_android_state state;
    memset(&state, 0, sizeof(state));

    state.app = app;
    state.display = EGL_NO_DISPLAY;
    state.surface = EGL_NO_SURFACE;
    state.context = EGL_NO_CONTEXT;

    app->userData = &state;
    app->onAppCmd = sprott_handle_command;
    app->onInputEvent = sprott_handle_input;

    for (;;) {
        int events = 0;
        struct android_poll_source *source = NULL;

        const int timeout =
            state.renderer_started && state.redraw ? 0 : -1;

        int ident = 0;
        while ((ident = ALooper_pollOnce(
                    timeout,
                    NULL,
                    &events,
                    (void **)&source
                )) >= 0) {
            (void)ident;

            if (source != NULL) {
                source->process(app, source);
            }

            if (app->destroyRequested != 0) {
                sprott_stop_surface(&state);
                return;
            }

            if (state.renderer_started && state.redraw) {
                break;
            }
        }

        if (app->destroyRequested != 0) {
            sprott_stop_surface(&state);
            return;
        }

        if (state.renderer_started && state.redraw) {
            sprott_renderer_draw();

            if (eglSwapBuffers(state.display, state.surface) != EGL_TRUE) {
                sprott_stop_surface(&state);
                continue;
            }

            state.redraw = false;
        }
    }
}
