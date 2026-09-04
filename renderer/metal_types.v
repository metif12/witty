module renderer

import macos

// Metal sub-types: Buffer, Frame, RenderPass, Pipeline, Sampler, Target, Texture
//
// These wrappers mirror the native Metal resources used by Ghostty.

// ============================================================
// Metal Buffer
// ============================================================

// MetalBuffer wraps a Metal GPU buffer (MTLBuffer).
//
// Port of ghostty's src/renderer/metal/buffer.zig `Buffer(comptime T)`.
// The local specialization stores bytes, so lengths are byte counts.
pub struct MetalBuffer {
pub mut:
	// The underlying buffer handle (opaque).
	handle voidptr = unsafe { nil }
	// The options this buffer was initialized with.
	opts MetalBufferOptions
	// The number of elements currently stored in the buffer.
	len u32
}

// MetalBufferOptions configures how a buffer is created.
pub struct MetalBufferOptions {
pub:
	// MTLDevice used to allocate this buffer.
	device voidptr = unsafe { nil }
	// CPU cache mode (write_combined for write-only from CPU).
	cpu_cache_mode MetalCPUCacheMode = .write_combined
	// Storage mode.
	storage_mode MetalStorageMode = .shared
}

pub enum MetalCPUCacheMode {
	default_cache
	write_combined
}

// Initialize a buffer with the given length pre-allocated.
pub fn MetalBuffer.init(opts MetalBufferOptions, len u32) !MetalBuffer {
	if opts.device == unsafe { nil } {
		return error('Metal buffer requires a device')
	}
	handle := macos.metal_new_buffer_length(opts.device, usize(len), opts.resource_options())
	if handle == unsafe { nil } {
		return error('Metal buffer allocation failed')
	}
	return MetalBuffer{
		handle: handle
		opts: opts
		len: len
	}
}

// Init the buffer filled with the given data.
pub fn MetalBuffer.init_fill(opts MetalBufferOptions, data []u8) !MetalBuffer {
	if data.len == 0 {
		return MetalBuffer.init(opts, 0)
	}
	if opts.device == unsafe { nil } {
		return error('Metal buffer requires a device')
	}
	handle := macos.metal_new_buffer_bytes(opts.device, data, opts.resource_options())
	if handle == unsafe { nil } {
		return error('Metal buffer allocation failed')
	}
	return MetalBuffer{
		handle: handle
		opts: opts
		len: u32(data.len)
	}
}

pub fn MetalBuffer.init_value[T](opts MetalBufferOptions, value &T) !MetalBuffer {
	if opts.device == unsafe { nil } {
		return error('Metal buffer requires a device')
	}
	length := usize($sizeof(T))
	handle := macos.metal_new_buffer_raw(opts.device, voidptr(value), length, opts.resource_options())
	if handle == unsafe { nil } {
		return error('Metal buffer allocation failed')
	}
	return MetalBuffer{
		handle: handle
		opts: opts
		len: u32(length)
	}
}

pub fn (mut self MetalBuffer) deinit() {
	macos.metal_release(self.handle)
	self.handle = unsafe { nil }
	self.len = 0
}

// Sync new contents to the buffer. The data is expected to be the complete
// contents of the buffer. If the amount of data is larger than the buffer
// capacity, the buffer is reallocated to hold it. If the amount of data is
// smaller than the buffer capacity, the remaining data is left untouched.
pub fn (mut self MetalBuffer) sync(data []u8) ! {
	req_bytes := usize(data.len)
	available_bytes := macos.metal_buffer_length(self.handle)
	if req_bytes > available_bytes {
		macos.metal_release(self.handle)
		new_len := req_bytes * 2
		self.handle = macos.metal_new_buffer_length(self.opts.device, new_len, self.opts.resource_options())
		if self.handle == unsafe { nil } {
			self.len = 0
			return error('Metal buffer reallocation failed')
		}
		self.len = u32(new_len)
	}
	if req_bytes == 0 {
		return
	}
	dst := macos.metal_buffer_contents(self.handle)
	if dst == unsafe { nil } {
		return error('Metal buffer contents pointer is null')
	}
	unsafe { vmemcpy(dst, data.data, data.len) }
	if self.opts.storage_mode == .managed {
		macos.metal_buffer_did_modify(self.handle, req_bytes)
	}
}

