#pragma once
#include <stdbool.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
void witty_cimgui_show_demo(void* context, bool* open);
void witty_cimgui_readonly_text(void* context, const char* label, char* data, size_t length);
bool witty_cimgui_bindings_list(void* context, const char* label, size_t count);
#ifdef __cplusplus
}
#endif
