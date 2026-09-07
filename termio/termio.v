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

import apprt
import configpkg
import crash
import datastruct
import internal_os
import kitty
import os
import pty
import renderer
import sync
import terminal
import time

const log_tag_termio = 'io_exec'

// Termio manages terminal IO between the surface and the pty.
//
// This maintains the terminal state, pty, subprocess, etc. It parses the
// stream of bytes from the child process, dispatches the resulting events
// to the stream handler which mutates terminal state, and coordinates with
// the renderer and surface via mailboxes.
pub struct Termio {
pub mut:
	// The derived configuration for this termio implementation.
	config DerivedConfig

	// The terminal emulator internal state. This is the abstract "terminal"
	// that manages input, grid updating, etc. and is renderer-agnostic.
	terminal terminal.Terminal

	// The shared render state.
	renderer_state &renderer.State = unsafe { nil }

	// A handle to wake up the renderer.
	renderer_wakeup renderer.Wakeup

	// The mailbox for notifying the renderer of things.
	renderer_mailbox &renderer.Mailbox = unsafe { nil }

	// The mailbox for communicating with the surface.
	surface_mailbox apprt.SurfaceMailbox

	// The cached size info.
	size renderer.Size

	// The mailbox implementation to use.
	mailbox Mailbox

	// The stream parser. This parses the stream of escape codes and so on
	// from the child process and collects events which are then dispatched
	// to the stream handler.
	terminal_stream terminal.Stream

	// The stream handler. This mutates terminal state and sends messages
	// to the renderer/surface/termio mailboxes in response to stream events.
	stream_handler StreamHandler

	// The backend implementation responsible for io (i.e. the pty/exec state).
	backend Exec

	// Last time the cursor was reset (monotonic nanoseconds). This is used
	// to prevent message flooding with cursor resets. -1 means never.
	last_cursor_reset i64 = -1

	// Startup-only input, cloned and escape-decoded from the full config.
	// This is discarded after the one allowed subprocess start attempt.
	thread_enter_input []configpkg.ReadableIO
}

pub fn (mut t Termio) init(opts TermioOpts) ! {
	size := opts.size
	grid := size.grid()
	mut term := terminal.Terminal.init(terminal.Options{
		cols: u16(grid.columns)
		rows: u16(grid.rows)
		max_scrollback: opts.max_scrollback
		colors: terminal.Colors{
			background: terminal.DynamicRGB.init(opts.config.background)
			foreground: terminal.DynamicRGB.init(opts.config.foreground)
			cursor: if cursor := opts.config.cursor_color {
				terminal.DynamicRGB.init(cursor)
			} else {
				terminal.dynamic_rgb_unset
			}
			palette: opts.config.palette
		}
	})!
	term.modes.set(.grapheme_cluster, opts.grapheme_cluster)
	term.modes.set(.cursor_blinking, opts.config.cursor_blink or { true })
	term.modes.default = term.modes.values
	term.screens.active.cursor.cursor_style = opts.config.cursor_style
	term.width_px = grid.columns * size.cell.width
	term.height_px = grid.rows * size.cell.height
	term.kitty_image_limit = usize(opts.config.image_storage_limit)

	mut backend := Exec.init(opts.backend_config)!
	backend.init_terminal(mut term)

	mut renderer_state := opts.renderer_state
	if renderer_state == unsafe { nil } {
		renderer_state = &renderer.State{
			mutex: sync.new_mutex()
		}
	} else if renderer_state.mutex == unsafe { nil } {
		renderer_state.mutex = sync.new_mutex()
	}
	mut renderer_mailbox := opts.renderer_mailbox
	if renderer_mailbox == unsafe { nil } {
		renderer_mailbox = renderer.RendererMailbox.create()
	}

	t.config = opts.config
	t.terminal = term
	t.renderer_state = renderer_state
	t.renderer_wakeup = opts.renderer_wakeup
	t.renderer_mailbox = renderer_mailbox
	t.surface_mailbox = opts.surface_mailbox
	t.size = size
	t.mailbox = Mailbox.init()!
	t.terminal_stream = terminal.Stream.init()
	t.backend = backend
	if opts.full_config != unsafe { nil } && opts.full_config.input.items.len > 0 {
		t.thread_enter_input = opts.full_config.input.clone_parsed()!.items
	} else {
		t.thread_enter_input = []
	}
	t.renderer_state.terminal_ = &t.terminal
	t.stream_handler = StreamHandler{
		size: &t.size
		terminal: &t.terminal
		termio_mailbox: &t.mailbox
		surface_mailbox: t.surface_mailbox
		renderer_state: t.renderer_state
		renderer_wakeup: t.renderer_wakeup
		renderer_mailbox: t.renderer_mailbox
		osc_color_report_format: t.config.osc_color_report_format
		clipboard_write: t.config.clipboard_write
		enquiry_response: t.config.enquiry_response
		default_cursor_style: t.config.cursor_style
		default_cursor_blink: t.config.cursor_blink
	}
}

