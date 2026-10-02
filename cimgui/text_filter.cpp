#include "imgui.h"
#include "text_filter.h"
#include <cstring>
extern "C" void* witty_cimgui_filter_create(const char* text) { return new ImGuiTextFilter(text); }
extern "C" void witty_cimgui_filter_destroy(void* filter) { delete static_cast<ImGuiTextFilter*>(filter); }
extern "C" bool witty_cimgui_filter_pass(void* filter, const char* text) { return static_cast<ImGuiTextFilter*>(filter)->PassFilter(text); }
extern "C" void witty_cimgui_filter_set(void* handle, const char* text) {
    auto* filter = static_cast<ImGuiTextFilter*>(handle);
    std::strncpy(filter->InputBuf, text, sizeof(filter->InputBuf) - 1);
    filter->InputBuf[sizeof(filter->InputBuf) - 1] = 0;
    filter->Build();
}
extern "C" const char* witty_cimgui_filter_get(void* filter) { return static_cast<ImGuiTextFilter*>(filter)->InputBuf; }
extern "C" void witty_cimgui_filter_draw(void* context, void* filter, const char* label) {
    ImGui::SetCurrentContext(static_cast<ImGuiContext*>(context));
    static_cast<ImGuiTextFilter*>(filter)->Draw(label);
}
