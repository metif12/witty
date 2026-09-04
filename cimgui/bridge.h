#pragma once

#include <stddef.h>
#include <string.h>

#include "dcimgui.h"
#include "dcimgui_internal.h"

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

static inline bool witty_cimgui_build_font_atlas(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    cImFontAtlasBuildMain(ImGui_GetIO()->Fonts);
    return true;
}

static inline unsigned int witty_cimgui_get_id(ImGuiContext* context, const char* value) {
    ImGui_SetCurrentContext(context);
    return ImGui_GetID(value);
}

static inline bool witty_cimgui_dock_node_exists(ImGuiContext* context, unsigned int id) {
    ImGui_SetCurrentContext(context);
    return ImGui_DockBuilderGetNode(id) != NULL;
}

static inline bool witty_cimgui_dock_node_add(ImGuiContext* context, unsigned int id) {
    ImGui_SetCurrentContext(context);
    return ImGui_DockBuilderAddNodeEx(id, ImGuiDockNodeFlags_DockSpace) == id;
}

static inline void witty_cimgui_dock_node_set_main_viewport_size(ImGuiContext* context, unsigned int id) {
    ImGui_SetCurrentContext(context);
    ImGui_DockBuilderSetNodeSize(id, ImGui_GetMainViewport()->Size);
}

static inline void witty_cimgui_dock_window(ImGuiContext* context, const char* name, unsigned int id) {
    ImGui_SetCurrentContext(context);
    ImGui_DockBuilderDockWindow(name, id);
}

static inline void witty_cimgui_dock_finish(ImGuiContext* context, unsigned int id) {
    ImGui_SetCurrentContext(context);
    ImGui_DockBuilderFinish(id);
}

static inline bool witty_cimgui_dock_space_over_main_viewport(ImGuiContext* context, unsigned int id) {
    ImGui_SetCurrentContext(context);
    return ImGui_DockSpaceOverViewportEx(
        id,
        ImGui_GetMainViewport(),
        ImGuiDockNodeFlags_PassthruCentralNode,
        NULL
    ) == id;
}

static inline bool witty_cimgui_begin_window(ImGuiContext* context, const char* name) {
    ImGui_SetCurrentContext(context);
    return ImGui_Begin(name, NULL, ImGuiWindowFlags_NoFocusOnAppearing);
}

static inline void witty_cimgui_end_window(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_End();
}

static inline void witty_cimgui_set_window_focus(ImGuiContext* context, const char* name) {
    ImGui_SetCurrentContext(context);
    ImGui_SetWindowFocusStr(name);
}

static inline void witty_cimgui_text(ImGuiContext* context, const char* value) {
    ImGui_SetCurrentContext(context);
    ImGui_TextUnformatted(value);
}

static inline void witty_cimgui_text_disabled(ImGuiContext* context, const char* value) {
    ImGui_SetCurrentContext(context);
    ImGui_TextDisabledUnformatted(value);
}

static inline void witty_cimgui_text_wrapped(ImGuiContext* context, const char* value) {
    ImGui_SetCurrentContext(context);
    ImGui_TextWrappedUnformatted(value);
}

static inline bool witty_cimgui_collapsing_header(ImGuiContext* context, const char* label) {
    ImGui_SetCurrentContext(context);
    return ImGui_CollapsingHeader(label, 0);
}

static inline void witty_cimgui_separator_text(ImGuiContext* context, const char* label) {
    ImGui_SetCurrentContext(context);
    ImGui_SeparatorText(label);
}

static inline void witty_cimgui_set_next_item_open(ImGuiContext* context, bool open) {
    ImGui_SetCurrentContext(context);
    ImGui_SetNextItemOpen(open, ImGuiCond_Once);
}

static inline bool witty_cimgui_checkbox(ImGuiContext* context, const char* label, bool* value) {
    ImGui_SetCurrentContext(context);
    return ImGui_Checkbox(label, value);
}