fn (opts MetalBufferOptions) resource_options() u64 {
	cache := if opts.cpu_cache_mode == .write_combined { u64(1) } else { u64(0) }
	storage := if opts.storage_mode == .managed { u64(1 << 4) } else { u64(0) }
	return cache | storage
}

fn metal_command_buffer_status(raw u64) MetalCommandBufferStatus {
	return match raw {
		0 { .not_enqueued }
		1 { .enqueued }
		2 { .committed }
		3 { .scheduled }
		4 { .completed }
		else { .error }
	}
}

fn metal_sampler_address_mode(mode MetalSamplerAddressMode) u64 {
	return match mode {
		.clamp_to_edge { 0 }
		.repeat { 2 }
		.mirror_repeat { 3 }
	}
}

// ============================================================
// Metal Frame
// ============================================================

// MetalFrame wraps a Metal command buffer for encoding a frame.
pub struct MetalFrame {
pub mut:
	// The command buffer handle.
	command_buffer voidptr = unsafe { nil }
}

pub fn MetalFrame.begin(queue voidptr) !MetalFrame {
	if queue == unsafe { nil } {
		return error('Metal frame requires a command queue')
	}
	buffer := macos.metal_create_command_buffer(queue)
	if buffer == unsafe { nil } {
		return error('Metal command buffer allocation failed')
	}
	return MetalFrame{
		command_buffer: buffer
	}
}

pub fn (mut self MetalFrame) complete(sync_ bool) MetalCommandBufferStatus {
	if self.command_buffer == unsafe { nil } {
		return .error
	}
	macos.metal_command_buffer_commit(self.command_buffer)
	if sync_ {
		macos.metal_command_buffer_wait(self.command_buffer)
	}
	return metal_command_buffer_status(macos.metal_command_buffer_status(self.command_buffer))
}

// ============================================================
// Metal RenderPass
// ============================================================

// MetalRenderPass wraps a Metal render command encoder.
pub struct MetalRenderPass {
pub mut:
	// The render command encoder handle.
	encoder voidptr = unsafe { nil }
}

// MetalRenderStep describes a single step in a render pass.
pub struct MetalRenderStep {
pub:
	// The pipeline to use.
	pipeline MetalPipeline
	// Uniform buffer, bound at index 1 for both shader stages.
	uniforms voidptr = unsafe { nil }
	// Vertex and fragment buffers. Entry zero uses index zero; later entries
	// start at index two so uniforms can remain at index one.
	buffers []voidptr
	// Textures bound to both stages by slice index.
	textures []voidptr
	// Fragment samplers bound by slice index.
	samplers []voidptr
	// Draw call configuration.
	draw_type      MetalPrimitiveType = .triangle_strip
	vertex_count   u32 = 4
	instance_count u32 = 1
}

pub struct MetalRenderPassAttachment {
pub:
	texture     voidptr = unsafe { nil }
	clear_color ?[4]f64
}

pub fn MetalRenderPass.begin(command_buffer voidptr, attachments []MetalRenderPassAttachment) !MetalRenderPass {
	if command_buffer == unsafe { nil } {
		return error('Metal render pass requires a command buffer')
	}
	if attachments.len == 0 {
		return error('Metal render pass requires an attachment')
	}
	descriptor := macos.metal_render_pass_descriptor()
	if descriptor == unsafe { nil } {
		return error('Metal render pass descriptor unavailable')
	}
	for index, attachment in attachments {
		if attachment.texture == unsafe { nil } {
			return error('Metal render pass attachment texture is null')
		}
		macos.metal_render_pass_set_attachment(descriptor, usize(index), attachment.texture, attachment.clear_color)
	}
	encoder := macos.metal_create_encoder(command_buffer, descriptor)
	if encoder == unsafe { nil } {
		return error('Metal render command encoder creation failed')
	}
	return MetalRenderPass{
		encoder: encoder
	}
}

