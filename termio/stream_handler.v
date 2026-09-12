module termio

import apprt
import build_meta
import configpkg
import datastruct
import internal_os
import kitty
import osc
import renderer
import terminal
import tmux

// This is used as the handler for the terminal.Stream type. This is
// stateful and is expected to live for the entire lifetime of the terminal.
// It is NOT VALID to stop a stream handler, create a new one, and use that
// unless all of the member fields are copied.
pub struct StreamHandler {
pub mut:
	size     &renderer.Size = unsafe { nil }
	terminal &terminal.Terminal = unsafe { nil }

	// Mailbox for data to the termio thread.
	termio_mailbox &Mailbox = unsafe { nil }

	// Mailbox for the surface.
	surface_mailbox apprt.SurfaceMailbox

	// The shared render state
	renderer_state &renderer.State = unsafe { nil }

	// The mailbox for notifying the renderer of things.
	renderer_mailbox &renderer.Mailbox = unsafe { nil }

	// A handle to wake up the renderer. This hints to the renderer that
	// a repaint should happen.
	renderer_wakeup renderer.Wakeup

	// The default cursor state. This is used with CSI q. This is
	// set to true when we're currently in the default cursor state.
	default_cursor       bool = true
	default_cursor_style terminal.CursorStyle = .block
	default_cursor_blink ?bool

	// The response to use for ENQ requests.
	enquiry_response string

	// The color reporting format for OSC requests.
	osc_color_report_format configpkg.OSCColorReportFormat = .format_16_bit

	// The clipboard write access configuration.
	clipboard_write configpkg.ClipboardAccess = .allow

	// ---------------------------------------------------------------
	// Internal state

	// The APC command handler maintains the APC state. APC is like
	// CSI or OSC, but it is a private escape sequence that is used
	// to send commands to the terminal emulator. This is used by
	// the kitty graphics protocol.
	apc ApcHandler

	// The DCS handler maintains DCS state. DCS is like CSI or OSC,
	// but requires more stateful parsing. This is used by functionality
	// such as XTGETTCAP.
	dcs DcsHandler

	// Tmux control-mode viewer state, active between enter/exit notifications.
	tmux_viewer ?&terminal.TmuxViewer

	// This is set to true when a message was written to the termio
	// mailbox. This can be used by callers to determine if they need
	// to wake up the termio thread.
	termio_messaged bool

	// This is set to true when we've seen a title escape sequence. We use
	// this to determine if we need to default the window title.
	seen_title bool
}

pub fn (mut self StreamHandler) deinit() {
	self.apc.deinit()
	self.dcs.deinit()
	if mut viewer := self.tmux_viewer {
		viewer.deinit()
		self.tmux_viewer = none
	}
}

// This queues a render operation with the renderer thread. The render
// isn't guaranteed to happen immediately but it will happen as soon as
// practical.
pub fn (mut self StreamHandler) queue_render() ! {
	self.renderer_wakeup.notify()!
}

// Change the configuration for this handler.
pub fn (mut self StreamHandler) change_config(config &DerivedConfig) {
	self.osc_color_report_format = config.osc_color_report_format
	self.clipboard_write = config.clipboard_write
	self.enquiry_response = config.enquiry_response
	self.default_cursor_style = config.cursor_style
	self.default_cursor_blink = config.cursor_blink

	// If our cursor is the default, then we update it immediately.
	if self.default_cursor {
		self.set_cursor_style(.default_) or {}
	}

	// The config could have changed any of our colors so update mode 2031
	self.message_writer(Message.color_scheme_report_msg(false))
}

fn (mut self StreamHandler) surface_message_writer(msg apprt.SurfaceMessage) {
	// See message_writer which has similar logic and explains why
	// we may have to do this.
	if self.surface_mailbox.push(msg, datastruct.blocking_queue_instant) == 0 {
		self.renderer_state.mutex.unlock()
		defer { self.renderer_state.mutex.lock() }
		self.surface_mailbox.push(msg, datastruct.blocking_queue_forever)
	}
}

fn (mut self StreamHandler) message_writer(msg Message) {
	self.termio_mailbox.send(msg, self.renderer_state.mutex)
	self.termio_messaged = true
}

// Send a renderer message and unlock the renderer state mutex
// if necessary to ensure we don't deadlock.
//
// This assumes the renderer state mutex is locked.
fn (mut self StreamHandler) renderer_message_writer(msg renderer.RendererMessage) {
	// See termio.Mailbox.send for more details on how this works.

	// Try instant first. If it works then we can return.
	if self.renderer_mailbox.push(msg) > 0 {
		return
	}

	// Instant would have blocked. Release the renderer mutex,
	// wake up the renderer to allow it to process the message,
	// and then try again.
	self.renderer_state.mutex.unlock()
	defer { self.renderer_state.mutex.lock() }
	self.renderer_wakeup.notify() or {}
	self.renderer_mailbox.push(msg)
}

