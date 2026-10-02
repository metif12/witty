module synthetic

import rand
import io

pub enum OscValidKind as u8 {
	change_window_title
	prompt_start
	prompt_end
	end_of_input
	end_of_command
	rxvt_notify
	mouse_shape
	clipboard_operation
	report_pwd
	hyperlink_start
	hyperlink_end
	conemu_progress
	iterm2_notification
}

pub enum OscInvalidKind as u8 {
	random
	good_prefix
}

enum Validity as u8 {
	valid
	invalid
}

// Osc generates random terminal OSC requests, including configurable invalid
// traffic. Every result includes the ESC ] prefix and BEL terminator.
pub struct Osc {
pub mut:
	rng            &rand.PRNG = unsafe { nil }
	p_valid        f64        = 1.0
	p_valid_kind   [13]f64    = [f64(1), 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]!
	p_invalid_kind [2]f64     = [f64(1), 1]!
}

pub fn Osc.init(rng &rand.PRNG) Osc {
	return Osc{
		rng: unsafe { rng }
	}
}

pub fn (mut self Osc) generator() Generator {
	return self
}

pub fn (mut self Osc) next(max_len usize) ![]u8 {
	mut writer := CollectingWriter{}
	self.next_writer(mut writer, max_len)!
	return writer.data
}

pub fn (mut self Osc) next_writer(mut writer io.Writer, max_len usize) ! {
	assert max_len >= 3
	source_write_all(mut writer, [u8(0x1b), `]`])!
	self.next_unwrapped_writer(mut writer, max_len - 3)!
	source_write_all(mut writer, [u8(7)])!
}

fn (mut self Osc) next_unwrapped(max_len usize) ![]u8 {
	mut writer := CollectingWriter{}
	self.next_unwrapped_writer(mut writer, max_len)!
	return writer.data
}

fn (mut self Osc) next_unwrapped_writer(mut writer io.Writer, max_len usize) ! {
	match self.choose_validity() {
		.valid {
			idx := source_weighted_index(mut self.rng, self.p_valid_kind[..])
			self.next_unwrapped_valid_writer(mut writer, unsafe { OscValidKind(idx) }, max_len)!
		}
		.invalid {
			idx := source_weighted_index(mut self.rng, self.p_invalid_kind[..])
			self.next_unwrapped_invalid_writer(mut writer, unsafe { OscInvalidKind(idx) }, max_len)!
		}
	}
}

fn (mut self Osc) next_unwrapped_valid_exact(kind OscValidKind, max_len usize) ![]u8 {
	mut writer := CollectingWriter{}
	self.next_unwrapped_valid_writer(mut writer, kind, max_len)!
	return writer.data
}

