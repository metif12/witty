module terminal

import tmux

fn test_tmux_viewer_state_uses_compact_source_storage() {
	assert sizeof(TmuxViewerState) == 1
}

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

fn tmux_viewer_next(mut viewer TmuxViewer, notification tmux.Notification) []TmuxViewerAction {
	return viewer.next(TmuxViewerInput{
		tmux: notification
	})
}

fn test_tmux_viewer_immediate_exit_is_terminal() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	assert tmux_viewer_has_exit(tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifExit{})))
	assert viewer.state == .defunct
	assert tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifExit{})).len == 0
}

fn test_tmux_viewer_initial_flow_and_live_output() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }

	assert tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{})).len == 0
	mut actions := tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifSessionChanged{
		id: 42
		name: 'main'
	}))
	assert tmux_viewer_command(actions)?.starts_with('display-message')
	assert viewer.session_id == 42

	actions = tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	assert tmux_viewer_command(actions)?.starts_with('list-windows')
	assert viewer.tmux_version == '3.5a'

	actions = tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{
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
	actions = tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: 'Hello, world!' }))
	assert tmux_viewer_command(actions)?.contains('-t %0')
	pane_zero := viewer.panes[0] or { panic('missing pane zero') }
	primary_zero := pane_zero.terminal.screens.get(.primary) or {
		panic('primary screen must be initialized')
	}
	assert primary_zero.dump_string_alloc(.history)! == 'Hello, world!'
	actions = tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	assert tmux_viewer_command(actions)?.contains('-a')
	actions = tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	assert tmux_viewer_command(actions)?.contains('-a')
	actions = tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	assert tmux_viewer_command(actions)?.contains('-t %1')

	// Finish pane 1's four captures and the final pane-state command.
	for _ in 0 .. 5 {
		tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	}
	assert viewer.command_queue.len == 0
	assert tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifOutput{
		pane_id: 0
		data: 'new output'
	})).len == 0
	assert pane_zero.terminal.screens.active.dump_string_alloc(.active)!.contains('new output')
}

fn test_tmux_viewer_layout_change_syncs_panes_and_queue() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifSessionChanged{ id: 1, name: 'test' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{
		data: '\$0 @0 83 44 b7dd,83x44,0,0,0'
	}))
	for _ in 0 .. 5 {
		tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	}
	assert viewer.command_queue.len == 0

	actions := tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifLayoutChange{
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

fn test_tmux_viewer_layout_change_does_not_send_when_queue_is_busy() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifSessionChanged{ id: 1, name: 'test' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{
		data: '\$0 @0 83 44 b7dd,83x44,0,0,0'
	}))
	assert viewer.command_queue.len > 0

	actions := tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifLayoutChange{
		window_id: 0
		layout: 'e07b,83x44,0,0[83x22,0,0,0,83x21,0,23,2]'
		visible_layout: 'e07b,83x44,0,0[83x22,0,0,0,83x21,0,23,2]'
		raw_flags: '*'
	}))
	assert viewer.panes.len == 2
	assert tmux_viewer_windows_action(actions)?.len == 1
	assert tmux_viewer_command(actions) == none
}

fn test_tmux_viewer_layout_change_sends_when_queue_was_empty() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifSessionChanged{ id: 1, name: 'test' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{
		data: '\$0 @0 83 44 b7dd,83x44,0,0,0'
	}))
	for _ in 0 .. 5 {
		tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	}
	assert viewer.command_queue.len == 0

	actions := tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifLayoutChange{
		window_id: 0
		layout: 'e07b,83x44,0,0[83x22,0,0,0,83x21,0,23,2]'
		visible_layout: 'e07b,83x44,0,0[83x22,0,0,0,83x21,0,23,2]'
		raw_flags: '*'
	}))
	assert viewer.command_queue.len == 5
	assert tmux_viewer_command(actions)?.contains('-t %2')
}

fn test_tmux_viewer_window_add_queues_refresh_with_correct_in_flight_behavior() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifSessionChanged{ id: 1, name: 'test' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{
		data: '\$0 @0 83 44 b7dd,83x44,0,0,0'
	}))

	// A refresh is queued behind the capture commands already in flight and
	// must not be sent early.
	queued_before := viewer.command_queue.len
	mut actions := tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifWindowAdd{ id: 1 }))
	assert viewer.command_queue.len == queued_before + 1
	assert tmux_viewer_command(actions) == none

	// Drain the capture commands and the queued refresh, then verify an idle
	// viewer immediately sends a newly queued refresh.
	for viewer.command_queue.len > 0 {
		tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	}
	assert viewer.command_queue.len == 0
	actions = tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifWindowAdd{ id: 2 }))
	assert viewer.command_queue.len == 1
	assert tmux_viewer_command(actions)?.starts_with('list-windows')
}

