module inspector

import ascii
import cimgui
import terminal

const max_vt_events = 100

const vt_filter_action_types = [
	terminal.ParserActionType.print_action,
	.execute_action,
	.csi_dispatch_action,
	.esc_dispatch_action,
	.osc_dispatch_action,
	.dcs_hook_action,
	.dcs_put_action,
	.dcs_unhook_action,
	.apc_start_action,
	.apc_put_action,
	.apc_end_action,
]

enum VTKind as u8 {
	print
	execute
	csi
	esc
	osc
	dcs
	apc
}

struct VTEvent {
mut:
	seq              usize = 1
	kind             VTKind
	raw_description  string
	cursor           terminal.Cursor
	scrolling_region terminal.ScrollingRegion
	metadata         map[string]string
	imgui_selected   bool
}

fn (mut self VTEvent) deinit() {
	self.raw_description = ''
	self.cursor.hyperlink_state = none
	self.metadata.clear()
}

// VTStream is Ghostty's bounded raw parser-action stream. Parser actions are
// recorded before their semantic counterparts mutate the terminal, so every
// event carries the cursor and scrolling-region state it observed on entry.
struct VTStream {
mut:
	events                  []VTEvent
	parser_stream           terminal.Stream
	paused                  bool
	current_seq             usize = 1
	filter_exclude          [11]bool
	filter_text             string
	selected_event_seq      ?u32
	need_scroll_to_selected bool
	is_keyboard_selection   bool
}

fn VTStream.init() VTStream {
	mut parser_stream := terminal.Stream.init_alloc(voidptr(1))
	parser_stream.capture_raw = true
	mut result := VTStream{
		events: []VTEvent{cap: 2}
		parser_stream: parser_stream
	}
	result.filter_exclude[int(terminal.ParserActionType.print_action)] = true
	return result
}

fn (mut self VTStream) deinit() {
	self.clear()
	self.parser_stream.deinit()
}

fn (mut self VTStream) record_pty_byte(byte u8, term &terminal.Terminal) {
	self.parser_stream.next(byte)
	for action in self.parser_stream.raw_events {
		self.record(action, term)
	}
	self.parser_stream.clear_events()
}

fn (mut self VTStream) clear() {
	for mut event in self.events {
		event.deinit()
	}
	self.events.clear()
	self.selected_event_seq = none
	self.need_scroll_to_selected = false
	self.is_keyboard_selection = false
}

fn (mut self VTStream) reset() {
	self.clear()
	self.current_seq = 1
}

fn (mut self VTStream) record(action terminal.ParserAction, term &terminal.Terminal) {
	seq := self.current_seq
	self.current_seq++

	if self.paused || action.action_type in [.dcs_put_action, .apc_put_action] {
		return
	}
	if self.filter_exclude[int(action.action_type)] {
		return
	}

	mut cursor := term.screens.active.cursor
	if hyperlink := cursor.hyperlink_state {
		cursor.hyperlink_state = hyperlink.dupe()
	}
	mut event := VTEvent{
		seq: seq
		kind: vt_kind(action.action_type)
		raw_description: encode_vt_action(action)
		cursor: cursor
		scrolling_region: term.scrolling_region
		metadata: vt_action_metadata(action)
	}
	if !event.pass_filter(self.filter_text) {
		event.deinit()
		return
	}

	if self.events.len == max_vt_events {
		mut oldest := self.events[0]
		oldest.deinit()
		self.events.delete(0)
	}
	self.events << event
}

fn vt_kind(action_type terminal.ParserActionType) VTKind {
	return match action_type {
		.print_action { .print }
		.execute_action { .execute }
		.csi_dispatch_action { .csi }
		.esc_dispatch_action { .esc }
		.osc_dispatch_action { .osc }
		.dcs_hook_action, .dcs_put_action, .dcs_unhook_action { .dcs }
		.apc_start_action, .apc_put_action, .apc_end_action { .apc }
	}
}

fn encode_vt_action(action terminal.ParserAction) string {
	return match action.action_type {
		.print_action { "'${rune(action.char)}' (U+${action.char:X})" }
		.execute_action { '${execute_name(action.byte_val)} (0x${action.byte_val:X})' }
		.csi_dispatch_action { encode_csi_action(action.csi) }
		.esc_dispatch_action { encode_esc_action(action.esc) }
		.osc_dispatch_action { '${action.osc.cmd_type} ' }
		else { action.action_type.str() }
	}
}

fn execute_name(value u8) string {
	return match value {
		0x00 { 'NUL' }
		0x01 { 'SOH' }
		0x02 { 'STX' }
		0x03 { 'ETX' }
		0x04 { 'EOT' }
		0x05 { 'ENQ' }
		0x06 { 'ACK' }
		0x07 { 'BEL' }
		0x08 { 'BS' }
		0x09 { 'HT' }
		0x0a { 'LF' }
		0x0b { 'VT' }
		0x0c { 'FF' }
		0x0d { 'CR' }
		0x0e { 'SO' }
		0x0f { 'SI' }
		else { '?' }
	}
}