// vt dispatches a single stream event from the VT parser to the
// appropriate handler.
pub fn (mut self StreamHandler) vt(event terminal.StreamEvent) {
	match event.key {
		.print {
			self.terminal.print(event.payload.cp) or {}
		}
		.print_repeat {
			self.terminal.print_repeat(event.payload.count) or {}
		}
		.bell {
			self.bell()
		}
		.backspace {
			self.terminal.backspace()
		}
		.horizontal_tab {
			self.horizontal_tab(event.payload.num)
		}
		.horizontal_tab_back {
			self.horizontal_tab_back(event.payload.num)
		}
		.linefeed {
			self.linefeed()
		}
		.carriage_return {
			self.terminal.carriage_return()
		}
		.enquiry {
			self.enquiry()
		}
		.invoke_charset {
			self.terminal.invoke_charset(event.payload.charset_bank, event.payload.charset_slot, event.payload.charset_locking)
		}
		.cursor_up {
			self.terminal.cursor_up(int(event.payload.num))
		}
		.cursor_down {
			self.terminal.cursor_down(int(event.payload.num))
		}
		.cursor_left {
			self.terminal.cursor_left(int(event.payload.num))
		}
		.cursor_right {
			self.terminal.cursor_right(int(event.payload.num))
		}
		.cursor_pos {
			self.terminal.set_cursor_pos(int(event.payload.num), int(event.payload.num2))
		}
		.cursor_col {
			self.terminal.set_cursor_pos(int(self.terminal.screens.active.cursor.y) + 1, int(event.payload.num))
		}
		.cursor_row {
			self.terminal.set_cursor_pos(int(event.payload.num), int(self.terminal.screens.active.cursor.x) + 1)
		}
		.cursor_col_relative {
			col := int(self.terminal.screens.active.cursor.x) + 1 + int(event.payload.num)
			self.terminal.set_cursor_pos(int(self.terminal.screens.active.cursor.y) + 1, col)
		}
		.cursor_row_relative {
			row := int(self.terminal.screens.active.cursor.y) + 1 + int(event.payload.num)
			self.terminal.set_cursor_pos(row, int(self.terminal.screens.active.cursor.x) + 1)
		}
		.cursor_style {
			self.set_cursor_style(event.payload.cursor_style) or {}
		}
		.erase_display_below {
			self.terminal.erase_display(.below, event.payload.flag)
		}
		.erase_display_above {
			self.terminal.erase_display(.above, event.payload.flag)
		}
		.erase_display_complete {
			self.terminal.scroll_viewport(terminal.scroll_viewport_bottom) or {}
			self.terminal.erase_display(.complete, event.payload.flag)
		}
		.erase_display_scrollback {
			self.terminal.erase_display(.scrollback, event.payload.flag)
		}
		.erase_display_scroll_complete {
			self.terminal.erase_display(.scroll_complete, event.payload.flag)
		}
		.erase_line_right {
			self.terminal.erase_line(.right, event.payload.flag)
		}
		.erase_line_left {
			self.terminal.erase_line(.left, event.payload.flag)
		}
		.erase_line_complete {
			self.terminal.erase_line(.complete, event.payload.flag)
		}
		.erase_line_right_unless_pending_wrap {
			self.terminal.erase_line(.right_unless_pending_wrap, event.payload.flag)
		}
		.delete_chars {
			self.terminal.delete_chars(event.payload.count)
		}
		.erase_chars {
			self.terminal.erase_chars(event.payload.count)
		}
		.insert_lines {
			self.terminal.insert_lines(event.payload.count)
		}
		.insert_blanks {
			self.terminal.insert_blanks(event.payload.count)
		}
		.delete_lines {
			self.terminal.delete_lines(event.payload.count)
		}
		.scroll_up {
			self.terminal.scroll_up(event.payload.count) or {}
		}
		.scroll_down {
			self.terminal.scroll_down(event.payload.count)
		}
		.tab_clear_current {
			self.terminal.tab_clear(.current)
		}
		.tab_clear_all {
			self.terminal.tab_clear(.all)
		}
		.tab_set {
			self.terminal.tab_set()
		}
		.tab_reset {
			self.terminal.tab_reset()
		}
		.index {
			self.do_index()
		}
		.next_line {
			self.next_line()
		}
		.reverse_index {
			self.terminal.reverse_index()
		}
		.full_reset {
			self.full_reset()
		}
		.set_mode {
			self.set_mode(event.payload.mode, true)
		}
		.reset_mode {
			self.set_mode(event.payload.mode, false)
		}
		.save_mode {
			self.terminal.modes.save(event.payload.mode)
		}
		.restore_mode {
			// For restore mode we have to restore but if we set it, we
			// always have to call set_mode because setting some modes have
			// side effects and we want to make sure we process those.
			v := self.terminal.modes.restore(event.payload.mode)
			self.set_mode(event.payload.mode, v)
		}
		.request_mode {
			self.request_mode(event.payload.mode)
		}
		.request_mode_unknown {
			self.request_mode_unknown(event.payload.raw_mode, event.payload.raw_ansi)
		}
		.top_and_bottom_margin {
			self.terminal.set_top_and_bottom_margin(int(event.payload.num), int(event.payload.num2))
		}
		.left_and_right_margin {
			self.terminal.set_left_and_right_margin(int(event.payload.num), int(event.payload.num2))
		}
		.left_and_right_margin_ambiguous {
			if self.terminal.modes.get(.enable_left_and_right_margin) {
				self.terminal.set_left_and_right_margin(0, 0)
			} else {
				self.terminal.save_cursor()
			}
		}
		.save_cursor {
			self.terminal.save_cursor()
		}
		.restore_cursor {
			self.terminal.restore_cursor()
		}
		.modify_key_format {
			self.set_modify_key_format(event.payload.modify_key_format)
		}
		.protected_mode_off {
			self.terminal.set_protected_mode(.off)
		}
		.protected_mode_iso {
			self.terminal.set_protected_mode(.iso)
		}
		.protected_mode_dec {
			self.terminal.set_protected_mode(.dec)
		}
		.mouse_shift_capture {
			self.terminal.flags.set_mouse_shift_capture(if event.payload.flag {
				.true_
			} else {
				.false_
			})
		}
		.size_report {
			self.send_size_report(event.payload.size_report_style)
		}
		.xtversion {
			self.report_xtversion()
		}
		.device_attributes {
			self.device_attributes(event.payload.device_attr)
		}
		.device_status {
			// The stream dispatches with num=param and flag=question.
			// Convert back to a DeviceStatusRequest and call device_status_report().
			if req := terminal.DeviceStatusRequest.from_int(event.payload.num, event.payload.flag) {
				self.device_status_report(req)
			}
		}
		.kitty_keyboard_query {
			self.query_kitty_keyboard()
		}
		.kitty_keyboard_push {
			self.terminal.screens.active.kitty_keyboard.push(terminal.KeyFlags.from_int(event.payload.kitty_flags))
		}
		.kitty_keyboard_pop {
			self.terminal.screens.active.kitty_keyboard.pop(usize(event.payload.num))
		}
		.kitty_keyboard_set {
			self.terminal.screens.active.kitty_keyboard.set(.set_, terminal.KeyFlags.from_int(event.payload.kitty_flags))
		}
		.kitty_keyboard_set_or {
			self.terminal.screens.active.kitty_keyboard.set(.or_, terminal.KeyFlags.from_int(event.payload.kitty_flags))
		}
		.kitty_keyboard_set_not {
			self.terminal.screens.active.kitty_keyboard.set(.not_, terminal.KeyFlags.from_int(event.payload.kitty_flags))
		}
		.kitty_color_report {
			// Kitty color protocol: query/set/reset colors (OSC 21).
			self.kitty_color_report(event.payload.kitty_color_items, event.payload.osc_terminator)
		}
		.color_operation {
			// OSC color operations: set/query/reset palette and dynamic colors.
			self.color_operation(event.payload.color_op, event.payload.color_requests, event.payload.osc_terminator)
		}
		.end_hyperlink {
			self.terminal.screens.active.end_hyperlink()
		}
		.active_status_display {
			self.terminal.status_display = event.payload.status_display
		}
		.decaln {
			self.terminal.decaln() or {}
		}
		.window_title {
			self.window_title(event.payload.str1)
		}
		.report_pwd {
			self.report_pwd(event.payload.str1)
		}
		.show_desktop_notification {
			self.show_desktop_notification(event.payload.desktop_notification)
		}
		.progress_report {
			self.progress_report(event.payload.progress_report)
		}
		.start_hyperlink {
			self.start_hyperlink(event.payload.hyperlink.uri, event.payload.hyperlink.id)
		}
		.clipboard_contents {
			self.clipboard_contents(event.payload.clipboard.kind, event.payload.clipboard.data)
		}
		.semantic_prompt {
			self.semantic_prompt(event.payload)
		}
		.mouse_shape {
			self.set_mouse_shape(event.payload.mouse_shape_val)
		}
		.configure_charset {
			self.terminal.configure_charset(event.payload.charset_slot, event.payload.charset_val)
		}
		.set_attribute {
			sgr := event.payload.sgr
			if sgr.kind == .unknown {
				// Unknown/invalid SGR attributes aren't common in the wild
			} else {
				self.terminal.set_attribute(sgr) or {}
			}
		}
		.dcs_hook {
			self.dcs_hook(event.payload)
		}
		.dcs_put {
			self.dcs_put(event.payload.byte_val)
		}
		.dcs_unhook {
			self.dcs_unhook()
		}
		.apc_start {
			self.apc.start()
		}
		.apc_end {
			self.apc_end()
		}
		.apc_put {
			self.apc.feed(event.payload.byte_val)
		}

		// Unimplemented
		.title_push, .title_pop {}
	}
}

// ============================================================
// DCS handlers
// ============================================================

pub fn (mut self StreamHandler) dcs_hook(payload terminal.ActionPayload) {
	mut cmd := self.dcs.hook(terminal.DcsParams{
		intermediates: payload.dcs_intermediates.bytestr()
		params: payload.dcs_params.clone()
		final_byte: payload.dcs_final
	}) or { return }
	defer { cmd.deinit() }
	self.dcs_command(mut cmd)
}

pub fn (mut self StreamHandler) dcs_put(byte_val u8) {
	mut cmd := self.dcs.put(byte_val) or { return }
	defer { cmd.deinit() }
	self.dcs_command(mut cmd)
}

pub fn (mut self StreamHandler) dcs_unhook() {
	mut cmd := self.dcs.unhook() or { return }
	defer { cmd.deinit() }
	self.dcs_command(mut cmd)
}

fn (mut self StreamHandler) dcs_command(mut cmd terminal.DcsCommand) {
	match mut cmd {
		terminal.DcsCommandXtgettcap {
			self.dcs_xtgettcap(mut cmd.xtgettcap)
		}
		terminal.DcsCommandDecrqss {
			self.dcs_decrqss(cmd.decrqss)
		}
		terminal.DcsCommandTmux {
			match cmd.notification {
				tmux.NotifEnter {
					if mut old := self.tmux_viewer {
						old.deinit()
					}
					viewer_value := terminal.TmuxViewer.init() or { return }
					mut viewer := &terminal.TmuxViewer{}
					unsafe {
						*viewer = viewer_value
					}
					self.tmux_viewer = viewer
					return
				}
				tmux.NotifExit {
					if mut viewer := self.tmux_viewer {
						viewer.deinit()
						self.tmux_viewer = none
					}
					return
				}
				else {}
			}

			mut viewer := self.tmux_viewer or { return }
			for action in viewer.next(cmd.notification) {
				match action {
					terminal.TmuxViewerActionExit {}
					terminal.TmuxViewerActionCommand {
						self.message_writer(Message.write_req(action.command))
					}
					terminal.TmuxViewerActionWindows {
						// The pinned source also leaves GUI window diffing as a TODO.
					}
				}
			}
		}
	}
}

