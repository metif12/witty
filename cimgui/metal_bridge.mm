#define IMGUI_IMPL_API extern "C"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "imgui.h"
#include "imgui_impl_metal.h"

extern "C" {

bool witty_cimgui_metal_init(void* raw_device) {
    id<MTLDevice> device = (id<MTLDevice>)raw_device;
    const bool result = ImGui_ImplMetal_Init(device);
    [(id)device release];
    return result;
}

void witty_cimgui_metal_shutdown(void) {
    ImGui_ImplMetal_Shutdown();
}

void witty_cimgui_metal_new_frame(void* raw_descriptor) {
    ImGui_ImplMetal_NewFrame((MTLRenderPassDescriptor*)raw_descriptor);
}

void witty_cimgui_metal_render(void* raw_command_buffer, void* raw_descriptor) {
    id<MTLCommandBuffer> command_buffer = (id<MTLCommandBuffer>)raw_command_buffer;
    MTLRenderPassDescriptor* descriptor = (MTLRenderPassDescriptor*)raw_descriptor;
    id<MTLRenderCommandEncoder> encoder =
        [command_buffer renderCommandEncoderWithDescriptor:descriptor];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), command_buffer, encoder);
    [encoder endEncoding];
    [(id)command_buffer release];
    [(id)descriptor release];
}

}
