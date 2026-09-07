module terminal

import strconv
import tmux

// TmuxViewer is a tmux control-mode client that maintains a local terminal for
// every remote pane. This translates terminal/tmux/viewer.zig; V's GC replaces
// the source arenas and the command queue is represented by a normal slice.
pub struct TmuxViewer {
pub mut:
	state         TmuxViewerState = .startup_block
	session_id    usize
	tmux_version  string
	command_queue []TmuxViewerCommand
	windows       []TmuxViewerWindow
	// V maps do not support usize keys, so use an unsigned storage key.
	panes map[u64]&TmuxViewerPane
}

pub enum TmuxViewerState {
	startup_block
	startup_session
	defunct
	command_queue
}

pub type TmuxViewerAction = TmuxViewerActionExit | TmuxViewerActionCommand | TmuxViewerActionWindows

pub struct TmuxViewerActionExit {}

pub struct TmuxViewerActionCommand {
pub:
	command string
}

pub struct TmuxViewerActionWindows {
pub:
	windows []TmuxViewerWindow
}

pub struct TmuxViewerWindow {
pub:
	id     usize
	width  usize
	height usize
	layout tmux.Layout
}

@[heap]
pub struct TmuxViewerPane {
pub mut:
	terminal Terminal
}

pub type TmuxViewerCommand = TmuxViewerListWindows
	| TmuxViewerPaneHistory
	| TmuxViewerPaneVisible
	| TmuxViewerPaneState
	| TmuxViewerVersion
	| TmuxViewerUserCommand

pub struct TmuxViewerListWindows {}

pub struct TmuxViewerPaneHistory {
pub:
	id         usize
	screen_key ScreenKey
}

pub struct TmuxViewerPaneVisible {
pub:
	id         usize
	screen_key ScreenKey
}

pub struct TmuxViewerPaneState {}

pub struct TmuxViewerVersion {}

pub struct TmuxViewerUserCommand {
pub:
	command string
}

const tmux_viewer_list_panes_vars = [
	tmux.Variable.pane_id,
	tmux.Variable.cursor_x,
	tmux.Variable.cursor_y,
	tmux.Variable.cursor_flag,
	tmux.Variable.cursor_shape,
	tmux.Variable.cursor_colour,
	tmux.Variable.cursor_blinking,
	tmux.Variable.alternate_on,
	tmux.Variable.alternate_saved_x,
	tmux.Variable.alternate_saved_y,
	tmux.Variable.insert_flag,
	tmux.Variable.wrap_flag,
	tmux.Variable.keypad_flag,
	tmux.Variable.keypad_cursor_flag,
	tmux.Variable.origin_flag,
	tmux.Variable.mouse_all_flag,
	tmux.Variable.mouse_any_flag,
	tmux.Variable.mouse_button_flag,
	tmux.Variable.mouse_standard_flag,
	tmux.Variable.mouse_utf8_flag,
	tmux.Variable.mouse_sgr_flag,
	tmux.Variable.focus_flag,
	tmux.Variable.bracketed_paste,
	tmux.Variable.scroll_region_upper,
	tmux.Variable.scroll_region_lower,
	tmux.Variable.pane_tabs,
]

const tmux_viewer_list_windows_vars = [
	tmux.Variable.session_id,
	tmux.Variable.window_id,
	tmux.Variable.window_width,
	tmux.Variable.window_height,
	tmux.Variable.window_layout,
]

const tmux_viewer_version_vars = [tmux.Variable.version]

pub fn TmuxViewer.init() !TmuxViewer {
	return TmuxViewer{
		command_queue: []TmuxViewerCommand{cap: 8}
		windows: []TmuxViewerWindow{}
		panes: map[u64]&TmuxViewerPane{}
	}
}

pub fn (mut self TmuxViewer) deinit() {
	for _, mut pane in self.panes {
		pane.terminal.deinit()
	}
	self.panes.clear()
	self.windows.clear()
	self.command_queue.clear()
	self.tmux_version = ''
}

