#pragma once

#include <stddef.h>
#include <string.h>

#include "dcimgui.h"

#ifdef __cplusplus
extern "C" {
#endif

// Extensions supplied by Ghostty's pkg/dcimgui/ext.cpp.
void ImFontConfig_ImFontConfig(ImFontConfig* self);
void ImGuiStyle_ImGuiStyle(ImGuiStyle* self);

static inline ImGuiContext* witty_cimgui_context_create(void* font_data, int font_len) {
    ImGuiContext* context = ImGui_CreateContext(NULL);
    if (context == NULL) return NULL;

    ImGui_SetCurrentContext(context);
    ImGuiIO* io = ImGui_GetIO();
    io->BackendPlatformName = "ghostty_embedded";
    io->ConfigFlags |= ImGuiConfigFlags_DockingEnable;
    io->ConfigFlags |= ImGuiConfigFlags_IsSRGB;
    io->IniFilename = NULL;
    io->LogFilename = NULL;

    ImFontConfig font_config;
    ImFontConfig_ImFontConfig(&font_config);
    font_config.FontDataOwnedByAtlas = false;
    (void)ImFontAtlas_AddFontFromMemoryTTF(
        io->Fonts,
        font_data,
        font_len,
        32.0f,
        &font_config,
        NULL
    );

    return context;
}

static inline void witty_cimgui_context_destroy(ImGuiContext* context) {
    if (context == NULL) return;
    ImGui_SetCurrentContext(context);
    ImGui_DestroyContext(context);
}

static inline void witty_cimgui_reset_style(ImGuiContext* context, float scale) {
    ImGui_SetCurrentContext(context);
    ImGuiStyle style;
    ImGuiStyle_ImGuiStyle(&style);
    ImGuiStyle_ScaleAllSizes(&style, scale);
    *ImGui_GetStyle() = style;
}

static inline void witty_cimgui_set_size(ImGuiContext* context, unsigned int width, unsigned int height) {
    ImGui_SetCurrentContext(context);
    ImGui_GetIO()->DisplaySize = (ImVec2){(float)width, (float)height};
}

static inline void witty_cimgui_add_mouse_button(ImGuiContext* context, int button, bool down) {
    ImGui_SetCurrentContext(context);
    ImGuiIO_AddMouseButtonEvent(ImGui_GetIO(), button, down);
}

static inline void witty_cimgui_add_mouse_wheel(ImGuiContext* context, float x, float y) {
    ImGui_SetCurrentContext(context);
    ImGuiIO_AddMouseWheelEvent(ImGui_GetIO(), x, y);
}

static inline void witty_cimgui_add_mouse_pos(ImGuiContext* context, float x, float y) {
    ImGui_SetCurrentContext(context);
    ImGuiIO_AddMousePosEvent(ImGui_GetIO(), x, y);
}

static inline void witty_cimgui_add_focus(ImGuiContext* context, bool focused) {
    ImGui_SetCurrentContext(context);
    ImGuiIO_AddFocusEvent(ImGui_GetIO(), focused);
}

static inline void witty_cimgui_add_text(ImGuiContext* context, const char* text) {
    ImGui_SetCurrentContext(context);
    ImGuiIO_AddInputCharactersUTF8(ImGui_GetIO(), text);
}

static inline void witty_cimgui_add_key(ImGuiContext* context, int key, bool down) {
    ImGui_SetCurrentContext(context);
    ImGuiIO_AddKeyEvent(ImGui_GetIO(), key, down);
}

static inline void witty_cimgui_begin_frame(ImGuiContext* context, float delta_time) {
    ImGui_SetCurrentContext(context);
    ImGui_GetIO()->DeltaTime = delta_time;
    ImGui_NewFrame();
}

static inline void witty_cimgui_render_frame(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_Render();
}

static inline const char* witty_cimgui_version(void) {
    return ImGui_GetVersion();
}

static inline int witty_cimgui_config_flags(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    return ImGui_GetIO()->ConfigFlags;
}

static inline float witty_cimgui_display_width(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    return ImGui_GetIO()->DisplaySize.x;
}

static inline float witty_cimgui_display_height(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    return ImGui_GetIO()->DisplaySize.y;
}

static inline float witty_cimgui_delta_time(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    return ImGui_GetIO()->DeltaTime;
}

static inline bool witty_cimgui_is_key_down(ImGuiContext* context, int key) {
    ImGui_SetCurrentContext(context);
    return ImGui_IsKeyDown(key);
}

#ifdef __APPLE__
bool witty_cimgui_metal_init(void* device);
void witty_cimgui_metal_shutdown(void);
void witty_cimgui_metal_new_frame(void* descriptor);
void witty_cimgui_metal_render(void* command_buffer, void* descriptor);
#endif

#ifdef __cplusplus
}
#endif
