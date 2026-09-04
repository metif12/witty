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

	// True when this instance created and therefore owns device and queue.
	owns_handles bool
	// True when this instance owns its IOSurface presentation layer.
	owns_layer bool
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
	layer := macos.metal_iosurface_layer_new()

	if device == unsafe { nil } || queue == unsafe { nil } || layer == unsafe { nil } {
		macos.metal_release(layer)
		return error('Metal not available')
	}
	macos.metal_install_iosurface_layer(view, layer)

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
		owns_layer: true
	}
}

// init creates a MetalAPI with default/stub values (no device).
pub fn MetalAPI.init() !MetalAPI {
	device := macos.metal_system_default_device()
	if device == unsafe { nil } {
		return error('Metal not available')
	}
	queue := macos.metal_new_command_queue(device)
	if queue == unsafe { nil } {
		return error('Metal command queue unavailable')
	}
	return MetalAPI{
		device: device
		queue: queue
		blending: .none_
		default_storage_mode: if macos.metal_has_unified_memory(device) {
			.shared
		} else {
			.managed
		}
		max_texture_size: macos.metal_max_texture_size(device)
		owns_handles: true
	}
}

pub fn (mut self MetalAPI) deinit() {
	if self.owns_handles {
		macos.metal_release(self.queue)
		macos.metal_release(self.device)
	}
	if self.owns_layer {
		macos.metal_release(self.layer)
	}
	self.device = unsafe { nil }
	self.queue = unsafe { nil }
	self.layer = unsafe { nil }
	self.owns_handles = false
	self.owns_layer = false
}

// next_drawable gets the next drawable from the Metal layer.
pub fn (self &MetalAPI) next_drawable() voidptr {
	return macos.metal_next_drawable(self.layer)
}

// create_command_buffer creates a new command buffer from the queue.
pub fn (self &MetalAPI) create_command_buffer() voidptr {
	return macos.metal_create_command_buffer(self.queue)
}

pub fn (self &MetalAPI) buffer_options() MetalBufferOptions {
	return MetalBufferOptions{
		device: self.device
		cpu_cache_mode: .write_combined
		storage_mode: self.default_storage_mode
	}
}

pub fn (self &MetalAPI) image_texture_options(format PixelFormat, srgb bool) MetalTextureOptions {
	pixel_format := match format {
		.gray {
			if srgb { MetalPixelFormat.r8unorm_srgb } else { MetalPixelFormat.r8unorm }
		}
		.rgba {
			if srgb { MetalPixelFormat.rgba8unorm_srgb } else { MetalPixelFormat.rgba8unorm }
		}
		.bgra {
			if srgb { MetalPixelFormat.bgra8unorm_srgb } else { MetalPixelFormat.bgra8unorm }
		}
		else { MetalPixelFormat.rgba8unorm }
	}
	return MetalTextureOptions{
		device: self.device
		pixel_format: pixel_format
		storage_mode: self.default_storage_mode
		usage: MetalTextureUsage{
			shader_read: true
		}
	}
}

// custom_shader_texture_options returns the render-target/readable texture
// configuration used by Ghostty's ping-pong post-processing passes.
pub fn (self &MetalAPI) custom_shader_texture_options() MetalTextureOptions {
	return MetalTextureOptions{
		device: self.device
		pixel_format: self.target_pixel_format()
		storage_mode: self.default_storage_mode
		usage: MetalTextureUsage{
			shader_read: true
			render_target: true
		}
	}
}

pub fn (self &MetalAPI) custom_shader_sampler_options() MetalSamplerOptions {
	return MetalSamplerOptions{
		device: self.device
		min_filter: .linear
		mag_filter: .linear
		s_address_mode: .clamp_to_edge
		t_address_mode: .clamp_to_edge
	}
}

pub fn (self &MetalAPI) target_pixel_format() MetalPixelFormat {
	return if self.blending.is_linear() { .bgra8unorm_srgb } else { .bgra8unorm }
}

pub fn (self &MetalAPI) target_options(width u32, height u32) MetalTargetOptions {
	return MetalTargetOptions{
		device: self.device
		width: width
		height: height
		pixel_format: self.target_pixel_format()
		storage_mode: self.default_storage_mode
	}
}

// present_and_commit presents the drawable and commits the command buffer.
pub fn (self &MetalAPI) present_and_commit(cmd_buf voidptr, drawable voidptr) {
	macos.metal_present_and_commit(cmd_buf, drawable)
}

pub fn (self &MetalAPI) present(target &MetalTarget, sync_ bool) ! {
	if self.layer == unsafe { nil } || target.surface == unsafe { nil } {
		return error('Metal presentation layer unavailable')
	}
	if sync_ {
		macos.metal_iosurface_layer_set_surface_sync(self.layer, voidptr(target.surface))
	} else if !macos.metal_iosurface_layer_set_surface(self.layer, voidptr(target.surface)) {
		return error('Metal surface presentation failed')
	}
}

// Get the current size of the runtime surface.
pub fn (self &MetalAPI) surface_size() (u32, u32) {
	width, height := macos.metal_layer_surface_size(self.layer)
	return clamped_metal_surface_dimension(width, self.max_texture_size), clamped_metal_surface_dimension(height, self.max_texture_size)
}

fn clamped_metal_surface_dimension(value f64, maximum u32) u32 {
	if value <= 0 || maximum == 0 {
		return 0
	}
	if value >= f64(maximum) {
		return maximum
	}
	return u32(value)
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
	float
	float2
	float3
	float4
	uchar
	uchar4
	uchar4_normalized
	short2
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
