module renderer

import datastruct
import font
import terminal

// SurfaceEvent is the renderer-owned projection of the two messages it sends
// to a surface. The apprt adapter converts these to its SurfaceMessage union,
// avoiding a renderer -> apprt module cycle.
pub type SurfaceEvent = RendererHealthEvent | ScrollbarEvent

pub struct RendererHealthEvent {
pub:
	health Health
}

pub struct ScrollbarEvent {
pub:
	scrollbar terminal.Scrollbar
}

pub type SurfaceEventPushFn = fn (voidptr, SurfaceEvent, datastruct.BlockingQueueTimeout) u32

pub struct SurfaceMailbox {
pub:
	user_data voidptr = unsafe { nil }
	push_fn   SurfaceEventPushFn = unsafe { nil }
}

pub fn (m SurfaceMailbox) push(event SurfaceEvent, timeout datastruct.BlockingQueueTimeout) u32 {
	return m.push_fn(m.user_data, event, timeout)
}

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
	surface_mailbox SurfaceMailbox

	// The apprt surface.
	// In V/gg, this is handled by the framework.
	rt_surface voidptr = unsafe { nil }

	// The renderer thread.
	thread &RendererThread = unsafe { nil }
}