fn test_tmux_viewer_session_change_resets_layout_and_preserves_version() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifSessionChanged{ id: 1, name: 'first' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{
		data: '\$1 @0 83 44 b7dd,83x44,0,0,0'
	}))

	actions := tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifSessionChanged{ id: 2, name: 'second' }))
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

fn test_tmux_viewer_two_pane_state_restoration() {
	mut viewer := TmuxViewer.init()!
	defer { viewer.deinit() }
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifSessionChanged{ id: 0, name: '0' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: '3.5a' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{
		data: '\$0 @0 165 79 ca97,165x79,0,0[165x40,0,0,0,165x38,0,41,4]'
	}))
	assert viewer.windows.len == 1
	assert viewer.windows[0].width == 165
	assert viewer.windows[0].height == 79
	assert viewer.panes.len == 2

	// Four captures per pane: primary history/visible, then alternate
	// history/visible. The last response restores terminal state.
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: 'prompt %\nprompt %' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: 'prompt %' }))
	mut pane := viewer.panes[0] or { panic('missing pane zero') }
	mut pane_primary := pane.terminal.screens.get(.primary) or {
		panic('primary screen must be initialized')
	}
	assert pane_primary.dump_string_alloc(.history)!.count('prompt %') == 2
	assert pane_primary.dump_string_alloc(.active)! == 'prompt %'
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: 'prompt %' }))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{ data: 'prompt %' }))
	pane = viewer.panes[4] or { panic('missing pane four') }
	pane_primary = pane.terminal.screens.get(.primary) or {
		panic('primary screen must be initialized')
	}
	assert pane_primary.dump_string_alloc(.history)! == 'prompt %'
	assert pane_primary.dump_string_alloc(.active)!.starts_with('prompt %')
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{}))
	tmux_viewer_next(mut viewer, tmux.Notification(tmux.NotifBlockEnd{
		data: '%0;42;0;1;;;;0;4294967295;4294967295;0;1;0;0;0;0;0;0;0;0;0;;;41;123;-0,+8,1__6,24,32,40,48,56,64,72,80,88,96,104,112,120,128,136,144,152,160\n%4;10;5;1;;;;0;4294967295;4294967295;0;1;0;0;0;0;0;0;0;0;0;;;0;37;8,16,24,32,40,48,56,64,72,80,88,96,104,112,120,128,136,144,152,160'
	}))

	state_pane_zero := viewer.panes[0] or { panic('missing pane zero') }
	state_primary_zero := state_pane_zero.terminal.screens.get(.primary) or {
		panic('primary screen must be initialized')
	}
	assert state_primary_zero.cursor.x == 42
	assert state_primary_zero.cursor.y == 0
	assert state_pane_zero.terminal.modes.get(.cursor_visible)
	assert state_pane_zero.terminal.modes.get(.wraparound)
	assert !state_pane_zero.terminal.modes.get(.insert)
	assert !state_pane_zero.terminal.modes.get(.origin)
	assert !state_pane_zero.terminal.modes.get(.keypad_keys)
	assert !state_pane_zero.terminal.modes.get(.cursor_keys)
	// Ghostty preserves representable tmux values even when they exceed the
	// current terminal height.
	assert state_pane_zero.terminal.scrolling_region.top == 41
	assert state_pane_zero.terminal.scrolling_region.bottom == 123
	assert state_pane_zero.terminal.tabstops.get(0)
	assert state_pane_zero.terminal.tabstops.get(8)
	assert state_pane_zero.terminal.tabstops.get(16)
	assert state_pane_zero.terminal.tabstops.get(24)

	state_pane_four := viewer.panes[4] or { panic('missing pane four') }
	state_primary_four := state_pane_four.terminal.screens.get(.primary) or {
		panic('primary screen must be initialized')
	}
	assert state_primary_four.cursor.x == 10
	assert state_primary_four.cursor.y == 5
	assert state_pane_four.terminal.modes.get(.cursor_visible)
	assert state_pane_four.terminal.modes.get(.wraparound)
	assert !state_pane_four.terminal.modes.get(.insert)
	assert !state_pane_four.terminal.modes.get(.origin)
	assert !state_pane_four.terminal.modes.get(.keypad_keys)
	assert !state_pane_four.terminal.modes.get(.cursor_keys)
}
