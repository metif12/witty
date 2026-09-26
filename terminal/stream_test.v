module terminal

import osc

// Tests for the Stream VT escape sequence processor.
// Translated from Ghostty's src/terminal/stream.zig test suite. Each source
// test declares its own handler struct `H`; V has no function-local types,
// so each one is declared right before its test.

struct StreamPrintH {
mut:
	c ?u32 = 0
}

pub fn (mut self StreamPrintH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.print {
			if value is ActionPrint {
				self.c = value.cp
			}
		}
		else {}
	}
}

pub fn (mut self StreamPrintH) deinit() {}

fn test_stream_print() ! {
	mut s := Stream.init[StreamPrintH](StreamPrintH{})
	s.next(`x`)!
	assert s.handler.c? == u32(`x`)
}

struct SimdPrintInvalidUtf8H {
mut:
	c ?u32 = 0
}

pub fn (mut self SimdPrintInvalidUtf8H) vt(action ActionKey, value ActionValue) ! {
	match action {
		.print {
			if value is ActionPrint {
				self.c = value.cp
			}
		}
		else {}
	}
}

pub fn (mut self SimdPrintInvalidUtf8H) deinit() {}

fn test_simd_print_invalid_utf_8() ! {
	mut s := Stream.init[SimdPrintInvalidUtf8H](SimdPrintInvalidUtf8H{})
	s.next_slice([u8(0xFF)])!
	assert s.handler.c? == u32(0xFFFD)
}

struct SimdCompleteIncompleteUtf8H {
mut:
	c ?u32
}

pub fn (mut self SimdCompleteIncompleteUtf8H) vt(action ActionKey, value ActionValue) ! {
	match action {
		.print {
			if value is ActionPrint {
				self.c = value.cp
			}
		}
		else {}
	}
}

pub fn (mut self SimdCompleteIncompleteUtf8H) deinit() {}

fn test_simd_complete_incomplete_utf_8() ! {
	mut s := Stream.init[SimdCompleteIncompleteUtf8H](SimdCompleteIncompleteUtf8H{})
	s.next_slice([u8(0xE0)])! // 3 byte
	assert s.handler.c == none
	s.next_slice([u8(0xA0)])! // still incomplete
	assert s.handler.c == none
	s.next_slice([u8(0x80)])!
	assert s.handler.c? == u32(0x800)
}

struct StreamCursorRightH {
mut:
	amount u16
}

pub fn (mut self StreamCursorRightH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.cursor_right {
			if value is ActionCursorMovement {
				self.amount = value.value
			}
		}
		else {}
	}
}

pub fn (mut self StreamCursorRightH) deinit() {}

fn test_stream_cursor_right_cuf() ! {
	mut s := Stream.init[StreamCursorRightH](StreamCursorRightH{})
	s.next_slice('\x1b[C'.bytes())!
	assert s.handler.amount == u16(1)

	s.next_slice('\x1b[5C'.bytes())!
	assert s.handler.amount == u16(5)

	s.handler.amount = 0
	s.next_slice('\x1b[5;4C'.bytes())!
	assert s.handler.amount == u16(0)

	s.handler.amount = 0
	s.next_slice('\x1b[?3C'.bytes())!
	assert s.handler.amount == u16(0)
}

struct StreamDecSetModeH {
mut:
	mode Mode = unsafe { Mode(1) }
}

pub fn (mut self StreamDecSetModeH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.set_mode {
			if value is ActionMode {
				self.mode = value.mode
			}
		}
		.reset_mode {
			self.mode = unsafe { Mode(1) }
		}
		else {}
	}
}

pub fn (mut self StreamDecSetModeH) deinit() {}

fn test_stream_dec_set_mode_sm_and_reset_mode_rm() ! {
	mut s := Stream.init[StreamDecSetModeH](StreamDecSetModeH{})
	s.next_slice('\x1b[?6h'.bytes())!
	assert s.handler.mode == Mode.origin

	s.next_slice('\x1b[?6l'.bytes())!
	assert s.handler.mode == unsafe { Mode(1) }

	s.handler.mode = unsafe { Mode(1) }
	s.next_slice('\x1b[6 h'.bytes())!
	assert s.handler.mode == unsafe { Mode(1) }
}

struct StreamAnsiSetModeH {
mut:
	mode ?Mode
}

pub fn (mut self StreamAnsiSetModeH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.set_mode {
			if value is ActionMode {
				self.mode = value.mode
			}
		}
		.reset_mode {
			self.mode = none
		}
		else {}
	}
}

pub fn (mut self StreamAnsiSetModeH) deinit() {}

fn test_stream_ansi_set_mode_sm_and_reset_mode_rm() ! {
	mut s := Stream.init[StreamAnsiSetModeH](StreamAnsiSetModeH{})
	s.next_slice('\x1b[4h'.bytes())!
	assert s.handler.mode? == Mode.insert

	s.next_slice('\x1b[4l'.bytes())!
	assert s.handler.mode == none

	s.handler.mode = none
	s.next_slice('\x1b[>5h'.bytes())!
	assert s.handler.mode == none
}