pub fn (mut self MetalRenderPass) step(s MetalRenderStep) {
	if s.instance_count == 0 || self.encoder == unsafe { nil }
		|| s.pipeline.handle == unsafe { nil } {
		return
	}
	macos.metal_encoder_set_pipeline(self.encoder, s.pipeline.handle)
	if s.buffers.len > 0 {
		macos.metal_encoder_set_buffer(self.encoder, s.buffers[0], 0)
		for index in 1 .. s.buffers.len {
			macos.metal_encoder_set_buffer(self.encoder, s.buffers[index], usize(index + 1))
		}
	}
	if s.uniforms != unsafe { nil } {
		macos.metal_encoder_set_buffer(self.encoder, s.uniforms, 1)
	}
	for index, texture in s.textures {
		macos.metal_encoder_set_texture(self.encoder, texture, usize(index))
	}
	for index, sampler in s.samplers {
		macos.metal_encoder_set_sampler(self.encoder, sampler, usize(index))
	}
	macos.metal_encoder_draw(self.encoder, u64(s.draw_type), usize(s.vertex_count), usize(s.instance_count))
}

pub fn (mut self MetalRenderPass) complete() {
	macos.metal_end_encoding(self.encoder)
	self.encoder = unsafe { nil }
}

// ============================================================
// Metal Pipeline
// ============================================================

// MetalPipeline wraps a Metal render pipeline state (MTLRenderPipelineState).
pub struct MetalPipeline {
pub mut:
	// The pipeline state handle.
	handle voidptr = unsafe { nil }
}

pub struct MetalVertexAttribute {
pub:
	format MetalVertexFormat
	offset usize
}

pub enum MetalVertexStepFunction {
	constant
	per_vertex
	per_instance
	per_patch
	per_patch_control_point
}

pub struct MetalPipelineOptions {
pub:
	device           voidptr = unsafe { nil }
	vertex_fn        string
	fragment_fn      string
	vertex_library   voidptr = unsafe { nil }
	fragment_library voidptr = unsafe { nil }
	attributes       []MetalVertexAttribute
	vertex_stride    usize
	step_fn          MetalVertexStepFunction = .per_vertex
	pixel_format     MetalPixelFormat = .bgra8unorm
	blending_enabled bool = true
}

pub fn MetalPipeline.init(opts MetalPipelineOptions) !MetalPipeline {
	if opts.device == unsafe { nil } || opts.vertex_library == unsafe { nil }
		|| opts.fragment_library == unsafe { nil } {
		return error('Metal pipeline requires a device and shader libraries')
	}
	if opts.vertex_fn.len == 0 || opts.fragment_fn.len == 0 {
		return error('Metal pipeline requires shader function names')
	}
	mut attributes := []macos.MetalVertexAttribute{cap: opts.attributes.len}
	for attribute in opts.attributes {
		attributes << macos.MetalVertexAttribute{
			format: metal_vertex_format_value(attribute.format)
			offset: attribute.offset
		}
	}
	handle := macos.metal_new_pipeline(opts.device, opts.vertex_library, opts.fragment_library, opts.vertex_fn, opts.fragment_fn, attributes, opts.vertex_stride, u64(opts.step_fn), metal_pixel_format_value(opts.pixel_format), opts.blending_enabled)
	if handle == unsafe { nil } {
		return error('Metal render pipeline creation failed')
	}
	return MetalPipeline{
		handle: handle
	}
}

pub fn (mut self MetalPipeline) deinit() {
	macos.metal_release(self.handle)
	self.handle = unsafe { nil }
}

// ============================================================
// Metal Sampler
// ============================================================

// MetalSampler wraps a Metal sampler state (MTLSamplerState).
pub struct MetalSampler {
pub mut:
	handle voidptr = unsafe { nil }
}

// MetalSamplerOptions configures sampler creation.
pub struct MetalSamplerOptions {
pub:
	device         voidptr = unsafe { nil }
	min_filter     MetalSamplerFilter = .linear
	mag_filter     MetalSamplerFilter = .linear
	s_address_mode MetalSamplerAddressMode = .clamp_to_edge
	t_address_mode MetalSamplerAddressMode = .clamp_to_edge
}

pub fn MetalSampler.init(opts MetalSamplerOptions) !MetalSampler {
	if opts.device == unsafe { nil } {
		return error('Metal sampler requires a device')
	}
	handle := macos.metal_new_sampler(opts.device, u64(opts.min_filter), u64(opts.mag_filter), metal_sampler_address_mode(opts.s_address_mode), metal_sampler_address_mode(opts.t_address_mode))
	if handle == unsafe { nil } {
		return error('Metal sampler allocation failed')
	}
	return MetalSampler{
		handle: handle
	}
}

