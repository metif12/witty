#pragma once
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
void* witty_cimgui_filter_create(const char* text);
void witty_cimgui_filter_destroy(void* filter);
bool witty_cimgui_filter_pass(void* filter, const char* text);
void witty_cimgui_filter_set(void* filter, const char* text);
const char* witty_cimgui_filter_get(void* filter);
void witty_cimgui_filter_draw(void* context, void* filter, const char* label);
#ifdef __cplusplus
}
#endif
