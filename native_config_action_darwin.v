module main

import apprt
import configpkg
import macos

@[heap]
struct NativeConfigChangeTask {
mut:
	config configpkg.Config
	target ?&TermState
}
fn native_config_change(app &apprt.App, target ?&TermState, config &configpkg.Config) bool {
	if config == unsafe { nil } { return false }
	owned := config.clone()
	if target == none {
		mut host_app := unsafe { &apprt.App(app) }
		host_app.config.deinit()
		host_app.config = owned.clone()
	}
	task := &NativeConfigChangeTask{config: owned, target: target}
	macos.dispatch_main(native_config_change_main, voidptr(task))
	return true
}
fn native_config_change_main(context voidptr) {
	mut task := unsafe { &NativeConfigChangeTask(context) }
	defer { task.config.deinit() }
	projection := native_window_config(&task.config)
	if mut current := task.target {
		if !current.closed {
			current.native_config = projection
            native_action_config(current,&task.config)
			sync_native_window(current)
		}
	} else {
		sync_config_menu(&task.config)
		macos.update_quick_terminal_config(native_quick_config(&task.config))
		macos.apply_native_save_state(int(task.config.window_save_state))
		mut runtime := standalone_runtime()
		for mut current in runtime.states {
			if current.closed { continue }
			current.native_config = projection
            native_action_config(current,&task.config)
			sync_native_window(current)
		}
	}
}
@[heap]
struct NativeCellSizeTask {
	state &TermState
	width u32
	height u32
}
fn native_cell_size_main(context voidptr) {
	task := unsafe { &NativeCellSizeTask(context) }
	mut current := task.state
	if current.closed { return }
	scale := macos.view_backing_scale(current.view)
	current.cell_width = f64(task.width) / scale
	current.cell_height = f64(task.height) / scale
    current.actions.set_scroll_cell_height(current.cell_height)
	if current.controller != unsafe { nil } && current.controller.focused == current {
		macos.set_native_cell_size(current.view, current.cell_width, current.cell_height, current.native_config.step_resize)
		mut host := current.controller.host
		host.increment_width = if current.native_config.step_resize && current.cell_width > 0 { current.cell_width } else { 1 }
		host.increment_height = if current.native_config.step_resize && current.cell_height > 0 { current.cell_height } else { 1 }
		host.layout()
	}
}