struct StreamAnsiSetModeUnknownH {
mut:
	mode ?Mode
}

pub fn (mut self StreamAnsiSetModeUnknownH) set_mode(mode Mode, v bool) ! {
	self.mode = none
	if v {
		self.mode = mode
	}
}

pub fn (mut self StreamAnsiSetModeUnknownH) vt(action ActionKey, value ActionValue) ! {
}

pub fn (mut self StreamAnsiSetModeUnknownH) deinit() {}

fn test_stream_ansi_set_mode_sm_and_reset_mode_rm_with_unknown_value() ! {
	mut s := Stream.init[StreamAnsiSetModeUnknownH](StreamAnsiSetModeUnknownH{})
	s.next_slice('\x1b[6h'.bytes())!
	assert s.handler.mode == none

	s.next_slice('\x1b[6l'.bytes())!
	assert s.handler.mode == none
}

struct StreamRestoreModeH {
mut:
	called bool
}

pub fn (mut self StreamRestoreModeH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.top_and_bottom_margin {
			self.called = true
		}
		else {}
	}
}

pub fn (mut self StreamRestoreModeH) deinit() {}

fn test_stream_restore_mode() ! {
	mut s := Stream.init[StreamRestoreModeH](StreamRestoreModeH{})
	for c in '\x1b[?42r' {
		s.next(c)!
	}
	assert !s.handler.called
}

struct StreamPopKittyKeyboardH {
mut:
	n u16
}