fn encode_csi_action(action terminal.CSIAction) string {
	mut result := ''
	for intermediate in action.intermediates {
		result += '${rune(intermediate)} '
	}
	for index, param in action.params {
		if index > 0 {
			result += ';'
		}
		result += param.str()
	}
	if action.intermediates.len > 0 || action.params.len > 0 {
		result += ' '
	}
	result += rune(action.final_byte).str()
	return result
}

fn encode_esc_action(action terminal.ESCAction) string {
	mut result := ''
	for intermediate in action.intermediates {
		result += '${rune(intermediate)} '
	}
	result += rune(action.final_byte).str()
	return result
}

fn vt_action_metadata(action terminal.ParserAction) map[string]string {
	mut result := map[string]string{}
	if action.action_type != .osc_dispatch_action {
		return result
	}
	cmd := action.osc
	match cmd.cmd_type {
		.change_window_title, .change_window_icon, .report_pwd, .mouse_shape, .conemu_show_message_box, .conemu_guimacro, .conemu_run_process, .conemu_output_environment_variable, .conemu_comment {
			result['data'] = cmd.str_value.clone()
		}
		.semantic_prompt {
			result['action'] = cmd.semantic_prompt_action.str()
			result['options_unvalidated'] = cmd.semantic_prompt_options.clone()
		}
		.clipboard_contents {
			result['kind'] = cmd.clipboard.kind.str()
			result['data'] = cmd.clipboard.data.clone()
		}
		.color_operation {
			result['op'] = cmd.color_op.str()
			result['requests'] = cmd.color_requests.len.str()
			result['terminator'] = cmd.terminator.str()
		}
		.kitty_color_protocol {
			result['list'] = cmd.kitty_color_items.len.str()
			result['terminator'] = cmd.terminator.str()
		}
		.show_desktop_notification {
			result['title'] = cmd.desktop_notification.title.clone()
			result['body'] = cmd.desktop_notification.body.clone()
		}
		.hyperlink_start {
			result['id'] = cmd.hyperlink.id or { '(unset)' }
			result['uri'] = cmd.hyperlink.uri.clone()
		}
		.conemu_sleep {
			result['duration_ms'] = cmd.duration_ms.str()
		}
		.conemu_change_tab_title {
			result['data'] = if cmd.tab_title.kind == .reset {
				'reset'
			} else {
				'value=${cmd.tab_title.value}'
			}
		}
		.conemu_progress_report {
			result['state'] = cmd.progress_state.str()
			result['progress'] = if progress := cmd.progress { progress.str() } else { '(unset)' }
		}
		.conemu_xterm_emulation {
			result['keyboard'] = optional_bool_string(cmd.xterm_keyboard)
			result['output'] = optional_bool_string(cmd.xterm_output)
		}
		.kitty_text_sizing {
			value := cmd.kitty_text_sizing
			result['scale'] = value.scale.str()
			result['width'] = value.width.str()
			result['numerator'] = value.numerator.str()
			result['denominator'] = value.denominator.str()
			result['valign'] = value.valign.str()
			result['halign'] = value.halign.str()
			result['text'] = value.text.clone()
		}
		.invalid, .hyperlink_end, .conemu_wait_input {}
	}
	return result
}

fn optional_bool_string(value ?bool) string {
	if unwrapped := value {
		return unwrapped.str()
	}
	return '(unset)'
}

fn (self &VTEvent) pass_filter(filter string) bool {
	if imgui_text_filter_pass(filter, self.raw_description) {
		return true
	}
	for key, value in self.metadata {
		if imgui_text_filter_pass(filter, key) || imgui_text_filter_pass(filter, value) {
			return true
		}
	}
	return false
}

// This mirrors ImGuiTextFilter.PassFilter: comma-separated positive terms are
// alternatives, negative terms exclude, matching is ASCII case-insensitive,
// and an all-negative filter has an implicit wildcard.
fn imgui_text_filter_pass(filter string, text string) bool {
	if filter.len == 0 {
		return true
	}
	text_lower := ascii.lower_string(text)
	mut positive_count := 0
	for raw_term in filter.split(',') {
		term := raw_term.trim_space()
		if term.len == 0 {
			continue
		}
		if term[0] == `-` {
			if text_lower.contains(ascii.lower_string(term[1..])) {
				return false
			}
		} else {
			positive_count++
			if text_lower.contains(ascii.lower_string(term)) {
				return true
			}
		}
	}
	return positive_count == 0
}