pub fn (mut t Termio) deinit() {
	t.backend.deinit()
	kitty.deinit_terminal_storage(mut t.terminal)
	t.terminal.deinit()
	t.config.deinit()
	t.mailbox.deinit()
	t.terminal_stream.deinit()
	t.stream_handler.deinit()
	t.thread_enter_input = []
}

// Send a message to the mailbox. Depending on the mailbox type in use this
// may process now or it may just enqueue and process later. This will also
// notify the mailbox thread to process the message.
pub fn (mut t Termio) queue_message(msg Message, mutex_state MutexState) {
	match mutex_state {
		.locked {
			t.mailbox.send(msg, t.renderer_state.mutex)
		}
		.unlocked {
			t.mailbox.send(msg, unsafe { nil })
		}
	}
	t.mailbox.notify()
}

// Queue a write directly to the pty. If linefeed is true, carriage returns
// are converted to CRLF.
pub fn (mut t Termio) queue_write(data []u8, linefeed bool) ! {
	t.backend.queue_write(data, linefeed)!
}

pub struct TermioOpts {
pub:
	config           DerivedConfig
	full_config      &configpkg.Config = unsafe { nil }
	size             renderer.Size
	max_scrollback   int = 10_000_000
	grapheme_cluster bool = true
	backend_config   ExecConfig
	renderer_state   &renderer.State = unsafe { nil }
	renderer_wakeup  renderer.Wakeup
	renderer_mailbox &renderer.Mailbox = unsafe { nil }
	surface_mailbox  apprt.SurfaceMailbox
}

// DerivedConfig holds configuration derived from the main config
// that the stream handler needs.
pub struct DerivedConfig {
pub mut:
	osc_color_report_format OSCColorReportFormat = .bits_16
	clipboard_write         ClipboardAccess = .allow
	enquiry_response        string
	cursor_style            terminal.CursorStyle = .block
	cursor_blink            ?bool

	// The default 256-color palette.
	palette terminal.DynamicPalette = terminal.dynamic_palette_default_val

	// The default foreground/background colors and optional cursor color.
	foreground   terminal.RGB = terminal.RGB{ r: 0xff, g: 0xff, b: 0xff }
	background   terminal.RGB = terminal.RGB{ r: 0x28, g: 0x2c, b: 0x34 }
	cursor_color ?terminal.RGB

	// The image storage limit in bytes.
	image_storage_limit int

	// The conditional state, used for the color scheme (light/dark) report.
	conditional_state configpkg.ConditionalState
}

pub fn DerivedConfig.init(config &configpkg.Config) !DerivedConfig {
	mut palette := [256]terminal.RGB{}
	for i, color in config.palette.value {
		palette[i] = terminal.RGB{ r: color.r, g: color.g, b: color.b }
	}
	return DerivedConfig{
		palette: terminal.DynamicPalette.init(palette)
		foreground: terminal.RGB{
			r: config.foreground.r
			g: config.foreground.g
			b: config.foreground.b
		}
		background: terminal.RGB{
			r: config.background.r
			g: config.background.g
			b: config.background.b
		}
		cursor_color: if cursor_color := config.cursor_color {
			if cursor_color.kind == .color {
				terminal.RGB{
					r: cursor_color.color.r
					g: cursor_color.color.g
					b: cursor_color.color.b
				}
			} else {
				none
			}
		} else {
			none
		}
		image_storage_limit: int(config.image_storage_limit)
		cursor_style: match config.cursor_style {
			.block { .block }
			.bar { .bar }
			.underline { .underline }
			.block_hollow { .block_hollow }
		}
		cursor_blink: config.cursor_style_blink
		osc_color_report_format: match config.osc_color_report_format {
			.none_ { .none_ }
			.format_8_bit { .bits_8 }
			.format_16_bit { .bits_16 }
		}
		clipboard_write: match config.clipboard_write {
			.allow { .allow }
			.ask { .ask }
			.deny { .deny }
		}
		enquiry_response: config.enquiry_response.clone()
		conditional_state: config.conditional_state
	}
}

pub fn (d DerivedConfig) deinit() {}

// ============================================================
// Termio methods (translated from Termio.zig)
// ============================================================

