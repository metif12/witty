module terminal

import tmux

fn tmux_viewer_command(actions []TmuxViewerAction) ?string {
	for action in actions {
		match action {
			TmuxViewerActionCommand {
				return action.command
			}
			else {}
		}
	}
	return none
}

fn tmux_viewer_has_exit(actions []TmuxViewerAction) bool {
	for action in actions {
		if action is TmuxViewerActionExit {
			return true
		}
	}
	return false
}

fn tmux_viewer_windows_action(actions []TmuxViewerAction) ?[]TmuxViewerWindow {
	for action in actions {
		match action {
			TmuxViewerActionWindows {
				return action.windows
			}
			else {}
		}
	}
	return none
}

fn test_tmux_viewer_immediate_exit_is_terminal() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	assert tmux_viewer_has_exit(viewer.next(tmux.Notification(tmux.NotifExit{})))
	assert viewer.state == .defunct
	assert viewer.next(tmux.Notification(tmux.NotifExit{})).len == 0
}

fn test_tmux_viewer_initial_flow_and_live_output() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }

	assert viewer.next(tmux.Notification(tmux.NotifBlockEnd{})).len == 0
	mut actions := viewer.next(tmux.Notification(tmux.NotifSessionChanged{
		id: 42
		name: 'main'
	}))
	assert tmux_viewer_command(actions)?.starts_with('display-message')
	assert viewer.session_id == 42

	actions = viewer.next(tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	assert tmux_viewer_command(actions)?.starts_with('list-windows')
	assert viewer.tmux_version == '3.5a'

	actions = viewer.next(tmux.Notification(tmux.NotifBlockEnd{
		data: '\$0 @0 83 44 027b,83x44,0,0[83x20,0,0,0,83x23,0,21,1]'
	}))
	assert viewer.windows.len == 1
	assert viewer.panes.len == 2
	assert 0 in viewer.panes
	assert 1 in viewer.panes
	assert tmux_viewer_windows_action(actions)?.len == 1
	command := tmux_viewer_command(actions) or { panic('missing capture command') }
	assert command.starts_with('capture-pane')
	assert command.contains('-t %0')
	assert !command.contains('-a')

	// Primary history and visible area, alternate history and visible area.
	actions = viewer.next(tmux.Notification(tmux.NotifBlockEnd{ data: 'Hello, world!' }))
	assert tmux_viewer_command(actions)?.contains('-t %0')
	pane_zero := viewer.panes[0] or { panic('missing pane zero') }
	assert pane_zero.terminal.screens.primary.dump_string_alloc(.history)! == 'Hello, world!'
	actions = viewer.next(tmux.Notification(tmux.NotifBlockEnd{}))
	assert tmux_viewer_command(actions)?.contains('-a')
	actions = viewer.next(tmux.Notification(tmux.NotifBlockEnd{}))
	assert tmux_viewer_command(actions)?.contains('-a')
	actions = viewer.next(tmux.Notification(tmux.NotifBlockEnd{}))
	assert tmux_viewer_command(actions)?.contains('-t %1')

	// Finish pane 1's four captures and the final pane-state command.
	for _ in 0 .. 5 {
		viewer.next(tmux.Notification(tmux.NotifBlockEnd{}))
	}
	assert viewer.command_queue.len == 0
	assert viewer.next(tmux.Notification(tmux.NotifOutput{
		pane_id: 0
		data: 'new output'
	})).len == 0
	assert pane_zero.terminal.screens.active.dump_string_alloc(.active)!.contains('new output')
}

fn test_tmux_viewer_layout_change_syncs_panes_and_queue() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	viewer.next(tmux.Notification(tmux.NotifBlockEnd{}))
	viewer.next(tmux.Notification(tmux.NotifSessionChanged{ id: 1, name: 'test' }))
	viewer.next(tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	viewer.next(tmux.Notification(tmux.NotifBlockEnd{
		data: '\$0 @0 83 44 b7dd,83x44,0,0,0'
	}))
	for _ in 0 .. 5 {
		viewer.next(tmux.Notification(tmux.NotifBlockEnd{}))
	}
	assert viewer.command_queue.len == 0

	actions := viewer.next(tmux.Notification(tmux.NotifLayoutChange{
		window_id: 0
		layout: 'e07b,83x44,0,0[83x22,0,0,0,83x21,0,23,2]'
		visible_layout: 'e07b,83x44,0,0[83x22,0,0,0,83x21,0,23,2]'
		raw_flags: '*'
	}))
	assert viewer.panes.len == 2
	assert 0 in viewer.panes
	assert 2 in viewer.panes
	assert viewer.command_queue.len == 5
	assert tmux_viewer_windows_action(actions)?.len == 1
	assert tmux_viewer_command(actions)?.contains('-t %2')
}

fn test_tmux_viewer_session_change_resets_layout_and_preserves_version() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	viewer.next(tmux.Notification(tmux.NotifBlockEnd{}))
	viewer.next(tmux.Notification(tmux.NotifSessionChanged{ id: 1, name: 'first' }))
	viewer.next(tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	viewer.next(tmux.Notification(tmux.NotifBlockEnd{
		data: '\$1 @0 83 44 b7dd,83x44,0,0,0'
	}))

	actions := viewer.next(tmux.Notification(tmux.NotifSessionChanged{ id: 2, name: 'second' }))
	assert viewer.session_id == 2
	assert viewer.tmux_version == '3.5a'
	assert viewer.windows.len == 0
	assert viewer.panes.len == 0
	assert tmux_viewer_windows_action(actions)?.len == 0
	assert tmux_viewer_command(actions)?.starts_with('list-windows')
}

fn test_tmux_viewer_command_formatting() {
	assert TmuxViewerCommand(TmuxViewerPaneHistory{
		id: 7
		screen_key: .alternate
	}).format_command() == 'capture-pane -p -e -q -a -S - -E -1 -t %7\n'
	assert TmuxViewerCommand(TmuxViewerPaneVisible{
		id: 7
		screen_key: .primary
	}).format_command() == 'capture-pane -p -e -q -t %7\n'
	assert TmuxViewerCommand(TmuxViewerUserCommand{
		command: 'select-pane -t %2\n'
	}).format_command() == 'select-pane -t %2\n'
}