// next processes one control-mode notification and returns every action the
// caller must perform before delivering the next notification.
pub fn (mut self TmuxViewer) next(notification tmux.Notification) []TmuxViewerAction {
	return match self.state {
		.defunct { []TmuxViewerAction{} }
		.startup_block { self.next_startup_block(notification) }
		.startup_session { self.next_startup_session(notification) }
		.command_queue { self.next_command(notification) }
	}
}

fn (mut self TmuxViewer) next_startup_block(notification tmux.Notification) []TmuxViewerAction {
	match notification {
		tmux.NotifEnter {
			return self.defunct()
		}
		tmux.NotifExit {
			return self.defunct()
		}
		tmux.NotifBlockEnd, tmux.NotifBlockErr {
			self.state = .startup_session
		}
		else {}
	}
	return []TmuxViewerAction{}
}

fn (mut self TmuxViewer) next_startup_session(notification tmux.Notification) []TmuxViewerAction {
	match notification {
		tmux.NotifEnter {
			return self.defunct()
		}
		tmux.NotifExit {
			return self.defunct()
		}
		tmux.NotifSessionChanged {
			self.session_id = notification.id
			return self.enter_command_queue([
				TmuxViewerCommand(TmuxViewerVersion{}),
				TmuxViewerCommand(TmuxViewerListWindows{}),
			]) or { return self.defunct() }
		}
		else {}
	}
	return []TmuxViewerAction{}
}

fn (mut self TmuxViewer) next_command(notification tmux.Notification) []TmuxViewerAction {
	mut actions := []TmuxViewerAction{}
	mut command_consumed := self.command_queue.len == 0

	match notification {
		tmux.NotifEnter {
			return self.defunct()
		}
		tmux.NotifExit {
			return self.defunct()
		}
		tmux.NotifBlockEnd {
			self.received_command_output(mut actions, notification.data, false) or {
				return self.defunct()
			}
			command_consumed = true
		}
		tmux.NotifBlockErr {
			self.received_command_output(mut actions, notification.data, true) or {
				return self.defunct()
			}
			command_consumed = true
		}
		tmux.NotifOutput {
			self.received_output(notification.pane_id, notification.data) or {}
		}
		tmux.NotifSessionChanged {
			self.session_changed(mut actions, notification.id) or { return self.defunct() }
			command_consumed = true
		}
		tmux.NotifLayoutChange {
			self.layout_changed(mut actions, notification.window_id, notification.layout) or {
				return self.defunct()
			}
		}
		tmux.NotifWindowAdd {
			self.window_add(notification.id)
		}
		tmux.NotifWindowPaneChanged, tmux.NotifSessionsChanged, tmux.NotifWindowRenamed, tmux.NotifClientDetached, tmux.NotifClientSessionChanged {
		}
	}

	if self.state == .command_queue && command_consumed && self.command_queue.len > 0 {
		actions << TmuxViewerAction(TmuxViewerActionCommand{
			command: self.command_queue[0].format_command()
		})
	}
	return actions
}

fn (mut self TmuxViewer) layout_changed(mut actions []TmuxViewerAction, window_id usize, layout_str string) ! {
	mut found := -1
	for i, window in self.windows {
		if window.id == window_id {
			found = i
			break
		}
	}
	if found < 0 {
		return
	}
	layout := tmux.Layout.parse_with_checksum(layout_str)!
	self.windows[found] = TmuxViewerWindow{
		...self.windows[found]
		layout: layout
	}
	actions << TmuxViewerAction(TmuxViewerActionWindows{
		windows: self.windows.clone()
	})
	self.sync_layouts(self.windows, false)!
}

fn (mut self TmuxViewer) window_add(window_id usize) {
	_ = window_id
	self.queue_commands([TmuxViewerCommand(TmuxViewerListWindows{})])
}