// dcs_xtgettcap handles XTGETTCAP requests by iterating over requested
// terminfo capability names and sending responses. Each found capability is
// returned as DCS 1 + r <hex-name> [= <hex-value>] ST. Unknown capabilities
// are omitted, matching Ghostty's generated XTGETTCAP map.
fn (mut self StreamHandler) dcs_xtgettcap(mut xtgettcap terminal.DcsXtgettcap) {
	for {
		key := xtgettcap.next() or { break }
		if val := xtgettcap_lookup(key) {
			resp := if val.len == 0 {
				'\x1bP1+r${key}\x1b\\'
			} else {
				'\x1bP1+r${key}=${val}\x1b\\'
			}
			self.message_writer(Message.write_req(resp))
		}
	}
}

// dcs_decrqss handles DECRQSS (Request Status String) by querying
// terminal state and sending a DECRPSS response.
// Format: DCS <valid> $ r <response> ST
// where <valid> is 1 for valid or 0 for invalid.
fn (mut self StreamHandler) dcs_decrqss(setting terminal.DcsDecrqss) {
	resp := match setting {
		.sgr {
			// Report current SGR attributes.
			sgr_str := self.format_sgr()
			'\x1bP1\$r${sgr_str}m\x1b\\'
		}
		.decscusr {
			// Report current cursor style.
			style_val := self.format_decscusr()
			'\x1bP1\$r${style_val} q\x1b\\'
		}
		.decstbm {
			// Report top and bottom margins.
			top := int(self.terminal.scrolling_region.top) + 1
			bottom := int(self.terminal.scrolling_region.bottom) + 1
			'\x1bP1\$r${top};${bottom}r\x1b\\'
		}
		.decslrm {
			// We only send a valid response when left and right margin mode
			// (DECLRMM) is enabled.
			if self.terminal.modes.get(.enable_left_and_right_margin) {
				left := int(self.terminal.scrolling_region.left) + 1
				right := int(self.terminal.scrolling_region.right) + 1
				'\x1bP1\$r${left};${right}s\x1b\\'
			} else {
				'\x1bP0\$r\x1b\\'
			}
		}
		.none_val {
			// Unknown setting, report invalid.
			'\x1bP0\$r\x1b\\'
		}
	}
	self.message_writer(Message.write_req(resp))
}

// format_sgr builds the SGR parameter string from the current cursor style.
fn (mut self StreamHandler) format_sgr() string {
	return self.terminal.print_attributes() or { '0' }
}

// format_decscusr returns the DECSCUSR value for the current cursor state.
fn (self &StreamHandler) format_decscusr() int {
	blinking := self.terminal.modes.get(.cursor_blinking)
	return match self.terminal.screens.active.cursor.cursor_style {
		.block {
			if blinking { 1 } else { 2 }
		}
		.underline {
			if blinking { 3 } else { 4 }
		}
		.bar {
			if blinking { 5 } else { 6 }
		}
		.block_hollow {
			if blinking { 1 } else { 2 }
		}
	}
}

// xtgettcap_lookup looks up a hex-encoded terminfo capability name
// and returns the hex-encoded value, or none if not found.
// The key is the hex-encoded capability name (e.g., "536D756C78" for "Smulx").
fn xtgettcap_lookup(hex_key string) ?string {
	// Decode the hex key to get the capability name.
	name := hex_decode(hex_key) or { return none }

	val := xtgettcap_value(name) or { return none }
	return hex_encode(val)
}