pub fn (mut self MetalSampler) deinit() {
	macos.metal_release(self.handle)
	self.handle = unsafe { nil }
}

// ============================================================
// Metal Target
// ============================================================

// MetalTarget wraps a Metal render target (IOSurface-backed MTLTexture).
pub struct MetalTarget {
pub mut:
	// The IOSurface handle.
	surface &macos.IOSurface = unsafe { nil }
	// The texture handle.
	texture voidptr = unsafe { nil }
	// Width and height of the target.
	width  u32
	height u32
}

pub struct MetalTargetOptions {
pub:
	device       voidptr = unsafe { nil }
	width        u32
	height       u32
	pixel_format MetalPixelFormat = .bgra8unorm
	storage_mode MetalStorageMode = .shared
}

pub fn MetalTarget.init(opts MetalTargetOptions) !MetalTarget {
	if opts.device == unsafe { nil } {
		return error('Metal target requires a device')
	}
	if opts.width == 0 || opts.height == 0 {
		return error('Metal target dimensions must be non-zero')
	}
	colorspace := macos.CGColorSpace.create_named(.display_p3)!
	defer {
		colorspace.release()
	}
	surface := macos.IOSurface.init(macos.IOSurfaceProperties{
		width: int(opts.width)
		height: int(opts.height)
		pixel_format: .p32_bgra
		bytes_per_element: 4
		colorspace: colorspace
	})!
	texture := macos.metal_new_iosurface_texture(opts.device, voidptr(surface), metal_pixel_format_value(opts.pixel_format), usize(opts.width), usize(opts.height), metal_resource_options(.write_combined, opts.storage_mode))
	if texture == unsafe { nil } {
		surface.deinit()
		return error('Metal target texture allocation failed')
	}
	return MetalTarget{
		surface: surface
		texture: texture
		width: opts.width
		height: opts.height
	}
}

pub fn (mut self MetalTarget) deinit() {
	if self.surface != unsafe { nil } {
		self.surface.deinit()
	}
	macos.metal_release(self.texture)
	self.surface = unsafe { nil }
	self.texture = unsafe { nil }
}

// ============================================================
// Metal Texture
// ============================================================

// MetalTexture wraps a Metal texture (MTLTexture).
//
// Port of ghostty's src/renderer/metal/texture.zig.
pub struct MetalTexture {
pub mut:
	// The texture handle.
	handle voidptr = unsafe { nil }
	// Width and height.
	width  u32
	height u32
	// Bytes per pixel for this texture.
	bpp u32
}

// MetalTextureOptions configures texture creation.
pub struct MetalTextureOptions {
pub:
	device       voidptr = unsafe { nil }
	pixel_format MetalPixelFormat = .bgra8unorm
	storage_mode MetalStorageMode = .shared
	usage        MetalTextureUsage
}

// Initialize a texture. If data is provided, it is uploaded starting at the
// top-left (0, 0) origin.
pub fn MetalTexture.init(opts MetalTextureOptions, width u32, height u32, data ?[]u8) !MetalTexture {
	if opts.device == unsafe { nil } {
		return error('Metal texture requires a device')
	}
	if width == 0 || height == 0 {
		return error('Metal texture dimensions must be non-zero')
	}
	bpp := bpp_of(opts.pixel_format)
	handle := macos.metal_new_texture(opts.device, metal_pixel_format_value(opts.pixel_format), usize(width), usize(height), metal_resource_options(.default_cache, opts.storage_mode), metal_texture_usage_value(opts.usage))
	if handle == unsafe { nil } {
		return error('Metal texture allocation failed')
	}
	mut self := MetalTexture{
		handle: handle
		width: width
		height: height
		bpp: bpp
	}

	if d := data {
		if d.len != int(width * height * bpp) {
			self.deinit()
			return error('Metal texture data size does not match dimensions')
		}
		self.replace_region(0, 0, width, height, d)!
	}

	return self
}

