module main

import apprt
import macos

enum ControllerUndoKind { tree restore close focus new_close new_redo }
struct ControllerUndoState {
	tree macos.NativeSplitTree
	frame macos.NativeWindowFrame
	focused voidptr
	tab_group &macos.NativeWeakObject
	tab_index int = -1
	title_override ?string
	tab_color int
}
@[heap]
struct ControllerUndo {
mut:
	kind ControllerUndoKind
	controller &TerminalController = unsafe { nil }
	tree macos.NativeSplitTree
	focus voidptr
	opposite_focus voidptr
	states []ControllerUndoState
	key_index int = -1
	group bool
	register_redo bool = true
	close_window bool
	mode apprt.CloseTabMode = .this
	name string
	source ?&TermState
	new_tab bool
	base_options apprt.SurfaceOptions
}
fn undo_expiration() f64 { return f64(standalone_runtime().app.config.undo_timeout.duration) / 1e9 }
fn register_controller_undo(record &ControllerUndo, target voidptr) {
	mut runtime := standalone_runtime()
	runtime.undos << record
	if !macos.register_expiring_undo(target, undo_expiration(), voidptr(record), record.name, perform_controller_undo, release_controller_undo) { release_controller_undo(voidptr(record)) }
}
fn release_controller_undo(context voidptr) {
	mut runtime := standalone_runtime()
	record := unsafe { &ControllerUndo(context) }
	for i, item in runtime.undos { if item == record { runtime.undos.delete(i); break } }
	for snapshot in record.states { mut group:=snapshot.tab_group; group.deinit() }
	collect_detached_surfaces()
}
fn collect_detached_surfaces() {
	mut runtime := standalone_runtime()
	for mut state in runtime.states {
		if state.closed { continue }
		mut retained := false
		for controller in runtime.controllers { if !controller.closed && controller.host.tree.root.find(state.view) != none { retained = true; break } }
		if !retained {
			if pending := runtime.pending_quick { if pending.tree.root.find(state.view) != none { retained = true } }
			for record in runtime.undos {
				if record.tree.root.find(state.view) != none { retained = true; break }
				for snapshot in record.states { if snapshot.tree.root.find(state.view) != none { retained = true; break } }
				if retained { break }
			}
		}
		if retained { continue }
		state.closed = true
		state.closing = false
		if state.actions != unsafe { nil } { state.actions.deinit() }
		macos.view_set_userdata(state.view, unsafe { nil })
		if state.surface != unsafe { nil } { apprt.ghostty_surface_free(mut state.surface); state.surface = unsafe { nil } }
		macos.release_native_object(state.view)
	}
}
fn replace_controller_tree(controller &TerminalController, tree macos.NativeSplitTree, new_focus voidptr, old_focus voidptr, name string) {
	if tree.root == unsafe { nil } && !controller.quick { close_controller_immediately(controller, false); return }
	old_tree := controller.host.tree
	mut c := unsafe { &TerminalController(controller) }
	c.host.replace_tree(tree)
	macos.invalidate_native_restorable_state(c.host.container)
	if new_focus != unsafe { nil } { macos.dispatch_main(focus_controller_view, new_focus) }
	register_controller_undo(&ControllerUndo{kind: .tree, controller: c, tree: old_tree, focus: old_focus, opposite_focus: new_focus, name: name}, voidptr(c))
}
fn focus_controller_view(view voidptr) { macos.focus_split_view(view) }
// Close-other/right undo queues the controller, then resolves its window on
// the next main-queue turn. Runtime.controllers retains the controller; a
// closed controller has already released its native host and window.
fn refocus_controller_window(context voidptr) {
	controller := unsafe { &TerminalController(context) }
	if controller.closed { return }
	macos.focus_native_window(macos.view_window(controller.host.container))
}
fn controller_undo_state(controller &TerminalController) ?ControllerUndoState {
	views := controller.host.tree.root.leaves()
	if views.len == 0 { return none }
	view := views[0]
	window := macos.view_window(view)
	mut index := -1
	for i, tab in macos.native_tab_windows(view) { if tab == window { index = i; break } }
	mut focused := voidptr(unsafe { nil })
	if controller.focused != unsafe { nil } { focused = controller.focused.view }
	return ControllerUndoState{tree: controller.host.tree, frame: macos.native_window_frame(view), focused: focused, tab_group: macos.new_native_weak_object(macos.native_tab_group(view)), tab_index: index, title_override: controller.title_override, tab_color: macos.native_tab_color(view)}
}
fn restore_controller_state(snapshot ControllerUndoState) &TerminalController {
	view := macos.create_window(800, 600, '')
	mut runtime := standalone_runtime()
	app_config := native_window_config(&runtime.app.config)
	mut controller := &TerminalController{host: macos.create_split_host(view), app_config: app_config, creation_config: app_config, initial_frame: snapshot.frame, title_override: snapshot.title_override}
	runtime.controllers << controller
	controller.host.replace_tree(snapshot.tree)
	macos.release_native_object(view)
	for leaf in snapshot.tree.root.leaves() {
		mut state := state_from_userdata(macos.view_get_userdata(leaf)) or { continue }
		state.controller = controller
		state.closing = false
		if controller.focused == unsafe { nil } || leaf == snapshot.focused { controller.focused = state }
	}
	if controller.focused != unsafe { nil } {
		state := controller.focused
		macos.set_native_window_title_font(state.view, state.native_config.window_title_font_family)
		macos.apply_native_window_config(state.view, native_surface_appearance_config(state), true, state.background_color or { state.native_config.background }, state.native_config.opacity, false)
		macos.apply_native_window_frame(state.view, snapshot.frame)
		macos.configure_native_restoration(state.view, true)
		macos.restore_native_tab(state.view, snapshot.tab_group.object(), snapshot.tab_index)
		macos.set_native_tab_color(state.view, snapshot.tab_color)
		if title := snapshot.title_override { macos.set_view_title(state.view, title) }
		macos.dispatch_main(focus_controller_view, state.view)
	}
	return controller
}
fn controller_for_window(window voidptr) ?&TerminalController {
	for controller in standalone_runtime().controllers { if !controller.closed && macos.view_window(controller.host.container) == window { return controller } }
	return none
}
fn close_one_controller(controller &TerminalController) {
	mut c := unsafe { &TerminalController(controller) }
	if c.closed { return }
	window := macos.view_window(c.host.container)
	c.closed = true
	macos.remove_native_undo(voidptr(c))
	c.host.replace_tree(macos.NativeSplitTree{})
	macos.close_native_window(window)
	macos.release_native_object(c.host.container)
	macos.release_native_object(window)
	collect_detached_surfaces()
}
fn close_controller_immediately(controller &TerminalController, close_window bool) {
	if controller.closed || controller.quick { return }
	mut controllers := [controller]
	if close_window {
		controllers = []&TerminalController{}
		for window in macos.native_tab_windows(controller.host.container) { if c := controller_for_window(window) { controllers << c } }
	}
	mut states := []ControllerUndoState{}
	mut key_index := -1
	for c in controllers {
		if mut snapshot := controller_undo_state(c) {
			if macos.native_window_is_key(macos.view_window(c.host.container)) { key_index = states.len }
			if close_window && controllers.len > 1 { snapshot = ControllerUndoState{...snapshot, tab_group: macos.new_native_weak_object(unsafe { nil })} }
			states << snapshot
		}
	}
	register_controller_undo(&ControllerUndo{kind: .restore, states: states, key_index: key_index, group: close_window && controllers.len > 1, close_window: close_window, name: if close_window { 'Close Window' } else { 'Close Tab' }}, voidptr(standalone_runtime().app))
	for c in controllers { close_one_controller(c) }
}
fn perform_controller_undo(context voidptr) {
	record := unsafe { &ControllerUndo(context) }
	match record.kind {
		.tree {
			if record.controller.closed { return }
			mut c := record.controller
			current := c.host.tree
			c.host.replace_tree(record.tree)
			macos.invalidate_native_restorable_state(c.host.container)
			if record.focus != unsafe { nil } { macos.dispatch_main(focus_controller_view, record.focus) }
			register_controller_undo(&ControllerUndo{kind: .tree, controller: c, tree: current, focus: record.opposite_focus, opposite_focus: record.focus, name: record.name}, voidptr(c))
		}
		.restore {
			mut restored := []&TerminalController{}
			for state in record.states { restored << restore_controller_state(state) }
			if restored.len == 0 { return }
			if record.group { for c in restored[1..] { macos.add_native_tab(restored[0].host.container, c.host.container) } }
			index := if record.key_index >= 0 && record.key_index < restored.len { record.key_index } else { restored.len-1 }
			macos.focus_native_window(macos.view_window(restored[index].host.container))
			if record.register_redo { register_controller_undo(&ControllerUndo{kind: .close, controller: restored[0], close_window: record.close_window, name: record.name}, voidptr(restored[0])) }
		}
		.close { if record.mode != .this { close_selected_tabs_immediately(record.controller, record.mode) } else { close_controller_immediately(record.controller, record.close_window) } }
		.focus {
			if record.controller.closed { return }
			macos.dispatch_main(refocus_controller_window, voidptr(record.controller))
			register_controller_undo(&ControllerUndo{kind: .close, controller: record.controller, mode: record.mode, name: record.name}, voidptr(record.controller))
		}
		.new_close {
			if record.controller.closed { return }
			if record.new_tab { macos.dispatch_main(undo_new_controller_close,voidptr(record)) }
			else { undo_new_controller_close(voidptr(record)) }
			register_controller_undo(&ControllerUndo{kind: .new_redo, source: record.source, new_tab: record.new_tab, name: record.name,base_options:record.base_options}, voidptr(standalone_runtime().app))
		}
		.new_redo { new_controller_with_options(record.source,record.base_options,record.new_tab) }
	}
}
fn undo_new_controller_close(context voidptr) {
	record:=unsafe { &ControllerUndo(context) }
	if record.controller.closed || record.controller.focused == unsafe { nil } { return }
	macos.native_undo_disable()
	do_close_controller(record.controller.focused,!record.new_tab,.this)
	macos.native_undo_enable()
}
fn register_new_controller_undo(state &TermState, source ?&TermState, tab bool,options apprt.SurfaceOptions) { register_controller_undo(&ControllerUndo{kind: .new_close, controller: state.controller, source: source, new_tab: tab, name: if tab { 'New Tab' } else { 'New Window' },base_options:options}, voidptr(state.controller)) }
fn do_reset_window_size(current &TermState) bool {
	if current.controller == unsafe { nil } || current.controller.closed || current.controller.quick { return false }
	config := native_controller_config(current)
	macos.reset_native_window_size(current.view, config.maximize, current.controller.initial_frame, current.initial_width, current.initial_height)
	return true
}
fn apply_initial_native_content_size(context voidptr) {
	controller:=unsafe { &TerminalController(context) }
	if controller.closed || controller.quick || controller.focused == unsafe { nil } { return }
	state:=controller.focused
	if state.closed || state.initial_width<=0 || state.initial_height<=0 { return }
	macos.reset_native_window_size(state.view,false,controller.initial_frame,state.initial_width,state.initial_height)
	config := native_controller_config(state)
	macos.adjust_native_window_origin_after_default_size(state.view,config.position_x,config.position_y)
}