// thread_enter is called when the IO thread starts. It sets up the backend
// (starting the subprocess and read thread). The backend needs a pointer to
// this Termio so its read thread can forward pty data to process_output.
pub fn (mut t Termio) thread_enter() ! {
	defer {
		// Exec only starts once, so startup input is never retained afterward.
		t.thread_enter_input = []
	}

	// Open every configured path before starting the command. If any source is
	// missing, no subprocess starts and therefore none of the input is sent.
	mut inputs := t.prepare_initial_input()!
	defer {
		close_prepared_inputs(mut inputs)
	}

	// Setup our backend. The backend's read thread will feed process_output.
	t.backend.thread_enter_io(t)!
	for mut item in inputs {
		data := match item.kind {
			.raw { item.data }
			.path {
				read_initial_input_file(mut item.file) or {
					t.backend.thread_exit()
					return error('input failed')
				}
			}
		}
		t.queue_write(data, false) or {
			t.backend.thread_exit()
			return error('input failed')
		}
	}
}

const initial_input_max_bytes = 10 * 1024 * 1024

struct PreparedInput {
	kind ReadableInputKind
	data []u8
mut:
	file os.File
}

enum ReadableInputKind {
	raw
	path
}

fn (t &Termio) prepare_initial_input() ![]PreparedInput {
	mut result := []PreparedInput{cap: t.thread_enter_input.len}
	for item in t.thread_enter_input {
		match item.kind {
			.raw {
				result << PreparedInput{
					kind: .raw
					data: item.value.bytes()
				}
			}
			.path {
				file := os.open(item.value) or {
					close_prepared_inputs(mut result)
					return error('input not found')
				}
				result << PreparedInput{
					kind: .path
					file: file
				}
			}
		}
	}
	return result
}

fn read_initial_input_file(mut file os.File) ![]u8 {
	mut data := []u8{len: initial_input_max_bytes + 1}
	mut total := 0
	for total < data.len {
		read := file.read_from(u64(total), mut data[total..]) or {
			if err is os.Eof {
				break
			}
			return err
		}
		if read == 0 {
			break
		}
		total += read
	}
	if total > initial_input_max_bytes {
		return error('input failed')
	}
	data.trim(total)
	return data
}

fn close_prepared_inputs(mut inputs []PreparedInput) {
	for mut item in inputs {
		if item.kind == .path {
			item.file.close()
		}
	}
}

// thread_exit is called when the IO thread exits.
pub fn (mut t Termio) thread_exit() {
	t.backend.thread_exit()
}

// change_config updates the configuration.
pub fn (mut t Termio) change_config(config &DerivedConfig) ! {
	// The remainder of this function is modifying terminal state or the read
	// thread data, all of which requires holding the renderer state lock.
	t.renderer_state.mutex.lock()
	defer {
		t.renderer_state.mutex.unlock()
	}

	// Deinit our old config. We do this in the lock because the stream
	// handler may be referencing the old config (i.e. enquiry resp).
	t.config.deinit()
	t.config = *config

	// Update our stream handler. The stream handler uses the same renderer
	// mutex so this is safe to do despite being executed from another thread.
	t.stream_handler.change_config(&t.config)
	t.backend.thread_data.change_config(&t.config)

	// Update the configuration that we know about.
	//
	// Specific things we don't update:
	//   - command, working-directory: we never restart the underlying
	//     process so we don't care or need to know about these.

	// Update the default palette.
	t.terminal.colors.palette.change_default(config.palette.entries)
	t.terminal.flags.dirty.palette = true

	// Update all our other colors.
	t.terminal.colors.background.default_color = config.background
	t.terminal.colors.foreground.default_color = config.foreground
	t.terminal.colors.cursor.default_color = config.cursor_color

	// Set image limits on both existing screens; future alternate screens use
	// Terminal.kitty_image_limit when their storage is first materialized.
	kitty.set_terminal_storage_limit(mut t.terminal, usize(config.image_storage_limit))
}

// resize resizes the terminal.
pub fn (mut t Termio) resize(size renderer.Size) ! {
	t.size = size
	grid_size := size.grid()

	// Update the size of our pty.
	t.backend.resize(grid_size, size.terminal_size())!

	// Enter the critical area that we want to keep small.
	{
		t.renderer_state.mutex.lock()
		defer {
			t.renderer_state.mutex.unlock()
		}

		// Update the size of our terminal state.
		t.terminal.resize(u16(grid_size.columns), u16(grid_size.rows))!

		// Update our pixel sizes.
		t.terminal.width_px = grid_size.columns * t.size.cell.width
		t.terminal.height_px = grid_size.rows * t.size.cell.height

		// Disable synchronized output mode so that we show changes
		// immediately for a resize. This is allowed by the spec.
		t.terminal.modes.set(.synchronized_output, false)

		// If we have size reporting enabled we need to send a report.
		if t.terminal.modes.get(.in_band_size_reports) {
			t.size_report_locked(.mode_2048)!
		}
	}

	// Mail the renderer so that it can update the GPU and re-render.
	t.renderer_mailbox.push(renderer.RendererMessage(renderer.ResizeMessage{
		size: t.size
	}))
	t.renderer_wakeup.notify() or {}
}

