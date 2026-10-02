module gtk

fn C.g_type_is_a(GType, GType) int
fn C.g_type_name(GType) &char

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

fn test_imgui_native_class_and_inspector_inheritance() {
	base := imgui_widget_get_type()
	inspector := inspector_widget_get_type()
	assert C.g_type_is_a(base, C.adw_bin_get_type()) != 0
	assert C.g_type_is_a(inspector, base) != 0
	assert unsafe { cstring_to_vstring(C.g_type_name(base)) } == 'GhosttyImguiWidget'
	assert unsafe { cstring_to_vstring(C.g_type_name(inspector)) } == 'GhosttyInspectorWidget'
}

fn test_imgui_widget_native_virtual_methods_dispatch_the_inspector_override() {
	if !C.gtk_init_check() { return }
	C.adw_init()
	mut counts := &ImguiWidgetCallbackCounts{}
	mut widget := new_imgui_widget_type(inspector_widget_get_type(), count_imgui_setup,
		count_imgui_render, voidptr(counts))
	widget.ref_sink()
	widget.setup()
	widget.render()
	widget.render()
	assert counts.setup == 1
	assert counts.render == 2
	// Avoid invoking the inspector surface lifecycle with synthetic user_data.
	object := GObject(widget.widget)
	native_wrapper_set(object, imgui_widget_wrapper_key, unsafe { nil })
	widget.deinit()
	object_unref(object)
}
