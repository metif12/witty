module renderer

// Metal sub-types: Buffer, Frame, RenderPass, Pipeline, Sampler, Target, Texture
//
// These are stubs providing type parity with the Zig Metal renderer
// subdirectory (metal/*.zig). In the V translation, the gg graphics
// backend handles these abstractions internally.

// ============================================================
// Metal Buffer
// ============================================================

// MetalBuffer wraps a Metal GPU buffer (MTLBuffer).
//
// Port of ghostty's src/renderer/metal/buffer.zig `Buffer(comptime T)`.
// In ghostty the actual bytes live in the MTLBuffer's `contents` pointer;
// in this pure-logic port we keep a CPU-side copy in `data` so behavior can
// be exercised without a live GPU. Lengths/capacities are in elements, which
// for this port are single bytes (`u8`), matching the vertex-buffer usage
// where the element type is chosen by the caller.
pub struct MetalBuffer {
pub mut:
	// The underlying buffer handle (opaque).
	handle voidptr = unsafe { nil }
	// The options this buffer was initialized with.
	opts MetalBufferOptions
	// The number of elements currently stored in the buffer.
	len u32
	// The allocated capacity (in elements) of the buffer.
	capacity u32
	// CPU-side copy of the buffer contents. Mirrors the MTLBuffer `contents`.
	data []u8
}

// MetalBufferOptions configures how a buffer is created.
pub struct MetalBufferOptions {
pub:
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
	// XTODO: Requires [device newBufferWithLength:options:]
	return MetalBuffer{
		opts: opts
		len: len
		capacity: len
		data: []u8{len: int(len)}
	}
}

// Init the buffer filled with the given data.
pub fn MetalBuffer.init_fill(opts MetalBufferOptions, data []u8) !MetalBuffer {
	// XTODO: Requires [device newBufferWithBytes:length:options:]
	return MetalBuffer{
		opts: opts
		len: u32(data.len)
		capacity: u32(data.len)
		data: data.clone()
	}
}

pub fn (mut self MetalBuffer) deinit() {
	self.handle = unsafe { nil }
	self.data = []u8{}
}

// Sync new contents to the buffer. The data is expected to be the complete
// contents of the buffer. If the amount of data is larger than the buffer
// capacity, the buffer is reallocated to hold it. If the amount of data is
// smaller than the buffer capacity, the remaining data is left untouched.
pub fn (mut self MetalBuffer) sync(data []u8) {
	// XTODO: Requires memcpy to buffer contents pointer
	// and didModifyRange: for managed storage mode.
	req := u32(data.len)

	// If we need more capacity than we have, reallocate.
	if req > self.capacity {
		self.capacity = req
		self.data = []u8{len: int(req)}
	}

	// Copy the requested bytes into our storage.
	for i in 0 .. int(req) {
		self.data[i] = data[i]
	}

	self.len = req
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
	draw_type MetalPrimitiveType = .triangle_strip
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
	min_filter     MetalSamplerFilter      = .linear
	mag_filter     MetalSamplerFilter      = .linear
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
// Port of ghostty's src/renderer/metal/texture.zig. As with MetalBuffer, the
// real MTLTexture bytes are replaced here with a CPU-side `data` buffer of
// size `width * height * bpp` so that region uploads can be exercised without
// a live GPU.
pub struct MetalTexture {
pub mut:
	// The texture handle.
	handle voidptr = unsafe { nil }
	// Width and height.
	width  u32
	height u32
	// Bytes per pixel for this texture.
	bpp u32
	// CPU-side copy of the texture contents (row-major, width*height*bpp).
	data []u8
}

// MetalTextureOptions configures texture creation.
pub struct MetalTextureOptions {
pub:
	pixel_format MetalPixelFormat = .bgra8unorm
	storage_mode MetalStorageMode = .shared
	usage        MetalTextureUsage
}

// Initialize a texture. If data is provided, it is uploaded starting at the
// top-left (0, 0) origin.
pub fn MetalTexture.init(opts MetalTextureOptions, width u32, height u32, data ?[]u8) !MetalTexture {
	// XTODO: Requires MTLTextureDescriptor setup and
	// [device newTextureWithDescriptor:]
	bpp := bpp_of(opts.pixel_format)
	mut self := MetalTexture{
		width: width
		height: height
		bpp: bpp
		data: []u8{len: int(width * height * bpp)}
	}

	// If we have data, we set it here.
	if d := data {
		// Upload the provided bytes at the origin. Ghostty uploads the
		// full texture in one replaceRegion; here we copy as many bytes
		// as were supplied so partial seed data can be exercised.
		n := if d.len < self.data.len { d.len } else { self.data.len }
		for i in 0 .. n {
			self.data[i] = d[i]
		}
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
	self.handle = unsafe { nil }
	self.data = []u8{}
}

// Replace a rectangular region of the texture with the provided data.
//
// Does NOT check the dimensions of the data to ensure correctness. The source
// data is laid out with a stride of `width * bpp` (the region width), and is
// written into the texture using the texture's own row stride of
// `self.width * bpp`.
pub fn (mut self MetalTexture) replace_region(x u32, y u32, width u32, height u32, data []u8) {
	// XTODO: Requires [texture replaceRegion:mipmapLevel:withBytes:bytesPerRow:]
	tex_stride := self.width * self.bpp
	src_stride := width * self.bpp
	for row in 0 .. height {
		dst_off := (y + row) * tex_stride + x * self.bpp
		src_off := row * src_stride
		for col in 0 .. src_stride {
			self.data[int(dst_off + col)] = data[int(src_off + col)]
		}
	}
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
	// Bearing offsets for positioning.
	bearing_x i32
	bearing_y i32
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
		bearing_x: cell.bearings[0]
		bearing_y: cell.bearings[1]
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