// Values generated from pinned Ghostty src/terminfo/ghostty.zig. Parameterized
// strings remain in terminfo source notation; non-parameterized strings decode
// the same escape and control forms as Source.xtgettcapMap.
fn xtgettcap_value(name string) ?string {
	return match name {
		'TN' { 'xterm-ghostty' }
		'Co' { '256' }
		'RGB' { '8' }
		'am' { '' }
		'bce' { '' }
		'ccc' { '' }
		'hs' { '' }
		'km' { '' }
		'mc5i' { '' }
		'mir' { '' }
		'msgr' { '' }
		'npc' { '' }
		'xenl' { '' }
		'AX' { '' }
		'Tc' { '' }
		'Su' { '' }
		'XT' { '' }
		'fullkbd' { '' }
		'colors' { '256' }
		'cols' { '80' }
		'it' { '8' }
		'lines' { '24' }
		'pairs' { '32767' }
		'acsc' { '++\\,\\,--..00``aaffgghhiijjkkllmmnnooppqqrrssttuuvvwwxxyyzz{{||}}~~' }
		'Smulx' { '\\E[4:%p1%dm' }
		'Setulc' { '\\E[58:2::%p1%{65536}%/%d:%p1%{256}%/%{255}%&%d:%p1%{255}%&%d%;m' }
		'Ss' { '\\E[%p1%d q' }
		'Se' { '\x1b[2 q' }
		'Ms' { '\\E]52;%p1%s;%p2%s\\007' }
		'Sync' { '\\E[?2026%?%p1%{1}%-%tl%eh%;' }
		'BD' { '\x1b[?2004l' }
		'BE' { '\x1b[?2004h' }
		'PS' { '\x1b[200~' }
		'PE' { '\x1b[201~' }
		'XM' { '\\E[?1006;1000%?%p1%{1}%=%th%el%;' }
		'xm' { '\\E[<%i%p3%d;%p1%d;%p2%d;%?%p4%tM%em%;' }
		'RV' { '\x1b[>c' }
		'rv' { '\x1b\\\\[[0-9]+;[0-9]+;[0-9]+c' }
		'XR' { '\x1b[>0q' }
		'xr' { '\x1bP>\\\\|[ -~]+a\x1b\\\\' }
		'Enmg' { '\x1b[?69h' }
		'Dsmg' { '\x1b[?69l' }
		'Clmg' { '\x1b[s' }
		'Cmg' { '\\E[%i%p1%d;%p2%ds' }
		'clear' { '\x1b[H\x1b[2J' }
		'E3' { '\x1b[3J' }
		'fe' { '\x1b[?1004h' }
		'fd' { '\x1b[?1004l' }
		'kxIN' { '\x1b[I' }
		'kxOUT' { '\x1b[O' }
		'bel' { '\a' }
		'blink' { '\x1b[5m' }
		'bold' { '\x1b[1m' }
		'cbt' { '\x1b[Z' }
		'civis' { '\x1b[?25l' }
		'cnorm' { '\x1b[?12l\x1b[?25h' }
		'cr' { '\\r' }
		'csr' { '\\E[%i%p1%d;%p2%dr' }
		'cub' { '\\E[%p1%dD' }
		'cub1' { '\b' }
		'cud' { '\\E[%p1%dB' }
		'cud1' { '\n' }
		'cuf' { '\\E[%p1%dC' }
		'cuf1' { '\x1b[C' }
		'cup' { '\\E[%i%p1%d;%p2%dH' }
		'cuu' { '\\E[%p1%dA' }
		'cuu1' { '\x1b[A' }
		'cvvis' { '\x1b[?12;25h' }
		'dch' { '\\E[%p1%dP' }
		'dch1' { '\x1b[P' }
		'dim' { '\x1b[2m' }
		'dl' { '\\E[%p1%dM' }
		'dl1' { '\x1b[M' }
		'dsl' { '\x1b]2;\\007' }
		'ech' { '\\E[%p1%dX' }
		'ed' { '\x1b[J' }
		'el' { '\x1b[K' }
		'el1' { '\x1b[1K' }
		'flash' { '\x1b[?5h\$<100/>\x1b[?5l' }
		'fsl' { '\a' }
		'home' { '\x1b[H' }
		'hpa' { '\\E[%i%p1%dG' }
		'ht' { '\t' }
		'hts' { '\x1bH' }
		'ich' { '\\E[%p1%d@' }
		'ich1' { '\x1b[@' }
		'il' { '\\E[%p1%dL' }
		'il1' { '\x1b[L' }
		'ind' { '\\n' }
		'indn' { '\\E[%p1%dS' }
		'initc' {
			'\\E]4;%p1%d;rgb\\:%p2%{255}%*%{1000}%/%2.2X/%p3%{255}%*%{1000}%/%2.2X/%p4%{255}%*%{1000}%/%2.2X\\E\\\\'
		}
		'invis' { '\x1b[8m' }
		'oc' { '\x1b]104\\007' }
		'op' { '\x1b[39;49m' }
		'rc' { '\x1b8' }
		'rep' { '%p1%c\\E[%p2%{1}%-%db' }
		'rev' { '\x1b[7m' }
		'ri' { '\x1bM' }
		'rin' { '\\E[%p1%dT' }
		'ritm' { '\x1b[23m' }
		'rmacs' { '\x1b(B' }
		'rmam' { '\x1b[?7l' }
		'rmcup' { '\x1b[?1049l' }
		'rmir' { '\x1b[4l' }
		'rmkx' { '\x1b[?1l\x1b>' }
		'rmso' { '\x1b[27m' }
		'rmul' { '\x1b[24m' }
		'rmxx' { '\x1b[29m' }
		'setab' { '\\E[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m' }
		'setaf' { '\\E[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m' }
		'setrgbb' { '\\E[48:2:%p1%d:%p2%d:%p3%dm' }
		'setrgbf' { '\\E[38:2:%p1%d:%p2%d:%p3%dm' }
		'sgr' {
			'%?%p9%t\\E(0%e\\E(B%;\\E[0%?%p6%t;1%;%?%p2%t;4%;%?%p1%p3%|%t;7%;%?%p4%t;5%;%?%p7%t;8%;m'
		}
		'sgr0' { '\x1b(B\x1b[m' }
		'sitm' { '\x1b[3m' }
		'smacs' { '\x1b(0' }
		'smam' { '\x1b[?7h' }
		'smcup' { '\x1b[?1049h' }
		'smir' { '\x1b[4h' }
		'smkx' { '\x1b[?1h\x1b=' }
		'smso' { '\x1b[7m' }
		'smul' { '\x1b[4m' }
		'smxx' { '\x1b[9m' }
		'tbc' { '\x1b[3g' }
		'tsl' { '\x1b]2;' }
		'u6' { '\\E[%i%d;%dR' }
		'u7' { '\x1b[6n' }
		'u8' { '\\E[?%[;0123456789]c' }
		'u9' { '\x1b[c' }
		'vpa' { '\\E[%i%p1%dd' }
		'kDC' { '\x1b[3;2~' }
		'kDC3' { '\x1b[3;3~' }
		'kDC4' { '\x1b[3;4~' }
		'kDC5' { '\x1b[3;5~' }
		'kDC6' { '\x1b[3;6~' }
		'kDC7' { '\x1b[3;7~' }
		'kDN' { '\x1b[1;2B' }
		'kDN3' { '\x1b[1;3B' }
		'kDN4' { '\x1b[1;4B' }
		'kDN5' { '\x1b[1;5B' }
		'kDN6' { '\x1b[1;6B' }
		'kDN7' { '\x1b[1;7B' }
		'kEND' { '\x1b[1;2F' }
		'kEND3' { '\x1b[1;3F' }
		'kEND4' { '\x1b[1;4F' }
		'kEND5' { '\x1b[1;5F' }
		'kEND6' { '\x1b[1;6F' }
		'kEND7' { '\x1b[1;7F' }
		'kHOM' { '\x1b[1;2H' }
		'kHOM3' { '\x1b[1;3H' }
		'kHOM4' { '\x1b[1;4H' }
		'kHOM5' { '\x1b[1;5H' }
		'kHOM6' { '\x1b[1;6H' }
		'kHOM7' { '\x1b[1;7H' }
		'kIC' { '\x1b[2;2~' }
		'kIC3' { '\x1b[2;3~' }
		'kIC4' { '\x1b[2;4~' }
		'kIC5' { '\x1b[2;5~' }
		'kIC6' { '\x1b[2;6~' }
		'kIC7' { '\x1b[2;7~' }
		'kLFT' { '\x1b[1;2D' }
		'kLFT3' { '\x1b[1;3D' }
		'kLFT4' { '\x1b[1;4D' }
		'kLFT5' { '\x1b[1;5D' }
		'kLFT6' { '\x1b[1;6D' }
		'kLFT7' { '\x1b[1;7D' }
		'kNXT' { '\x1b[6;2~' }
		'kNXT3' { '\x1b[6;3~' }
		'kNXT4' { '\x1b[6;4~' }
		'kNXT5' { '\x1b[6;5~' }
		'kNXT6' { '\x1b[6;6~' }
		'kNXT7' { '\x1b[6;7~' }
		'kPRV' { '\x1b[5;2~' }
		'kPRV3' { '\x1b[5;3~' }
		'kPRV4' { '\x1b[5;4~' }
		'kPRV5' { '\x1b[5;5~' }
		'kPRV6' { '\x1b[5;6~' }
		'kPRV7' { '\x1b[5;7~' }
		'kRIT' { '\x1b[1;2C' }
		'kRIT3' { '\x1b[1;3C' }
		'kRIT4' { '\x1b[1;4C' }
		'kRIT5' { '\x1b[1;5C' }
		'kRIT6' { '\x1b[1;6C' }
		'kRIT7' { '\x1b[1;7C' }
		'kUP' { '\x1b[1;2A' }
		'kUP3' { '\x1b[1;3A' }
		'kUP4' { '\x1b[1;4A' }
		'kUP5' { '\x1b[1;5A' }
		'kUP6' { '\x1b[1;6A' }
		'kUP7' { '\x1b[1;7A' }
		'kbs' { '\x7f' }
		'kcbt' { '\x1b[Z' }
		'kcub1' { '\x1bOD' }
		'kcud1' { '\x1bOB' }
		'kcuf1' { '\x1bOC' }
		'kcuu1' { '\x1bOA' }
		'kdch1' { '\x1b[3~' }
		'kend' { '\x1bOF' }
		'kent' { '\x1bOM' }
		'kf1' { '\x1bOP' }
		'kf10' { '\x1b[21~' }
		'kf11' { '\x1b[23~' }
		'kf12' { '\x1b[24~' }
		'kf13' { '\x1b[1;2P' }
		'kf14' { '\x1b[1;2Q' }
		'kf15' { '\x1b[1;2R' }
		'kf16' { '\x1b[1;2S' }
		'kf17' { '\x1b[15;2~' }
		'kf18' { '\x1b[17;2~' }
		'kf19' { '\x1b[18;2~' }
		'kf2' { '\x1bOQ' }
		'kf20' { '\x1b[19;2~' }
		'kf21' { '\x1b[20;2~' }
		'kf22' { '\x1b[21;2~' }
		'kf23' { '\x1b[23;2~' }
		'kf24' { '\x1b[24;2~' }
		'kf25' { '\x1b[1;5P' }
		'kf26' { '\x1b[1;5Q' }
		'kf27' { '\x1b[1;5R' }
		'kf28' { '\x1b[1;5S' }
		'kf29' { '\x1b[15;5~' }
		'kf3' { '\x1bOR' }
		'kf30' { '\x1b[17;5~' }
		'kf31' { '\x1b[18;5~' }
		'kf32' { '\x1b[19;5~' }
		'kf33' { '\x1b[20;5~' }
		'kf34' { '\x1b[21;5~' }
		'kf35' { '\x1b[23;5~' }
		'kf36' { '\x1b[24;5~' }
		'kf37' { '\x1b[1;6P' }
		'kf38' { '\x1b[1;6Q' }
		'kf39' { '\x1b[1;6R' }
		'kf4' { '\x1bOS' }
		'kf40' { '\x1b[1;6S' }
		'kf41' { '\x1b[15;6~' }
		'kf42' { '\x1b[17;6~' }
		'kf43' { '\x1b[18;6~' }
		'kf44' { '\x1b[19;6~' }
		'kf45' { '\x1b[20;6~' }
		'kf46' { '\x1b[21;6~' }
		'kf47' { '\x1b[23;6~' }
		'kf48' { '\x1b[24;6~' }
		'kf49' { '\x1b[1;3P' }
		'kf5' { '\x1b[15~' }
		'kf50' { '\x1b[1;3Q' }
		'kf51' { '\x1b[1;3R' }
		'kf52' { '\x1b[1;3S' }
		'kf53' { '\x1b[15;3~' }
		'kf54' { '\x1b[17;3~' }
		'kf55' { '\x1b[18;3~' }
		'kf56' { '\x1b[19;3~' }
		'kf57' { '\x1b[20;3~' }
		'kf58' { '\x1b[21;3~' }
		'kf59' { '\x1b[23;3~' }
		'kf6' { '\x1b[17~' }
		'kf60' { '\x1b[24;3~' }
		'kf61' { '\x1b[1;4P' }
		'kf62' { '\x1b[1;4Q' }
		'kf63' { '\x1b[1;4R' }
		'kf7' { '\x1b[18~' }
		'kf8' { '\x1b[19~' }
		'kf9' { '\x1b[20~' }
		'khome' { '\x1bOH' }
		'kich1' { '\x1b[2~' }
		'kind' { '\x1b[1;2B' }
		'kmous' { '\x1b[<' }
		'knp' { '\x1b[6~' }
		'kpp' { '\x1b[5~' }
		'kri' { '\x1b[1;2A' }
		'rs1' { '\x1b]\x1b\\\\\x1bc' }
		'sc' { '\x1b7' }
		else {
			return none
		}
	}
}

