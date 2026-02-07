module termio

import apprt
import renderer
import terminal

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
	default_cursor bool = true
	default_cursor_style terminal.CursorStyle = .block
	default_cursor_blink ?bool

	// The response to use for ENQ requests.
	enquiry_response string

	// The color reporting format for OSC requests.
	osc_color_report_format OSCColorReportFormat = .bits_16

	// The clipboard write access configuration.
	clipboard_write ClipboardAccess = .allow

	//---------------------------------------------------------------
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
	if self.surface_mailbox.push(msg) == 0 {
		self.renderer_state.mutex.unlock()
		defer { self.renderer_state.mutex.lock() }
		self.surface_mailbox.push(msg)
	}
}

fn (mut self StreamHandler) message_writer(msg Message) {
	self.termio_mailbox.send(msg, &self.renderer_state.mutex)
	self.termio_messaged = true
}

// Send a renderer message and unlock the renderer state mutex
// if necessary to ensure we don't deadlock.
//
// This assumes the renderer state mutex is locked.
fn (mut self StreamHandler) renderer_message_writer(msg renderer.Message) {
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
			self.terminal.print_repeat(int(event.payload.num)) or {}
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
			self.terminal.invoke_charset(event.payload.charset_bank, event.payload.charset_slot,
				event.payload.charset_locking)
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
			self.terminal.set_cursor_pos(int(self.terminal.screens.active.cursor.y) + 1,
				int(event.payload.num))
		}
		.cursor_row {
			self.terminal.set_cursor_pos(int(event.payload.num), int(self.terminal.screens.active.cursor.x) + 1)
		}
		.cursor_col_relative {
			col := int(self.terminal.screens.active.cursor.x) + 1 + int(event.payload.num)
			self.terminal.set_cursor_pos(int(self.terminal.screens.active.cursor.y) + 1,
				col)
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
			self.terminal.scroll_viewport(.bottom, 0) or {}
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
			self.terminal.delete_chars(int(event.payload.num))
		}
		.erase_chars {
			self.terminal.erase_chars(int(event.payload.num))
		}
		.insert_lines {
			self.terminal.insert_lines(int(event.payload.num))
		}
		.insert_blanks {
			self.terminal.insert_blanks(int(event.payload.num))
		}
		.delete_lines {
			self.terminal.delete_lines(int(event.payload.num))
		}
		.scroll_up {
			self.terminal.scroll_up(int(event.payload.num)) or {}
		}
		.scroll_down {
			self.terminal.scroll_down(int(event.payload.num))
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
			self.terminal.flags.mouse_shift_capture = if event.payload.flag { .true_ } else { .false_ }
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
			// XTODO: DeviceStatusRequest uses a different enum in stream.v
			// Map it to the handler's request_mode types
		}
		.kitty_keyboard_query {
			self.query_kitty_keyboard()
		}
		.kitty_keyboard_push {
			self.terminal.screens.active.kitty_keyboard.push(u32(event.payload.kitty_flags))
		}
		.kitty_keyboard_pop {
			self.terminal.screens.active.kitty_keyboard.pop(u8(event.payload.num))
		}
		.kitty_keyboard_set {
			self.terminal.screens.active.kitty_keyboard.set(.set_, u32(event.payload.kitty_flags))
		}
		.kitty_keyboard_set_or {
			self.terminal.screens.active.kitty_keyboard.set(.or_, u32(event.payload.kitty_flags))
		}
		.kitty_keyboard_set_not {
			self.terminal.screens.active.kitty_keyboard.set(.not_, u32(event.payload.kitty_flags))
		}
		.kitty_color_report {
			// XTODO: kitty color report protocol requires complex color
			// query/set/reset logic and response encoding
		}
		.color_operation {
			// XTODO: color operations (set/query/reset palette and dynamic
			// colors) require OSC color parsing and response encoding
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
			self.show_desktop_notification(event.payload.str1, event.payload.str2)
		}
		.progress_report {
			self.progress_report(event.payload.num)
		}
		.start_hyperlink {
			id_val := if event.payload.str2.len > 0 { ?string(event.payload.str2) } else { ?string(none) }
			self.terminal.screens.active.start_hyperlink(event.payload.str1, id_val) or {}
		}
		.clipboard_contents {
			self.clipboard_contents(event.payload.clipboard_kind, event.payload.str1)
		}
		.semantic_prompt {
			self.semantic_prompt(event.payload)
		}
		.mouse_shape_action {
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
	// XTODO: DCS hook requires full DCS command parsing (XTGETTCAP,
	// DECRQSS, tmux control mode). The DCS handler would parse the
	// intermediates and params to determine the DCS command type.
	mut cmd := self.dcs.hook(payload) or { return }
	defer { cmd.deinit() }
	self.dcs_command(mut cmd)
}

