#include "imgui.h"
#include "detail.h"
extern "C" void witty_cimgui_show_demo(void* context, bool* open) {
    ImGui::SetCurrentContext(static_cast<ImGuiContext*>(context));
    ImGui::ShowDemoWindow(open);
}
extern "C" void witty_cimgui_readonly_text(void* context, const char* label, char* data, size_t length) {
    ImGui::SetCurrentContext(static_cast<ImGuiContext*>(context));
    ImGui::InputText(label, data, length, ImGuiInputTextFlags_ReadOnly);
}
extern "C" bool witty_cimgui_bindings_list(void* context, const char* label, size_t count) {
    ImGui::SetCurrentContext(static_cast<ImGuiContext*>(context));
    const float items = static_cast<float>(count < 5 ? count : 5);
    const float height = ImGui::GetTextLineHeightWithSpacing() * items + ImGui::GetStyle().FramePadding.y * 2;
    return ImGui::BeginListBox(label, ImVec2(0, height));
}