// size_report makes a size report of the given style.
pub fn (mut t Termio) size_report(style SizeReportKind) ! {
	t.renderer_state.mutex.lock()
	defer {
		t.renderer_state.mutex.unlock()
	}
	t.size_report_locked(style)!
}

fn (mut t Termio) size_report_locked(style SizeReportKind) ! {
	grid_size := t.size.grid()

	// Build the size report message. Reports in columns and pixels.
	message := match style {
		.mode_2048 {
			'\x1b[48;${grid_size.rows};${grid_size.columns};${grid_size.rows * t.size.cell.height};${grid_size.columns * t.size.cell.width}t'
		}
		.csi_14_t {
			'\x1b[4;${grid_size.rows * t.size.cell.height};${grid_size.columns * t.size.cell.width}t'
		}
		.csi_16_t {
			'\x1b[6;${t.size.cell.height};${t.size.cell.width}t'
		}
		.csi_18_t {
			'\x1b[8;${grid_size.rows};${grid_size.columns}t'
		}
	}

	t.queue_write(message.bytes(), false)!
}

// reset_synchronized_output resets the synchronized output mode. This is
// usually called by timer expiration from the termio thread.
pub fn (mut t Termio) reset_synchronized_output() {
	t.renderer_state.mutex.lock()
	defer {
		t.renderer_state.mutex.unlock()
	}
	t.terminal.modes.set(.synchronized_output, false)
	t.renderer_wakeup.notify() or {}
}

// clear_screen clears the screen. If history is true, the scrollback is
// also cleared.
pub fn (mut t Termio) clear_screen(history bool) ! {
	{
		t.renderer_state.mutex.lock()
		defer {
			t.renderer_state.mutex.unlock()
		}

		// If we're on the alternate screen, we do not clear. Since this is
		// an emulator-level screen clear, this messes up the running
		// program's knowledge of where the cursor is and causes rendering
		// issues. So, for alt screen, we do nothing.
		if t.terminal.screens.active_key == .alternate {
			return
		}

		// Clear our selection.
		t.terminal.screens.active.clear_selection()

		// Clear our scrollback.
		if history {
			t.terminal.erase_display(.scrollback, false)
		}

		// If we're not at a prompt, we just delete above the cursor.
		if !t.terminal.cursor_is_at_prompt() {
			if t.terminal.screens.active.cursor.y > 0 {
				t.terminal.screens.active.erase_rows(terminal.Point.new(.active, terminal.Coordinate{}), terminal.Point.new(.active, terminal.Coordinate{
					y: t.terminal.screens.active.cursor.y - 1
				}))
			}
			kitty.clear_active_images(mut t.terminal)
			return
		}

		// At a prompt, we want to first fully clear the screen, and then
		// after send a FF (0x0C) to the shell so that it can repaint the
		// screen.
		t.terminal.erase_display(.complete, false)
	}

	// If we reached here it means we're at a prompt, so we send a form-feed.
	t.queue_write([u8(0x0C)], false)!
}

// scroll_viewport scrolls the viewport.
pub fn (mut t Termio) scroll_viewport(behavior terminal.ScrollViewport, delta int) ! {
	t.renderer_state.mutex.lock()
	defer {
		t.renderer_state.mutex.unlock()
	}
	t.terminal.scroll_viewport(behavior, delta)!
}

// jump_to_prompt jumps the viewport to the prompt.
pub fn (mut t Termio) jump_to_prompt(delta int) ! {
	{
		t.renderer_state.mutex.lock()
		defer {
			t.renderer_state.mutex.unlock()
		}
		t.terminal.screens.active.scroll_delta_prompts(delta)
	}

	t.renderer_wakeup.notify()!
}

// focus_gained is called when focus is gained or lost (when focus events
// are enabled).
pub fn (mut t Termio) focus_gained(focused bool) ! {
	t.renderer_state.mutex.lock()
	focus_event := t.terminal.modes.get(.focus_event)
	t.renderer_state.mutex.unlock()

	// If we have focus events enabled, we send the focus event.
	if focus_event {
		seq := if focused { '\x1b[I' } else { '\x1b[O' }
		t.queue_write(seq.bytes(), false)!
	}

	// We always notify our backend of focus changes.
	t.backend.focus_gained(focused)!
}