fn (mut self TmuxViewer) sync_layouts(windows []TmuxViewerWindow, replace_windows bool) ! {
	mut pane_layouts := map[u64]tmux.Layout{}
	mut pane_order := []usize{}
	for window in windows {
		collect_tmux_pane_layouts(window.layout, mut pane_layouts, mut pane_order)
	}

	mut replacement := map[u64]&TmuxViewerPane{}
	mut added := []usize{}
	for id in pane_order {
		layout := pane_layouts[u64(id)]
		if pane := self.panes[u64(id)] {
			replacement[u64(id)] = pane
			continue
		}
		if layout.width == 0 || layout.height == 0 || layout.width > 65535 || layout.height > 65535 {
			return error('invalid tmux pane size')
		}
		mut terminal_ := Terminal.init(Options{
			cols: u16(layout.width)
			rows: u16(layout.height)
		})!
		replacement[u64(id)] = &TmuxViewerPane{
			terminal: terminal_
		}
		added << id
	}

	for id, mut pane in self.panes {
		if id !in replacement {
			pane.terminal.deinit()
		}
	}
	self.panes = replacement.move()
	if replace_windows {
		self.windows = windows.clone()
	}

	for id in added {
		self.queue_commands([
			TmuxViewerCommand(TmuxViewerPaneHistory{ id: id, screen_key: .primary }),
			TmuxViewerCommand(TmuxViewerPaneVisible{ id: id, screen_key: .primary }),
			TmuxViewerCommand(TmuxViewerPaneHistory{ id: id, screen_key: .alternate }),
			TmuxViewerCommand(TmuxViewerPaneVisible{ id: id, screen_key: .alternate }),
		])
	}
	if added.len > 0 {
		self.queue_commands([TmuxViewerCommand(TmuxViewerPaneState{})])
	}
}

fn collect_tmux_pane_layouts(layout tmux.Layout, mut panes map[u64]tmux.Layout, mut order []usize) {
	match layout.content {
		tmux.ContentPane {
			id := layout.content.pane_id
			if u64(id) !in panes {
				order << id
			}
			panes[u64(id)] = layout
		}
		tmux.ContentHorizontal {
			for child in layout.content.children {
				collect_tmux_pane_layouts(child, mut panes, mut order)
			}
		}
		tmux.ContentVertical {
			for child in layout.content.children {
				collect_tmux_pane_layouts(child, mut panes, mut order)
			}
		}
	}
}

fn (mut self TmuxViewer) session_changed(mut actions []TmuxViewerAction, session_id usize) ! {
	version := self.tmux_version
	self.deinit()
	self.state = .command_queue
	self.session_id = session_id
	self.tmux_version = version
	self.command_queue = [TmuxViewerCommand(TmuxViewerListWindows{})]
	actions << TmuxViewerAction(TmuxViewerActionWindows{
		windows: []TmuxViewerWindow{}
	})
}

fn (mut self TmuxViewer) received_command_output(mut actions []TmuxViewerAction, content string, is_err bool) ! {
	if self.command_queue.len == 0 {
		_ = is_err
		return
	}
	command := self.command_queue[0]
	self.command_queue.delete(0)
	match command {
		TmuxViewerUserCommand {}
		TmuxViewerPaneState {
			self.received_pane_state(content)!
		}
		TmuxViewerListWindows {
			self.received_list_windows(mut actions, content)!
		}
		TmuxViewerPaneHistory {
			self.received_pane_history(command.screen_key, command.id, content)!
		}
		TmuxViewerPaneVisible {
			self.received_pane_visible(command.screen_key, command.id, content)!
		}
		TmuxViewerVersion {
			self.received_tmux_version(content)!
		}
	}
}

fn (mut self TmuxViewer) received_tmux_version(content string) ! {
	line := content.trim(' \t\r\n')
	if line.len == 0 {
		return
	}
	data := tmux.parse_format_struct(tmux_viewer_version_vars, line, ` `)!
	self.tmux_version = data.get_string(.version) or { return error('missing tmux version') }
}

fn (mut self TmuxViewer) received_list_windows(mut actions []TmuxViewerAction, content string) ! {
	mut windows := []TmuxViewerWindow{}
	for raw_line in content.split('\n') {
		line := raw_line.trim(' \t\r')
		if line.len == 0 {
			continue
		}
		data := tmux.parse_format_struct(tmux_viewer_list_windows_vars, line, ` `)!
		layout_str := data.get_string(.window_layout) or { return error('missing window layout') }
		windows << TmuxViewerWindow{
			id: data.get_int(.window_id) or { return error('missing window id') }
			width: data.get_int(.window_width) or { return error('missing window width') }
			height: data.get_int(.window_height) or { return error('missing window height') }
			layout: tmux.Layout.parse_with_checksum(layout_str)!
		}
	}
	actions << TmuxViewerAction(TmuxViewerActionWindows{
		windows: windows.clone()
	})
	self.sync_layouts(windows, true)!
}

