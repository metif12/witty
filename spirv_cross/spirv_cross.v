module spirv_cross

$if !system_spirv_cross ? {
	#flag -I@VMODROOT/thirdparty/spirv-cross
}
$if !managed_native ? {
	#flag @VMODROOT/.witty-build/native/libspirv_cross.a
}
#flag darwin -lc++
#flag linux -lstdc++
#flag freebsd -lstdc++
#include "spirv_cross_c.h"

pub fn C.spvc_context_create(context &voidptr) int
pub fn C.spvc_context_destroy(context voidptr)
pub fn C.spvc_context_set_error_callback(context voidptr, callback fn (voidptr, &char), userdata voidptr)
pub fn C.spvc_context_parse_spirv(context voidptr, words &u32, count uint, ir &voidptr) int
pub fn C.spvc_context_create_compiler(context voidptr, backend int, ir voidptr, mode int, compiler &voidptr) int
pub fn C.spvc_compiler_create_compiler_options(compiler voidptr, options &voidptr) int
pub fn C.spvc_compiler_options_set_bool(options voidptr, option int, value bool) int
pub fn C.spvc_compiler_options_set_uint(options voidptr, option int, value u32) int
pub fn C.spvc_compiler_install_compiler_options(compiler voidptr, options voidptr) int
pub fn C.spvc_compiler_compile(compiler voidptr, result &&char) int
