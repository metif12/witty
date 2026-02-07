module renderer

// OpenGL sub-types: Buffer, Frame, RenderPass, Pipeline, Sampler, Target, Texture
//
// These are stubs providing type parity with the Zig OpenGL renderer
// subdirectory (opengl/*.zig). In the V translation, the gg graphics
// backend handles these abstractions internally.

// ============================================================
// OpenGL Buffer
// ============================================================

// GLBuffer wraps an OpenGL buffer object.
pub struct GLBuffer {
pub mut:
	// The buffer object name (GLuint).
	id u32
	// The number of elements in the buffer.
	len u32
	// The capacity (in elements) of the buffer.
	capacity u32
}

// GLBufferOptions configures how a buffer is created.
pub struct GLBufferOptions {
pub:
	target GLBufferTarget = .array
	usage  GLBufferUsage  = .dynamic_draw
}

pub fn GLBuffer.init(opts GLBufferOptions, len u32) !GLBuffer {
	// XTODO: Requires glGenBuffers, glBindBuffer, glBufferData
	_ = opts
	return GLBuffer{
		len: 0
		capacity: len
	}
}

pub fn (mut self GLBuffer) deinit() {
	// XTODO: Requires glDeleteBuffers
	self.id = 0
}

// Sync buffer contents. Reallocates if needed.
pub fn (mut self GLBuffer) sync(data []u8) {
	// XTODO: Requires glBindBuffer, glBufferSubData or glBufferData
	_ = data
}

// ============================================================
// OpenGL Frame
// ============================================================

// GLFrame wraps the context for encoding a single OpenGL frame.
pub struct GLFrame {
pub mut:
	dummy_ u8
}

pub fn GLFrame.begin() !GLFrame {
	// XTODO: Begins a new frame for rendering.
	return GLFrame{}
}

pub fn (mut self GLFrame) complete() {
	// XTODO: Finalizes the frame, presents the target,
	// and checks for GL errors.
}

// ============================================================
// OpenGL RenderPass
// ============================================================

// GLRenderPass manages render passes with multiple steps.
pub struct GLRenderPass {
pub mut:
	dummy_ u8
}

// GLRenderStep describes a single step in a render pass.
pub struct GLRenderStep {
pub:
	pipeline     GLPipeline
	vertex_count u32 = 4
}

pub fn GLRenderPass.begin() !GLRenderPass {
	// XTODO: Binds the framebuffer, sets viewport, optionally clears.
	return GLRenderPass{}
}

pub fn (mut self GLRenderPass) step(s GLRenderStep) {
	// XTODO: Requires glUseProgram, glBindVertexArray,
	// glBindBuffer, glActiveTexture, glBindTexture,
	// glBindSampler, glDrawArraysInstanced
	_ = s
}

pub fn (mut self GLRenderPass) complete() {
	// XTODO: Unbinds the framebuffer.
}

// ============================================================
// OpenGL Pipeline
// ============================================================

// GLPipeline wraps an OpenGL render pipeline (shader program + VAO).
pub struct GLPipeline {
pub mut:
	// The shader program name.
	program u32
	// The vertex array object.
	vao u32
}

pub fn GLPipeline.init() !GLPipeline {
	// XTODO: Requires compiling vertex/fragment shaders,
	// linking program, creating VAO, configuring vertex attributes.
	return GLPipeline{}
}

pub fn (mut self GLPipeline) deinit() {
	// XTODO: Requires glDeleteProgram, glDeleteVertexArrays
	self.program = 0
	self.vao = 0
}

// ============================================================
// OpenGL Sampler
// ============================================================

// GLSampler wraps an OpenGL sampler object.
pub struct GLSampler {
pub mut:
	id u32
}

// GLSamplerOptions configures sampler creation.
pub struct GLSamplerOptions {
pub:
	min_filter GLFilter   = .linear
	mag_filter GLFilter   = .linear
	wrap_s     GLWrapMode = .clamp_to_edge
	wrap_t     GLWrapMode = .clamp_to_edge
}

