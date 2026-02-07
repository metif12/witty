module termio

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

pub struct DerivedConfig {}

pub fn DerivedConfig.init(config voidptr) !DerivedConfig {
	return DerivedConfig{}
}

pub fn (d DerivedConfig) deinit() {}

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

// Message represents an IO message to send to the terminal.
pub struct Message {
pub:
	kind MessageKind
	data MessageData
}

pub enum MessageKind {
	write_small
	write_stable
	write_alloc
	resize
	inspector
	change_config
	focused
	color_scheme_report
	selection_scroll
	visible
}

pub union MessageData {
	write_small  WriteSmall
	write_stable WriteStable
	write_alloc  WriteAlloc
	resize       voidptr
	flag         bool
}

pub struct WriteSmall {
pub mut:
	data [128]u8
	len  u8
}

pub fn WriteSmall.from_slice(s []u8) WriteSmall {
	mut w := WriteSmall{}
	len := if s.len < 128 { u8(s.len) } else { u8(128) }
	for i in 0 .. int(len) {
		w.data[i] = s[i]
	}
	w.len = len
	return w
}

pub struct WriteStable {
pub:
	data []u8
}

pub struct WriteAlloc {
pub:
	data []u8
}

pub fn (w WriteAlloc) deinit() {
	// stub: frees allocated data
}

// WriteReq is what gets queued for IO writes.
pub struct WriteReq {
pub:
	kind WriteReqKind
	data []u8
}

pub enum WriteReqKind {
	small
	stable
	alloc_
}

pub fn (w WriteReq) deinit() {
	// stub: frees if alloc
}

pub fn Message.write_small_msg(data []u8) Message {
	return Message{
		kind: .write_small
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
	}
}

pub fn Message.focused_msg(focused bool) Message {
	return Message{
		kind: .focused
	}
}

pub fn Message.color_scheme_report_msg() Message {
	return Message{
		kind: .color_scheme_report
	}
}

pub fn Message.selection_scroll_msg(active bool) Message {
	return Message{
		kind: .selection_scroll
	}
}

pub fn Message.visible_msg(vis bool) Message {
	return Message{
		kind: .visible
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
pub struct Mailbox {}

pub fn Mailbox.init() !Mailbox {
	return Mailbox{}
}

pub fn (m Mailbox) deinit() {}
