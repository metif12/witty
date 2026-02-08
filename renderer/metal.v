module renderer

import macos

// Graphics API wrapper for Metal.
//
// In this V translation, Metal is used directly via Objective-C
// helpers in macos/appkit.m. The MetalAPI struct holds opaque
// pointers to MTLDevice, MTLCommandQueue, and CAMetalLayer.

// MetalAPI wraps the Metal graphics API implementation.
pub struct MetalAPI {
pub mut:
	// Opaque handles to Metal objects.
	device voidptr = unsafe { nil }
	queue  voidptr = unsafe { nil }
	layer  voidptr = unsafe { nil }

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

// init_from_view initializes the Metal API using a view that already
// has a CAMetalLayer set up (done in appkit.m's initWithFrame).
pub fn MetalAPI.init_from_view(view voidptr) !MetalAPI {
	device := macos.metal_device(view)
	queue := macos.metal_queue(view)
	layer := macos.metal_layer(view)

	if device == unsafe { nil } || queue == unsafe { nil } || layer == unsafe { nil } {
		return error('Metal not available')
	}

	unified := macos.metal_has_unified_memory(device)
	storage := if unified { MetalStorageMode.shared } else { MetalStorageMode.managed }
	max_tex := macos.metal_max_texture_size(device)

	return MetalAPI{
		device: device
		queue: queue
		layer: layer
		blending: .none_
		default_storage_mode: storage
		max_texture_size: max_tex
	}
}

// init creates a MetalAPI with default/stub values (no device).
pub fn MetalAPI.init() !MetalAPI {
	return MetalAPI{
		blending: .none_
		default_storage_mode: .shared
		max_texture_size: 16384
	}
}

pub fn (mut self MetalAPI) deinit() {
	// Handles are owned by the view; nothing to release here.
	self.device = unsafe { nil }
	self.queue = unsafe { nil }
	self.layer = unsafe { nil }
}

// next_drawable gets the next drawable from the Metal layer.
pub fn (self &MetalAPI) next_drawable() voidptr {
	return macos.metal_next_drawable(self.layer)
}

// create_command_buffer creates a new command buffer from the queue.
pub fn (self &MetalAPI) create_command_buffer() voidptr {
	return macos.metal_create_command_buffer(self.queue)
}

// present_and_commit presents the drawable and commits the command buffer.
pub fn (self &MetalAPI) present_and_commit(cmd_buf voidptr, drawable voidptr) {
	macos.metal_present_and_commit(cmd_buf, drawable)
}

// Get the current size of the runtime surface.
pub fn (self &MetalAPI) surface_size() (u32, u32) {
	// XTODO: Requires reading drawableSize from CAMetalLayer
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