pub fn GLSampler.init(opts GLSamplerOptions) !GLSampler {
	// XTODO: Requires glGenSamplers, glSamplerParameteri
	_ = opts
	return GLSampler{}
}

pub fn (mut self GLSampler) deinit() {
	// XTODO: Requires glDeleteSamplers
	self.id = 0
}

// ============================================================
// OpenGL Target
// ============================================================

// GLTarget represents a render target backed by an OpenGL renderbuffer.
pub struct GLTarget {
pub mut:
	// The framebuffer object name.
	fbo u32
	// The renderbuffer object name.
	rbo u32
	// Width and height of the target.
	width  u32
	height u32
}

pub fn GLTarget.init(width u32, height u32) !GLTarget {
	// XTODO: Requires glGenRenderbuffers, glRenderbufferStorage,
	// glGenFramebuffers, glFramebufferRenderbuffer
	return GLTarget{
		width: width
		height: height
	}
}

pub fn (mut self GLTarget) deinit() {
	// XTODO: Requires glDeleteFramebuffers, glDeleteRenderbuffers
	self.fbo = 0
	self.rbo = 0
}

// ============================================================
// OpenGL Texture
// ============================================================

// GLTexture wraps an OpenGL texture.
pub struct GLTexture {
pub mut:
	// The texture object name.
	id u32
	// Width and height.
	width  u32
	height u32
}

// GLTextureOptions configures texture creation.
pub struct GLTextureOptions {
pub:
	format          GLTextureFormat = .rgba
	internal_format GLInternalFormat = .rgba
	target          GLTextureTarget = .texture_2d
	min_filter      GLFilter        = .nearest
	mag_filter      GLFilter        = .nearest
	wrap_s          GLWrapMode      = .clamp_to_edge
	wrap_t          GLWrapMode      = .clamp_to_edge
}

pub fn GLTexture.init(opts GLTextureOptions, width u32, height u32, data ?[]u8) !GLTexture {
	// XTODO: Requires glGenTextures, glBindTexture,
	// glTexParameteri (filter, wrap), glTexImage2D
	_ = opts
	_ = data
	return GLTexture{
		width: width
		height: height
	}
}

pub fn (mut self GLTexture) deinit() {
	// XTODO: Requires glDeleteTextures
	self.id = 0
}

// Update a rectangular region of the texture.
pub fn (mut self GLTexture) replace_region(x u32, y u32, width u32, height u32, data []u8) {
	// XTODO: Requires glTexSubImage2D
	_ = x
	_ = y
	_ = width
	_ = height
	_ = data
}

// ============================================================
// OpenGL Shaders
// ============================================================

// GLShaders manages the OpenGL shader programs and all pipelines.
pub struct GLShaders {
pub mut:
	// Pipeline for background color.
	bg_color GLPipeline
	// Pipeline for cell backgrounds.
	cell_bg GLPipeline
	// Pipeline for cell text.
	cell_text GLPipeline
	// Pipeline for images.
	image GLPipeline
	// Pipeline for background images.
	bg_image GLPipeline
	// Post-processing pipelines (custom shaders).
	post_pipelines []GLPipeline
}

pub fn GLShaders.init() !GLShaders {
	// XTODO: Requires compiling built-in vertex/fragment shaders
	// and creating pipeline objects for each shader program.
	return GLShaders{
		bg_color: GLPipeline{}
		cell_bg: GLPipeline{}
		cell_text: GLPipeline{}
		image: GLPipeline{}
		bg_image: GLPipeline{}
	}
}

pub fn (mut self GLShaders) deinit() {
	self.bg_color.deinit()
	self.cell_bg.deinit()
	self.cell_text.deinit()
	self.image.deinit()
	self.bg_image.deinit()
	for mut p in self.post_pipelines {
		p.deinit()
	}
}
