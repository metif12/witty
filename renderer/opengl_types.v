module renderer

import opengl

// OpenGL sub-types: Buffer, Frame, RenderPass, Pipeline, Sampler, Target, Texture.
//
// Translated from ghostty/src/renderer/opengl/*.zig.

// ============================================================
// OpenGL Buffer
// ============================================================

pub struct GLBuffer {
pub mut:
	id       u32
	len      u32
	capacity u32
	target   GLBufferTarget = .array
	usage    GLBufferUsage  = .dynamic_draw
}

pub struct GLBufferOptions {
pub:
	target GLBufferTarget = .array
	usage  GLBufferUsage  = .dynamic_draw
}

fn gl_buffer_target(target GLBufferTarget) opengl.BufferTarget {
	return match target {
		.array { .array }
		.element_array { .element_array }
		.uniform { .uniform }
	}
}

fn gl_buffer_usage(usage GLBufferUsage) opengl.BufferUsage {
	return match usage {
		.static_draw { .static_draw }
		.dynamic_draw { .dynamic_draw }
		.stream_draw { .stream_draw }
	}
}

pub fn GLBuffer.init(opts GLBufferOptions, len u32) !GLBuffer {
	buffer := opengl.Buffer.create()!
	binding := buffer.bind(gl_buffer_target(opts.target))!
	defer {
		binding.unbind()
	}
	binding.set_data_null(usize(len), gl_buffer_usage(opts.usage))!
	return GLBuffer{
		id:       buffer.id
		len:      0
		capacity: len
		target:   opts.target
		usage:    opts.usage
	}
}

pub fn (mut self GLBuffer) deinit() {
	if self.id != 0 {
		opengl.Buffer{
			id: self.id
		}.destroy()
	}
	self.id = 0
	self.len = 0
	self.capacity = 0
}

pub fn (mut self GLBuffer) sync(data []u8) {
	if self.id == 0 {
		return
	}
	buffer := opengl.Buffer{
		id: self.id
	}
	binding := buffer.bind(gl_buffer_target(self.target)) or { return }
	defer {
		binding.unbind()
	}
	if u32(data.len) > self.capacity {
		mut next := u32(data.len * 2)
		if next == 0 {
			next = 1
		}
		binding.set_data_null(usize(next), gl_buffer_usage(self.usage)) or { return }
		self.capacity = next
	}
	binding.set_sub_data(0, data) or { return }
	self.len = u32(data.len)
}

// ============================================================
// OpenGL Frame
// ============================================================

pub struct GLFrame {
pub mut:
	healthy bool = true
}

pub fn GLFrame.begin() !GLFrame {
	return GLFrame{}
}

pub fn (mut self GLFrame) complete() {
	opengl.finish()
	opengl.get_error() or { self.healthy = false }
}

// ============================================================
// OpenGL RenderPass
// ============================================================

pub enum GLRenderAttachmentKind {
	default_target
	target
	texture
}

pub struct GLRenderAttachment {
pub:
	kind        GLRenderAttachmentKind = .default_target
	target      GLTarget
	texture     GLTexture
	clear_color ?[4]f32
}

pub struct GLRenderPass {
pub mut:
	attachments []GLRenderAttachment
	step_number int
}

pub struct GLDraw {
pub:
	primitive      opengl.Primitive = .triangle_strip
	vertex_count   u32              = 4
	instance_count u32              = 1
}

pub struct GLRenderStep {
pub:
	pipeline     GLPipeline
	uniforms     ?GLBuffer
	buffers      []GLBuffer
	textures     []GLTexture
	samplers     []GLSampler
	draw         GLDraw = GLDraw{}
	vertex_count u32    = 4
}

pub fn GLRenderPass.begin() !GLRenderPass {
	return GLRenderPass{}
}

pub fn GLRenderPass.begin_with_attachments(attachments []GLRenderAttachment) !GLRenderPass {
	return GLRenderPass{
		attachments: attachments
	}
}

