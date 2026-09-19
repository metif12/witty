module renderer

import font
import highlight
import configpkg

// The messages that can be sent to a renderer thread.
// This is the full message definition matching the Zig union type.
pub type RendererMessage = CrashMessage
	| FocusMessage
	| VisibleMessage
	| ResetCursorBlinkMessage
	| FontGridMessage
	| ResizeMessage
	| ChangeConfigMessage
	| SearchViewportMatchesMessage
	| SearchSelectedMatchMessage
	| InspectorMessage
	| MacosDisplayIdMessage

// Purposely crash the renderer. This is used for testing and debugging.
// See the "crash" binding action.
pub struct CrashMessage {}

// A change in state in the window focus that this renderer is
// rendering within. This is only sent when a change is detected so
// the renderer is expected to handle all of these.
pub struct FocusMessage {
pub:
	focused bool
}

// A change in the view occlusion state. This can be used to determine
// if the window is visible or not. A window can be not visible (occluded)
// and still have focus.
pub struct VisibleMessage {
pub:
	visible bool
}

// Reset the cursor blink by immediately showing the cursor then
// restarting the timer.
pub struct ResetCursorBlinkMessage {}

// Change the font grid. This can happen for any number of reasons
// including a font size change, family change, etc.
pub struct FontGridMessage {
pub:
	grid    &font.SharedGrid = unsafe { nil }
	set     &font.SharedGridSet = unsafe { nil }
	new_key font.GridSetKey
	old_key font.GridSetKey
}

// Changes the size. The screen size might change, padding, grid, etc.
pub struct ResizeMessage {
pub:
	size Size
}

// The derived configuration to update the renderer with.
pub struct ChangeConfigMessage {
pub mut:
	thread_config   &ThreadDerivedConfig = unsafe { nil }
	renderer_config &DerivedConfig = unsafe { nil }
}

// Matches for the current viewport from the search thread. These happen
// async so they may be off for a frame or two from the actually rendered
// viewport. The renderer must handle this gracefully.
pub struct SearchViewportMatchesMessage {
pub:
	matches []highlight.Flattened
}

// The selected match from the search thread. May be none to indicate
// no match currently.
pub struct SearchSelectedMatchMessage {
pub:
	match_ ?highlight.Flattened
}

// Activate or deactivate the inspector.
pub struct InspectorMessage {
pub:
	active bool
}

// The macOS display ID has changed for the window.
pub struct MacosDisplayIdMessage {
pub:
	display_id u32
}

// Initialize a change_config message.
pub fn RendererMessage.init_change_config(config &configpkg.Config) !RendererMessage {
	mut thread_value := ThreadDerivedConfig.init(config)
	mut renderer_value := DerivedConfig.init(config)!
	return RendererMessage(ChangeConfigMessage{
		thread_config: &thread_value
		renderer_config: &renderer_value
	})
}

// Deinit the message, freeing any owned resources.
pub fn (msg &RendererMessage) deinit() {
	match msg {
		ChangeConfigMessage {
			if msg.renderer_config != unsafe { nil } {
				mut config := unsafe { msg.renderer_config }
				config.deinit()
			}
		}
		else {}
	}
}