// hex_decode decodes a hex string to a regular string.
fn hex_decode(s string) ?string {
	if s.len % 2 != 0 {
		return none
	}
	mut result := []u8{cap: s.len / 2}
	for i := 0; i < s.len; i += 2 {
		hi := hex_nibble(s[i]) or { return none }
		lo := hex_nibble(s[i + 1]) or { return none }
		result << (hi << 4) | lo
	}
	return result.bytestr()
}

// hex_encode encodes a string as uppercase hex.
fn hex_encode(s string) string {
	hex_chars := '0123456789ABCDEF'
	mut result := []u8{cap: s.len * 2}
	for b in s.bytes() {
		result << hex_chars[int(b >> 4)]
		result << hex_chars[int(b & 0x0F)]
	}
	return result.bytestr()
}

// hex_nibble converts a hex character to its 4-bit value.
fn hex_nibble(c u8) ?u8 {
	if c >= u8(`0`) && c <= u8(`9`) {
		return c - u8(`0`)
	}
	if c >= u8(`A`) && c <= u8(`F`) {
		return c - u8(`A`) + 10
	}
	if c >= u8(`a`) && c <= u8(`f`) {
		return c - u8(`a`) + 10
	}
	return none
}

// ============================================================
// APC handler
// ============================================================

pub fn (mut self StreamHandler) apc_end() {
	cmd := self.apc.end() or { return }
	if response := kitty.execute(mut self.terminal, &cmd) {
		encoded := response.encode()
		if encoded.len > 0 {
			self.message_writer(Message.write_req(encoded))
		}
	}
}

// ============================================================
// Simple terminal operation handlers
// ============================================================

fn (mut self StreamHandler) bell() {
	self.surface_message_writer(apprt.SurfaceMessage{
		kind: .ring_bell
	})
}

fn (mut self StreamHandler) horizontal_tab(count u16) {
	for _ in 0 .. int(count) {
		x := self.terminal.screens.active.cursor.x
		self.terminal.horizontal_tab()
		if x == self.terminal.screens.active.cursor.x {
			break
		}
	}
}

fn (mut self StreamHandler) horizontal_tab_back(count u16) {
	for _ in 0 .. int(count) {
		x := self.terminal.screens.active.cursor.x
		self.terminal.horizontal_tab_back()
		if x == self.terminal.screens.active.cursor.x {
			break
		}
	}
}

fn (mut self StreamHandler) linefeed() {
	// Small optimization: call index instead of linefeed because they're
	// identical and this avoids one layer of function call overhead.
	self.terminal.index() or {}
}

pub fn (mut self StreamHandler) do_index() {
	self.terminal.index() or {}
}

pub fn (mut self StreamHandler) next_line() {
	self.terminal.index() or {}
	self.terminal.carriage_return()
}

// ============================================================
// Modify key format
// ============================================================

pub fn (mut self StreamHandler) set_modify_key_format(format terminal.ModifyKeyFormat) {
	self.terminal.flags.set_modify_other_keys_2(false)
	match format {
		.other_keys_numeric {
			self.terminal.flags.set_modify_other_keys_2(true)
		}
		else {}
	}
}

// ============================================================
// Mode request/response
// ============================================================

fn (mut self StreamHandler) request_mode(mode terminal.Mode) {
	code := if self.terminal.modes.get(mode) { u8(1) } else { u8(2) }
	prefix := if terminal.mode_is_ansi(mode) { '' } else { '?' }
	resp := '\x1b[${prefix}${terminal.mode_value(mode)};${code}\$y'
	self.message_writer(Message.write_req(resp))
}

fn (mut self StreamHandler) request_mode_unknown(mode_raw u16, ansi bool) {
	prefix := if ansi { '' } else { '?' }
	resp := '\x1b[${prefix}${mode_raw};0\$y'
	self.message_writer(Message.write_req(resp))
}

// ============================================================
// Set mode (with side effects)
// ============================================================

pub fn (mut self StreamHandler) set_mode(mode terminal.Mode, enabled bool) {
	// Note: this function doesn't need to grab the render state or
	// terminal locks because it is only called from process() which
	// grabs the lock.

	// If we are setting cursor blinking, we ignore it if we have
	// a default cursor blink setting set. This is a really weird
	// behavior so this comment will go deep into trying to explain it.
	//
	// There are two ways to set cursor blinks: DECSCUSR (CSI _ q)
	// and DEC mode 12. DECSCUSR is the modern approach and has a
	// way to revert to the "default" (as defined by the terminal)
	// cursor style and blink by doing "CSI 0 q". DEC mode 12 controls
	// blinking and is either on or off and has no way to set a
	// default. DEC mode 12 is also the more antiquated approach.
	//
	// The problem is that if the user specifies a desired default
	// cursor blink with `cursor-style-blink`, the moment a running
	// program uses DEC mode 12, the cursor blink can never be reset
	// to the default without an explicit DECSCUSR. But if a program
	// is using mode 12, it is by definition not using DECSCUSR.
	// This makes for somewhat annoying interactions where a poorly
	// (or legacy) behaved program will stop blinking, and it simply
	// never restarts.
	//
	// To get around this, we have a special case where if the user
	// specifies some explicit default cursor blink desire, we ignore
	// DEC mode 12. We allow DECSCUSR to still set the cursor blink
	// because programs using DECSCUSR usually are well behaved and
	// reset the cursor blink to the default when they exit.
	//
	// To be extra safe, users can also add a manual `CSI 0 q` to
	// their shell config when they render prompts to ensure the
	// cursor is exactly as they request.
	if mode == .cursor_blinking && self.default_cursor_blink != none {
		return
	}

	// We first always set the raw mode on our mode state.
	self.terminal.modes.set(mode, enabled)

	// And then some modes require additional processing.
	match mode {
		// Just noting here that autorepeat has no effect on
		// the terminal. xterm ignores this mode and so do we.
		// We know about just so that we don't log that it is
		// an unknown mode.
		.autorepeat {}

		// Schedule a render since we changed colors
		.reverse_colors {
			self.terminal.flags.set_dirty_reverse_colors(true)
		}

		// Origin resets cursor pos. This is called whether or not
		// we're enabling or disabling origin mode and whether or
		// not the value changed.
		.origin {
			self.terminal.set_cursor_pos(1, 1)
		}
		.enable_left_and_right_margin {
			if !enabled {
				// When we disable left/right margin mode we need to
				// reset the left/right margins.
				self.terminal.scrolling_region.left = 0
				self.terminal.scrolling_region.right = self.terminal.cols - 1
			}
		}
		.alt_screen_legacy {
			self.terminal.switch_screen_mode(.mode_47, enabled) or {}
		}
		.alt_screen {
			self.terminal.switch_screen_mode(.mode_1047, enabled) or {}
		}
		.alt_screen_save_cursor_clear_enter {
			self.terminal.switch_screen_mode(.mode_1049, enabled) or {}
		}

		// Mode 1048 is xterm's conditional save cursor depending
		// on if alt screen is enabled or not (at the terminal emulator
		// level). Alt screen is always enabled for us so this just
		// does a save/restore cursor.
		.save_cursor {
			if enabled {
				self.terminal.save_cursor()
			} else {
				self.terminal.restore_cursor()
			}
		}

		// Force resize back to the window size
		.enable_mode_3 {
			grid_size := self.size.grid()
			self.terminal.resize(u16(grid_size.columns), u16(grid_size.rows)) or {}
		}
		.column_132 {
			self.terminal.deccolm(if enabled { .cols_132 } else { .cols_80 }) or {}
		}

		// We need to start a timer to prevent the emulator being hung
		// forever.
		.synchronized_output {
			if enabled {
				self.message_writer(Message{
					kind: .start_synchronized_output
				})
			}
		}
		.linefeed {
			self.message_writer(Message{
				kind: .linefeed_mode
				flag_val: enabled
			})
		}
		.in_band_size_reports {
			if enabled {
				self.message_writer(Message{
					kind: .size_report
					size_report_val: .mode_2048
				})
			}
		}
		.focus_event {
			if enabled {
				self.message_writer(Message.focused_msg(self.terminal.flags.focused()))
			}
		}
		.mouse_event_x10 {
			if enabled {
				self.terminal.flags.set_mouse_event(.x10)
				self.set_mouse_shape(.default_)
			} else {
				self.terminal.flags.set_mouse_event(.none)
				self.set_mouse_shape(.text)
			}
		}
		.mouse_event_normal {
			if enabled {
				self.terminal.flags.set_mouse_event(.normal)
				self.set_mouse_shape(.default_)
			} else {
				self.terminal.flags.set_mouse_event(.none)
				self.set_mouse_shape(.text)
			}
		}
		.mouse_event_button {
			if enabled {
				self.terminal.flags.set_mouse_event(.button)
				self.set_mouse_shape(.default_)
			} else {
				self.terminal.flags.set_mouse_event(.none)
				self.set_mouse_shape(.text)
			}
		}
		.mouse_event_any {
			if enabled {
				self.terminal.flags.set_mouse_event(.any)
				self.set_mouse_shape(.default_)
			} else {
				self.terminal.flags.set_mouse_event(.none)
				self.set_mouse_shape(.text)
			}
		}
		.mouse_format_utf8 {
			self.terminal.flags.set_mouse_format(if enabled { .utf8 } else { .x10 })
		}
		.mouse_format_sgr {
			self.terminal.flags.set_mouse_format(if enabled { .sgr } else { .x10 })
		}
		.mouse_format_urxvt {
			self.terminal.flags.set_mouse_format(if enabled { .urxvt } else { .x10 })
		}
		.mouse_format_sgr_pixels {
			self.terminal.flags.set_mouse_format(if enabled { .sgr_pixels } else { .x10 })
		}
		else {}
	}
}