// process_output processes output from the pty. This is the manual API that
// users can call with pty data but it is also called by the read thread when
// using an exec subprocess.
pub fn (mut t Termio) process_output(buf []u8) {
	// We are modifying terminal state from here on out and we need the lock
	// to grab our read data.
	t.renderer_state.mutex.lock()
	defer {
		t.renderer_state.mutex.unlock()
	}
	t.process_output_locked(buf)
}

// process_output_locked processes output from readdata but the lock is
// already held.
fn (mut t Termio) process_output_locked(buf []u8) {
	// Schedule a render. We can call this first because we have the lock.
	t.stream_handler.queue_render() or {}

	// Whenever a character is typed, we ensure the cursor is in the
	// non-blink state so it is rendered if visible. If we're under HEAVY
	// read load, we don't want to send a ton of these so we use a timer
	// under the covers (500ms throttle).
	now := i64(time.sys_mono_now())
	if t.last_cursor_reset < 0 || (now - t.last_cursor_reset) > (500 * i64(time.millisecond)) {
		t.last_cursor_reset = now
		t.renderer_mailbox.push(renderer.RendererMessage(renderer.ResetCursorBlinkMessage{}))
	}

	// If the inspector is active, use Ghostty's slow path: process a byte at a
	// time, record each raw action with pre-dispatch terminal state, and then
	// apply the semantic actions. Normal operation retains the bulk fast path.
	if !isnil(t.renderer_state.inspector) {
		for byte in buf {
			t.renderer_state.record_inspector_pty_byte(byte)
			t.terminal_stream.next(byte)
			for event in t.terminal_stream.events {
				t.stream_handler.vt(event)
			}
			t.terminal_stream.clear_events()
		}
	} else {
		t.terminal_stream.next_slice(buf)
		for event in t.terminal_stream.events {
			t.stream_handler.vt(event)
		}
		t.terminal_stream.clear_events()
	}

	// If our stream handling caused messages to be sent to the mailbox
	// thread, then we need to wake it up so that it processes them.
	if t.stream_handler.termio_messaged {
		t.stream_handler.termio_messaged = false
		t.mailbox.notify()
	}
}

// color_scheme_report sends a DSR response for the current color scheme to
// the pty.
pub fn (mut t Termio) color_scheme_report(force bool) ! {
	t.renderer_state.mutex.lock()
	defer {
		t.renderer_state.mutex.unlock()
	}
	t.color_scheme_report_locked(force)!
}

fn (mut t Termio) color_scheme_report_locked(force bool) ! {
	if !force && !t.terminal.modes.get(.report_color_scheme) {
		return
	}
	output := match t.config.conditional_state.theme {
		.light { '\x1b[?997;2n' }
		.dark { '\x1b[?997;1n' }
	}
	t.queue_write(output.bytes(), false)!
}

// ThreadData is the data created and stored in the termio thread when the
// thread is started and destroyed when the thread is stopped.
//
// All of the fields in this struct should only be read/written by the termio
// thread. As such, a lock is not necessary.
pub struct ThreadData {
pub mut:
	// The shared render state.
	renderer_state &renderer.State = unsafe { nil }

	// Mailbox for the surface.
	surface_mailbox apprt.SurfaceMailbox

	// The termio mailbox.
	mailbox &Mailbox = unsafe { nil }
}

pub fn (mut self ThreadData) deinit() {}

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
	// Thread-local flags mirrored from Ghostty's writer thread.
	linefeed_mode bool
	has_inspector bool
	drain         bool
	scroll_active bool
	// Timer/coalescing state. Deadlines use time.sys_mono_now nanoseconds.
	pending_resize  ?renderer.Size
	resize_deadline i64
	sync_deadline   i64
	scroll_deadline i64
}

pub fn Thread.init() !Thread {
	return Thread{
		stop: Stopwatch.init()
	}
}

pub fn (mut t Thread) deinit() {
	t.stop.deinit()
}

// thread_main is the writer-thread entry point. Ghostty drives the same state
// machine with libxev; V's implementation uses a short monotonic polling wait
// so mailbox and timer behavior remains identical without tying Termio to a
// particular event-loop implementation.
pub fn (mut t Thread) thread_main(mut io Termio) {
	$if macos {
		internal_os.set_thread_name('io')
	}

	crash.set_thread_state(crash.ThreadState{
		kind: .io
		surface: io.surface_mailbox.surface
	})
	defer {
		crash.clear_thread_state()
	}

	io.thread_enter() or {
		t.show_start_error(mut io, err.msg())
		t.drain = true
	}
	defer {
		if !t.drain {
			io.thread_exit()
		}
	}

	for !t.stop.is_notified() {
		mut did_work := t.drain_mailbox(mut io)
		if t.run_timers(mut io, i64(time.sys_mono_now())) {
			did_work = true
		}

		if !did_work {
			time.sleep(time.millisecond)
		}
	}

	// Match the abnormal-exit behavior: after startup failure, continue
	// accepting and discarding messages until the owner requests shutdown.
	if t.drain {
		for io.mailbox.pop() != none {
		}
	}
}