pub fn (mut self StreamPopKittyKeyboardH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.kitty_keyboard_pop {
			if value is u16 {
				self.n = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamPopKittyKeyboardH) deinit() {}

fn test_stream_pop_kitty_keyboard_with_no_params_defaults_to_1() ! {
	mut s := Stream.init[StreamPopKittyKeyboardH](StreamPopKittyKeyboardH{})
	for c in '\x1b[<u' {
		s.next(c)!
	}
	assert s.handler.n == u16(1)
}

struct StreamDecscaH {
mut:
	v ?ProtectedMode
}

pub fn (mut self StreamDecscaH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.protected_mode_off {
			self.v = ProtectedMode.off
		}
		.protected_mode_iso {
			self.v = ProtectedMode.iso
		}
		.protected_mode_dec {
			self.v = ProtectedMode.dec
		}
		else {}
	}
}

pub fn (mut self StreamDecscaH) deinit() {}

fn test_stream_decsca() ! {
	mut s := Stream.init[StreamDecscaH](StreamDecscaH{})
	{
		for c in '\x1b["q' {
			s.next(c)!
		}
		assert s.handler.v? == ProtectedMode.off
	}
	{
		for c in '\x1b[0"q' {
			s.next(c)!
		}
		assert s.handler.v? == ProtectedMode.off
	}
	{
		for c in '\x1b[2"q' {
			s.next(c)!
		}
		assert s.handler.v? == ProtectedMode.off
	}
	{
		for c in '\x1b[1"q' {
			s.next(c)!
		}
		assert s.handler.v? == ProtectedMode.dec
	}
}

struct StreamDecedDecsedH {
mut:
	mode      ?EraseDisplay
	protected ?bool
}

pub fn (mut self StreamDecedDecsedH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.erase_display_below {
			self.mode = EraseDisplay.below
			if value is bool {
				self.protected = value
			}
		}
		.erase_display_above {
			self.mode = EraseDisplay.above
			if value is bool {
				self.protected = value
			}
		}
		.erase_display_complete {
			self.mode = EraseDisplay.complete
			if value is bool {
				self.protected = value
			}
		}
		.erase_display_scrollback {
			self.mode = EraseDisplay.scrollback
			if value is bool {
				self.protected = value
			}
		}
		.erase_display_scroll_complete {
			self.mode = EraseDisplay.scroll_complete
			if value is bool {
				self.protected = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamDecedDecsedH) deinit() {}

fn test_stream_deced_decsed() ! {
	mut s := Stream.init[StreamDecedDecsedH](StreamDecedDecsedH{})
	{
		for c in '\x1b[?J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.below
		assert s.handler.protected?
	}
	{
		for c in '\x1b[?0J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.below
		assert s.handler.protected?
	}
	{
		for c in '\x1b[?1J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.above
		assert s.handler.protected?
	}
	{
		for c in '\x1b[?2J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.complete
		assert s.handler.protected?
	}
	{
		for c in '\x1b[?3J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.scrollback
		assert s.handler.protected?
	}

	{
		for c in '\x1b[J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.below
		assert !s.handler.protected?
	}
	{
		for c in '\x1b[0J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.below
		assert !s.handler.protected?
	}
	{
		for c in '\x1b[1J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.above
		assert !s.handler.protected?
	}
	{
		for c in '\x1b[2J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.complete
		assert !s.handler.protected?
	}
	{
		for c in '\x1b[3J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.scrollback
		assert !s.handler.protected?
	}
	{
		// Invalid and ignored by the handler
		for c in '\x1b[>0J' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseDisplay.scrollback
		assert !s.handler.protected?
	}
}

struct StreamDecelDecselH {
mut:
	mode      ?EraseLine
	protected ?bool
}

pub fn (mut self StreamDecelDecselH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.erase_line_right {
			self.mode = EraseLine.right
			if value is bool {
				self.protected = value
			}
		}
		.erase_line_left {
			self.mode = EraseLine.left
			if value is bool {
				self.protected = value
			}
		}
		.erase_line_complete {
			self.mode = EraseLine.complete
			if value is bool {
				self.protected = value
			}
		}
		.erase_line_right_unless_pending_wrap {
			self.mode = EraseLine.right_unless_pending_wrap
			if value is bool {
				self.protected = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamDecelDecselH) deinit() {}

fn test_stream_decel_decsel() ! {
	mut s := Stream.init[StreamDecelDecselH](StreamDecelDecselH{})
	{
		for c in '\x1b[?K' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseLine.right
		assert s.handler.protected?
	}
	{
		for c in '\x1b[?0K' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseLine.right
		assert s.handler.protected?
	}
	{
		for c in '\x1b[?1K' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseLine.left
		assert s.handler.protected?
	}
	{
		for c in '\x1b[?2K' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseLine.complete
		assert s.handler.protected?
	}

	{
		for c in '\x1b[K' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseLine.right
		assert !s.handler.protected?
	}
	{
		for c in '\x1b[0K' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseLine.right
		assert !s.handler.protected?
	}
	{
		for c in '\x1b[1K' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseLine.left
		assert !s.handler.protected?
	}
	{
		for c in '\x1b[2K' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseLine.complete
		assert !s.handler.protected?
	}
	{
		// Invalid and ignored by the handler
		for c in '\x1b[<1K' {
			s.next(c)!
		}
		assert s.handler.mode? == EraseLine.complete
		assert !s.handler.protected?
	}
}

struct StreamDecscusrH {
mut:
	style ?AnsiCursorStyle
}

pub fn (mut self StreamDecscusrH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.cursor_style {
			if value is AnsiCursorStyle {
				self.style = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamDecscusrH) deinit() {}

fn test_stream_decscusr() ! {
	mut s := Stream.init[StreamDecscusrH](StreamDecscusrH{})
	s.next_slice('\x1b[ q'.bytes())!
	assert s.handler.style? == .default_

	s.next_slice('\x1b[1 q'.bytes())!
	assert s.handler.style? == .blinking_block

	// Invalid and ignored by the handler
	s.next_slice('\x1b[?0 q'.bytes())!
	assert s.handler.style? == .blinking_block
}

struct StreamDecscusrWithoutSpaceH {
mut:
	style ?AnsiCursorStyle
}

pub fn (mut self StreamDecscusrWithoutSpaceH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.cursor_style {
			if value is AnsiCursorStyle {
				self.style = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamDecscusrWithoutSpaceH) deinit() {}

fn test_stream_decscusr_without_space() ! {
	mut s := Stream.init[StreamDecscusrWithoutSpaceH](StreamDecscusrWithoutSpaceH{})
	s.next_slice('\x1b[q'.bytes())!
	assert s.handler.style == none

	s.next_slice('\x1b[1q'.bytes())!
	assert s.handler.style == none
}

struct StreamXtshiftescapeH {
mut:
	escape ?bool
}

pub fn (mut self StreamXtshiftescapeH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.mouse_shift_capture {
			if value is bool {
				self.escape = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamXtshiftescapeH) deinit() {}

fn test_stream_xtshiftescape() ! {
	mut s := Stream.init[StreamXtshiftescapeH](StreamXtshiftescapeH{})
	s.next_slice('\x1b[>2s'.bytes())!
	assert s.handler.escape == none

	s.next_slice('\x1b[>s'.bytes())!
	assert s.handler.escape? == false

	s.next_slice('\x1b[>0s'.bytes())!
	assert s.handler.escape? == false

	s.next_slice('\x1b[>1s'.bytes())!
	assert s.handler.escape? == true

	// Invalid and ignored by the handler
	s.next_slice('\x1b[1 s'.bytes())!
	assert s.handler.escape? == true
}

struct StreamChangeWindowTitleH {
mut:
	seen bool
}

pub fn (mut self StreamChangeWindowTitleH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.window_title {
			self.seen = true
		}
		else {}
	}
}

pub fn (mut self StreamChangeWindowTitleH) deinit() {}

fn test_stream_change_window_title_with_invalid_utf_8() ! {
	{
		mut s := Stream.init[StreamChangeWindowTitleH](StreamChangeWindowTitleH{})
		s.next_slice('\x1b]2;abc\x1b\\'.bytes())!
		assert s.handler.seen
	}

	{
		mut s := Stream.init[StreamChangeWindowTitleH](StreamChangeWindowTitleH{})
		s.next_slice('\x1b]2;abc\xc0\x1b\\'.bytes())!
		assert !s.handler.seen
	}
}

struct StreamInsertCharactersH {
mut:
	called bool
}

pub fn (mut self StreamInsertCharactersH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.insert_blanks {
			self.called = true
		}
		else {}
	}
}

pub fn (mut self StreamInsertCharactersH) deinit() {}

fn test_stream_insert_characters() ! {
	mut s := Stream.init[StreamInsertCharactersH](StreamInsertCharactersH{})
	for c in '\x1b[42@' {
		s.next(c)!
	}
	assert s.handler.called

	s.handler.called = false
	for c in '\x1b[?42@' {
		s.next(c)!
	}
	assert !s.handler.called
}

struct StreamScoscH {
mut:
	called bool
}

pub fn (mut self StreamScoscH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.left_and_right_margin {
			panic('bad')
		}
		.left_and_right_margin_ambiguous {
			self.called = true
		}
		else {}
	}
}

pub fn (mut self StreamScoscH) deinit() {}

fn test_stream_scosc() ! {
	mut s := Stream.init[StreamScoscH](StreamScoscH{})
	for c in '\x1b[s' {
		s.next(c)!
	}
	assert s.handler.called
}

struct StreamScorcH {
mut:
	called bool
}

pub fn (mut self StreamScorcH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.restore_cursor {
			self.called = true
		}
		else {}
	}
}

pub fn (mut self StreamScorcH) deinit() {}

fn test_stream_scorc() ! {
	mut s := Stream.init[StreamScorcH](StreamScorcH{})
	for c in '\x1b[u' {
		s.next(c)!
	}
	assert s.handler.called
}

struct StreamTooManyCsiParamsH {}

pub fn (mut self StreamTooManyCsiParamsH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.cursor_right {
			panic('unreachable')
		}
		else {}
	}
}

pub fn (mut self StreamTooManyCsiParamsH) deinit() {}

fn test_stream_too_many_csi_params() ! {
	mut s := Stream.init[StreamTooManyCsiParamsH](StreamTooManyCsiParamsH{})
	s.next_slice('\x1b[1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1C'.bytes())!
}

struct StreamCsiParamTooLongH {}

pub fn (mut self StreamCsiParamTooLongH) vt(action ActionKey, value ActionValue) ! {
}

pub fn (mut self StreamCsiParamTooLongH) deinit() {}

fn test_stream_csi_param_too_long() ! {
	mut s := Stream.init[StreamCsiParamTooLongH](StreamCsiParamTooLongH{})
	s.next_slice('\x1b[1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111C'.bytes())!
}

struct StreamSendReportCsiTH {
mut:
	style ?SizeReportStyle
}

pub fn (mut self StreamSendReportCsiTH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.size_report {
			if value is SizeReportStyle {
				self.style = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamSendReportCsiTH) deinit() {}

fn test_stream_send_report_with_csi_t() ! {
	mut s := Stream.init[StreamSendReportCsiTH](StreamSendReportCsiTH{})

	s.next_slice('\x1b[14t'.bytes())!
	assert s.handler.style? == SizeReportStyle.csi_14_t

	s.next_slice('\x1b[16t'.bytes())!
	assert s.handler.style? == SizeReportStyle.csi_16_t

	s.next_slice('\x1b[18t'.bytes())!
	assert s.handler.style? == SizeReportStyle.csi_18_t

	s.next_slice('\x1b[21t'.bytes())!
	assert s.handler.style? == SizeReportStyle.csi_21_t
}

struct StreamInvalidCsiTH {
mut:
	style ?SizeReportStyle
}

pub fn (mut self StreamInvalidCsiTH) send_size_report(style SizeReportStyle) {
	self.style = style
}

pub fn (mut self StreamInvalidCsiTH) vt(action ActionKey, value ActionValue) ! {
}

pub fn (mut self StreamInvalidCsiTH) deinit() {}

fn test_stream_invalid_csi_t() ! {
	mut s := Stream.init[StreamInvalidCsiTH](StreamInvalidCsiTH{})

	s.next_slice('\x1b[19t'.bytes())!
	assert s.handler.style == none
}

struct StreamCsiTPushTitleH {
mut:
	index ?u16
}

pub fn (mut self StreamCsiTPushTitleH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.title_push {
			if value is u16 {
				self.index = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamCsiTPushTitleH) deinit() {}

fn test_stream_csi_t_push_title() ! {
	mut s := Stream.init[StreamCsiTPushTitleH](StreamCsiTPushTitleH{})

	s.next_slice('\x1b[22;0t'.bytes())!
	assert s.handler.index? == u16(0)
}

struct StreamCsiTPushTitleWithExplicitWindowH {
mut:
	index ?u16
}

pub fn (mut self StreamCsiTPushTitleWithExplicitWindowH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.title_push {
			if value is u16 {
				self.index = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamCsiTPushTitleWithExplicitWindowH) deinit() {}

fn test_stream_csi_t_push_title_with_explicit_window() ! {
	mut s := Stream.init[StreamCsiTPushTitleWithExplicitWindowH](StreamCsiTPushTitleWithExplicitWindowH{})

	s.next_slice('\x1b[22;2t'.bytes())!
	assert s.handler.index? == u16(0)
}

struct StreamCsiTPushTitleWithExplicitIconH {
mut:
	index ?u16
}

pub fn (mut self StreamCsiTPushTitleWithExplicitIconH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.title_push {
			if value is u16 {
				self.index = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamCsiTPushTitleWithExplicitIconH) deinit() {}

fn test_stream_csi_t_push_title_with_explicit_icon() ! {
	mut s := Stream.init[StreamCsiTPushTitleWithExplicitIconH](StreamCsiTPushTitleWithExplicitIconH{})

	s.next_slice('\x1b[22;1t'.bytes())!
	assert s.handler.index == none
}

struct StreamCsiTPushTitleWithIndexH {
mut:
	index ?u16
}

pub fn (mut self StreamCsiTPushTitleWithIndexH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.title_push {
			if value is u16 {
				self.index = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamCsiTPushTitleWithIndexH) deinit() {}

fn test_stream_csi_t_push_title_with_index() ! {
	mut s := Stream.init[StreamCsiTPushTitleWithIndexH](StreamCsiTPushTitleWithIndexH{})

	s.next_slice('\x1b[22;0;5t'.bytes())!
	assert s.handler.index? == u16(5)
}

struct StreamCsiTPopTitleH {
mut:
	index ?u16
}

pub fn (mut self StreamCsiTPopTitleH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.title_pop {
			if value is u16 {
				self.index = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamCsiTPopTitleH) deinit() {}

fn test_stream_csi_t_pop_title() ! {
	mut s := Stream.init[StreamCsiTPopTitleH](StreamCsiTPopTitleH{})

	s.next_slice('\x1b[23;0t'.bytes())!
	assert s.handler.index? == u16(0)
}

struct StreamCsiTPopTitleWithExplicitWindowH {
mut:
	index ?u16
}

pub fn (mut self StreamCsiTPopTitleWithExplicitWindowH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.title_pop {
			if value is u16 {
				self.index = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamCsiTPopTitleWithExplicitWindowH) deinit() {}

fn test_stream_csi_t_pop_title_with_explicit_window() ! {
	mut s := Stream.init[StreamCsiTPopTitleWithExplicitWindowH](StreamCsiTPopTitleWithExplicitWindowH{})

	s.next_slice('\x1b[23;2t'.bytes())!
	assert s.handler.index? == u16(0)
}

struct StreamCsiTPopTitleWithExplicitIconH {
mut:
	index ?u16
}

pub fn (mut self StreamCsiTPopTitleWithExplicitIconH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.title_pop {
			if value is u16 {
				self.index = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamCsiTPopTitleWithExplicitIconH) deinit() {}

fn test_stream_csi_t_pop_title_with_explicit_icon() ! {
	mut s := Stream.init[StreamCsiTPopTitleWithExplicitIconH](StreamCsiTPopTitleWithExplicitIconH{})

	s.next_slice('\x1b[23;1t'.bytes())!
	assert s.handler.index == none
}

struct StreamCsiTPopTitleWithIndexH {
mut:
	index ?u16
}

pub fn (mut self StreamCsiTPopTitleWithIndexH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.title_pop {
			if value is u16 {
				self.index = value
			}
		}
		else {}
	}
}

pub fn (mut self StreamCsiTPopTitleWithIndexH) deinit() {}

fn test_stream_csi_t_pop_title_with_index() ! {
	mut s := Stream.init[StreamCsiTPopTitleWithIndexH](StreamCsiTPopTitleWithIndexH{})

	s.next_slice('\x1b[23;0;5t'.bytes())!
	assert s.handler.index? == u16(5)
}

struct StreamCsiWClearTabStopsH {
mut:
	action ?ActionKey
}

pub fn (mut self StreamCsiWClearTabStopsH) vt(action ActionKey, value ActionValue) ! {
	self.action = action
}

pub fn (mut self StreamCsiWClearTabStopsH) deinit() {}

fn test_stream_csi_w_clear_tab_stops() ! {
	mut s := Stream.init[StreamCsiWClearTabStopsH](StreamCsiWClearTabStopsH{})

	s.next_slice('\x1b[2W'.bytes())!
	assert s.handler.action? == ActionKey.tab_clear_current

	s.next_slice('\x1b[5W'.bytes())!
	assert s.handler.action? == ActionKey.tab_clear_all
}

struct StreamCsiWTabSetH {
mut:
	action ?ActionKey
}

pub fn (mut self StreamCsiWTabSetH) vt(action ActionKey, value ActionValue) ! {
	self.action = action
}

pub fn (mut self StreamCsiWTabSetH) deinit() {}

fn test_stream_csi_w_tab_set() ! {
	mut s := Stream.init[StreamCsiWTabSetH](StreamCsiWTabSetH{})

	s.next_slice('\x1b[W'.bytes())!
	assert s.handler.action? == ActionKey.tab_set

	s.handler.action = none
	s.next_slice('\x1b[0W'.bytes())!
	assert s.handler.action? == ActionKey.tab_set

	s.handler.action = none
	s.next_slice('\x1b[>W'.bytes())!
	assert s.handler.action == none

	s.handler.action = none
	s.next_slice('\x1b[99W'.bytes())!
	assert s.handler.action == none
}

struct StreamCsiWResetTabStopsH {
mut:
	action ?ActionKey
}

pub fn (mut self StreamCsiWResetTabStopsH) vt(action ActionKey, value ActionValue) ! {
	self.action = action
}

pub fn (mut self StreamCsiWResetTabStopsH) deinit() {}

fn test_stream_csi_w_reset_tab_stops() ! {
	mut s := Stream.init[StreamCsiWResetTabStopsH](StreamCsiWResetTabStopsH{})

	s.next_slice('\x1b[?2W'.bytes())!
	assert s.handler.action == none

	s.next_slice('\x1b[?5W'.bytes())!
	assert s.handler.action? == ActionKey.tab_reset

	// Invalid and ignored by the handler
	s.handler.action = none
	s.next_slice('\x1b[?1;2;3W'.bytes())!
	assert s.handler.action == none
}

struct StreamSgrUnderlineColorH {
mut:
	attrs  ?SgrAttribute
	called bool
}

pub fn (mut self StreamSgrUnderlineColorH) vt(action ActionKey, value ActionValue) ! {
	match action {
		.set_attribute {
			if value is SgrAttribute {
				self.attrs = value
			}
			self.called = true
		}
		else {}
	}
}

pub fn (mut self StreamSgrUnderlineColorH) deinit() {}

fn test_stream_sgr_with_17_parameters_for_underline_color() ! {
	mut s := Stream.init[StreamSgrUnderlineColorH](StreamSgrUnderlineColorH{})

	// Kakoune-style SGR with underline color as 17th parameter
	// This tests the fix where param 17 was being dropped
	s.next_slice('\x1b[4:3;38;2;51;51;51;48;2;170;170;170;58;2;255;97;136;0m'.bytes())!
	assert s.handler.called
}

// ============================================================
// Witty-only tests
// ============================================================

fn test_stream_action_key_c_abi_layout_and_ordinals() {
	assert sizeof(ActionKey) == 4
	mut action_count := 0
	$for enum_value in ActionKey.values {
		assert i32(enum_value.value) == i32(action_count)
		action_count++
	}
	assert action_count == 93
	assert i32(ActionKey.print) == 0
	assert i32(ActionKey.semantic_prompt) == 92
}

// ActionRecorder records every action the stream dispatches, in order.
// Values that view parser storage are only valid until the next input.
struct ActionRecorder {
mut:
	actions []Action
}

pub fn (mut self ActionRecorder) vt(action ActionKey, value ActionValue) ! {
	self.actions << Action{
		key:   action
		value: value
	}
}

pub fn (mut self ActionRecorder) deinit() {}

fn (self ActionRecorder) has(key ActionKey) bool {
	for a in self.actions {
		if a.key == key {
			return true
		}
	}
	return false
}

// last returns the value of the last recorded action with the given key.
fn (self ActionRecorder) last(key ActionKey) ?ActionValue {
	for i := self.actions.len - 1; i >= 0; i-- {
		if self.actions[i].key == key {
			return self.actions[i].value
		}
	}
	return none
}

// The source's Action.print_repeat field is a usize count, which is a
// different ActionValue variant than the u16 counts of other actions.
fn test_stream_print_repeat_carries_source_usize_count() ! {
	mut s := Stream.init[ActionRecorder](ActionRecorder{})
	defer { s.deinit() }

	s.next_slice('x\x1b[65535b'.bytes())!
	count := s.handler.last(.print_repeat)?
	assert count is usize
	if count is usize {
		assert count == usize(65535)
	}
}

// RawActionRecorder observes parser actions through the source's optional
// vtRaw hook. The actions view the parser's buffers, so it copies what it
// keeps.
struct RawActionRecorder {
mut:
	raw        []ParserActionType
	csi_params [][]u16
	csi_finals []u8
	osc_titles []string
	keys       []ActionKey
	skip_csi   bool
}

pub fn (mut self RawActionRecorder) vt_raw(action ParserAction) !bool {
	self.raw << action.tag()
	if action.tag() == .csi_dispatch_action {
		self.csi_params << (action as CSIAction).params.clone()
		self.csi_finals << (action as CSIAction).final_byte
		return self.skip_csi
	}
	if action.tag() == .osc_dispatch_action {
		cmd := (action as osc.Command)
		if cmd is osc.ChangeWindowTitle {
			self.osc_titles << cmd.value.clone()
		}
	}
	return false
}

pub fn (mut self RawActionRecorder) vt(action ActionKey, value ActionValue) ! {
	self.keys << action
}

pub fn (mut self RawActionRecorder) deinit() {}

// The inspector slow path consumes parser actions through vt_raw before the
// stream interprets them. Ground-state printing and C0 execution bypass the
// parser, as in the source, so they only reach vt.
fn test_stream_vt_raw_receives_parser_actions() ! {
	mut s := Stream.init[RawActionRecorder](RawActionRecorder{})
	defer { s.deinit() }

	s.next_slice('x\a\x1b[5C\x1b]0;title\a'.bytes())!
	assert s.handler.raw == [ParserActionType.csi_dispatch_action, .osc_dispatch_action]
	assert s.handler.csi_params == [[u16(5)]]
	assert s.handler.csi_finals == [u8(`C`)]
	assert s.handler.osc_titles == ['title']
	assert s.handler.keys == [ActionKey.print, .bell, .cursor_right, .window_title]

	// Returning true from vt_raw skips the stream's own processing.
	s.handler = RawActionRecorder{
		skip_csi: true
	}
	s.next_slice('\x1b[5C'.bytes())!
	assert s.handler.raw == [ParserActionType.csi_dispatch_action]
	assert s.handler.keys.len == 0
}

fn test_stream_preserves_osc_terminator_for_color_responses() ! {
	mut s := Stream.init_alloc[ActionRecorder](voidptr(1), ActionRecorder{})
	defer { s.deinit() }

	s.next_slice('\x1b]10;?\a'.bytes())!
	color := s.handler.last(.color_operation)?
	assert color is ActionColorOperation
	if color is ActionColorOperation {
		assert color.terminator == .bel
		assert color.op == .osc_10
		assert color.requests.len == 1
		request := color.requests[0]
		assert request is osc.ColorRequestQuery
		if request is osc.ColorRequestQuery {
			assert request.target is osc.ColorTargetDynamic
			if request.target is osc.ColorTargetDynamic {
				assert request.target.color == .foreground
			}
		}
	}

	s.handler.actions.clear()
	s.next_slice('\x1b]21;foreground=?\x1b\\'.bytes())!
	kitty := s.handler.last(.kitty_color_report)?
	assert kitty is osc.KittyColorOSC
	if kitty is osc.KittyColorOSC {
		assert kitty.terminator == .st
		assert kitty.list.len == 1
		item := kitty.list[0]
		assert item is osc.KittyColorQuery
		if item is osc.KittyColorQuery {
			assert item.key == osc.KittyColorKind(osc.KittyColorSpecial.foreground)
		}
	}
}

fn test_stream_carries_typed_semantic_and_progress_actions() ! {
	mut s := Stream.init[ActionRecorder](ActionRecorder{})
	defer { s.deinit() }

	s.next_slice('\x1b]133;D;err=23\a'.bytes())!
	semantic := s.handler.last(.semantic_prompt)?
	assert semantic is osc.SemanticPrompt
	if semantic is osc.SemanticPrompt {
		assert semantic.action == .end_command
		assert semantic.options_unvalidated == 'err=23'
	}

	s.handler.actions.clear()
	s.next_slice('\x1b]9;4;1;900\a'.bytes())!
	progress := s.handler.last(.progress_report)?
	assert progress is osc.ProgressReport
	if progress is osc.ProgressReport {
		assert progress.state == .set
		assert progress.progress? == 100
	}
}

fn test_stream_carries_typed_desktop_notifications() ! {
	mut s := Stream.init[ActionRecorder](ActionRecorder{})
	defer { s.deinit() }

	s.next_slice('\x1b]9;Build complete\a'.bytes())!
	iterm := s.handler.last(.show_desktop_notification)?
	assert iterm is ActionShowDesktopNotification
	if iterm is ActionShowDesktopNotification {
		assert iterm.title == ''
		assert iterm.body == 'Build complete'
	}

	s.handler.actions.clear()
	s.next_slice('\x1b]777;notify;Compiler;Build failed\x1b\\'.bytes())!
	rxvt := s.handler.last(.show_desktop_notification)?
	assert rxvt is ActionShowDesktopNotification
	if rxvt is ActionShowDesktopNotification {
		assert rxvt.title == 'Compiler'
		assert rxvt.body == 'Build failed'
	}
}

fn test_stream_carries_typed_clipboard_and_hyperlink_actions() ! {
	mut s := Stream.init_alloc[ActionRecorder](voidptr(1), ActionRecorder{})
	defer { s.deinit() }

	s.next_slice('\x1b]52;s;?\a'.bytes())!
	clipboard := s.handler.last(.clipboard_contents)?
	assert clipboard is ActionClipboardContents
	if clipboard is ActionClipboardContents {
		assert clipboard.kind == `s`
		assert clipboard.data == '?'
	}

	s.handler.actions.clear()
	s.next_slice('\x1b]8;id=build;https://example.com\x1b\\'.bytes())!
	hyperlink := s.handler.last(.start_hyperlink)?
	assert hyperlink is ActionStartHyperlink
	if hyperlink is ActionStartHyperlink {
		assert hyperlink.uri == 'https://example.com'
		assert hyperlink.id? == 'build'
	}

	s.handler.actions.clear()
	s.next_slice('\x1b]8;;https://example.com\x1b\\'.bytes())!
	without_id := s.handler.last(.start_hyperlink)?
	assert without_id is ActionStartHyperlink
	if without_id is ActionStartHyperlink {
		assert without_id.id == none
	}
}

fn test_ground_scalar_control_boundaries_match_source() ! {
	mut s := Stream.init[ActionRecorder](ActionRecorder{})
	defer { s.deinit() }

	s.next(0x0f)!
	assert s.handler.has(.invoke_charset)

	s.handler.actions.clear()
	s.next(0x10)!
	assert s.handler.actions.len == 1
	assert s.handler.actions[0].key == .print
	cp_10 := s.handler.actions[0].value
	assert cp_10 is ActionPrint
	if cp_10 is ActionPrint {
		assert cp_10.cp == 0x10
	}

	s.handler.actions.clear()
	s.next(0x7f)!
	assert s.handler.actions.len == 1
	assert s.handler.actions[0].key == .print
	cp_7f := s.handler.actions[0].value
	assert cp_7f is ActionPrint
	if cp_7f is ActionPrint {
		assert cp_7f.cp == 0x7f
	}
}

// next_slice decodes at most 4096 codepoints per internal chunk; input that
// spans chunks must behave as if it arrived in one piece.
fn test_simd_next_slice_crosses_internal_chunk_boundary() ! {
	mut s := Stream.init[ActionRecorder](ActionRecorder{})
	defer { s.deinit() }

	s.next_slice('x'.repeat(5000).bytes())!
	assert s.handler.actions.len == 5000
	assert s.handler.actions[0].key == .print
	last := s.handler.actions.last().value
	assert last is ActionPrint
	if last is ActionPrint {
		assert last.cp == u32(`x`)
	}
}

fn test_simd_escape_sequence_crosses_internal_chunk_boundary() ! {
	mut s := Stream.init[ActionRecorder](ActionRecorder{})
	defer { s.deinit() }

	s.next_slice(('x'.repeat(4095) + '\x1b[5C').bytes())!
	assert s.handler.actions.len == 4096
	assert s.handler.actions.last().key == .cursor_right
	last := s.handler.actions.last().value
	assert last is ActionCursorMovement
	if last is ActionCursorMovement {
		assert last.value == 5
	}
}

fn test_simd_utf8_sequence_crosses_internal_chunk_boundary() ! {
	mut s := Stream.init[ActionRecorder](ActionRecorder{})
	defer { s.deinit() }

	s.next_slice(('x'.repeat(4095) + '€y').bytes())!
	assert s.handler.actions.len == 4097
	euro := s.handler.actions[4095].value
	assert euro is ActionPrint
	if euro is ActionPrint {
		assert euro.cp == 0x20ac
	}
	y := s.handler.actions[4096].value
	assert y is ActionPrint
	if y is ActionPrint {
		assert y.cp == u32(`y`)
	}
}

// Kitty's CSI 22 J extension erases the display after scrolling it into the
// scrollback; 4 is not its wire value.
fn test_stream_erase_display_scroll_complete() ! {
	mut s := Stream.init[ActionRecorder](ActionRecorder{})
	defer { s.deinit() }

	s.next_slice('\x1b[22J'.bytes())!
	protected := s.handler.last(.erase_display_scroll_complete)?
	assert protected is bool
	if protected is bool {
		assert protected == false
	}

	s.handler.actions.clear()
	s.next_slice('\x1b[4J'.bytes())!
	assert s.handler.actions.len == 0
}

fn test_stream_decrqm_rejects_malformed_two_intermediate_ansi_form() ! {
	mut s := Stream.init[ActionRecorder](ActionRecorder{})
	defer { s.deinit() }

	s.next_slice('\x1b[4$$p'.bytes())!
	assert !s.handler.has(.request_mode)
	assert !s.handler.has(.request_mode_unknown)

	s.next_slice('\x1b[?25$p'.bytes())!
	assert s.handler.has(.request_mode)
}