fn (mut self Osc) next_unwrapped_valid_writer(mut writer io.Writer, kind OscValidKind, max_len usize) ! {
	match kind {
		.change_window_title {
			if max_len < 3 { return }
			source_write_all(mut writer, '0;'.bytes())!
			self.write_bytes(mut writer, max_len - 3, osc_alphabet)!
		}
		.prompt_start {
			if max_len < 4 { return }
			mut remaining := max_len
			source_write_all(mut writer, '133;A'.bytes())!
			remaining -= 4
			if self.random_bool() {
				if remaining >= 6 {
					source_write_all(mut writer, ';aid='.bytes())!
					remaining -= 5
					remaining -= self.write_bytes(mut writer, synthetic_min_usize(16, remaining),
						osc_kv_alphabet)!
				}
			}
			if self.random_bool() {
				if remaining >= 9 {
					source_write_all(mut writer, ';redraw='.bytes())!
					source_write_all(mut writer, if self.random_bool() {
						'1'.bytes()
					} else {
						'0'.bytes()
					})!
					remaining -= 9
				}
			}
		}
		.prompt_end {
			if max_len < 4 { return }
			source_write_all(mut writer, '133;B'.bytes())!
		}
		.end_of_input {
			if max_len < 5 { return }
			mut remaining := max_len
			source_write_all(mut writer, '133;C'.bytes())!
			remaining -= 5
			if self.random_bool() {
				prefix := ';cmdline_url='
				if remaining < usize(prefix.len + 1) { return }
				source_write_all(mut writer, prefix.bytes())!
				remaining -= usize(prefix.len)
				mut fixed := FixedWriter{
					buffer: []u8{len: 128}
				}
				self.write_bytes(mut fixed, synthetic_min_usize(remaining, 128), osc_ascii_alphabet)!
				source_url_percent_encode(mut writer, fixed.buffer[..fixed.end])!
				remaining -= usize(fixed.end)
			}
		}
		.end_of_command {
			if max_len < 4 { return }
			source_write_all(mut writer, '133;D'.bytes())!
			if self.random_bool() {
				if max_len < 7 { return }
				code := source_uint(mut self.rng, 8)
				source_write_all(mut writer, ';${code}'.bytes())!
			}
		}
		.mouse_shape {
			if max_len < 4 { return }
			source_write_all(mut writer, '22;'.bytes())!
			self.write_bytes(mut writer, synthetic_min_usize(32, max_len - 3),
				osc_alphabetic_alphabet)!
		}
		.rxvt_notify {
			prefix := '777;notify;'
			if max_len < usize(prefix.len) { return }
			mut remaining := max_len
			source_write_all(mut writer, prefix.bytes())!
			remaining -= usize(prefix.len)
			remaining -= self.write_bytes(mut writer,
				synthetic_min_usize(source_sub(remaining, 2), 32), osc_kv_alphabet)!
			source_write_all(mut writer, ';'.bytes())!
			remaining = source_sub(remaining, 1)
			remaining -= self.write_bytes(mut writer, remaining, osc_alphabet)!
		}
		.clipboard_operation {
			source_write_all(mut writer, '52;'.bytes())!
			mut remaining := source_sub(max_len, 3)
			if self.random_bool() {
				remaining -= self.write_bytes(mut writer, 1, osc_alphabetic_alphabet)!
			}
			source_write_all(mut writer, ';'.bytes())!
			remaining = source_sub(remaining, 1)
			if self.random_bool() {
				remaining -= self.write_bytes(mut writer, remaining, osc_alphabet)!
			}
		}
		.report_pwd {
			prefix := '7;file://localhost'
			if max_len < usize(prefix.len) { return }
			mut remaining := max_len
			source_write_all(mut writer, prefix.bytes())!
			remaining -= usize(prefix.len)
			count := source_range(mut self.rng, 2, 5, int(sizeof(usize) * 8))
			for _ in u64(0) .. count {
				source_write_all(mut writer, '/'.bytes())!
				remaining = source_sub(remaining, 1)
				remaining -= self.write_bytes(mut writer, synthetic_min_usize(16, remaining),
					osc_alphanumeric_alphabet)!
			}
		}
		.hyperlink_start {
			source_write_all(mut writer, '8;'.bytes())!
			if self.random_bool() {
				source_write_all(mut writer, 'id='.bytes())!
				self.write_bytes(mut writer, 16, osc_alphanumeric_alphabet)!
			}
			source_write_all(mut writer, ';https://localhost'.bytes())!
			count := source_range(mut self.rng, 2, 5, int(sizeof(usize) * 8))
			for _ in u64(0) .. count {
				source_write_all(mut writer, '/'.bytes())!
				self.write_bytes(mut writer, 16, osc_alphanumeric_alphabet)!
			}
		}
		.hyperlink_end {
			if max_len < 3 { return }
			source_write_all(mut writer, '8;;'.bytes())!
		}
		.conemu_progress {
			source_write_all(mut writer, '9;'.bytes())!
			code := source_range(mut self.rng, 0, 4, 3)
			if code == 0 || code == 3 {
				source_write_all(mut writer, ';${code}'.bytes())!
			} else if self.random_bool() {
				source_write_all(mut writer, ';${code}'.bytes())!
			} else {
				progress := source_range(mut self.rng, 0, 100, 8)
				source_write_all(mut writer, ';${code};${progress}'.bytes())!
			}
		}
		.iterm2_notification {
			if max_len < 3 { return }
			source_write_all(mut writer, '9;_'.bytes())!
			self.write_bytes(mut writer, max_len - 3, osc_ascii_alphabet)!
		}
	}
}

fn (mut self Osc) next_unwrapped_invalid_exact(kind OscInvalidKind, max_len usize) ![]u8 {
	mut writer := CollectingWriter{}
	self.next_unwrapped_invalid_writer(mut writer, kind, max_len)!
	return writer.data
}

fn (mut self Osc) next_unwrapped_invalid_writer(mut writer io.Writer, kind OscInvalidKind, max_len usize) ! {
	match kind {
		.random {
			self.write_bytes(mut writer, max_len, osc_alphabet)!
		}
		.good_prefix {
			source_write_all(mut writer, '133;'.bytes())!
			self.write_bytes(mut writer, source_sub(max_len, 4), osc_alphabet)!
		}
	}
}

fn (mut self Osc) write_bytes(mut writer io.Writer, max_len usize, alphabet []u8) !usize {
	mut bytes := self.bytes().new_alphabet(alphabet).at_most(max_len)
	return bytes.write_writer(mut writer)
}

fn (self &Osc) bytes() Bytes {
	mut bytes := Bytes.init(self.rng)
	bytes.alphabet = unsafe { osc_alphabet }
	return bytes
}

fn (mut self Osc) choose_validity() Validity {
	return if source_float(mut self.rng) > self.p_valid { .invalid } else { .valid }
}

fn (mut self Osc) random_bool() bool {
	return source_uint(mut self.rng, 1) != 0
}

fn osc_weighted_index(mut rng rand.PRNG, weights []f64) !int {
	return source_weighted_index(mut rng, weights)
}

fn osc_kv_byte(byte u8) bool {
	return byte !in [u8(0x1b), 0x07, `;`, `=`] && byte >= 0x20 && byte <= 0x7e
}

fn osc_byte(byte u8) bool {
	return byte !in [u8(0x1b), 0x07]
}

fn osc_ascii_byte(byte u8) bool {
	return byte >= 0x20 && byte <= 0x7e
}

fn osc_alphabetic_byte(byte u8) bool {
	return byte.is_letter()
}

fn osc_alphanumeric_byte(byte u8) bool {
	return byte.is_alnum()
}

pub const osc_kv_alphabet = generate_alphabet(osc_kv_byte)
pub const osc_alphabet = generate_alphabet(osc_byte)
pub const osc_ascii_alphabet = generate_alphabet(osc_ascii_byte)
pub const osc_alphabetic_alphabet = generate_alphabet(osc_alphabetic_byte)
pub const osc_alphanumeric_alphabet = generate_alphabet(osc_alphanumeric_byte)
