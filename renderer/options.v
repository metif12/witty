module renderer

import font

// The options that are used to configure a renderer.
//
// This is passed to Renderer.init() to set up the initial state.
pub struct RendererOptions {
pub:
	// The derived configuration for this renderer implementation.
	config DerivedConfig

	// The font grid that should be used.
	font_grid &font.SharedGrid = unsafe { nil }

	// The size of everything.
	size Size

	// The surface mailbox for sending messages back to the surface.
	// In V/gg, this is handled by the framework.
	surface_mailbox voidptr = unsafe { nil }

	// The apprt surface.
	// In V/gg, this is handled by the framework.
	rt_surface voidptr = unsafe { nil }

	// The renderer thread.
	thread &RendererThread = unsafe { nil }
}