// ============================================================
// Hyperlinks
// ============================================================

fn (mut self StreamHandler) start_hyperlink(uri string, id_ ?string) {
	self.terminal.screens.active.start_hyperlink(uri, id_) or {}
}

pub fn (mut self StreamHandler) end_hyperlink() {
	self.terminal.screens.active.end_hyperlink()
}

// ============================================================
// Device attributes
// ============================================================

pub fn (mut self StreamHandler) device_attributes(req terminal.DeviceAttributeReq) {
	// For the below, we quack as a VT220. We don't quack as
	// a 420 because we don't support DCS sequences.
	match req {
		.primary {
			resp := if self.clipboard_write != .deny {
				// 62 = Level 2 conformance
				// 22 = Color text
				// 52 = Clipboard access
				'\x1b[?62;22;52c'
			} else {
				'\x1b[?62;22c'
			}
			self.message_writer(Message.write_stable_msg(resp))
		}
		.secondary {
			self.message_writer(Message.write_stable_msg('\x1b[>1;10;0c'))
		}
		.tertiary {}
	}
}

// ============================================================
// Device status report
// ============================================================

pub fn (mut self StreamHandler) device_status_report(req terminal.DeviceStatusRequest) {
	match req {
		.operating_status {
			self.message_writer(Message.write_stable_msg('\x1b[0n'))
		}
		.cursor_position {
			mut pos_x := int(self.terminal.screens.active.cursor.x)
			mut pos_y := int(self.terminal.screens.active.cursor.y)
			if self.terminal.modes.get(.origin) {
				pos_x -= int(self.terminal.scrolling_region.left)
				pos_y -= int(self.terminal.scrolling_region.top)
				if pos_x < 0 {
					pos_x = 0
				}
				if pos_y < 0 {
					pos_y = 0
				}
			}

			// Response always is at least 4 chars, so this leaves the
			// remainder for the row/column as base-10 numbers. This
			// will support a very large terminal.
			resp := '\x1b[${pos_y + 1};${pos_x + 1}R'
			self.message_writer(Message.write_req(resp))
		}
		.color_scheme {
			self.message_writer(Message.color_scheme_report_msg(true))
		}
	}
}

// ============================================================
// Cursor style (DECSCUSR)
// ============================================================

pub fn (mut self StreamHandler) set_cursor_style(style terminal.AnsiCursorStyle) ! {
	// Assume we're setting to a non-default.
	self.default_cursor = false

	match style {
		.default_ {
			self.default_cursor = true
			self.terminal.screens.active.cursor.cursor_style = self.default_cursor_style
			self.terminal.modes.set(.cursor_blinking, self.default_cursor_blink or { true })
		}
		.blinking_block {
			self.terminal.screens.active.cursor.cursor_style = .block
			self.terminal.modes.set(.cursor_blinking, true)
		}
		.steady_block {
			self.terminal.screens.active.cursor.cursor_style = .block
			self.terminal.modes.set(.cursor_blinking, false)
		}
		.blinking_underline {
			self.terminal.screens.active.cursor.cursor_style = .underline
			self.terminal.modes.set(.cursor_blinking, true)
		}
		.steady_underline {
			self.terminal.screens.active.cursor.cursor_style = .underline
			self.terminal.modes.set(.cursor_blinking, false)
		}
		.blinking_bar {
			self.terminal.screens.active.cursor.cursor_style = .bar
			self.terminal.modes.set(.cursor_blinking, true)
		}
		.steady_bar {
			self.terminal.screens.active.cursor.cursor_style = .bar
			self.terminal.modes.set(.cursor_blinking, false)
		}
	}
}

// ============================================================
// Simple delegating methods
// ============================================================

pub fn (mut self StreamHandler) decaln() {
	self.terminal.decaln() or {}
}

pub fn (mut self StreamHandler) save_cursor() {
	self.terminal.save_cursor()
}

pub fn (mut self StreamHandler) restore_cursor() {
	self.terminal.restore_cursor()
}

pub fn (mut self StreamHandler) enquiry() {
	self.message_writer(Message.write_req(self.enquiry_response))
}

fn (mut self StreamHandler) configure_charset(slot terminal.CharsetSlot, set terminal.Charset) {
	self.terminal.configure_charset(slot, set)
}

pub fn (mut self StreamHandler) full_reset() {
	self.terminal.full_reset()
	self.set_mouse_shape(.text)

	// Reset resets our palette so we report it for mode 2031.
	self.message_writer(Message.color_scheme_report_msg(false))

	// Clear the progress bar
	self.surface_message_writer(apprt.SurfaceMessage{
		kind: .progress_report
	})
}

// ============================================================
// Kitty keyboard query
// ============================================================

pub fn (mut self StreamHandler) query_kitty_keyboard() {
	flags := self.terminal.screens.active.kitty_keyboard.current()
	resp := '\x1b[?${flags.int()}u'
	self.message_writer(Message.write_req(resp))
}

// ============================================================
// XTVERSION
// ============================================================

pub fn (mut self StreamHandler) report_xtversion() {
	resp := '\x1bP>|ghostty ${build_meta.version_string}\x1b\\'
	self.message_writer(Message.write_req(resp))
}

// ============================================================
// OSC handlers
// ============================================================

fn (mut self StreamHandler) window_title(title string) {
	mut buf := [256]u8{}
	if title.len >= buf.len {
		// Title larger than our buffer, ignore
		return
	}

	for i in 0 .. title.len {
		buf[i] = title[i]
	}
	buf[title.len] = 0

	// Special handling for the empty title. We treat the empty title
	// as resetting to as if we never saw a title. Other terminals
	// behave this way too (e.g. iTerm2).
	if title.len == 0 {
		// If we have a pwd then we set the title as the pwd else
		// we just set it to blank.
		pwd := self.terminal.get_pwd() or { '' }
		if pwd.len > 0 && pwd.len < buf.len {
			for i in 0 .. pwd.len {
				buf[i] = pwd[i]
			}
			buf[pwd.len] = 0
		}

		mut msg := apprt.SurfaceMessage{
			kind: .set_title
		}
		msg.title_buf = buf
		self.surface_message_writer(msg)
		self.seen_title = false
		return
	}

	self.seen_title = true
	mut msg := apprt.SurfaceMessage{
		kind: .set_title
	}
	msg.title_buf = buf
	self.surface_message_writer(msg)
}