fn (mut self TmuxViewer) received_pane_state(content string) ! {
	for raw_line in content.split('\n') {
		line := raw_line.trim(' \t\r')
		if line.len == 0 {
			continue
		}
		data := tmux.parse_format_struct(tmux_viewer_list_panes_vars, line, `;`)!
		id := data.get_int(.pane_id) or { return error('missing pane id') }
		mut pane := self.panes[u64(id)] or { continue }
		mut terminal_ := &pane.terminal
		alternate_on := data.get_bool(.alternate_on) or { return error('missing alternate_on') }
		screen_key := if alternate_on { ScreenKey.alternate } else { ScreenKey.primary }

		if mut screen := terminal_.screens.get(screen_key) {
			x := data.get_int(.cursor_x) or { return error('missing cursor_x') }
			y := data.get_int(.cursor_y) or { return error('missing cursor_y') }
			if x < usize(terminal_.cols) && y < usize(terminal_.rows) {
				screen.cursor_absolute(u32(x), u32(y))
			}
			shape := data.get_string(.cursor_shape) or { return error('missing cursor_shape') }
			match shape {
				'block' {
					screen.cursor.cursor_style = .block
				}
				'underline' {
					screen.cursor.cursor_style = .underline
				}
				'bar' {
					screen.cursor.cursor_style = .bar
				}
				else {}
			}
		}

		if mut alternate := terminal_.screens.get(.alternate) {
			x := data.get_int(.alternate_saved_x) or { return error('missing alternate_saved_x') }
			y := data.get_int(.alternate_saved_y) or { return error('missing alternate_saved_y') }
			if x < usize(terminal_.cols) && y < usize(terminal_.rows) {
				alternate.cursor_absolute(u32(x), u32(y))
			}
		}

		terminal_.modes.set(.cursor_visible, data.get_bool(.cursor_flag) or {
			return error('missing cursor_flag')
		})
		terminal_.modes.set(.cursor_blinking, data.get_bool(.cursor_blinking) or {
			return error('missing cursor_blinking')
		})
		terminal_.modes.set(.insert, data.get_bool(.insert_flag) or {
			return error('missing insert_flag')
		})
		terminal_.modes.set(.wraparound, data.get_bool(.wrap_flag) or {
			return error('missing wrap_flag')
		})
		terminal_.modes.set(.keypad_keys, data.get_bool(.keypad_flag) or {
			return error('missing keypad_flag')
		})
		terminal_.modes.set(.cursor_keys, data.get_bool(.keypad_cursor_flag) or {
			return error('missing keypad_cursor_flag')
		})
		terminal_.modes.set(.origin, data.get_bool(.origin_flag) or {
			return error('missing origin_flag')
		})
		terminal_.modes.set(.mouse_event_any, data.get_bool(.mouse_all_flag) or {
			return error('missing mouse_all_flag')
		})
		terminal_.modes.set(.mouse_event_button, data.get_bool(.mouse_any_flag) or {
			return error('missing mouse_any_flag')
		})
		terminal_.modes.set(.mouse_event_normal, data.get_bool(.mouse_button_flag) or {
			return error('missing mouse_button_flag')
		})
		terminal_.modes.set(.mouse_event_x10, data.get_bool(.mouse_standard_flag) or {
			return error('missing mouse_standard_flag')
		})
		terminal_.modes.set(.mouse_format_utf8, data.get_bool(.mouse_utf8_flag) or {
			return error('missing mouse_utf8_flag')
		})
		terminal_.modes.set(.mouse_format_sgr, data.get_bool(.mouse_sgr_flag) or {
			return error('missing mouse_sgr_flag')
		})
		terminal_.modes.set(.focus_event, data.get_bool(.focus_flag) or {
			return error('missing focus_flag')
		})
		terminal_.modes.set(.bracketed_paste, data.get_bool(.bracketed_paste) or {
			return error('missing bracketed_paste')
		})

		top := data.get_int(.scroll_region_upper) or { return error('missing scroll region') }
		bottom := data.get_int(.scroll_region_lower) or { return error('missing scroll region') }
		if top <= usize(65535) && bottom <= usize(65535) {
			terminal_.scrolling_region.top = u16(top)
			terminal_.scrolling_region.bottom = u16(bottom)
		}

		terminal_.tabstops.reset(0)
		tabs := data.get_string(.pane_tabs) or { return error('missing pane tabs') }
		for tab in tabs.split(',') {
			if tab.len == 0 || !tab.bytes().all(it >= `0` && it <= `9`) {
				continue
			}
			col := strconv.parse_uint(tab, 10, int(sizeof(usize) * 8)) or { continue }
			if col < u64(terminal_.cols) {
				terminal_.tabstops.set(u32(col))
			}
		}
	}
}