pub fn (mut self StreamHandler) dcs_put(byte_val u8) {
	// XTODO: DCS put feeds bytes into the active DCS command handler.
	mut cmd := self.dcs.put(byte_val) or { return }
	defer { cmd.deinit() }
	self.dcs_command(mut cmd)
}

pub fn (mut self StreamHandler) dcs_unhook() {
	// XTODO: DCS unhook completes the DCS sequence.
	mut cmd := self.dcs.unhook() or { return }
	defer { cmd.deinit() }
	self.dcs_command(mut cmd)
}

fn (mut self StreamHandler) dcs_command(mut cmd DcsCommand) {
	// XTODO: Full DCS command dispatch requires:
	// - tmux control mode enter/exit/commands
	// - XTGETTCAP terminfo capability reporting
	// - DECRQSS (Request Status String) for SGR, DECSCUSR, DECSTBM, DECSLRM
	// Each of these needs their own response encoding and state management.
	match cmd.kind {
		.xtgettcap {
			// XTODO: Would iterate over requested terminfo capabilities
			// and send responses from a precomputed map.
		}
		.decrqss {
			// XTODO: Would query terminal state (SGR attributes, cursor style,
			// scroll margins) and format a DECRPSS response.
		}
		.tmux {
			// XTODO: tmux control mode requires a full tmux viewer state
			// machine with enter/exit/command handling.
		}
	}
}

// ============================================================
// APC handler
// ============================================================

pub fn (mut self StreamHandler) apc_end() {
	// XTODO: APC end completes the APC sequence. The primary use is
	// the Kitty graphics protocol which requires image encoding/decoding,
	// shared memory management, and response generation.
	mut cmd := self.apc.end() or { return }
	defer { cmd.deinit() }

	match cmd.kind {
		.kitty {
			// XTODO: Kitty graphics protocol command processing.
			// Would call self.terminal.kitty_graphics() and encode response.
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
	self.terminal.flags.modify_other_keys_2 = false
	match format {
		.other_keys_numeric {
			self.terminal.flags.modify_other_keys_2 = true
		}
		else {}
	}
}

// ============================================================
// Mode request/response
// ============================================================

fn (mut self StreamHandler) request_mode(mode terminal.Mode) {
	code := if self.terminal.modes.get(mode) { u8(1) } else { u8(2) }
	mode_val := int(mode)
	// Build response: ESC [ ? <mode> ; <code> $ y
	resp := '\x1b[?${mode_val};${code}\$y'
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
			self.terminal.flags.dirty.reverse_colors = true
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
				self.message_writer(Message.focused_msg(self.terminal.flags.focused))
			}
		}

		.mouse_event_x10 {
			if enabled {
				self.terminal.flags.mouse_event = .x10
				self.set_mouse_shape(.default_)
			} else {
				self.terminal.flags.mouse_event = .none
				self.set_mouse_shape(.text)
			}
		}
		.mouse_event_normal {
			if enabled {
				self.terminal.flags.mouse_event = .normal
				self.set_mouse_shape(.default_)
			} else {
				self.terminal.flags.mouse_event = .none
				self.set_mouse_shape(.text)
			}
		}
		.mouse_event_button {
			if enabled {
				self.terminal.flags.mouse_event = .button
				self.set_mouse_shape(.default_)
			} else {
				self.terminal.flags.mouse_event = .none
				self.set_mouse_shape(.text)
			}
		}
		.mouse_event_any {
			if enabled {
				self.terminal.flags.mouse_event = .any
				self.set_mouse_shape(.default_)
			} else {
				self.terminal.flags.mouse_event = .none
				self.set_mouse_shape(.text)
			}
		}

		.mouse_format_utf8 {
			self.terminal.flags.mouse_format = if enabled { .utf8 } else { .x10 }
		}
		.mouse_format_sgr {
			self.terminal.flags.mouse_format = if enabled { .sgr } else { .x10 }
		}
		.mouse_format_urxvt {
			self.terminal.flags.mouse_format = if enabled { .urxvt } else { .x10 }
		}
		.mouse_format_sgr_pixels {
			self.terminal.flags.mouse_format = if enabled { .sgr_pixels } else { .x10 }
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
	resp := '\x1b[?${flags}u'
	self.message_writer(Message.write_req(resp))
}

// ============================================================
// XTVERSION
// ============================================================

pub fn (mut self StreamHandler) report_xtversion() {
	// Report as ghostty (the upstream project we translated from)
	resp := '\x1bP>|ghostty 0.0.0\x1b\\'
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
	})
}

fn (mut self StreamHandler) semantic_prompt(payload terminal.ActionPayload) {
	// XTODO: Full semantic prompt processing. Currently only handles
	// the basic prompt/input/command lifecycle. The Zig code has more
	// complex handling including readOption for exit codes, and the
	// SemanticPromptAction enum has many more variants (end_input_start_output,
	// end_command, end_prompt_start_input, fresh_line, new_command, etc.).
	// The stream would dispatch with the proper action + options.
	//
	// For now, just call the terminal's semantic_prompt stub.
	self.terminal.semantic_prompt(.prompt_start, none)
}