// bpp_of returns the bytes per pixel for the provided pixel format.
//
// Port of ghostty's texture.zig `bppOf`, restricted to the pixel formats we
// actually expose in MetalPixelFormat.
fn bpp_of(pixel_format MetalPixelFormat) u32 {
	return match pixel_format {
		// 8-bit pixel formats.
		.r8unorm, .r8unorm_srgb {
			u32(1)
		}

		// 32-bit pixel formats.
		.rgba8unorm, .rgba8unorm_srgb, .bgra8unorm, .bgra8unorm_srgb {
			u32(4)
		}
	}
}

pub fn (mut self MetalTexture) deinit() {
	macos.metal_release(self.handle)
	self.handle = unsafe { nil }
}

// Replace a rectangular region of the texture with the provided data.
//
// Does NOT check the dimensions of the data to ensure correctness. The source
// data is laid out with a stride of `width * bpp` (the region width), and is
// written into the texture using the texture's own row stride of
// `self.width * bpp`.
pub fn (mut self MetalTexture) replace_region(x u32, y u32, width u32, height u32, data []u8) ! {
	if x + width > self.width || y + height > self.height {
		return error('Metal texture region is out of bounds')
	}
	required := width * height * self.bpp
	if data.len != int(required) {
		return error('Metal texture region data size does not match dimensions')
	}
	if required == 0 {
		return
	}
	macos.metal_texture_replace_region(self.handle, usize(x), usize(y), usize(width), usize(height), data, usize(width * self.bpp))
}

fn metal_resource_options(cache MetalCPUCacheMode, storage MetalStorageMode) u64 {
	return (if cache == .write_combined { u64(1) } else { u64(0) }) | (if storage == .managed {
		u64(1 << 4)
	} else {
		u64(0)
	})
}

fn metal_pixel_format_value(format MetalPixelFormat) u64 {
	return match format {
		.r8unorm { 10 }
		.r8unorm_srgb { 11 }
		.rgba8unorm { 70 }
		.rgba8unorm_srgb { 71 }
		.bgra8unorm { 80 }
		.bgra8unorm_srgb { 81 }
	}
}

fn metal_vertex_format_value(format MetalVertexFormat) u64 {
	return match format {
		.uchar4 { 3 }
		.uchar4_normalized { 9 }
		.ushort2 { 13 }
		.short2 { 16 }
		.float { 28 }
		.float2 { 29 }
		.float3 { 30 }
		.float4 { 31 }
		.uint { 36 }
		.uint2 { 37 }
		.uchar { 45 }
	}
}

fn metal_texture_usage_value(usage MetalTextureUsage) u64 {
	mut value := u64(0)
	if usage.shader_read {
		value |= 1
	}
	if usage.render_target {
		value |= 4
	}
	return value
}

// ============================================================
// Metal IOSurfaceLayer
// ============================================================

// MetalIOSurfaceLayer wraps a CALayer subclass with IOSurface backing.
pub struct MetalIOSurfaceLayer {
pub mut:
	// The layer handle (CALayer*).
	layer voidptr = unsafe { nil }
}

pub fn MetalIOSurfaceLayer.init() !MetalIOSurfaceLayer {
	layer := macos.metal_iosurface_layer_new()
	if layer == unsafe { nil } {
		return error('Metal IOSurface layer allocation failed')
	}
	return MetalIOSurfaceLayer{
		layer: layer
	}
}

pub fn (mut self MetalIOSurfaceLayer) release() {
	macos.metal_release(self.layer)
	self.layer = unsafe { nil }
}

// Set the surface to display (async, on main thread).
pub fn (mut self MetalIOSurfaceLayer) set_surface(surface &macos.IOSurface) ! {
	if !macos.metal_iosurface_layer_set_surface(self.layer, voidptr(surface)) {
		return error('Metal IOSurface layer update failed')
	}
}

// Set the surface to display synchronously.
pub fn (mut self MetalIOSurfaceLayer) set_surface_sync(surface &macos.IOSurface) {
	macos.metal_iosurface_layer_set_surface_sync(self.layer, voidptr(surface))
}

pub type MetalLayerDisplayCallback = fn (context voidptr)

pub fn (mut self MetalIOSurfaceLayer) set_display_callback(callback MetalLayerDisplayCallback, context voidptr) {
	macos.metal_iosurface_layer_set_display_callback(self.layer, voidptr(callback), context)
}

// ============================================================
// Metal cell shader parameter (GPU-side text cell)
// ============================================================

