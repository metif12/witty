module gtk

// GTK terminal inspector translated from:
// - ghostty/src/apprt/gtk/class/inspector_widget.zig
// - ghostty/src/apprt/gtk/class/inspector_window.zig
//
// The source uses GObject subclasses and blueprint templates. Witty's GTK
// runtime expands those templates programmatically, while preserving the same
// ownership and activation lifecycle.

@[heap]
pub struct InspectorWidget {
mut:
	imgui   &ImguiWidget = unsafe { nil }
	surface &SurfaceWidget = unsafe { nil }
	owner   &InspectorWindow = unsafe { nil }
}

@[heap]
pub struct InspectorWindow {
mut:
	obj       AdwApplicationWindow = unsafe { nil }
	inspector &InspectorWidget = unsafe { nil }
}

fn new_inspector_widget(surface &SurfaceWidget) !&InspectorWidget {
	mut self := &InspectorWidget{}
	self.imgui = new_imgui_widget(inspector_widget_setup_cb, inspector_widget_render_cb, voidptr(self))
	C.gtk_widget_add_css_class(self.imgui.as_widget(), c'inspector')
	self.set_surface(surface)!
	return self
}

fn (mut self InspectorWidget) set_surface(surface &SurfaceWidget) ! {
	if self.surface == surface {
		return
	}
	if !isnil(self.surface) {
		mut old := unsafe { self.surface }
		self.surface = unsafe { nil }
		if !isnil(old.widget) {
			C.g_object_weak_unref(GObject(old.widget), voidptr(inspector_surface_weak_notify), voidptr(self))
		}
		if old.has_core() {
			mut core_surface := old.core_surface
			core_surface.deactivate_inspector()
		}
		if !isnil(self.owner) && old.inspector == self.owner {
			old.inspector = unsafe { nil }
		}
	}

	if isnil(surface) || !surface.has_core() {
		return
	}
	mut core_surface := surface.core_surface
	core_surface.activate_inspector()!
	C.g_object_weak_ref(GObject(surface.widget), voidptr(inspector_surface_weak_notify), voidptr(self))
	self.surface = surface
	self.imgui.queue_render()
}

fn (mut self InspectorWidget) clear_surface_from_weak(surface_obj GObject) {
	if isnil(self.surface) || GObject(self.surface.widget) != surface_obj {
		return
	}
	mut old := unsafe { self.surface }
	self.surface = unsafe { nil }
	if old.has_core() {
		mut core_surface := old.core_surface
		core_surface.deactivate_inspector()
	}
	old.inspector = unsafe { nil }
	if !isnil(self.owner) {
		self.owner.destroy_window()
	}
}

fn (self &InspectorWidget) queue_render() {
	if !isnil(self.imgui) {
		self.imgui.queue_render()
	}
}

fn (mut self InspectorWidget) deinit() {
	self.set_surface(unsafe { nil }) or {}
	if !isnil(self.imgui) {
		mut imgui := unsafe { self.imgui }
		imgui.deinit()
		self.imgui = unsafe { nil }
	}
	self.owner = unsafe { nil }
}

fn inspector_widget_setup_cb(data voidptr) {
	_ = data
	// cimgui.Context.create performs Inspector.setup exactly once for the
	// current context: docking and sRGB flags, disabled ini/log files, and the
	// embedded regular font at 32 px.
}

fn inspector_widget_render_cb(data voidptr) {
	if isnil(data) {
		return
	}
	self := unsafe { &InspectorWidget(data) }
	if isnil(self.surface) || !self.surface.has_core() || isnil(self.imgui) {
		return
	}
	mut core_surface := self.surface.core_surface
	core_surface.render_inspector(self.imgui.context.handle)
}

fn inspector_surface_weak_notify(data voidptr, object GObject) {
	if !isnil(data) {
		mut self := unsafe { &InspectorWidget(data) }
		self.clear_surface_from_weak(object)
	}
}

pub fn new_inspector_window(mut surface SurfaceWidget) !&InspectorWindow {
	obj := AdwApplicationWindow(C.g_object_new(C.adw_application_window_get_type(), c'application', surface.app.obj, &char(unsafe { nil })))
	if isnil(obj) {
		return error('unable to create GTK inspector window')
	}
	mut self := &InspectorWindow{
		obj: obj
	}
	mut inspector := new_inspector_widget(surface) or {
		C.gtk_window_destroy(GtkWindow(obj))
		return err
	}
	self.inspector = inspector
	inspector.owner = self
	surface.inspector = self

	C.gtk_window_set_title(GtkWindow(obj), c'Ghostty: Terminal Inspector')
	C.gtk_window_set_icon_name(GtkWindow(obj), &char(application_id.str))
	C.gtk_window_set_default_size(GtkWindow(obj), 1000, 600)
	C.gtk_widget_add_css_class(GtkWidget(obj), c'inspector')

	toolbar := C.adw_toolbar_view_new()
	header := C.adw_header_bar_new()
	title := C.adw_window_title_new(c'Ghostty: Terminal Inspector', c'')
	C.adw_header_bar_set_title_widget(header, title)
	C.adw_toolbar_view_add_top_bar(toolbar, header)

	content := C.gtk_box_new(1, 0)
	C.gtk_widget_set_hexpand(content, 1)
	C.gtk_widget_set_vexpand(content, 1)
	debug_warning := GtkWidget(C.g_object_new(debug_warning_get_type(), &char(unsafe { nil })))
	C.gtk_widget_set_visible(debug_warning, $if !prod { 1 } $else { 0 })
	C.gtk_box_append(content, debug_warning)
	C.gtk_box_append(content, inspector.imgui.as_widget())
	C.adw_toolbar_view_set_content(toolbar, content)
	C.adw_application_window_set_content(obj, GtkWidget(toolbar))
	C.g_object_weak_ref(GObject(obj), voidptr(inspector_window_weak_notify), voidptr(self))
	return self
}

pub fn (self &InspectorWindow) present() {
	if !isnil(self.obj) {
		C.gtk_window_present(GtkWindow(self.obj))
	}
}

pub fn (self &InspectorWindow) queue_render() {
	if !isnil(self.inspector) {
		self.inspector.queue_render()
	}
}

pub fn (mut self InspectorWindow) close() {
	if !isnil(self.inspector) {
		self.inspector.set_surface(unsafe { nil }) or {}
	}
	self.destroy_window()
}

fn (self &InspectorWindow) destroy_window() {
	if !isnil(self.obj) {
		C.gtk_window_destroy(GtkWindow(self.obj))
	}
}

fn inspector_window_weak_notify(data voidptr, object GObject) {
	_ = object
	if isnil(data) {
		return
	}
	mut self := unsafe { &InspectorWindow(data) }
	self.obj = unsafe { nil }
	if !isnil(self.inspector) {
		mut inspector := unsafe { self.inspector }
		inspector.deinit()
		self.inspector = unsafe { nil }
	}
}
