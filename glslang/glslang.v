module glslang

#flag -I@VMODROOT/thirdparty/glslang
#flag -I@VMODROOT/thirdparty/glslang/override
#flag @VMODROOT/.witty-build/native/libglslang.a
#flag darwin -lc++
#flag linux -lstdc++
#flag freebsd -lstdc++
#include "glslang/Include/glslang_c_interface.h"
#include "glslang/Public/resource_limits_c.h"

@[typedef]
pub struct C.glslang_input_t {
pub mut:
	language                          int
	stage                             int
	client                            int
	client_version                    int
	target_language                   int
	target_language_version           int
	code                              &char
	default_version                   int
	default_profile                   int
	force_default_version_and_profile int
	forward_compatible                int
	messages                          int
	resource                          voidptr
}

fn C.glslang_initialize_process() int
fn C.glslang_finalize_process()
pub fn C.glslang_default_resource() voidptr
pub fn C.glslang_shader_create(input &C.glslang_input_t) voidptr
pub fn C.glslang_shader_delete(shader voidptr)
pub fn C.glslang_shader_preprocess(shader voidptr, input &C.glslang_input_t) int
pub fn C.glslang_shader_parse(shader voidptr, input &C.glslang_input_t) int
pub fn C.glslang_shader_get_info_log(shader voidptr) &char
pub fn C.glslang_shader_get_info_debug_log(shader voidptr) &char
pub fn C.glslang_program_create() voidptr
pub fn C.glslang_program_delete(program voidptr)
pub fn C.glslang_program_add_shader(program voidptr, shader voidptr)
pub fn C.glslang_program_link(program voidptr, messages int) int
pub fn C.glslang_program_SPIRV_generate(program voidptr, stage int)
pub fn C.glslang_program_SPIRV_get_size(program voidptr) usize
pub fn C.glslang_program_SPIRV_get_ptr(program voidptr) &u32
pub fn C.glslang_program_get_info_log(program voidptr) &char
pub fn C.glslang_program_get_info_debug_log(program voidptr) &char

// pkg/glslang/init.zig. Initialization is process setup, not a PATH tool.
pub fn initialize() ! {
	if C.glslang_initialize_process() == 0 { return error('GlslangInitFailed') }
}

pub fn finalize() {
	C.glslang_finalize_process()
}