// MetalTextCell is a single parameter for the terminal cell text shader.
//
// Port of ghostty's src/renderer/metal/shaders.zig `CellText`. It is the
// flattened, GPU-ready form of the logical CellText: the atlas kind is stored
// as a raw u8 (0 = grayscale, 1 = color), the boolean flags are packed into a
// single `flags` byte, and the grid position is split into grid_x / grid_y.
pub struct MetalTextCell {
pub mut:
	// Position of the glyph in the atlas [x, y].
	glyph_x u32
	glyph_y u32
	// Size of the glyph in the atlas [w, h].
	glyph_w u32
	glyph_h u32
	// Bearing offsets for positioning. i16 to match ghostty's CellText
	// (the GPU vertex struct must stay 32 bytes).
	bearing_x i16
	bearing_y i16
	// Grid position (column, row).
	grid_x u16
	grid_y u16
	// Color [r, g, b, a].
	color [4]u8
	// Which texture atlas this glyph is in (0 = grayscale, 1 = color).
	atlas u8
	// Packed boolean flags:
	//   bit 0 = no_min_contrast
	//   bit 1 = is_cursor_glyph
	flags u8
}

// metal_text_cell converts a logical CellText into its GPU representation.
//
// Mirrors ghostty's construction of shaders.CellText, packing the atlas kind
// and boolean flags into their compact GPU encodings.
pub fn metal_text_cell(cell CellText) MetalTextCell {
	mut flags := u8(0)
	if cell.bools.no_min_contrast {
		flags |= 0x01
	}
	if cell.bools.is_cursor_glyph {
		flags |= 0x02
	}

	atlas := match cell.atlas {
		.grayscale { u8(0) }
		.color { u8(1) }
	}

	return MetalTextCell{
		glyph_x: cell.glyph_pos[0]
		glyph_y: cell.glyph_pos[1]
		glyph_w: cell.glyph_size[0]
		glyph_h: cell.glyph_size[1]
		bearing_x: i16(cell.bearings[0])
		bearing_y: i16(cell.bearings[1])
		grid_x: cell.grid_pos[0]
		grid_y: cell.grid_pos[1]
		color: cell.color
		atlas: atlas
		flags: flags
	}
}

// ============================================================
// Metal Shaders
// ============================================================

pub struct MetalImageVertex {
pub:
	grid_pos    [2]f32
	cell_offset [2]f32
	source_rect [4]f32
	dest_size   [2]f32
}

pub struct MetalBgImageVertex {
pub:
	opacity f32
	info    u8
}

const metal_shader_source = $embed_file('shaders.metal').to_string()

// MetalShaders manages the Metal shader library and all pipelines.
pub struct MetalShaders {
pub mut:
	// Library containing Ghostty's built-in Metal shader functions.
	library voidptr = unsafe { nil }
	// Pipeline for background color.
	bg_color MetalPipeline
	// Pipeline for cell backgrounds.
	cell_bg MetalPipeline
	// Pipeline for cell text.
	cell_text MetalPipeline
	// Pipeline for images.
	image MetalPipeline
	// Pipeline for background images.
	bg_image MetalPipeline
	// Post-processing pipelines (custom shaders).
	post_pipelines []MetalPipeline
	// Protect against duplicate lifecycle teardown.
	defunct bool
}

