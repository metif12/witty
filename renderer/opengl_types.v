module renderer

import log
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
	usage    GLBufferUsage = .dynamic_draw
}

pub struct GLBufferOptions {
pub:
	target GLBufferTarget = .array
	usage  GLBufferUsage = .dynamic_draw
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
		id: buffer.id
		len: 0
		capacity: len
		target: opts.target
		usage: opts.usage
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

pub fn (mut self GLBuffer) sync_values[T](values []T) {
	if values.len == 0 {
		self.sync([]u8{})
		return
	}
	byte_len := values.len * int($sizeof(T))
	bytes := unsafe { voidptr(values.data).vbytes(byte_len) }
	self.sync(bytes)
}

// ============================================================
// OpenGL Frame
// ============================================================

pub struct GLFrame {
pub mut:
	healthy bool = true
	api     &OpenGLAPI = unsafe { nil }
	target  &GLTarget = unsafe { nil }
}

pub fn GLFrame.begin() !GLFrame {
	return GLFrame{}
}

pub fn GLFrame.begin_for_target(mut api OpenGLAPI, mut target GLTarget) !GLFrame {
	return GLFrame{
		api: unsafe { &api }
		target: unsafe { &target }
	}
}

pub fn (mut self GLFrame) complete() {
	opengl.finish()
	opengl.get_error() or { self.healthy = false }
	if self.healthy && self.api != unsafe { nil } && self.target != unsafe { nil } {
		mut api := unsafe { self.api }
		target := unsafe { *self.target }
		api.present(target) or { self.healthy = false }
	}
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
	vertex_count   u32 = 4
	instance_count u32 = 1
}

pub struct GLRenderStep {
pub:
	pipeline     GLPipeline
	uniforms     ?GLBuffer
	buffers      []GLBuffer
	textures     []GLTexture
	samplers     []GLSampler
	draw         GLDraw = GLDraw{}
	vertex_count u32 = 4
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
	attributes       []GLVertexAttribute
	step_function    GLVertexStepFunction = .per_vertex
	blending_enabled bool = true
}

pub enum GLVertexStepFunction {
	constant
	per_vertex
	per_instance
}

pub enum GLVertexScalarType {
	u8_
	u16_
	u32_
	i8_
	i16_
	i32_
	f32_
	f64_
}

pub struct GLVertexAttribute {
pub:
	scalar_type GLVertexScalarType
	count       u32 = 1
	offset      u32
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
	program_binding := program.use() or {
		program.destroy()
		return err
	}
	defer {
		program_binding.unbind()
	}
	fbo := opengl.Framebuffer.create() or {
		program.destroy()
		return err
	}
	fbo_binding := fbo.bind(.framebuffer) or {
		fbo.destroy()
		program.destroy()
		return err
	}
	defer {
		fbo_binding.unbind()
	}
	vao := opengl.VertexArray.create() or {
		fbo.destroy()
		program.destroy()
		return err
	}
	vao_binding := vao.bind() or {
		vao.destroy()
		fbo.destroy()
		program.destroy()
		return err
	}
	defer {
		vao_binding.unbind()
	}
	configure_gl_vertex_attributes(vao_binding, opts.attributes, opts.step_function) or {
		vao.destroy()
		fbo.destroy()
		program.destroy()
		return err
	}
	return GLPipeline{
		program: program.id
		vao: vao.id
		fbo: fbo.id
		stride: opts.stride
		blending_enabled: opts.blending_enabled
	}
}

fn configure_gl_vertex_attributes(binding opengl.VertexArrayBinding, attributes []GLVertexAttribute, step_function GLVertexStepFunction) ! {
	divisor := match step_function {
		.per_vertex { u32(0) }
		.per_instance { u32(1) }
		.constant { ~u32(0) }
	}
	for i, attribute in attributes {
		index := u32(i)
		binding.enable_attrib_array(index)!
		binding.attribute_binding(index, 0)!
		binding.binding_divisor(index, divisor)!
		match attribute.scalar_type {
			.u8_ {
				binding.attribute_i_format(index, int(attribute.count), opengl.gl_unsigned_byte, attribute.offset)!
			}
			.u16_ {
				binding.attribute_i_format(index, int(attribute.count), opengl.gl_unsigned_short, attribute.offset)!
			}
			.u32_ {
				binding.attribute_i_format(index, int(attribute.count), opengl.gl_unsigned_int, attribute.offset)!
			}
			.i8_ {
				binding.attribute_i_format(index, int(attribute.count), opengl.gl_byte, attribute.offset)!
			}
			.i16_ {
				binding.attribute_i_format(index, int(attribute.count), opengl.gl_short, attribute.offset)!
			}
			.i32_ {
				binding.attribute_i_format(index, int(attribute.count), opengl.gl_int, attribute.offset)!
			}
			.f32_ {
				binding.attribute_format(index, int(attribute.count), opengl.gl_float, false, attribute.offset)!
			}
			.f64_ {
				binding.attribute_l_format(index, int(attribute.count), attribute.offset)!
			}
		}
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
	min_filter GLFilter = .linear
	mag_filter GLFilter = .linear
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

pub struct GLTargetOptions {
pub:
	width           u32
	height          u32
	internal_format GLInternalFormat = .rgba
}

pub fn GLTarget.init(width u32, height u32) !GLTarget {
	return GLTarget.init_with_options(GLTargetOptions{
		width: width
		height: height
	})
}

pub fn GLTarget.init_with_options(opts GLTargetOptions) !GLTarget {
	rbo := opengl.Renderbuffer.create()!
	rbo_bind := rbo.bind()!
	defer {
		rbo_bind.unbind()
	}
	rbo_bind.storage(gl_internal_format(opts.internal_format), int(opts.width), int(opts.height))!

	fbo := opengl.Framebuffer.create()!
	fbo_bind := fbo.bind(.framebuffer)!
	defer {
		fbo_bind.unbind()
	}
	fbo_bind.renderbuffer(.color0, rbo)!

	return GLTarget{
		fbo: fbo.id
		rbo: rbo.id
		width: opts.width
		height: opts.height
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
	format          GLTextureFormat = .rgba
	internal_format GLInternalFormat = .rgba
	target          GLTextureTarget = .texture_2d
	min_filter      GLFilter = .nearest
	mag_filter      GLFilter = .nearest
	wrap_s          GLWrapMode = .clamp_to_edge
	wrap_t          GLWrapMode = .clamp_to_edge
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
	binding.image_2d(0, gl_internal_format(opts.internal_format), int(width), int(height), gl_texture_format(opts.format), .unsigned_byte, ptr)!
	return GLTexture{
		id: texture.id
		width: width
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
	binding.sub_image_2d(0, int(x), int(y), int(width), int(height), gl_texture_format(self.format), .unsigned_byte, ptr) or { return }
}

// ============================================================
// OpenGL per-frame resources
// ============================================================

// GLFrameState owns every OpenGL resource whose contents can change while a
// frame is being assembled. OpenGL completes synchronously, so its swap chain
// contains one of these states, matching renderer/opengl/Frame.zig.
pub struct GLFrameState {
pub mut:
	uniforms                 GLBuffer
	cells                    GLBuffer
	cells_bg                 GLBuffer
	bg_image_buffer          GLBuffer
	grayscale                GLTexture
	grayscale_modified       usize
	color                    GLTexture
	color_modified           usize
	target                   GLTarget
	target_config_modified   u64
	bg_image_buffer_modified u64
	custom_shader_state      ?GLCustomShaderState
}

pub fn GLFrameState.init(api &OpenGLAPI, custom_shaders bool) !GLFrameState {
	mut uniforms := GLBuffer.init(api.uniform_buffer_options(), u32($sizeof(GLUniforms)))!
	mut cells := GLBuffer.init(api.fg_buffer_options(), u32($sizeof(GLTextCell))) or {
		uniforms.deinit()
		return err
	}
	mut cells_bg := GLBuffer.init(api.bg_buffer_options(), u32($sizeof(CellBg))) or {
		cells.deinit()
		uniforms.deinit()
		return err
	}
	mut bg_image_buffer := GLBuffer.init(api.bg_image_buffer_options(), u32($sizeof(GLBgImageVertex))) or {
		cells_bg.deinit()
		cells.deinit()
		uniforms.deinit()
		return err
	}
	mut grayscale := GLTexture.init(api.atlas_texture_options(.grayscale)!, 1, 1, [
		u8(0),
	]) or {
		bg_image_buffer.deinit()
		cells_bg.deinit()
		cells.deinit()
		uniforms.deinit()
		return err
	}
	mut color := GLTexture.init(api.atlas_texture_options(.bgra)!, 1, 1, [u8(0), 0, 0, 0]) or {
		grayscale.deinit()
		bg_image_buffer.deinit()
		cells_bg.deinit()
		cells.deinit()
		uniforms.deinit()
		return err
	}
	mut custom_shader_state := if custom_shaders {
		GLCustomShaderState.init(api) or {
			color.deinit()
			grayscale.deinit()
			bg_image_buffer.deinit()
			cells_bg.deinit()
			cells.deinit()
			uniforms.deinit()
			return err
		}
	} else {
		none
	}
	mut target := api.init_target(1, 1) or {
		if mut state := custom_shader_state {
			state.deinit()
		}
		color.deinit()
		grayscale.deinit()
		bg_image_buffer.deinit()
		cells_bg.deinit()
		cells.deinit()
		uniforms.deinit()
		return err
	}
	return GLFrameState{
		uniforms: uniforms
		cells: cells
		cells_bg: cells_bg
		bg_image_buffer: bg_image_buffer
		grayscale: grayscale
		color: color
		target: target
		custom_shader_state: custom_shader_state
	}
}

pub fn (mut self GLFrameState) deinit() {
	self.target.deinit()
	self.uniforms.deinit()
	self.cells.deinit()
	self.cells_bg.deinit()
	self.grayscale.deinit()
	self.color.deinit()
	self.bg_image_buffer.deinit()
	if mut state := self.custom_shader_state {
		state.deinit()
	}
	self.custom_shader_state = none
}

pub fn (mut self GLFrameState) resize_target(api &OpenGLAPI, width u32, height u32) ! {
	if mut state := self.custom_shader_state {
		state.resize(api, width, height)!
		self.custom_shader_state = state
	}
	mut target := api.init_target(width, height)!
	self.target.deinit()
	self.target = target
}

// GLCustomShaderState is the ping-pong texture pair and uniforms used by a
// chain of Shadertoy-compatible post-processing pipelines.
pub struct GLCustomShaderState {
pub mut:
	front_texture GLTexture
	back_texture  GLTexture
	sampler       GLSampler
	uniforms      GLBuffer
}

pub fn GLCustomShaderState.init(api &OpenGLAPI) !GLCustomShaderState {
	mut uniforms := GLBuffer.init(api.uniform_buffer_options(), u32($sizeof(CustomShaderUniforms)))!
	mut front_texture := GLTexture.init(api.texture_options(), 1, 1, none) or {
		uniforms.deinit()
		return err
	}
	mut back_texture := GLTexture.init(api.texture_options(), 1, 1, none) or {
		front_texture.deinit()
		uniforms.deinit()
		return err
	}
	mut sampler := GLSampler.init(api.sampler_options()) or {
		back_texture.deinit()
		front_texture.deinit()
		uniforms.deinit()
		return err
	}
	return GLCustomShaderState{
		front_texture: front_texture
		back_texture: back_texture
		sampler: sampler
		uniforms: uniforms
	}
}

pub fn (mut self GLCustomShaderState) deinit() {
	self.front_texture.deinit()
	self.back_texture.deinit()
	self.sampler.deinit()
	self.uniforms.deinit()
}

pub fn (mut self GLCustomShaderState) swap() {
	front := self.front_texture
	self.front_texture = self.back_texture
	self.back_texture = front
}

pub fn (mut self GLCustomShaderState) resize(api &OpenGLAPI, width u32, height u32) ! {
	mut front_texture := GLTexture.init(api.texture_options(), width, height, none)!
	mut back_texture := GLTexture.init(api.texture_options(), width, height, none) or {
		front_texture.deinit()
		return err
	}
	self.front_texture.deinit()
	self.back_texture.deinit()
	self.front_texture = front_texture
	self.back_texture = back_texture
}

// ============================================================
// OpenGL Shaders
// ============================================================

// GLUniforms is the std140 byte layout consumed by common.glsl.
pub struct GLUniforms {
pub mut:
	projection_matrix     [16]f32
	screen_size           [2]f32
	cell_size             [2]f32
	grid_size             [2]u16
	reserved0             [12]u8
	grid_padding          [4]f32
	padding_extend        u8
	reserved1             [3]u8
	min_contrast          f32
	cursor_pos            [2]u16
	cursor_color          [4]u8
	bg_color              [4]u8
	cursor_wide           u8
	use_display_p3        u8
	use_linear_blending   u8
	use_linear_correction u8
	reserved2             [8]u8
}

pub fn gl_uniforms(value Uniforms) GLUniforms {
	mut padding_extend := u8(0)
	if value.padding_extend.left {
		padding_extend |= 1
	}
	if value.padding_extend.right {
		padding_extend |= 2
	}
	if value.padding_extend.up {
		padding_extend |= 4
	}
	if value.padding_extend.down {
		padding_extend |= 8
	}
	return GLUniforms{
		projection_matrix: value.projection_matrix
		screen_size: value.screen_size
		cell_size: value.cell_size
		grid_size: value.grid_size
		grid_padding: value.grid_padding
		padding_extend: padding_extend
		min_contrast: value.min_contrast
		cursor_pos: value.cursor_pos
		cursor_color: value.cursor_color
		bg_color: value.bg_color
		cursor_wide: u8(value.bools.cursor_wide)
		use_display_p3: u8(value.bools.use_display_p3)
		use_linear_blending: u8(value.bools.use_linear_blending)
		use_linear_correction: u8(value.bools.use_linear_correction)
	}
}

// GLTextCell is the 32-byte per-instance layout consumed by cell_text.v.glsl.
pub struct GLTextCell {
pub mut:
	glyph_x   u32
	glyph_y   u32
	glyph_w   u32
	glyph_h   u32
	bearing_x i16
	bearing_y i16
	grid_x    u16
	grid_y    u16
	color     [4]u8
	atlas     u8
	flags     u8
}

pub fn gl_text_cell(cell CellText) GLTextCell {
	mut flags := u8(0)
	if cell.bools.no_min_contrast {
		flags |= 1
	}
	if cell.bools.is_cursor_glyph {
		flags |= 2
	}
	return GLTextCell{
		glyph_x: cell.glyph_pos[0]
		glyph_y: cell.glyph_pos[1]
		glyph_w: cell.glyph_size[0]
		glyph_h: cell.glyph_size[1]
		bearing_x: i16(cell.bearings[0])
		bearing_y: i16(cell.bearings[1])
		grid_x: cell.grid_pos[0]
		grid_y: cell.grid_pos[1]
		color: cell.color
		atlas: match cell.atlas {
			.grayscale { u8(0) }
			.color { u8(1) }
		}
		flags: flags
	}
}

pub struct GLImageVertex {
pub:
	grid_pos    [2]f32
	cell_offset [2]f32
	source_rect [4]f32
	dest_size   [2]f32
}

pub struct GLBgImageVertex {
pub:
	opacity f32
	info    u8
}

pub fn gl_bg_image_vertex(value BgImageBuffer) GLBgImageVertex {
	position := match value.info.position {
		.tl { u8(0) }
		.tc { u8(1) }
		.tr { u8(2) }
		.ml { u8(3) }
		.mc { u8(4) }
		.mr { u8(5) }
		.bl { u8(6) }
		.bc { u8(7) }
		.br { u8(8) }
	}
	fit := match value.info.fit {
		.contain { u8(0) }
		.cover { u8(1) }
		.stretch { u8(2) }
		.none_ { u8(3) }
	}
	return GLBgImageVertex{
		opacity: value.opacity
		info: position | (fit << 4) | (if value.info.repeat { u8(1 << 6) } else { u8(0) })
	}
}

pub struct GLShaders {
pub mut:
	bg_color       GLPipeline
	cell_bg        GLPipeline
	cell_text      GLPipeline
	image          GLPipeline
	bg_image       GLPipeline
	post_pipelines []GLPipeline
	defunct        bool
}

pub fn GLShaders.init() !GLShaders {
	return GLShaders.init_with_sources([])
}

pub fn GLShaders.init_with_sources(custom_shaders []string) !GLShaders {
	mut shaders := GLShaders{}
	shaders.bg_color = gl_builtin_pipeline(gl_full_screen_vertex_shader, gl_bg_color_fragment_shader_raw, [], 0, .per_vertex, false) or {
		return err
	}
	shaders.cell_bg = gl_builtin_pipeline(gl_full_screen_vertex_shader, gl_cell_bg_fragment_shader_raw, [], 0, .per_vertex, true) or {
		shaders.deinit()
		return err
	}
	shaders.cell_text = gl_builtin_pipeline(gl_cell_text_vertex_shader_raw, gl_cell_text_fragment_shader_raw, gl_text_cell_attributes(), u32($sizeof(GLTextCell)), .per_instance, true) or {
		shaders.deinit()
		return err
	}
	shaders.image = gl_builtin_pipeline(gl_image_vertex_shader_raw, gl_image_fragment_shader_raw, gl_image_attributes(), u32($sizeof(GLImageVertex)), .per_instance, true) or {
		shaders.deinit()
		return err
	}
	shaders.bg_image = gl_builtin_pipeline(gl_bg_image_vertex_shader_raw, gl_bg_image_fragment_shader_raw, gl_bg_image_attributes(), u32($sizeof(GLBgImageVertex)), .per_instance, true) or {
		shaders.deinit()
		return err
	}
	for source in custom_shaders {
		pipeline := GLPipeline.init_with_sources(GLPipelineOptions{
			vertex_source: gl_full_screen_vertex_shader
			fragment_source: source
		}) or {
			for mut initialized in shaders.post_pipelines {
				initialized.deinit()
			}
			shaders.post_pipelines = []
			log.warn('error initializing OpenGL post-process shaders: ${err}')
			return shaders
		}
		shaders.post_pipelines << pipeline
	}
	return shaders
}

pub fn (mut self GLShaders) deinit() {
	if self.defunct {
		return
	}
	self.defunct = true
	self.bg_color.deinit()
	self.cell_bg.deinit()
	self.cell_text.deinit()
	self.image.deinit()
	self.bg_image.deinit()
	for mut p in self.post_pipelines {
		p.deinit()
	}
	self.post_pipelines = []
}

const gl_full_screen_vertex_shader = $embed_file('shaders/glsl/full_screen.v.glsl').to_string()
const gl_common_shader = $embed_file('shaders/glsl/common.glsl').to_string()
const gl_bg_color_fragment_shader_raw = $embed_file('shaders/glsl/bg_color.f.glsl').to_string()
const gl_cell_bg_fragment_shader_raw = $embed_file('shaders/glsl/cell_bg.f.glsl').to_string()
const gl_cell_text_vertex_shader_raw = $embed_file('shaders/glsl/cell_text.v.glsl').to_string()
const gl_cell_text_fragment_shader_raw = $embed_file('shaders/glsl/cell_text.f.glsl').to_string()
const gl_image_vertex_shader_raw = $embed_file('shaders/glsl/image.v.glsl').to_string()
const gl_image_fragment_shader_raw = $embed_file('shaders/glsl/image.f.glsl').to_string()
const gl_bg_image_vertex_shader_raw = $embed_file('shaders/glsl/bg_image.v.glsl').to_string()
const gl_bg_image_fragment_shader_raw = $embed_file('shaders/glsl/bg_image.f.glsl').to_string()

fn expand_gl_shader(source string) string {
	return source.replace('#include "common.glsl"', gl_common_shader)
}

fn gl_builtin_pipeline(vertex_source string, fragment_source string, attributes []GLVertexAttribute, stride u32, step_function GLVertexStepFunction, blending_enabled bool) !GLPipeline {
	return GLPipeline.init_with_sources(GLPipelineOptions{
		vertex_source: expand_gl_shader(vertex_source)
		fragment_source: expand_gl_shader(fragment_source)
		attributes: attributes
		stride: stride
		step_function: step_function
		blending_enabled: blending_enabled
	})
}

fn gl_text_cell_attributes() []GLVertexAttribute {
	return [
		GLVertexAttribute{ scalar_type: .u32_, count: 2, offset: __offsetof(GLTextCell, glyph_x) },
		GLVertexAttribute{ scalar_type: .u32_, count: 2, offset: __offsetof(GLTextCell, glyph_w) },
		GLVertexAttribute{ scalar_type: .i16_, count: 2, offset: __offsetof(GLTextCell, bearing_x) },
		GLVertexAttribute{ scalar_type: .u16_, count: 2, offset: __offsetof(GLTextCell, grid_x) },
		GLVertexAttribute{ scalar_type: .u8_, count: 4, offset: __offsetof(GLTextCell, color) },
		GLVertexAttribute{ scalar_type: .u8_, count: 1, offset: __offsetof(GLTextCell, atlas) },
		GLVertexAttribute{ scalar_type: .u8_, count: 1, offset: __offsetof(GLTextCell, flags) },
	]
}

fn gl_image_attributes() []GLVertexAttribute {
	return [
		GLVertexAttribute{ scalar_type: .f32_, count: 2, offset: __offsetof(GLImageVertex, grid_pos) },
		GLVertexAttribute{ scalar_type: .f32_, count: 2, offset: __offsetof(GLImageVertex, cell_offset) },
		GLVertexAttribute{ scalar_type: .f32_, count: 4, offset: __offsetof(GLImageVertex, source_rect) },
		GLVertexAttribute{ scalar_type: .f32_, count: 2, offset: __offsetof(GLImageVertex, dest_size) },
	]
}

fn gl_bg_image_attributes() []GLVertexAttribute {
	return [
		GLVertexAttribute{ scalar_type: .f32_, count: 1, offset: __offsetof(GLBgImageVertex, opacity) },
		GLVertexAttribute{ scalar_type: .u8_, count: 1, offset: __offsetof(GLBgImageVertex, info) },
	]
}
