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

// ============================================================
// Metal Frame
// ============================================================

// MetalFrame wraps a Metal command buffer for encoding a frame.
pub struct MetalFrame {
pub mut:
	// The command buffer handle.
	command_buffer voidptr = unsafe { nil }
}

pub fn MetalFrame.begin() !MetalFrame {
	// XTODO: Requires [commandQueue commandBuffer] and
	// completion handler setup via addCompletedHandler:
	return MetalFrame{}
}

pub fn (mut self MetalFrame) complete(sync_ bool) {
	// XTODO: Requires [commandBuffer commit] and optionally
	// [commandBuffer waitUntilCompleted] for sync
	_ = sync_
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
	// Draw call configuration.
	draw_type    MetalPrimitiveType = .triangle_strip
	vertex_count u32 = 4
}

pub fn MetalRenderPass.begin() !MetalRenderPass {
	// XTODO: Requires renderCommandEncoderWithDescriptor:
	return MetalRenderPass{}
}

pub fn (mut self MetalRenderPass) step(s MetalRenderStep) {
	// XTODO: Requires setRenderPipelineState:, setVertexBuffer:,
	// setFragmentTexture:, setFragmentSamplerState:,
	// drawPrimitives:vertexStart:vertexCount:instanceCount:
	_ = s
}

pub fn (mut self MetalRenderPass) complete() {
	// XTODO: Requires [encoder endEncoding]
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

pub fn MetalPipeline.init() !MetalPipeline {
	// XTODO: Requires MTLRenderPipelineDescriptor setup with
	// vertex/fragment functions, vertex descriptor, color attachment
	// pixel format, and blending configuration.
	// Then [device newRenderPipelineStateWithDescriptor:error:]
	return MetalPipeline{}
}

pub fn (mut self MetalPipeline) deinit() {
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
	min_filter     MetalSamplerFilter = .linear
	mag_filter     MetalSamplerFilter = .linear
	s_address_mode MetalSamplerAddressMode = .clamp_to_edge
	t_address_mode MetalSamplerAddressMode = .clamp_to_edge
}

pub fn MetalSampler.init(opts MetalSamplerOptions) !MetalSampler {
	// XTODO: Requires MTLSamplerDescriptor setup and
	// [device newSamplerStateWithDescriptor:]
	_ = opts
	return MetalSampler{}
}

pub fn (mut self MetalSampler) deinit() {
	self.handle = unsafe { nil }
}

// ============================================================
// Metal Target
// ============================================================

// MetalTarget wraps a Metal render target (IOSurface-backed MTLTexture).
pub struct MetalTarget {
pub mut:
	// The IOSurface handle.
	surface voidptr = unsafe { nil }
	// The texture handle.
	texture voidptr = unsafe { nil }
	// Width and height of the target.
	width  u32
	height u32
}

pub fn MetalTarget.init(width u32, height u32) !MetalTarget {
	// XTODO: Requires IOSurfaceCreate with Display P3 colorspace
	// and [device newTextureWithDescriptor:iosurface:plane:]
	return MetalTarget{
		width: width
		height: height
	}
}

pub fn (mut self MetalTarget) deinit() {
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
	// XTODO: Requires creating a custom CALayer subclass that
	// displays IOSurface contents and supports a display callback.
	return MetalIOSurfaceLayer{}
}

pub fn (mut self MetalIOSurfaceLayer) release() {
	self.layer = unsafe { nil }
}

// Set the surface to display (async, on main thread).
pub fn (mut self MetalIOSurfaceLayer) set_surface(surface voidptr) ! {
	// XTODO: Requires dispatch_async to main queue and
	// setting layer.contents = surface
	_ = surface
}

// Set the surface to display synchronously.
pub fn (mut self MetalIOSurfaceLayer) set_surface_sync(surface voidptr) {
	// XTODO: Requires dispatch_sync to main queue
	_ = surface
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

// MetalShaders manages the Metal shader library and all pipelines.
pub struct MetalShaders {
pub mut:
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
}

pub fn MetalShaders.init() !MetalShaders {
	// XTODO: Requires loading Metal shader library from
	// compiled .metallib or source, then creating each
	// pipeline with the appropriate vertex/fragment functions.
	return MetalShaders{
		bg_color: MetalPipeline{}
		cell_bg: MetalPipeline{}
		cell_text: MetalPipeline{}
		image: MetalPipeline{}
		bg_image: MetalPipeline{}
	}
}

pub fn (mut self MetalShaders) deinit() {
	self.bg_color.deinit()
	self.cell_bg.deinit()
	self.cell_text.deinit()
	self.image.deinit()
	self.bg_image.deinit()
	for mut p in self.post_pipelines {
		p.deinit()
	}
}
