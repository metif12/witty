module gtk

fn test_inspector_widget_public_surface_contract() {
	mut inspector := InspectorWidget{}
	assert inspector.get_surface() == none
	inspector.set_surface(none)
	assert inspector.get_surface() == none
	inspector.queue_render()
}
