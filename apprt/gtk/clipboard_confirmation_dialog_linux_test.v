module gtk

import apprt

fn test_clipboard_request_box_round_trips_every_arm() {
	requests := [
		apprt.ClipboardRequest(apprt.ClipboardRequestPaste{}),
		apprt.ClipboardRequest(apprt.ClipboardRequestOsc52Read{
			clipboard: .selection
		}),
		apprt.ClipboardRequest(apprt.ClipboardRequestOsc52Write{
			clipboard: .primary
		}),
	]
	for request in requests {
		boxed := clipboard_request_box(request)
		actual := boxed.value()
		assert actual.tag() == request.tag()
		match request {
			apprt.ClipboardRequestPaste {
				assert actual is apprt.ClipboardRequestPaste
			}
			apprt.ClipboardRequestOsc52Read {
				assert actual is apprt.ClipboardRequestOsc52Read
				if actual is apprt.ClipboardRequestOsc52Read {
					assert actual.clipboard == request.clipboard
				}
			}
			apprt.ClipboardRequestOsc52Write {
				assert actual is apprt.ClipboardRequestOsc52Write
				if actual is apprt.ClipboardRequestOsc52Write {
					assert actual.clipboard == request.clipboard
				}
			}
		}

		copy_ptr := clipboard_request_boxed_copy(voidptr(&boxed))
		assert !isnil(copy_ptr)
		copy := unsafe { &ClipboardRequestBox(copy_ptr) }
		assert copy.tag == boxed.tag
		assert copy.clipboard == boxed.clipboard
		clipboard_request_boxed_free(copy_ptr)
	}
}

fn test_clipboard_confirmation_legacy_template_omits_switch_row() {
	assert clipboard_confirmation_dialog_ui.contains(clipboard_confirmation_dialog_switch_row_ui)
	legacy := clipboard_confirmation_dialog_ui.replace(clipboard_confirmation_dialog_switch_row_ui,
		'')
	assert !legacy.contains('AdwSwitchRow')
	assert legacy.contains('id="text_view"')
}