pub fn MetalShaders.init(device voidptr, post_shaders []string, pixel_format MetalPixelFormat) !MetalShaders {
	if device == unsafe { nil } {
		return error('Metal shaders require a device')
	}
	library := macos.metal_new_library_source(device, metal_shader_source)
	if library == unsafe { nil } {
		return error('Metal shader library compilation failed')
	}
	mut self := MetalShaders{
		library: library
	}

	self.bg_color = MetalPipeline.init(MetalPipelineOptions{
		device: device
		vertex_fn: 'full_screen_vertex'
		fragment_fn: 'bg_color_fragment'
		vertex_library: library
		fragment_library: library
		pixel_format: pixel_format
		blending_enabled: false
	}) or {
		self.deinit()
		return err
	}
	self.cell_bg = MetalPipeline.init(MetalPipelineOptions{
		device: device
		vertex_fn: 'full_screen_vertex'
		fragment_fn: 'cell_bg_fragment'
		vertex_library: library
		fragment_library: library
		pixel_format: pixel_format
		blending_enabled: true
	}) or {
		self.deinit()
		return err
	}
	self.cell_text = MetalPipeline.init(MetalPipelineOptions{
		device: device
		vertex_fn: 'cell_text_vertex'
		fragment_fn: 'cell_text_fragment'
		vertex_library: library
		fragment_library: library
		attributes: metal_text_cell_attributes()
		vertex_stride: $sizeof(MetalTextCell)
		step_fn: .per_instance
		pixel_format: pixel_format
		blending_enabled: true
	}) or {
		self.deinit()
		return err
	}
	self.image = MetalPipeline.init(MetalPipelineOptions{
		device: device
		vertex_fn: 'image_vertex'
		fragment_fn: 'image_fragment'
		vertex_library: library
		fragment_library: library
		attributes: metal_image_attributes()
		vertex_stride: $sizeof(MetalImageVertex)
		step_fn: .per_instance
		pixel_format: pixel_format
		blending_enabled: true
	}) or {
		self.deinit()
		return err
	}
	self.bg_image = MetalPipeline.init(MetalPipelineOptions{
		device: device
		vertex_fn: 'bg_image_vertex'
		fragment_fn: 'bg_image_fragment'
		vertex_library: library
		fragment_library: library
		attributes: metal_bg_image_attributes()
		vertex_stride: $sizeof(MetalBgImageVertex)
		step_fn: .per_instance
		pixel_format: pixel_format
		blending_enabled: true
	}) or {
		self.deinit()
		return err
	}

	mut post_failed := false
	for source in post_shaders {
		post_library := macos.metal_new_library_source(device, source)
		if post_library == unsafe { nil } {
			post_failed = true
			break
		}
		pipeline := MetalPipeline.init(MetalPipelineOptions{
			device: device
			vertex_fn: 'full_screen_vertex'
			fragment_fn: 'main0'
			vertex_library: library
			fragment_library: post_library
			pixel_format: pixel_format
			blending_enabled: false
		}) or {
			macos.metal_release(post_library)
			post_failed = true
			break
		}
		macos.metal_release(post_library)
		self.post_pipelines << pipeline
	}
	if post_failed {
		for mut pipeline in self.post_pipelines {
			pipeline.deinit()
		}
		self.post_pipelines = []MetalPipeline{}
	}

	return self
}

pub fn (mut self MetalShaders) deinit() {
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
	self.post_pipelines = []MetalPipeline{}
	macos.metal_release(self.library)
	self.library = unsafe { nil }
}

fn metal_text_cell_attributes() []MetalVertexAttribute {
	return [
		MetalVertexAttribute{ format: .uint2, offset: __offsetof(MetalTextCell, glyph_x) },
		MetalVertexAttribute{ format: .uint2, offset: __offsetof(MetalTextCell, glyph_w) },
		MetalVertexAttribute{ format: .short2, offset: __offsetof(MetalTextCell, bearing_x) },
		MetalVertexAttribute{ format: .ushort2, offset: __offsetof(MetalTextCell, grid_x) },
		MetalVertexAttribute{ format: .uchar4, offset: __offsetof(MetalTextCell, color) },
		MetalVertexAttribute{ format: .uchar, offset: __offsetof(MetalTextCell, atlas) },
		MetalVertexAttribute{ format: .uchar, offset: __offsetof(MetalTextCell, flags) },
	]
}

fn metal_image_attributes() []MetalVertexAttribute {
	return [
		MetalVertexAttribute{ format: .float2, offset: __offsetof(MetalImageVertex, grid_pos) },
		MetalVertexAttribute{ format: .float2, offset: __offsetof(MetalImageVertex, cell_offset) },
		MetalVertexAttribute{ format: .float4, offset: __offsetof(MetalImageVertex, source_rect) },
		MetalVertexAttribute{ format: .float2, offset: __offsetof(MetalImageVertex, dest_size) },
	]
}

fn metal_bg_image_attributes() []MetalVertexAttribute {
	return [
		MetalVertexAttribute{ format: .float, offset: __offsetof(MetalBgImageVertex, opacity) },
		MetalVertexAttribute{ format: .uchar, offset: __offsetof(MetalBgImageVertex, info) },
	]
}