pub fn (mut self GLRenderPass) step(s GLRenderStep) {
	if s.draw.instance_count == 0 {
		return
	}
	if s.pipeline.program == 0 || s.pipeline.vao == 0 {
		return
	}

	program := opengl.Program{
		id: s.pipeline.program
	}
	pbind := program.use() or { return }
	defer {
		pbind.unbind()
	}

	vao := opengl.VertexArray{
		id: s.pipeline.vao
	}
	vaobind := vao.bind() or { return }
	defer {
		vaobind.unbind()
	}

	mut has_fbo := false
	mut fbobind := opengl.FramebufferBinding{
		target: .framebuffer
	}
	if self.attachments.len > 0 {
		attachment := self.attachments[0]
		match attachment.kind {
			.default_target {}
			.target {
				fbo := opengl.Framebuffer{
					id: attachment.target.fbo
				}
				fbobind = fbo.bind(.framebuffer) or { return }
				has_fbo = true
			}
			.texture {
				if s.pipeline.fbo == 0 {
					return
				}
				fbo := opengl.Framebuffer{
					id: s.pipeline.fbo
				}
				fbobind = fbo.bind(.framebuffer) or { return }
				fbobind.texture_2d(.color0, gl_texture_target(attachment.texture.target), opengl.Texture{
					id: attachment.texture.id
				}, 0) or {
					fbobind.unbind()
					return
				}
				has_fbo = true
			}
		}

		if self.step_number == 0 {
			if color := attachment.clear_color {
				opengl.clear_color(color[0], color[1], color[2], color[3])
				opengl.clear(opengl.gl_color_buffer_bit)
			}
		}
	}
	defer {
		if has_fbo {
			fbobind.unbind()
		}
	}

	if uniforms := s.uniforms {
		opengl.Buffer{
			id: uniforms.id
		}.bind_base(.uniform, 1) or { return }
	}

	if s.buffers.len > 0 {
		first := s.buffers[0]
		if first.id != 0 {
			vaobind.bind_vertex_buffer(0, first.id, 0, int(s.pipeline.stride)) or { return }
		}
		for i in 1 .. s.buffers.len {
			buffer := s.buffers[i]
			if buffer.id == 0 {
				continue
			}

			opengl.Buffer{
				id: buffer.id
			}.bind_base(.storage, u32(i)) or { return }
		}
	}

	for i, texture in s.textures {
		if texture.id == 0 {
			continue
		}
		opengl.texture_active(u32(i)) or { return }

		opengl.Texture{
			id: texture.id
		}.bind(gl_texture_target(texture.target)) or { return }
	}

	for i, sampler in s.samplers {
		if sampler.id == 0 {
			continue
		}

		opengl.Sampler{
			id: sampler.id
		}.bind(u32(i)) or { return }
	}

	if s.pipeline.blending_enabled {
		opengl.enable(opengl.gl_blend) or { return }
		opengl.blend_func(opengl.gl_one, opengl.gl_one_minus_src_alpha) or { return }
	} else {
		opengl.disable(opengl.gl_blend) or { return }
	}

	vertex_count := if s.draw.vertex_count > 0 { s.draw.vertex_count } else { s.vertex_count }
	opengl.draw_arrays_instanced(s.draw.primitive, 0, int(vertex_count), int(s.draw.instance_count)) or {
		return
	}
	self.step_number++
}

pub fn (mut self GLRenderPass) complete() {
	opengl.flush()
}

// ============================================================
// OpenGL Pipeline
// ============================================================

pub struct GLPipeline {
pub mut:
	program          u32
	fbo              u32
	vao              u32
	stride           u32
	blending_enabled bool = true
}

pub struct GLPipelineOptions {
pub:
	vertex_source    string
	fragment_source  string
	stride           u32
	blending_enabled bool = true
}

pub fn GLPipeline.init() !GLPipeline {
	vao := opengl.VertexArray.create()!
	fbo := opengl.Framebuffer.create()!
	return GLPipeline{
		vao: vao.id
		fbo: fbo.id
	}
}

pub fn GLPipeline.init_with_sources(opts GLPipelineOptions) !GLPipeline {
	program := opengl.Program.create_vf(opts.vertex_source, opts.fragment_source)!
	vao := opengl.VertexArray.create()!
	fbo := opengl.Framebuffer.create()!
	return GLPipeline{
		program:          program.id
		vao:              vao.id
		fbo:              fbo.id
		stride:           opts.stride
		blending_enabled: opts.blending_enabled
	}
}

pub fn (mut self GLPipeline) deinit() {
	if self.program != 0 {
		opengl.Program{
			id: self.program
		}.destroy()
	}
	if self.vao != 0 {
		opengl.VertexArray{
			id: self.vao
		}.destroy()
	}
	if self.fbo != 0 {
		opengl.Framebuffer{
			id: self.fbo
		}.destroy()
	}
	self.program = 0
	self.vao = 0
	self.fbo = 0
}

// ============================================================
// OpenGL Sampler
// ============================================================

pub struct GLSampler {
pub mut:
	id u32
}

pub struct GLSamplerOptions {
pub:
	min_filter GLFilter   = .linear
	mag_filter GLFilter   = .linear
	wrap_s     GLWrapMode = .clamp_to_edge
	wrap_t     GLWrapMode = .clamp_to_edge
}

pub fn GLSampler.init(opts GLSamplerOptions) !GLSampler {
	sampler := opengl.Sampler.create()!
	sampler.parameter(.min_filter, int(gl_min_filter(opts.min_filter)))!
	sampler.parameter(.mag_filter, int(gl_mag_filter(opts.mag_filter)))!
	sampler.parameter(.wrap_s, int(gl_wrap(opts.wrap_s)))!
	sampler.parameter(.wrap_t, int(gl_wrap(opts.wrap_t)))!
	return GLSampler{
		id: sampler.id
	}
}

pub fn (mut self GLSampler) deinit() {
	if self.id != 0 {
		opengl.Sampler{
			id: self.id
		}.destroy()
	}
	self.id = 0
}

// ============================================================
// OpenGL Target
// ============================================================

pub struct GLTarget {
pub mut:
	fbo    u32
	rbo    u32
	width  u32
	height u32
}

