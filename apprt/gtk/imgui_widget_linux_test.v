module gtk

struct ImguiWidgetCallbackCounts {
mut:
	setup  int
	render int
}

fn count_imgui_setup(data voidptr) {
	mut counts := unsafe { &ImguiWidgetCallbackCounts(data) }
	counts.setup++
}

fn count_imgui_render(data voidptr) {
	mut counts := unsafe { &ImguiWidgetCallbackCounts(data) }
	counts.render++
}

fn test_imgui_widget_virtual_method_wrappers_dispatch_callbacks() {
	mut counts := &ImguiWidgetCallbackCounts{}
	widget := &ImguiWidget{
		setup_fn:  count_imgui_setup
		render_fn: count_imgui_render
		user_data: voidptr(counts)
	}

	widget.setup()
	widget.render()
	widget.render()

	assert counts.setup == 1
	assert counts.render == 2
}