static inline void witty_cimgui_help_marker(ImGuiContext* context, const char* value) {
    ImGui_SetCurrentContext(context);
    ImGui_TextDisabledUnformatted("(?)");
    if (!ImGui_BeginItemTooltip()) return;
    ImGui_PushTextWrapPos(ImGui_GetFontSize() * 35.0f);
    ImGui_TextUnformatted(value);
    ImGui_PopTextWrapPos();
    ImGui_EndTooltip();
}

static inline void witty_cimgui_indent(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_Indent();
}

static inline void witty_cimgui_unindent(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_Unindent();
}

static inline bool witty_cimgui_color_button(
    ImGuiContext* context,
    const char* label,
    float r,
    float g,
    float b,
    float a
) {
    ImGui_SetCurrentContext(context);
    return ImGui_ColorButton(label, (ImVec4){r, g, b, a}, ImGuiColorEditFlags_NoTooltip);
}

static inline void witty_cimgui_text_colored(
    ImGuiContext* context,
    float r,
    float g,
    float b,
    float a,
    const char* value
) {
    ImGui_SetCurrentContext(context);
    ImGui_TextColoredUnformatted((ImVec4){r, g, b, a}, value);
}

static inline bool witty_cimgui_button(ImGuiContext* context, const char* label) {
    ImGui_SetCurrentContext(context);
    return ImGui_Button(label);
}

static inline bool witty_cimgui_small_button(ImGuiContext* context, const char* label) {
    ImGui_SetCurrentContext(context);
    return ImGui_SmallButton(label);
}

static inline void witty_cimgui_separator(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_Separator();
}

static inline bool witty_cimgui_begin_table(
    ImGuiContext* context,
    const char* id,
    int columns,
    int flags
) {
    ImGui_SetCurrentContext(context);
    return ImGui_BeginTable(id, columns, flags);
}

static inline void witty_cimgui_end_table(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_EndTable();
}

static inline void witty_cimgui_table_setup_scroll_freeze(
    ImGuiContext* context,
    int columns,
    int rows
) {
    ImGui_SetCurrentContext(context);
    ImGui_TableSetupScrollFreeze(columns, rows);
}

static inline void witty_cimgui_table_setup_column(
    ImGuiContext* context,
    const char* label,
    int flags,
    float width
) {
    ImGui_SetCurrentContext(context);
    ImGui_TableSetupColumnEx(label, flags, width, 0);
}

static inline void witty_cimgui_table_headers_row(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_TableHeadersRow();
}

static inline void witty_cimgui_table_next_row(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_TableNextRow();
}

static inline void witty_cimgui_table_set_column(ImGuiContext* context, int column) {
    ImGui_SetCurrentContext(context);
    (void)ImGui_TableSetColumnIndex(column);
}

static inline void witty_cimgui_table_set_bg_color(
    ImGuiContext* context,
    int target,
    unsigned int color
) {
    ImGui_SetCurrentContext(context);
    ImGui_TableSetBgColor(target, color, -1);
}

static inline void witty_cimgui_push_id_ptr(ImGuiContext* context, const void* value) {
    ImGui_SetCurrentContext(context);
    ImGui_PushIDPtr(value);
}

static inline void witty_cimgui_pop_id(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_PopID();
}

static inline void witty_cimgui_same_line(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_SameLine();
}

static inline void witty_cimgui_new_line(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    ImGui_NewLine();
}

static inline bool witty_cimgui_item_hovered(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    return ImGui_IsItemHovered(0);
}

static inline void witty_cimgui_tooltip(ImGuiContext* context, const char* value) {
    ImGui_SetCurrentContext(context);
    ImGui_SetTooltipUnformatted(value);
}

static inline float witty_cimgui_cursor_screen_y(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    return ImGui_GetCursorScreenPos().y;
}

static inline float witty_cimgui_mouse_y(ImGuiContext* context) {
    ImGui_SetCurrentContext(context);
    return ImGui_GetMousePos().y;
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
