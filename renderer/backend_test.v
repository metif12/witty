module renderer

fn test_backend_storage_and_default() {
	assert sizeof(Backend) == 1
	$if wasm32 {
		assert Backend.default_() == .webgl
	} $else $if macos || ios {
		assert Backend.default_() == .metal
	} $else {
		assert Backend.default_() == .opengl
	}
}

// renderer.zig instantiates GenericRenderer with the configured API rather than
// the OS default. Assignment checks all four associated aliases together.
fn test_selected_graphics_api_aliases() {
	$if renderer_opengl ?|| ( !renderer_metal ?&& !macos && !ios ) {
		mut api := unsafe { &GraphicsAPI(nil) }
		api = unsafe { &OpenGLAPI(nil) }
		mut shaders := unsafe { &GraphicsShaders(nil) }
		shaders = unsafe { &GLShaders(nil) }
		mut frame := unsafe { &GraphicsFrameState(nil) }
		frame = unsafe { &GLFrameState(nil) }
		mut texture := unsafe { &GraphicsTexture(nil) }
		texture = unsafe { &GLTexture(nil) }
		assert sizeof(GraphicsAPI) == sizeof(OpenGLAPI)
		assert sizeof(GraphicsShaders) == sizeof(GLShaders)
		assert sizeof(GraphicsFrameState) == sizeof(GLFrameState)
		assert sizeof(GraphicsTexture) == sizeof(GLTexture)
	} $else {
		mut api := unsafe { &GraphicsAPI(nil) }
		api = unsafe { &MetalAPI(nil) }
		mut shaders := unsafe { &GraphicsShaders(nil) }
		shaders = unsafe { &MetalShaders(nil) }
		mut frame := unsafe { &GraphicsFrameState(nil) }
		frame = unsafe { &MetalFrameState(nil) }
		mut texture := unsafe { &GraphicsTexture(nil) }
		texture = unsafe { &MetalTexture(nil) }
		assert sizeof(GraphicsAPI) == sizeof(MetalAPI)
		assert sizeof(GraphicsShaders) == sizeof(MetalShaders)
		assert sizeof(GraphicsFrameState) == sizeof(MetalFrameState)
		assert sizeof(GraphicsTexture) == sizeof(MetalTexture)
	}
}
