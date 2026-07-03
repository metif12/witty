module termio

// --- Original Ghostty Comments Start: src/termio/Termio.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/termio/Termio.zig
//
// Primary terminal IO ("termio") state. This maintains the terminal state,
// pty, subprocess, etc. This is flexible enough to be used in environments
// that don't have a pty and simply provides the input/output using raw
// bytes.
// Mutex state argument for queueMessage.
// Allocator
// This is the implementation responsible for io.
// The derived configuration for this termio implementation.
// The terminal emulator internal state. This is the abstract "terminal"
// that manages input, grid updating, etc. and is renderer-agnostic. It
// just stores internal state about a grid.
// The shared render state
// A handle to wake up the renderer. This hints to the renderer that that
// a repaint should happen.
// The mailbox for notifying the renderer of things.
// The mailbox for communicating with the surface.
// The cached size info
// The mailbox implementation to use.
// The stream parser. This parses the stream of escape codes and so on
// from the child process and calls callbacks in the stream handler.
// Last time the cursor was reset. This is used to prevent message
// flooding with cursor resets.
// State we have for thread enter. This may be null if we don't need
// to keep track of any state or if its already been freed.
// The state we need to keep around only until we enter the IO
// thread. Then we can throw it all away.
// Initial input to send to the subprocess after starting. This
// memory is freed once the subprocess start is attempted, even
// if it fails, because Exec only starts once.
// If we have no input then we have no thread enter state
// Create our arena allocator
// Allocate our ThreadEnterState
// Copy the input from the config
// Return the initialized state
// Prepare the inputs for use. Allocations happen on the arena.
// The configuration for this IO that is derived from the main
// configuration. This must be exported so that we don't need to
// pass around Config pointers which makes memory management a pain.
// This has to be last so that we copy AFTER the arena allocations
// above happen (Zig assigns in order).
// Initialize the termio state.
//
// This will also start the child process if the termio is configured
// to run a child process.
// The default terminal modes based on our config.
// Setup our initial grapheme cluster support if enabled. We use a
// switch to ensure we get a compiler error if more cases are added.
// Set default cursor blink settings
// Create our terminal
// Set the image size limits
// Set our default cursor style
// Setup our terminal size in pixels for certain requests.
// Setup our backend.
// Create our stream handler. This points to memory in self so it
// isn't safe to use until self.* is set.
// Clear any StreamHandler state
// Clear any initial state if we have it
// Always free our thread enter state when we're done.
// If we have thread enter state then we're going to validate
// and set that all up now so that we can error before we actually
// start the command and pty.
// Setup our backend
// If we have inputs, then queue them all up.
// Send a message to the the mailbox. Depending on the mailbox type in
// use this may process now or it may just enqueue and process later.
//
// This will also notify the mailbox thread to process the message. If
// you're sending a lot of messages, it may be more efficient to use
// the mailbox directly and then call notify separately.
// Queue a write directly to the pty.
//
// If you're using termio.Thread, this must ONLY be called from the
// mailbox thread. If you're not on the thread, use queueMessage with
// mailbox messages instead.
//
// If you're not using termio.Thread, this is not threadsafe.
// Update the configuration.
// The remainder of this function is modifying terminal state or
// the read thread data, all of which requires holding the renderer
// state lock.
// Deinit our old config. We do this in the lock because the
// stream handler may be referencing the old config (i.e. enquiry resp)
// Update our stream handler. The stream handler uses the same
// renderer mutex so this is safe to do despite being executed
// from another thread.
// Update the configuration that we know about.
//
// Specific things we don't update:
//   - command, working-directory: we never restart the underlying
//   process so we don't care or need to know about these.
// Update the default palette.
// Update all our other colors
// Set the image size limits
// Resize the terminal.
// Update the size of our pty.
// Enter the critical area that we want to keep small
// Update the size of our terminal state
// Update our pixel sizes
// Disable synchronized output mode so that we show changes
// immediately for a resize. This is allowed by the spec.
// If we have size reporting enabled we need to send a report.
// Mail the renderer so that it can update the GPU and re-render
// Make a size report.
// 1024 bytes should be enough for size report since report
// in columns and pixels.
// Reset the synchronized output mode. This is usually called by timer
// expiration from the termio thread.
// Clear the screen.
// If we're on the alternate screen, we do not clear. Since this is an
// emulator-level screen clear, this messes up the running programs
// knowledge of where the cursor is and causes rendering issues. So,
// for alt screen, we do nothing.
// Clear our selection
// Clear our scrollback
// If we're not at a prompt, we just delete above the cursor.
// Clear all Kitty graphics state for this screen. This copies
// Kitty's behavior when Cmd+K deletes all Kitty graphics. I
// didn't spend time researching whether it only deletes Kitty
// graphics that are placed baove the cursor or if it deletes
// all of them. We delete all of them for now but if this behavior
// isn't fully correct we should fix this later.
// At a prompt, we want to first fully clear the screen, and then after
// send a FF (0x0C) to the shell so that it can repaint the screen.
// Mark the current row as a not a prompt so we can properly
// clear the full screen in the next eraseDisplay call.
// TODO: fix this
// self.terminal.markSemanticPrompt(.command);
// assert(!self.terminal.cursorIsAtPrompt());
// If we reached here it means we're at a prompt, so we send a form-feed.
// Scroll the viewport
// Jump the viewport to the prompt.
// Called when focus is gained or lost (when focus events are enabled)
// If we have focus events enabled, we send the focus event.
// We always notify our backend of focus changes.
// Process output from the pty. This is the manual API that users can
// call with pty data but it is also called by the read thread when using
// an exec subprocess.
// We are modifying terminal state from here on out and we need
// the lock to grab our read data.
// Process output from readdata but the lock is already held.
// Schedule a render. We can call this first because we have the lock.
// Whenever a character is typed, we ensure the cursor is in the
// non-blink state so it is rendered if visible. If we're under
// HEAVY read load, we don't want to send a ton of these so we
// use a timer under the covers
// If we have an inspector, we enter SLOW MODE because we need to
// process a byte at a time alternating between the inspector handler
// and the termio handler. This is very slow compared to our optimizations
// below but at least users only pay for it if they're using the inspector.
// If our stream handling caused messages to be sent to the mailbox
// thread, then we need to wake it up so that it processes them.
// Sends a DSR response for the current color scheme to the pty.
// ThreadData is the data created and stored in the termio thread
// when the thread is started and destroyed when the thread is
// stopped.
//
// All of the fields in this struct should only be read/written by
// the termio thread. As such, a lock is not necessary.
// Allocator used for the event data
// The event loop associated with this thread. This is owned by
// the Thread but we have a pointer so we can queue new work to it.
// The shared render state
// Mailboxes for different threads
// Data associated with the backend implementation (i.e. pty/exec state)
//
// --- Original Ghostty Comments End: src/termio/Termio.zig


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
