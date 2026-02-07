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
pub struct MetalBuffer {
pub mut:
	// The underlying buffer handle (opaque).
	handle voidptr = unsafe { nil }
	// The number of elements in the buffer.
	len u32
	// The capacity (in elements) of the buffer.
	capacity u32
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

pub fn MetalBuffer.init(opts MetalBufferOptions, len u32) !MetalBuffer {
	// XTODO: Requires [device newBufferWithLength:options:]
	_ = opts
	return MetalBuffer{
		len: 0
		capacity: len
	}
}

pub fn (mut self MetalBuffer) deinit() {
	self.handle = unsafe { nil }
}

// Sync buffer contents. Reallocates if needed.
pub fn (mut self MetalBuffer) sync(data []u8) {
	// XTODO: Requires memcpy to buffer contents pointer
	// and didModifyRange: for managed storage mode
	_ = data
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
pub struct MetalTexture {
pub mut:
	// The texture handle.
	handle voidptr = unsafe { nil }
	// Width and height.
	width  u32
	height u32
}

// MetalTextureOptions configures texture creation.
pub struct MetalTextureOptions {
pub:
	pixel_format MetalPixelFormat = .bgra8unorm
	storage_mode MetalStorageMode = .shared
	usage        MetalTextureUsage
}

pub fn MetalTexture.init(opts MetalTextureOptions, width u32, height u32, data ?[]u8) !MetalTexture {
	// XTODO: Requires MTLTextureDescriptor setup and
	// [device newTextureWithDescriptor:]
	// If data is provided, call replaceRegion to upload.
	_ = opts
	_ = data
	return MetalTexture{
		width: width
		height: height
	}
}

pub fn (mut self MetalTexture) deinit() {
	self.handle = unsafe { nil }
}

// Update a rectangular region of the texture.
pub fn (mut self MetalTexture) replace_region(x u32, y u32, width u32, height u32, data []u8) {
	// XTODO: Requires [texture replaceRegion:mipmapLevel:withBytes:bytesPerRow:]
	_ = x
	_ = y
	_ = width
	_ = height
	_ = data
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