fn (mut self StreamHandler) set_mouse_shape(shape terminal.MouseShape) {
	// Avoid changing the shape if it is already set to avoid excess
	// cross-thread messaging.
	if self.terminal.mouse_shape == shape {
		return
	}

	self.terminal.mouse_shape = shape
	self.surface_message_writer(apprt.SurfaceMessage{
		kind: .set_mouse_shape
		mouse_shape: shape
	})
}

fn (mut self StreamHandler) clipboard_contents(kind u8, data string) {
	// Note: we ignore the "kind" field and always use the standard clipboard.
	// iTerm also appears to do this but other terminals seem to only allow
	// certain. Let's investigate more.

	clipboard_type := match kind {
		`c` { apprt.Clipboard.standard }
		`s` { apprt.Clipboard.selection }
		`p` { apprt.Clipboard.primary }
		else { apprt.Clipboard.standard }
	}

	// Get clipboard contents
	if data.len == 1 && data[0] == `?` {
		self.surface_message_writer(apprt.SurfaceMessage{
			kind: .clipboard_read
			clipboard_type: clipboard_type
		})
		return
	}

	// Write clipboard contents
	self.surface_message_writer(apprt.SurfaceMessage{
		kind: .clipboard_write
		clipboard_write_type: clipboard_type
		clipboard_write_req: apprt.WriteReq.init(data.bytes())
	})
}

fn (mut self StreamHandler) semantic_prompt(payload terminal.ActionPayload) {
	match payload.semantic_prompt_action {
		.end_input_start_output {
			self.surface_message_writer(apprt.SurfaceMessage{ kind: .start_command })
		}
		.end_command {
			raw := osc.read_exit_code(payload.semantic_prompt_opts) or { i32(0) }
			code := if raw >= 0 && raw <= 255 { u8(raw) } else { u8(1) }
			self.surface_message_writer(apprt.SurfaceMessage{
				kind: .stop_command
				stop_command_exit_code: code
			})
		}
		else {}
	}

	self.terminal.semantic_prompt_options(payload.semantic_prompt_action, payload.semantic_prompt_opts)
}

fn (mut self StreamHandler) report_pwd(url string) {
	// Special handling for the empty URL. We treat the empty URL
	// as resetting the pwd as if we never saw a pwd.
	if url.len == 0 {
		// Blank value can never fail because no allocs happen.
		self.terminal.set_pwd('') or {}

		// If we haven't seen a title, we're using the pwd as our title.
		// Set it to blank which will reset our title behavior.
		if !self.seen_title {
			self.window_title('')
		}

		// Report the change.
		self.surface_message_writer(apprt.SurfaceMessage{
			kind: .pwd_change
			pwd_change: apprt.WriteReq.stable([]u8{})
		})
		return
	}

	// Attempt to parse this file-style URI using options appropriate for
	// this OSC 7 context. kitty-shell-cwd expects the full, unencoded path.
	uri := internal_os.parse_uri(url, internal_os.UriParseOptions{
		mac_address: $if macos { false } $else { true }
		raw_path: url.starts_with('kitty-shell-cwd://')
	}) or {
		// invalid url in OSC 7
		return
	}

	if uri.scheme != 'file' && uri.scheme != 'kitty-shell-cwd' {
		// OSC 7 scheme must be file or kitty-shell-cwd.
		return
	}

	// OSC 7 is a little sketchy because anyone can send any value from
	// any host (such as an SSH session). The best practice terminals follow
	// is to validate the hostname to be local.
	if uri.host.len == 0 {
		// OSC 7 uri must contain a hostname.
		return
	}
	if !(internal_os.hostname_is_local(uri.host) or { false }) {
		// OSC 7 host must be local.
		return
	}

	self.terminal.set_pwd(uri.path) or {}

	// Report it to the surface.
	self.surface_message_writer(apprt.SurfaceMessage{
		kind: .pwd_change
		pwd_change: apprt.WriteReq.init(uri.path.bytes())
	})

	// If we haven't seen a title, use our pwd as the title.
	if !self.seen_title {
		self.window_title(uri.path)
		self.seen_title = false
	}
}

// ============================================================
// OSC color operations (OSC 4, 10-19, 104, 110-119)
// ============================================================

// color_operation applies the already-parsed OSC color requests. Parsing is
// performed once by osc.Parser, matching Ghostty's typed stream action.
fn (mut self StreamHandler) color_operation(op osc.ColorOperation, requests []osc.ColorRequest, terminator osc.Terminator) {
	_ = op
	if requests.len == 0 {
		return
	}

	mut response := ''
	for request in requests {
		match request {
			osc.ColorRequestSet {
				color := terminal_rgb(request.color)
				match request.target {
					osc.ColorTargetPalette {
						self.terminal.flags.set_dirty_palette(true)
						self.terminal.colors.palette.set(request.target.index, color)
					}
					osc.ColorTargetDynamic {
						self.set_dynamic_color(request.target.color, color)
					}
					osc.ColorTargetSpecial {}
				}
				self.notify_color_change(request.target, color)
			}
			osc.ColorRequestReset {
				match request.target {
					osc.ColorTargetPalette {
						idx := request.target.index
						self.terminal.flags.set_dirty_palette(true)
						self.terminal.colors.palette.reset(idx)
						self.notify_color_change(request.target, self.terminal.colors.palette.current[int(idx)])
					}
					osc.ColorTargetDynamic {
						self.reset_dynamic_color(request.target.color, request.target)
					}
					osc.ColorTargetSpecial {}
				}
			}
			osc.ColorRequestResetPalette {
				for i in 0 .. 256 {
					idx := u8(i)
					if self.terminal.colors.palette.mask_is_set(idx) {
						self.terminal.flags.set_dirty_palette(true)
						self.terminal.colors.palette.reset(idx)
						self.notify_color_change(osc.ColorTarget(osc.ColorTargetPalette{
							index: idx
						}), self.terminal.colors.palette.current[i])
					}
				}
			}
			osc.ColorRequestResetSpecial {}
			osc.ColorRequestQuery {
				if report := self.color_query_response(request.target, terminator) {
					response += report
				}
			}
		}
	}

	if response.len > 0 {
		self.message_writer(Message.write_req(response))
	}
}

fn terminal_rgb(color osc.RGB) terminal.RGB {
	return terminal.RGB{
		r: color.r
		g: color.g
		b: color.b
	}
}

fn (mut self StreamHandler) set_dynamic_color(dynamic osc.DynamicColor, color terminal.RGB) {
	match dynamic {
		.foreground { self.terminal.colors.foreground.set(color) }
		.background { self.terminal.colors.background.set(color) }
		.cursor { self.terminal.colors.cursor.set(color) }
		else {}
	}
}

fn (mut self StreamHandler) reset_dynamic_color(dynamic osc.DynamicColor, target osc.ColorTarget) {
	match dynamic {
		.foreground {
			self.terminal.colors.foreground.reset()
			if color := self.terminal.colors.foreground.default_color {
				self.notify_color_change(target, color)
			}
		}
		.background {
			self.terminal.colors.background.reset()
			if color := self.terminal.colors.background.default_color {
				self.notify_color_change(target, color)
			}
		}
		.cursor {
			self.terminal.colors.cursor.reset()
			if color := self.terminal.colors.cursor.default_color {
				self.notify_color_change(target, color)
			}
		}
		else {}
	}
}

fn (self &StreamHandler) color_query_response(target osc.ColorTarget, terminator osc.Terminator) ?string {
	if self.osc_color_report_format == .none_ {
		return none
	}
	mut prefix := ''
	color := match target {
		osc.ColorTargetPalette {
			prefix = '\x1b]4;${target.index};rgb:'
			self.terminal.colors.palette.current[int(target.index)]
		}
		osc.ColorTargetDynamic {
			prefix = '\x1b]${u8(target.color)};rgb:'
			match target.color {
				.foreground { self.terminal.colors.foreground.get() or { return none } }
				.background { self.terminal.colors.background.get() or { return none } }
				.cursor {
					self.terminal.colors.cursor.get() or {
						self.terminal.colors.foreground.get() or { return none }
					}
				}
				else {
					return none
				}
			}
		}
		osc.ColorTargetSpecial {
			return none
		}
	}
	term := terminator.string()
	return match self.osc_color_report_format {
		.format_16_bit {
			'${prefix}${hex4(color.r)}/${hex4(color.g)}/${hex4(color.b)}${term}'
		}
		.format_8_bit {
			'${prefix}${hex2(color.r)}/${hex2(color.g)}/${hex2(color.b)}${term}'
		}
		.none_ { '' }
	}
}

