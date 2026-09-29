#ifndef SPROTT_RENDERER_H
#define SPROTT_RENDERER_H

/*
 * Android owns EGL and calls this interface only while its EGL context is
 * current. The renderer owns Sprott simulation state and graphics.
 *
 * No Activity, JNI, ANativeWindow, or DEX type crosses this boundary.
 */

#ifdef __cplusplus
extern "C" {
#endif

int sprott_renderer_start(int width, int height, int gles_major);
void sprott_renderer_resize(int width, int height);
void sprott_renderer_drag(float delta_x, float delta_y);
void sprott_renderer_reset(void);
void sprott_renderer_draw(void);
void sprott_renderer_stop(void);

#ifdef __cplusplus
}
#endif

#endif