// Run callbacks whose deadlines have expired. This is the polling-loop
// equivalent of Ghostty's libxev timer callbacks.
fn (mut t Thread) run_timers(mut io Termio, now i64) bool {
	mut did_work := false
	if resize := t.pending_resize {
		if now >= t.resize_deadline {
			io.resize(resize) or {}
			t.pending_resize = none
			t.resize_deadline = 0
			did_work = true
		}
	}
	if t.sync_deadline > 0 && now >= t.sync_deadline {
		io.reset_synchronized_output()
		t.sync_deadline = 0
		did_work = true
	}
	if t.scroll_deadline > 0 && now >= t.scroll_deadline {
		// A stopped timer still completes once and reports false. The surface
		// uses that final callback to stop selection scrolling immediately.
		io.surface_mailbox.push(apprt.SurfaceMessage{
			kind: .selection_scroll_tick
			selection_scroll_tick: t.scroll_active
		})
		if t.scroll_active {
			t.scroll_deadline = now + 15 * i64(time.millisecond)
		} else {
			t.scroll_deadline = 0
		}
		did_work = true
	}
	if t.run_termios_timer(mut io, now) {
		did_work = true
	}
	return did_work
}

// Poll the pty mode while the surface is focused. Canonical input with echo
// disabled is Ghostty's password-entry heuristic; mode transitions are sent
// to the surface so it can disable unsafe conveniences while a password is
// being entered.
fn (mut t Thread) run_termios_timer(mut io Termio, now i64) bool {
	deadline := io.backend.thread_data.termios_deadline
	if deadline <= 0 || now < deadline {
		return false
	}
	io.backend.thread_data.termios_deadline = 0

	$if !windows {
		// The read descriptor is the pty master. Rebuild the lightweight Pty
		// view exactly as Ghostty does so polling remains valid for the full
		// backend-thread lifetime.
		mode := pty.Pty{ master: io.backend.thread_data.read_thread_fd }.get_mode() or {
			pty.Mode{}
		}
		t.apply_termios_mode(mut io, mode)
	}

	if io.backend.thread_data.termios_timer_running {
		io.backend.thread_data.termios_deadline = now + termios_poll_ms * i64(time.millisecond)
	}
	return true
}

fn (mut t Thread) apply_termios_mode(mut io Termio, mode pty.Mode) {
	if mode == io.backend.thread_data.termios_mode {
		return
	}
	io.backend.thread_data.termios_mode = mode
	password_input := mode.canonical && !mode.echo

	io.renderer_state.mutex.lock()
	unchanged := io.terminal.flags.password_input == password_input
	io.renderer_state.mutex.unlock()
	if unchanged {
		return
	}

	io.surface_mailbox.push(apprt.SurfaceMessage{
		kind: .password_input
		password_input: password_input
	})
}

// drain_mailbox dispatches every currently queued writer message. Returning
// true tells the caller that a renderer wakeup was requested.
fn (mut t Thread) drain_mailbox(mut io Termio) bool {
	mut redraw := false
	for {
		msg := io.mailbox.pop() or { break }
		if t.drain {
			continue
		}
		redraw = true
		match msg.kind {
			.color_scheme_report { io.color_scheme_report(msg.force_val) or {} }
			.crash { panic('crash request, crashing intentionally') }
			.change_config { io.change_config(&msg.config_val) or {} }
			.inspector {
				t.has_inspector = msg.flag_val
			}
			.resize {
				t.pending_resize = msg.resize_val
				if t.resize_deadline == 0 {
					t.resize_deadline = i64(time.sys_mono_now()) + 25 * i64(time.millisecond)
				}
			}
			.size_report { io.size_report(msg.size_report_val) or {} }
			.clear_screen { io.clear_screen(msg.flag_val) or {} }
			.scroll_viewport {
				io.scroll_viewport(msg.scroll_behavior, msg.scroll_delta) or {}
			}
			.selection_scroll {
				if msg.flag_val {
					t.scroll_active = true
					// An already armed timer is not restarted.
					if t.scroll_deadline == 0 {
						t.scroll_deadline = i64(time.sys_mono_now()) + 15 * i64(time.millisecond)
					}
				} else {
					// stopScrollTimer only changes the active flag. The armed
					// callback is allowed to fire once with a false value.
					t.scroll_active = false
				}
			}
			.jump_to_prompt { io.jump_to_prompt(msg.prompt_delta) or {} }
			.start_synchronized_output {
				t.sync_deadline = i64(time.sys_mono_now()) + 1000 * i64(time.millisecond)
			}
			.linefeed_mode {
				t.linefeed_mode = msg.flag_val
			}
			.focused { io.focus_gained(msg.flag_val) or {} }
			.write_small { io.queue_write(msg.write_small_data.slice(), t.linefeed_mode) or {} }
			.write_stable { io.queue_write(msg.write_stable_data.bytes(), t.linefeed_mode) or {} }
			.write_alloc { io.queue_write(msg.write_alloc_data.bytes(), t.linefeed_mode) or {} }
		}
	}
	if redraw {
		io.renderer_wakeup.notify() or {}
	}
	return redraw
}

