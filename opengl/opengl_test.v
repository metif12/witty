module opengl

fn test_compile_surface() {
	// Compile-time smoke checks for translated pkg/opengl surface.
	_ = Primitive.triangle
	_ = BufferTarget.array
	_ = BufferUsage.dynamic_draw
	_ = TextureTarget.t2d
	_ = TextureParameter.min_filter
	_ = TextureInternalFormat.rgba
	_ = TextureFormat.rgba
	_ = TextureDataType.unsigned_byte
	_ = FramebufferTarget.framebuffer
	_ = FramebufferAttachment.color0
	_ = FramebufferStatus.complete
	_ = shader_type_vertex
	_ = shader_type_fragment
	_ = gl_float
	_ = gl_double
	_ = gl_half_float
	_ = gl_unsigned_int
	_ = BufferTarget.storage
}
