module renderer

import opengl

// Graphics API wrapper for OpenGL.
//
// Translated from ghostty/src/renderer/OpenGL.zig.

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
	version := opengl.load(unsafe { nil })!
	major := opengl.version_major(version)
	minor := opengl.version_minor(version)
	if major < opengl_min_version_major
		|| (major == opengl_min_version_major && minor < opengl_min_version_minor) {
		return error('OpenGL ${major}.${minor} is too old; Witty requires OpenGL ${opengl_min_version_major}.${opengl_min_version_minor}')
	}
	opengl.enable(opengl.gl_debug_output) or {}
	opengl.enable(opengl.gl_framebuffer_srgb) or {}
	return OpenGLAPI{
		blending: .none_
	}
}

pub fn (mut self OpenGLAPI) deinit() {
	opengl.unload()
}

// Get the current size of the runtime surface.
pub fn (self &OpenGLAPI) surface_size() (u32, u32) {
	_ = self
	viewport := opengl.viewport_rect() or { return 0, 0 }
	if viewport[2] <= 0 || viewport[3] <= 0 {
		return 0, 0
	}
	return u32(viewport[2]), u32(viewport[3])
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