fn (mut self StreamHandler) report_pwd(url string) {
	// XTODO: Full reportPwd requires URI parsing (file:// and kitty-shell-cwd://
	// schemes), hostname validation for security (OSC 7 can come from SSH),
	// URL percent-decoding, and platform-specific handling (Windows is different).
	// For now we do a simplified version that handles the empty and simple cases.

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
		})
		return
	}

	// Simple path extraction: if it starts with file:// extract the path.
	// A full implementation would do proper URI parsing and hostname validation.
	mut path := url
	if url.starts_with('file://') {
		// Skip file://hostname/ - find the path after the third /
		rest := url[7..]
		slash_idx := rest.index('/') or { -1 }
		if slash_idx >= 0 {
			path = rest[slash_idx..]
		}
	} else if url.starts_with('kitty-shell-cwd://') {
		rest := url[18..]
		slash_idx := rest.index('/') or { -1 }
		if slash_idx >= 0 {
			path = rest[slash_idx..]
		}
	}

	self.terminal.set_pwd(path) or {}

	// Report it to the surface.
	self.surface_message_writer(apprt.SurfaceMessage{
		kind: .pwd_change
	})

	// If we haven't seen a title, use our pwd as the title.
	if !self.seen_title {
		self.window_title(path)
		self.seen_title = false
	}
}

fn (mut self StreamHandler) show_desktop_notification(title string, body string) {
	mut msg := apprt.SurfaceMessage{
		kind: .desktop_notification
	}

	title_len := if title.len < msg.notification_title.len { title.len } else { msg.notification_title.len - 1 }
	for i in 0 .. title_len {
		msg.notification_title[i] = title[i]
	}
	msg.notification_title[title_len] = 0

	body_len := if body.len < msg.notification_body.len { body.len } else { msg.notification_body.len - 1 }
	for i in 0 .. body_len {
		msg.notification_body[i] = body[i]
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
fn (mut self StreamHandler) progress_report(state u16) {
	self.surface_message_writer(apprt.SurfaceMessage{
		kind: .progress_report
	})
}

// ============================================================
// Stub types for APC and DCS handlers
// ============================================================

// ApcHandler maintains APC (Application Program Command) state.
// APC is used by the kitty graphics protocol.
pub struct ApcHandler {
mut:
	active bool
	data   []u8
}

pub fn (mut self ApcHandler) deinit() {
	self.data = []u8{}
}

pub fn (mut self ApcHandler) start() {
	self.active = true
	self.data = []u8{}
}

pub fn (mut self ApcHandler) feed(byte_val u8) {
	if self.active {
		self.data << byte_val
	}
}

pub fn (mut self ApcHandler) end() ?ApcCommand {
	if !self.active {
		return none
	}
	self.active = false
	return ApcCommand{
		kind: .kitty
		data: self.data
	}
}

pub struct ApcCommand {
pub mut:
	kind ApcCommandKind
	data []u8
}

pub enum ApcCommandKind {
	kitty
}

pub fn (mut self ApcCommand) deinit() {
	self.data = []u8{}
}

// DcsHandler maintains DCS (Device Control String) state.
// DCS is used by XTGETTCAP, DECRQSS, and tmux control mode.
pub struct DcsHandler {
mut:
	active        bool
	intermediates []u8
	params        []u16
	final_byte    u8
	data          []u8
}

pub fn (mut self DcsHandler) deinit() {
	self.data = []u8{}
	self.intermediates = []u8{}
	self.params = []u16{}
}

pub fn (mut self DcsHandler) hook(payload terminal.ActionPayload) ?DcsCommand {
	self.active = true
	self.intermediates = payload.dcs_intermediates.clone()
	self.params = payload.dcs_params.clone()
	self.final_byte = payload.dcs_final
	self.data = []u8{}
	// XTODO: Would parse the DCS intro to determine command type
	return none
}

pub fn (mut self DcsHandler) put(byte_val u8) ?DcsCommand {
	if self.active {
		self.data << byte_val
	}
	return none
}

pub fn (mut self DcsHandler) unhook() ?DcsCommand {
	if !self.active {
		return none
	}
	self.active = false
	// XTODO: Would determine command type from intermediates/params/final
	return DcsCommand{
		kind: .xtgettcap
	}
}

pub struct DcsCommand {
pub mut:
	kind DcsCommandKind
	data []u8
}

pub enum DcsCommandKind {
	xtgettcap
	decrqss
	tmux
}

pub fn (mut self DcsCommand) deinit() {
	self.data = []u8{}
}