fn (mut self TmuxViewer) received_pane_history(screen_key ScreenKey, id usize, content string) ! {
	mut pane := self.panes[u64(id)] or { return }
	mut terminal_ := &pane.terminal
	terminal_.switch_screen(screen_key)!
	mut stream := terminal_.vt_stream()
	defer { stream.deinit() }
	stream.next_slice(content)!
	terminal_.carriage_return()
	for _ in 0 .. int(terminal_.rows) {
		terminal_.index()!
	}
	terminal_.set_cursor_pos(1, 1)
}

fn (mut self TmuxViewer) received_pane_visible(screen_key ScreenKey, id usize, content string) ! {
	mut pane := self.panes[u64(id)] or { return }
	mut terminal_ := &pane.terminal
	terminal_.switch_screen(screen_key)!
	terminal_.erase_display(.complete, false)
	terminal_.set_cursor_pos(1, 1)
	mut stream := terminal_.vt_stream()
	defer { stream.deinit() }
	stream.next_slice(content)!
}

fn (mut self TmuxViewer) received_output(id usize, data string) ! {
	mut pane := self.panes[u64(id)] or { return }
	mut stream := pane.terminal.vt_stream()
	defer { stream.deinit() }
	stream.next_slice(data)!
}

fn (mut self TmuxViewer) enter_command_queue(commands []TmuxViewerCommand) ![]TmuxViewerAction {
	if self.state == .command_queue || commands.len == 0 {
		return error('invalid command queue transition')
	}
	self.queue_commands(commands)
	self.state = .command_queue
	return [TmuxViewerAction(TmuxViewerActionCommand{
		command: commands[0].format_command()
	})]
}

fn (mut self TmuxViewer) queue_commands(commands []TmuxViewerCommand) {
	self.command_queue << commands
}

fn (mut self TmuxViewer) defunct() []TmuxViewerAction {
	self.state = .defunct
	return [TmuxViewerAction(TmuxViewerActionExit{})]
}

pub fn (command TmuxViewerCommand) format_command() string {
	return match command {
		TmuxViewerListWindows {
			"list-windows -F '${tmux.format_variables(tmux_viewer_list_windows_vars, ` `)}'\n"
		}
		TmuxViewerPaneHistory {
			alternate := if command.screen_key == .alternate { '-a ' } else { '' }
			'capture-pane -p -e -q ${alternate}-S - -E -1 -t %${command.id}\n'
		}
		TmuxViewerPaneVisible {
			alternate := if command.screen_key == .alternate { '-a ' } else { '' }
			'capture-pane -p -e -q ${alternate}-t %${command.id}\n'
		}
		TmuxViewerPaneState {
			"list-panes -F '${tmux.format_variables(tmux_viewer_list_panes_vars, `;`)}'\n"
		}
		TmuxViewerVersion {
			"display-message -p '${tmux.format_variables(tmux_viewer_version_vars, ` `)}'\n"
		}
		TmuxViewerUserCommand {
			command.command
		}
	}
}