fn (t &Thread) show_start_error(mut io Termio, message string) {
	io.renderer_state.mutex.lock()
	defer { io.renderer_state.mutex.unlock() }
	io.terminal.modes.set(.cursor_visible, false)
	io.terminal.erase_display(.complete, false)
	text := match message {
		'openpty failed' {
			'Your system cannot allocate any more pty devices.\n\nGhostty requires a pty device to launch a new terminal.\nThis error is usually due to having too many terminal\nwindows open or having another program that is using too\nmany pty devices.\n\nPlease free up some pty devices and try again.'
		}
		'input not found', 'input failed' {
			'A configured `input` path was not found, was not readable,\nwas too large, or the underlying pty failed to accept\nthe write.\n\nGhostty can\'t continue since it can\'t guarantee that\ninitial terminal state will be as desired. Please review\nthe value of `input` in your configuration file and\nensure that all the path values exist and are readable.'
		}
		else {
			'error starting IO thread: ${message}\n\nThe underlying shell or command was unable to be started.\nThis error is usually due to exhausting a system resource.\nIf this looks like a bug, please report it.\n\nThis terminal is non-functional. Please close it and try again.'
		}
	}
	io.terminal.print_string(text) or {}
}

// Stopwatch is a cross-thread wakeup/stop signal. In ghostty this is backed
// by an xev.Async which lets one thread notify another's event loop. Here we
// model the notification state directly: notify() records that a signal was
// raised so the consuming thread can observe it.
pub struct Stopwatch {
pub mut:
	// Whether a notification has been raised on this stopwatch.
	notified bool
	mutex    &sync.Mutex = unsafe { nil }
}

pub fn Stopwatch.init() Stopwatch {
	return Stopwatch{
		mutex: sync.new_mutex()
	}
}

fn (mut s Stopwatch) ensure_mutex() &sync.Mutex {
	if s.mutex == unsafe { nil } {
		s.mutex = sync.new_mutex()
	}
	return s.mutex
}

// notify raises the wakeup/stop signal. In ghostty this wakes the target
// event loop; here we record that the signal was raised.
pub fn (mut s Stopwatch) notify() ! {
	mtx := s.ensure_mutex()
	mtx.lock()
	defer { mtx.unlock() }
	s.notified = true
}

pub fn (mut s Stopwatch) is_notified() bool {
	mtx := s.ensure_mutex()
	mtx.lock()
	defer { mtx.unlock() }
	return s.notified
}

// reset clears the notification state.
pub fn (mut s Stopwatch) reset() {
	mtx := s.ensure_mutex()
	mtx.lock()
	defer { mtx.unlock() }
	s.notified = false
}

pub fn (mut s Stopwatch) deinit() {
	if s.mutex != unsafe { nil } {
		s.mutex.destroy()
		s.mutex = unsafe { nil }
	}
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
	resize_val        renderer.Size
	config_val        DerivedConfig
	scroll_behavior   terminal.ScrollViewport
	scroll_delta      int
	prompt_delta      int
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
	start_synchronized_output
	linefeed_mode
	size_report
	clear_screen
	scroll_viewport
	jump_to_prompt
	crash
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
	data [38]u8
	len  u8
}