fn (mut self VTStream) draw(context cimgui.Context, palette [256]terminal.RGB) {
	pause_label := if self.paused { 'Resume##pause_play' } else { 'Pause##pause_play' }
	if context.button(pause_label) {
		self.paused = !self.paused
	}
	context.same_line()
	if context.button('Filter') {
		context.open_popup('Filter')
	}
	if self.events.len > 0 {
		context.same_line()
		if context.button('Clear') {
			self.reset()
		}
	}

	if self.events.len == 0 {
		context.text('Waiting for events...')
	}
	context.separator()
	self.draw_events(context, palette)
	self.draw_filter(context)
}

fn (mut self VTStream) draw_events(context cimgui.Context, palette [256]terminal.RGB) {
	if !context.begin_table('table_vt_events', 3, cimgui.table_flags_borders_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_setup_column('Seq', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Kind', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Description', cimgui.table_column_width_stretch, 0)

	if context.window_focused() {
		if action := vt_key_action(context) {
			self.navigate(action)
		}
	}

	for index := self.events.len - 1; index >= 0; index-- {
		mut event := &self.events[index]
		context.push_id(event)
		context.table_next_row()
		context.table_next_column()

		was_selected := event.imgui_selected
		if selected_seq := self.selected_event_seq {
			event.imgui_selected = u32(event.seq) == selected_seq
		}
		changed, selected := context.selectable_bool('##select', event.imgui_selected)
		event.imgui_selected = selected
		if changed && event.imgui_selected != was_selected {
			self.selected_event_seq = if event.imgui_selected { u32(event.seq) } else { none }
			self.is_keyboard_selection = false
		}

		context.same_line()
		context.text(event.seq.str())
		context.table_next_column()
		context.text(event.kind.str())
		context.table_next_column()
		context.text(event.raw_description)

		if event.imgui_selected {
			draw_vt_event_details(context, event, palette)
			if self.need_scroll_to_selected && self.is_keyboard_selection {
				context.set_scroll_here_y(0.5)
				self.need_scroll_to_selected = false
			}
		}
		context.pop_id()
	}
}

enum VTKeyAction {
	down
	up
}

fn vt_key_action(context cimgui.Context) ?VTKeyAction {
	if context.key_pressed(.key_j) || context.key_pressed(.down_arrow) {
		return .down
	}
	if context.key_pressed(.key_k) || context.key_pressed(.up_arrow) {
		return .up
	}
	return none
}

fn (mut self VTStream) navigate(action VTKeyAction) {
	if self.events.len == 0 {
		return
	}
	if selected := self.selected_event_seq {
		mut index := -1
		for i, event in self.events {
			if u32(event.seq) == selected {
				index = i
				break
			}
		}
		if index >= 0 {
			match action {
				.down {
					if index > 0 {
						self.selected_event_seq = u32(self.events[index - 1].seq)
					}
				}
				.up {
					if index + 1 < self.events.len {
						self.selected_event_seq = u32(self.events[index + 1].seq)
					}
				}
			}
		}
	} else {
		self.selected_event_seq = match action {
			.down { u32(self.events[self.events.len - 1].seq) }
			.up { u32(self.events[0].seq) }
		}
	}
	self.need_scroll_to_selected = true
	self.is_keyboard_selection = true
}

fn draw_vt_event_details(context cimgui.Context, event &VTEvent, palette [256]terminal.RGB) {
	draw_screen_cursor(context, event.cursor)
	draw_style(context, event.cursor.style, palette, true)
	if !context.begin_table('details', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_next_row()
	context.table_set_column(0)
	context.text('Scroll Region')
	context.table_set_column(1)
	region := event.scrolling_region
	context.text('T=${region.top} B=${region.bottom} L=${region.left} R=${region.right}')
	for key, value in event.metadata {
		context.table_next_row()
		context.table_next_column()
		context.text(key)
		context.table_next_column()
		context.text(value)
	}
}

fn (mut self VTStream) draw_filter(context cimgui.Context) {
	if !context.begin_popup_modal('Filter') {
		return
	}
	defer {
		context.end_popup()
	}
	context.text('Changed filter settings will only affect future events.')
	context.separator()
	if context.begin_table('table_filter_kind', 3, 0) {
		for action_type in vt_filter_action_types {
			if action_type in [.dcs_put_action, .apc_put_action] {
				continue
			}
			context.table_next_column()
			enabled := !self.filter_exclude[int(action_type)]
			changed, updated := context.checkbox(action_type.str(), enabled)
			if changed {
				self.filter_exclude[int(action_type)] = !updated
			}
		}
		context.end_table()
	}
	context.separator()
	context.text('Filter by string. Empty displays all, "abc" finds lines\ncontaining "abc", "abc,xyz" finds lines containing "abc"\nor "xyz", "-abc" excludes lines containing "abc".')
	_, self.filter_text = context.input_text('##filter_text', self.filter_text)
	context.separator()
	if context.button('Close') {
		context.close_current_popup()
	}
}