// notify_color_change forwards an OSC color mutation to the surface.
fn (mut self StreamHandler) notify_color_change(target osc.ColorTarget, color terminal.RGB) {
	self.surface_message_writer(apprt.SurfaceMessage{
		kind: .color_change
		color_change: osc.ColoredTarget{
			target: target
			color: osc.RGB{
				r: color.r
				g: color.g
				b: color.b
			}
		}
	})
}

// ============================================================
// Kitty color protocol (OSC 21)
// ============================================================

// kitty_color_report applies the parsed Kitty OSC 21 operations.
fn (mut self StreamHandler) kitty_color_report(items []osc.KittyColorItem, terminator osc.Terminator) {
	mut response := ''

	for item in items {
		match item.item_type {
			.query {
				key := kitty_color_key_string(item.key)
				if response.len == 0 {
					response += '\x1b]21'
				}
				if !kitty_color_supported(item.key) {
					continue
				}
				if color := self.kitty_color_get(item.key) {
					response += ';${key}=rgb:${hex2(color.r)}/${hex2(color.g)}/${hex2(color.b)}'
				} else {
					response += ';${key}='
				}
			}
			.set {
				self.kitty_color_set(item.key, terminal_rgb(item.color))
			}
			.reset {
				self.kitty_color_reset(item.key)
			}
		}
	}

	if response.len > 0 {
		response += terminator.string()
		self.message_writer(Message.write_req(response))
	}
}

fn kitty_color_supported(key osc.KittyColorKind) bool {
	return match key.kind {
		.palette { true }
		.special {
			key.special in [.foreground, .background, .cursor]
		}
	}
}

fn (self &StreamHandler) kitty_color_get(key osc.KittyColorKind) ?terminal.RGB {
	return match key.kind {
		.palette { self.terminal.colors.palette.current[int(key.palette)] }
		.special {
			match key.special {
				.foreground { self.terminal.colors.foreground.get() }
				.background { self.terminal.colors.background.get() }
				.cursor { self.terminal.colors.cursor.get() }
				else { none }
			}
		}
	}
}

fn (mut self StreamHandler) kitty_color_set(key osc.KittyColorKind, color terminal.RGB) {
	match key.kind {
		.palette {
			self.terminal.flags.set_dirty_palette(true)
			self.terminal.colors.palette.set(key.palette, color)
		}
		.special {
			match key.special {
				.foreground { self.terminal.colors.foreground.set(color) }
				.background { self.terminal.colors.background.set(color) }
				.cursor { self.terminal.colors.cursor.set(color) }
				else {}
			}
		}
	}
}

fn (mut self StreamHandler) kitty_color_reset(key osc.KittyColorKind) {
	match key.kind {
		.palette {
			self.terminal.flags.set_dirty_palette(true)
			self.terminal.colors.palette.reset(key.palette)
		}
		.special {
			match key.special {
				.foreground { self.terminal.colors.foreground.reset() }
				.background { self.terminal.colors.background.reset() }
				.cursor { self.terminal.colors.cursor.reset() }
				else {}
			}
		}
	}
}

fn kitty_color_key_string(key osc.KittyColorKind) string {
	return match key.kind {
		.palette { '${key.palette}' }
		.special {
			match key.special {
				.foreground { 'foreground' }
				.background { 'background' }
				.selection_foreground { 'selection_foreground' }
				.selection_background { 'selection_background' }
				.cursor { 'cursor' }
				.cursor_text { 'cursor_text' }
				.visual_bell { 'visual_bell' }
				.second_transparent_background { 'second_transparent_background' }
			}
		}
	}
}

// hex2 formats a byte as a 2-digit lowercase hex string.
fn hex2(v u8) string {
	digits := '0123456789abcdef'
	return '${digits[int(v >> 4)]:c}${digits[int(v & 0x0F)]:c}'
}

// hex4 formats a byte scaled to 16 bits (v * 257) as a 4-digit lowercase
// hex string, matching the "16-bit" OSC color report format.
fn hex4(v u8) string {
	scaled := u16(v) * 257
	digits := '0123456789abcdef'
	return '${digits[int((scaled >> 12) & 0x0F)]:c}${digits[int((scaled >> 8) & 0x0F)]:c}${digits[int((scaled >> 4) & 0x0F)]:c}${digits[int(scaled & 0x0F)]:c}'
}

fn (mut self StreamHandler) show_desktop_notification(notification osc.DesktopNotification) {
	mut msg := apprt.SurfaceMessage{
		kind: .desktop_notification
	}

	title_len := if notification.title.len < msg.notification_title.len {
		notification.title.len
	} else {
		msg.notification_title.len - 1
	}
	for i in 0 .. title_len {
		msg.notification_title[i] = notification.title[i]
	}
	msg.notification_title[title_len] = 0

	body_len := if notification.body.len < msg.notification_body.len {
		notification.body.len
	} else {
		msg.notification_body.len - 1
	}
	for i in 0 .. body_len {
		msg.notification_body[i] = notification.body[i]
	}
	msg.notification_body[body_len] = 0

	self.surface_message_writer(msg)
}

// Send a report to the pty.
pub fn (mut self StreamHandler) send_size_report(style terminal.SizeReportStyle) {
	match style {
		.csi_14_t {
			self.message_writer(Message{
				kind: .size_report
				size_report_val: .csi_14_t
			})
		}
		.csi_16_t {
			self.message_writer(Message{
				kind: .size_report
				size_report_val: .csi_16_t
			})
		}
		.csi_18_t {
			self.message_writer(Message{
				kind: .size_report
				size_report_val: .csi_18_t
			})
		}
		.csi_21_t {
			self.surface_message_writer(apprt.SurfaceMessage{
				kind: .report_title
				report_style: .csi_21_t
			})
		}
	}
}

// Display a GUI progress report.
fn (mut self StreamHandler) progress_report(report osc.ProgressReport) {
	self.surface_message_writer(apprt.SurfaceMessage{
		kind: .progress_report
		progress_report: report
	})
}

// ============================================================
// APC and DCS handlers
// ============================================================

// ApcHandler maintains APC (Application Program Command) state.
// APC is used by the kitty graphics protocol.
pub struct ApcHandler {
mut:
	state  ApcHandlerState
	parser kitty.Parser
}

pub fn (mut self ApcHandler) deinit() {
	self.state = .inactive
	self.parser = kitty.Parser.init()
}

pub fn (mut self ApcHandler) start() {
	self.state = .identify
	self.parser = kitty.Parser.init()
}

pub fn (mut self ApcHandler) feed(byte_val u8) {
	match self.state {
		.inactive { panic('ApcHandler.feed called while inactive') }
		.ignore {}
		.identify {
			self.state = if byte_val == `G` { .kitty } else { .ignore }
		}
		.kitty {
			self.parser.feed(byte_val) or {
				self.state = .ignore
			}
		}
	}
}

pub fn (mut self ApcHandler) end() ?kitty.Command {
	defer {
		self.state = .inactive
		self.parser = kitty.Parser.init()
	}

	if self.state == .inactive {
		panic('ApcHandler.end called while inactive')
	}
	if self.state != .kitty {
		return none
	}
	return self.parser.complete() or { return none }
}

enum ApcHandlerState as u8 {
	inactive
	ignore
	identify
	kitty
}

// DcsHandler wraps terminal.DcsHandler, delegating all DCS state
// management to the terminal module's implementation.
pub struct DcsHandler {
mut:
	handler terminal.DcsHandler = terminal.DcsHandler{}
}

pub fn (mut self DcsHandler) deinit() {
	self.handler.deinit()
}

pub fn (mut self DcsHandler) hook(dcs terminal.DcsParams) ?terminal.DcsCommand {
	return self.handler.hook(dcs)
}

pub fn (mut self DcsHandler) put(byte_val u8) ?terminal.DcsCommand {
	return self.handler.put(byte_val)
}

pub fn (mut self DcsHandler) unhook() ?terminal.DcsCommand {
	return self.handler.unhook()
}