pub fn GLTarget.init(width u32, height u32) !GLTarget {
	rbo := opengl.Renderbuffer.create()!
	rbo_bind := rbo.bind()!
	defer {
		rbo_bind.unbind()
	}
	rbo_bind.storage(.rgba, int(width), int(height))!

	fbo := opengl.Framebuffer.create()!
	fbo_bind := fbo.bind(.framebuffer)!
	defer {
		fbo_bind.unbind()
	}
	fbo_bind.renderbuffer(.color0, rbo)!

	return GLTarget{
		fbo:    fbo.id
		rbo:    rbo.id
		width:  width
		height: height
	}
}

pub fn (mut self GLTarget) deinit() {
	if self.fbo != 0 {
		opengl.Framebuffer{
			id: self.fbo
		}.destroy()
	}
	if self.rbo != 0 {
		opengl.Renderbuffer{
			id: self.rbo
		}.destroy()
	}
	self.fbo = 0
	self.rbo = 0
}

// ============================================================
// OpenGL Texture
// ============================================================

pub struct GLTexture {
pub mut:
	id     u32
	width  u32
	height u32
	format GLTextureFormat = .rgba
	target GLTextureTarget = .texture_2d
}

pub struct GLTextureOptions {
pub:
	format          GLTextureFormat  = .rgba
	internal_format GLInternalFormat = .rgba
	target          GLTextureTarget  = .texture_2d
	min_filter      GLFilter         = .nearest
	mag_filter      GLFilter         = .nearest
	wrap_s          GLWrapMode       = .clamp_to_edge
	wrap_t          GLWrapMode       = .clamp_to_edge
}

fn gl_texture_target(target GLTextureTarget) opengl.TextureTarget {
	return match target {
		.texture_2d { .t2d }
		.texture_rectangle { .rectangle }
	}
}

fn gl_texture_format(format GLTextureFormat) opengl.TextureFormat {
	return match format {
		.red { .red }
		.rgba { .rgba }
		.bgra { .bgra }
	}
}

fn gl_internal_format(format GLInternalFormat) opengl.TextureInternalFormat {
	return match format {
		.red { .red }
		.rgba { .rgba }
		.srgba { .srgba }
	}
}

fn gl_min_filter(filter GLFilter) opengl.TextureMinFilter {
	return match filter {
		.nearest { .nearest }
		.linear { .linear }
		.linear_mipmap_linear { .linear_mipmap_linear }
	}
}

fn gl_mag_filter(filter GLFilter) opengl.TextureMagFilter {
	return match filter {
		.nearest { .nearest }
		else { .linear }
	}
}

fn gl_wrap(wrap GLWrapMode) opengl.TextureWrap {
	return match wrap {
		.clamp_to_edge { .clamp_to_edge }
		.repeat { .repeat }
		.mirror_repeat { .mirrored_repeat }
	}
}

pub fn GLTexture.init(opts GLTextureOptions, width u32, height u32, data ?[]u8) !GLTexture {
	texture := opengl.Texture.create()!
	binding := texture.bind(gl_texture_target(opts.target))!
	defer {
		binding.unbind()
	}
	binding.parameter(.wrap_s, int(gl_wrap(opts.wrap_s)))!
	binding.parameter(.wrap_t, int(gl_wrap(opts.wrap_t)))!
	binding.parameter(.min_filter, int(gl_min_filter(opts.min_filter)))!
	binding.parameter(.mag_filter, int(gl_mag_filter(opts.mag_filter)))!
	mut ptr := voidptr(unsafe { nil })
	if d := data {
		if d.len > 0 {
			ptr = voidptr(d.data)
		}
	}
	binding.image_2d(0, gl_internal_format(opts.internal_format), int(width), int(height),
		gl_texture_format(opts.format), .unsigned_byte, ptr)!
	return GLTexture{
		id:     texture.id
		width:  width
		height: height
		format: opts.format
		target: opts.target
	}
}

pub fn (mut self GLTexture) deinit() {
	if self.id != 0 {
		opengl.Texture{
			id: self.id
		}.destroy()
	}
	self.id = 0
}

pub fn (mut self GLTexture) replace_region(x u32, y u32, width u32, height u32, data []u8) {
	if self.id == 0 {
		return
	}
	mut ptr := voidptr(unsafe { nil })
	if data.len > 0 {
		ptr = voidptr(data.data)
	}
	binding := opengl.Texture{
		id: self.id
	}.bind(gl_texture_target(self.target)) or { return }
	defer {
		binding.unbind()
	}
	binding.sub_image_2d(0, int(x), int(y), int(width), int(height),
		gl_texture_format(self.format), .unsigned_byte, ptr) or { return }
}

// ============================================================
// OpenGL Shaders
// ============================================================

pub struct GLShaders {
pub mut:
	bg_color       GLPipeline
	cell_bg        GLPipeline
	cell_text      GLPipeline
	image          GLPipeline
	bg_image       GLPipeline
	post_pipelines []GLPipeline
}

pub fn GLShaders.init() !GLShaders {
	return GLShaders{
		bg_color:  GLPipeline{}
		cell_bg:   GLPipeline{}
		cell_text: GLPipeline{}
		image:     GLPipeline{}
		bg_image:  GLPipeline{}
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
