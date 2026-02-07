module renderer

// Graphics API wrapper for Metal.
//
// In this V translation, Metal-specific functionality is abstracted
// behind the gg graphics backend. These types and stubs are provided
// for parity with the Zig source and to document the Metal API surface.

// MetalAPI wraps the Metal graphics API implementation.
pub struct MetalAPI {
pub mut:
	// Alpha blending mode
	blending AlphaBlendingMode

	// The default storage mode to use for resources.
	default_storage_mode MetalStorageMode

	// The maximum 2D texture width and height supported by the device.
	max_texture_size u32
}

// Storage mode for Metal resources.
pub enum MetalStorageMode {
	// Shared between CPU and GPU (unified memory).
	shared
	// Managed by the GPU (discrete GPU).
	managed
}

// Blending mode (re-export from configpkg for convenience).
pub enum AlphaBlendingMode {
	none_
	linear
	linear_corrected
}

pub fn (b AlphaBlendingMode) is_linear() bool {
	return b == .linear || b == .linear_corrected
}

// Triple buffering for Metal swap chain.
pub const metal_swap_chain_count = 3

// The fragCoord for Metal shaders is +Y = down.
pub const metal_custom_shader_y_is_down = true

pub fn MetalAPI.init() !MetalAPI {
	// XTODO: Metal initialization requires Objective-C runtime
	// (objc module) to:
	// 1. Choose a Metal device (MTLDevice) via MTLCopyAllDevices()
	// 2. Create a command queue (MTLCommandQueue)
	// 3. Determine storage mode based on hasUnifiedMemory
	// 4. Query max texture size via supportsFamily
	// 5. Create IOSurfaceLayer and attach to view
	return MetalAPI{
		blending: .none_
		default_storage_mode: .shared
		max_texture_size: 16384
	}
}

pub fn (mut self MetalAPI) deinit() {
	// Release device, queue, and layer
}

// Get the current size of the runtime surface.
pub fn (self &MetalAPI) surface_size() (u32, u32) {
	// XTODO: Requires reading bounds and contentsScale from CALayer
	return 0, 0
}

// Metal pixel format enum (subset).
pub enum MetalPixelFormat {
	bgra8unorm
	bgra8unorm_srgb
	rgba8unorm
	rgba8unorm_srgb
	r8unorm
	r8unorm_srgb
}

// Metal GPU family for feature detection.
pub enum MetalGPUFamily {
	apple3
	apple10
}

// Metal command buffer status.
pub enum MetalCommandBufferStatus {
	not_enqueued
	enqueued
	committed
	scheduled
	completed
	error
}

// Metal load action.
pub enum MetalLoadAction {
	dont_care
	load
	clear
}

// Metal store action.
pub enum MetalStoreAction {
	dont_care
	store
	multisample_resolve
}

// Metal primitive type.
pub enum MetalPrimitiveType {
	point
	line
	line_strip
	triangle
	triangle_strip
}

// Metal vertex format (subset).
pub enum MetalVertexFormat {
	float2
	float3
	float4
	uchar4_normalized
	uint
	ushort2
	uint2
}

// Metal blend factor.
pub enum MetalBlendFactor {
	zero
	one
	source_alpha
	one_minus_source_alpha
}

// Metal blend operation.
pub enum MetalBlendOperation {
	add
}

// Metal texture usage.
pub struct MetalTextureUsage {
pub mut:
	shader_read   bool
	render_target bool
}

// Metal sampler filter.
pub enum MetalSamplerFilter {
	nearest
	linear
}

// Metal sampler address mode.
pub enum MetalSamplerAddressMode {
	clamp_to_edge
	repeat
	mirror_repeat
}

// Metal clear color.
pub struct MetalClearColor {
pub:
	r f64
	g f64
	b f64
	a f64
}