pub fn WriteSmall.from_slice(s []u8) WriteSmall {
	mut w := WriteSmall{}
	length := if s.len < 38 { u8(s.len) } else { u8(38) }
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
	if data.len <= 38 {
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
	length := if data.len < 38 { u8(data.len) } else { u8(38) }
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

pub fn Message.resize_msg(size renderer.Size) Message {
	return Message{
		kind: .resize
		resize_val: size
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

pub fn Message.change_config_msg(cfg &DerivedConfig) Message {
	return Message{
		kind: .change_config
		config_val: *cfg
	}
}

pub fn Message.clear_screen_msg(history bool) Message {
	return Message{
		kind: .clear_screen
		flag_val: history
	}
}

pub fn Message.scroll_viewport_msg(behavior terminal.ScrollViewport, delta int) Message {
	return Message{
		kind: .scroll_viewport
		scroll_behavior: behavior
		scroll_delta: delta
	}
}

pub fn Message.jump_to_prompt_msg(delta int) Message {
	return Message{
		kind: .jump_to_prompt
		prompt_delta: delta
	}
}

pub enum MutexState {
	locked
	unlocked
}

// mailbox_capacity is the number of messages the mailbox can hold. Ghostty
// uses a BlockingQueue with a capacity of 64 that empirically makes sense for
// Ghostty usage.
const mailbox_capacity = 64

// Mailbox is the queue used for storing messages that is periodically drained.
// Typically used by a multi-threaded application (the surface/stream handler
// producer side and the termio thread consumer side).
//
// This is a translation of ghostty's termio.Mailbox, which wraps a
// BlockingQueue(termio.Message, 64) plus a wakeup async. The queue is a bounded
// SPSC ring buffer; here we model it with an inline fixed-size ring buffer so
// that a zero-valued Mailbox{} is immediately usable.
pub struct Mailbox {
mut:
	queue &datastruct.BlockingQueue[Message] = unsafe { nil }
	// Whether the wakeup signal has been raised for the consuming thread.
	notified bool
}

// init creates a mailbox. The underlying mutex is allocated here.
pub fn Mailbox.init() !Mailbox {
	return Mailbox{
		queue: datastruct.BlockingQueue.create[Message](mailbox_capacity)!
	}
}

pub fn (mut m Mailbox) deinit() {
	if m.queue != unsafe { nil } {
		m.queue.destroy()
		m.queue = unsafe { nil }
	}
}

// ensure_queue lazily allocates the queue so a zero-valued Mailbox{}
// (e.g. an embedded field that wasn't built via Mailbox.init) is usable.
fn (mut m Mailbox) ensure_queue() &datastruct.BlockingQueue[Message] {
	if m.queue == unsafe { nil } {
		m.queue = datastruct.BlockingQueue.create[Message](mailbox_capacity) or {
			panic(err)
		}
	}
	return m.queue
}

// len returns the number of unread messages in the mailbox.
pub fn (mut m Mailbox) len() int {
	mut queue := m.ensure_queue()
	return queue.len()
}

// send pushes the given message without notifying that there are messages.
//
// If the optional mutex is given, it must already be LOCKED. If the send would
// block (the queue is full), we raise the wakeup, unlock this mutex so the
// consuming thread can drain, retry the push, and lock it again. This handles
// the edge case where the queue is full.
pub fn (mut m Mailbox) send(msg Message, mtx &sync.Mutex) {
	// Try to write to the queue. This is the fast path because we can queue
	// without unlocking the renderer state.
	mut queue := m.ensure_queue()
	if queue.push(msg, datastruct.blocking_queue_instant) > 0 {
		return
	}

	// If we reach here, the queue is full. Wake up the writer thread so that it
	// can process messages to clear up space. However, the writer thread may
	// require the renderer lock so we need to unlock.
	m.notify()

	// Unlock the renderer state (if provided) so the writer thread can acquire
	// it, then retry queueing our message before continuing. This is a very
	// slow path that only triggers in pathological cases.
	if mtx != unsafe { nil } {
		mtx.unlock()
	}
	defer {
		if mtx != unsafe { nil } {
			mtx.lock()
		}
	}
	_ = queue.push(msg, datastruct.blocking_queue_forever)
}

// push attempts to push a message onto the queue without blocking. Returns the
// number of items pushed (1 on success, 0 if the queue is full).
pub fn (mut m Mailbox) push(msg Message) int {
	mut queue := m.ensure_queue()
	return if queue.push(msg, datastruct.blocking_queue_instant) > 0 { 1 } else { 0 }
}

// pop removes and returns the next message from the queue without blocking.
// Returns none if the queue is empty.
pub fn (mut m Mailbox) pop() ?Message {
	mut queue := m.ensure_queue()
	return queue.pop()
}

// notify wakes up the termio thread so it processes any queued messages. This
// records that a wakeup signal was raised. In ghostty this notifies the
// wakeup async tied to the consuming thread's event loop.
pub fn (mut m Mailbox) notify() {
	m.notified = true
}
