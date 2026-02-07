module renderer

// Graphics API wrapper for OpenGL.
//
// In this V translation, OpenGL-specific functionality is abstracted
// behind the gg graphics backend. These types and stubs are provided
// for parity with the Zig source and to document the OpenGL API surface.

// OpenGLAPI wraps the OpenGL graphics API implementation.
pub struct OpenGLAPI {
pub mut:
	// Alpha blending mode
	blending AlphaBlendingMode
}

// We require at least OpenGL 4.3
pub const opengl_min_version_major = 4
pub const opengl_min_version_minor = 3

// Because OpenGL's frame completion is always
// sync, we have no need for multi-buffering.
pub const opengl_swap_chain_count = 1

// The fragCoord for OpenGL shaders is +Y = up.
pub const opengl_custom_shader_y_is_down = false

pub fn OpenGLAPI.init() !OpenGLAPI {
	// XTODO: OpenGL initialization requires:
	// 1. Loading OpenGL function pointers via glad
	// 2. Checking OpenGL version >= 4.3
	// 3. Enabling GL_DEBUG_OUTPUT
	// 4. Registering debug message callback
	// 5. Enabling GL_FRAMEBUFFER_SRGB for linear blending
	return OpenGLAPI{
		blending: .none_
	}
}

pub fn (mut self OpenGLAPI) deinit() {
	// Release OpenGL resources
}

// Get the current size of the runtime surface.
pub fn (self &OpenGLAPI) surface_size() (u32, u32) {
	// XTODO: Requires glGetIntegerv(GL_VIEWPORT, ...)
	return 0, 0
}

// OpenGL texture target.
pub enum GLTextureTarget {
	texture_2d
	texture_rectangle
}

// OpenGL texture format.
pub enum GLTextureFormat {
	red
	rgba
	bgra
}

// OpenGL internal format.
pub enum GLInternalFormat {
	red
	rgba
	srgba
}

// OpenGL filter mode.
pub enum GLFilter {
	nearest
	linear
	linear_mipmap_linear
}

// OpenGL wrap mode.
pub enum GLWrapMode {
	clamp_to_edge
	repeat
	mirror_repeat
}

// OpenGL buffer target.
pub enum GLBufferTarget {
	array
	element_array
	uniform
}

// OpenGL buffer usage.
pub enum GLBufferUsage {
	static_draw
	dynamic_draw
	stream_draw
}

// OpenGL debug message severity levels.
pub enum GLDebugSeverity {
	high
	medium
	low
	notification
}

// OpenGL debug message source.
pub enum GLDebugSource {
	api
	window_system
	shader_compiler
	third_party
	application
	other
}

// OpenGL debug message type.
pub enum GLDebugType {
	error
	deprecated_behavior
	undefined_behavior
	portability
	performance
	marker
	push_group
	pop_group
	other
}
