module termio

import sync
import terminal

// Termio manages terminal IO between the surface and the pty.
pub struct Termio {
pub mut:
	terminal voidptr
}

pub fn (mut t Termio) init(opts TermioOpts) ! {
	// stub: initializes terminal IO
}

pub fn (mut t Termio) deinit() {
	// stub: cleans up terminal IO
}

pub fn (t Termio) queue_message(msg Message, mutex_state MutexState) {
	_ = msg
	_ = mutex_state
}

pub struct TermioOpts {}

// DerivedConfig holds configuration derived from the main config
// that the stream handler needs.
pub struct DerivedConfig {
pub mut:
	osc_color_report_format OSCColorReportFormat = .bits_16
	clipboard_write         ClipboardAccess      = .allow
	enquiry_response        string
	cursor_style            terminal.CursorStyle = .block
	cursor_blink            ?bool
}

pub fn DerivedConfig.init(config voidptr) !DerivedConfig {
	return DerivedConfig{}
}

pub fn (d DerivedConfig) deinit() {}

// OSCColorReportFormat controls how colors are reported in OSC responses.
pub enum OSCColorReportFormat {
	none_
	bits_8
	bits_16
}

// ClipboardAccess controls clipboard read/write permissions.
pub enum ClipboardAccess {
	allow
	ask
	deny
}

// CursorStyle: use terminal.CursorStyle directly.

// Thread manages the IO thread.
pub struct Thread {
pub mut:
	stop Stopwatch
}

pub fn Thread.init() !Thread {
	return Thread{}
}

pub fn (mut t Thread) deinit() {}

pub fn (t Thread) thread_main() {
	// stub: IO thread main loop
}

pub struct Stopwatch {}

pub fn (s Stopwatch) notify() ! {
	// stub: signals the thread to stop
}

// ============================================================
// Message: represents an IO message to send to the terminal.
// ============================================================

// Message represents an IO message to send to the terminal.
// We use a tagged union approach via a kind enum and associated data.
pub struct Message {
pub mut:
	kind MessageKind
	// Data fields — only the one matching `kind` is meaningful.
	write_small_data  WriteSmall
	write_stable_data string
	write_alloc_data  string
	flag_val          bool
	force_val         bool
	size_report_val   SizeReportKind
}

pub enum MessageKind {
	write_small
	write_stable
	write_alloc
	write_req
	resize
	inspector
	change_config
	focused
	color_scheme_report
	selection_scroll
	visible
	start_synchronized_output
	linefeed_mode
	size_report
}

// SizeReportKind identifies what kind of size report to send.
pub enum SizeReportKind {
	csi_14_t
	csi_16_t
	csi_18_t
	mode_2048
}

pub struct WriteSmall {
pub mut:
	data [128]u8
	len  u8
}

pub fn WriteSmall.from_slice(s []u8) WriteSmall {
	mut w := WriteSmall{}
	length := if s.len < 128 { u8(s.len) } else { u8(128) }
	for i in 0 .. int(length) {
		w.data[i] = s[i]
	}
	w.len = length
	return w
}

pub fn (w &WriteSmall) slice() []u8 {
	mut result := []u8{len: int(w.len)}
	for i in 0 .. int(w.len) {
		result[i] = w.data[i]
	}
	return result
}

// write_req creates a Message containing a write request from a
// dynamically sized slice. The data is copied.
pub fn Message.write_req(data string) Message {
	// If the data fits in a small write, use that
	if data.len <= 128 {
		mut msg := Message{
			kind: .write_small
		}
		for i in 0 .. data.len {
			msg.write_small_data.data[i] = data[i]
		}
		msg.write_small_data.len = u8(data.len)
		return msg
	}
	// Otherwise use an allocated write
	return Message{
		kind: .write_alloc
		write_alloc_data: data.clone()
	}
}

pub fn Message.write_small_msg(data []u8) Message {
	mut msg := Message{
		kind: .write_small
	}
	length := if data.len < 128 { u8(data.len) } else { u8(128) }
	for i in 0 .. int(length) {
		msg.write_small_data.data[i] = data[i]
	}
	msg.write_small_data.len = length
	return msg
}

pub fn Message.write_stable_msg(data string) Message {
	return Message{
		kind: .write_stable
		write_stable_data: data
	}
}

pub fn Message.resize_msg(size voidptr) Message {
	return Message{
		kind: .resize
	}
}

pub fn Message.inspector_msg(active bool) Message {
	return Message{
		kind: .inspector
		flag_val: active
	}
}

pub fn Message.focused_msg(focused bool) Message {
	return Message{
		kind: .focused
		flag_val: focused
	}
}

pub fn Message.color_scheme_report_msg(force bool) Message {
	return Message{
		kind: .color_scheme_report
		force_val: force
	}
}

pub fn Message.selection_scroll_msg(active bool) Message {
	return Message{
		kind: .selection_scroll
		flag_val: active
	}
}

pub fn Message.visible_msg(vis bool) Message {
	return Message{
		kind: .visible
		flag_val: vis
	}
}

pub fn Message.change_config_msg(cfg voidptr) Message {
	return Message{
		kind: .change_config
	}
}

pub enum MutexState {
	locked
	unlocked
}

// Mailbox for communicating with the IO thread.
pub struct Mailbox {
mut:
	// stub: would contain a ring buffer or channel
	dummy u8
}

pub fn Mailbox.init() !Mailbox {
	return Mailbox{}
}

pub fn (m Mailbox) deinit() {}

// send pushes a message to the mailbox, unlocking the provided mutex
// if the mailbox would block.
pub fn (m Mailbox) send(msg Message, mtx &sync.Mutex) {
	// stub: would push into a ring buffer
	_ = msg
	_ = mtx
}

// push attempts to push a message. Returns number of items pushed (0 or 1).
pub fn (m Mailbox) push(msg Message) int {
	// stub: always succeeds
	_ = msg
	return 1
}
