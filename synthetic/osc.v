module synthetic

import internal_os
import rand

pub enum OscValidKind {
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

pub enum OscInvalidKind {
	random
	good_prefix
}

// Osc generates random terminal OSC requests, including configurable invalid
// traffic. Every result includes the ESC ] prefix and BEL terminator.
pub struct Osc {
pub mut:
	rng            &rand.PRNG = unsafe { nil }
	p_valid        f64 = 1.0
	p_valid_kind   [13]f64 = [f64(1), 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]!
	p_invalid_kind [2]f64 = [f64(1), 1]!
}

pub fn Osc.init(rng &rand.PRNG) Osc {
	return Osc{ rng: unsafe { rng } }
}

pub fn (mut self Osc) generator() Generator {
	return self
}

pub fn (mut self Osc) next(max_len usize) ![]u8 {
	if isnil(self.rng) {
		return error('random generator is not initialized')
	}
	assert max_len >= 3
	payload := self.next_unwrapped(max_len - 3)!
	if usize(payload.len) > max_len - 3 {
		return error('WriteFailed')
	}
	mut result := [u8(0x1b), `]`]
	result << payload
	result << u8(0x07)
	return result
}

fn (mut self Osc) next_unwrapped(max_len usize) ![]u8 {
	if self.rng.f64() <= self.p_valid {
		idx := osc_weighted_index(mut self.rng, self.p_valid_kind[..])!
		return self.next_unwrapped_valid_exact(unsafe { OscValidKind(idx) }, max_len)
	}
	idx := osc_weighted_index(mut self.rng, self.p_invalid_kind[..])!
	return self.next_unwrapped_invalid_exact(unsafe { OscInvalidKind(idx) }, max_len)
}

fn (mut self Osc) next_unwrapped_valid_exact(kind OscValidKind, max_len usize) ![]u8 {
	mut result := []u8{}
	match kind {
		.change_window_title {
			if max_len < 3 {
				return result
			}
			result << '0;'.bytes()
			result << self.random_bytes(max_len - 3, [])!
		}
		.prompt_start {
			if max_len < 4 {
				return result
			}
			result << '133;A'.bytes()
			mut remaining := max_len - 4
			if self.random_bool() && remaining >= 6 {
				result << ';aid='.bytes()
				remaining -= 5
				aid := self.random_bytes(synthetic_min_usize(16, remaining), osc_kv_alphabet)!
				result << aid
				remaining -= usize(aid.len)
			}
			if self.random_bool() && remaining >= 9 {
				result << ';redraw='.bytes()
				result << if self.random_bool() { `1` } else { `0` }
			}
		}
		.prompt_end {
			if max_len >= 4 {
				result << '133;B'.bytes()
			}
		}
		.end_of_input {
			if max_len < 5 {
				return result
			}
			result << '133;C'.bytes()
			mut remaining := max_len - 5
			prefix := ';cmdline_url='
			if self.random_bool() && remaining >= usize(prefix.len) + 1 {
				result << prefix.bytes()
				remaining -= usize(prefix.len)
				raw := self.random_bytes(synthetic_min_usize(remaining, 128), osc_ascii_alphabet)!
				result << internal_os.url_percent_encode(raw).bytes()
			}
		}
		.end_of_command {
			if max_len < 4 {
				return result
			}
			result << '133;D'.bytes()
			if self.random_bool() && max_len >= 7 {
				result << ';${self.rng.u8()}'.bytes()
			}
		}
		.mouse_shape {
			if max_len < 4 {
				return result
			}
			result << '22;'.bytes()
			result << self.random_bytes(synthetic_min_usize(32, max_len - 3), osc_alphabetic_alphabet)!
		}
		.rxvt_notify {
			prefix := '777;notify;'
			if max_len < usize(prefix.len) {
				return result
			}
			result << prefix.bytes()
			mut remaining := max_len - usize(prefix.len)
			if remaining < 3 {
				return result
			}
			title := self.random_bytes(synthetic_min_usize(remaining - 2, 32), osc_kv_alphabet)!
			result << title
			remaining -= usize(title.len)
			result << `;`
			remaining--
			result << self.random_bytes(remaining, osc_alphabet)!
		}
		.clipboard_operation {
			if max_len < 4 {
				return result
			}
			result << '52;'.bytes()
			mut remaining := max_len - 3
			if self.random_bool() {
				selection := self.random_bytes(1, osc_alphabetic_alphabet)!
				result << selection
				remaining -= usize(selection.len)
			}
			result << `;`
			remaining--
			if self.random_bool() && remaining > 0 {
				result << self.random_bytes(remaining, osc_alphabet)!
			}
		}
		.report_pwd {
			prefix := '7;file://localhost'
			if max_len < usize(prefix.len) {
				return result
			}
			result << prefix.bytes()
			mut remaining := max_len - usize(prefix.len)
			count := synthetic_random_inclusive(mut self.rng, 2, 5)!
			for _ in 0 .. count {
				result << `/`
				remaining--
				component := self.random_bytes(synthetic_min_usize(16, remaining), osc_alphanumeric_alphabet)!
				result << component
				remaining -= usize(component.len)
			}
		}
		.hyperlink_start {
			result << '8;'.bytes()
			if self.random_bool() {
				result << 'id='.bytes()
				result << self.random_bytes(16, osc_alphanumeric_alphabet)!
			}
			result << ';https://localhost'.bytes()
			count := synthetic_random_inclusive(mut self.rng, 2, 5)!
			for _ in 0 .. count {
				result << `/`
				result << self.random_bytes(16, osc_alphanumeric_alphabet)!
			}
		}
		.hyperlink_end {
			if max_len >= 3 {
				result << '8;;'.bytes()
			}
		}
		.conemu_progress {
			result << '9;'.bytes()
			value := synthetic_random_inclusive(mut self.rng, 0, 4)!
			if value == 0 || value == 3 || self.random_bool() {
				result << ';${value}'.bytes()
			} else {
				progress := synthetic_random_inclusive(mut self.rng, 0, 100)!
				result << ';${value};${progress}'.bytes()
			}
		}
		.iterm2_notification {
			if max_len < 3 {
				return result
			}
			result << '9;_'.bytes()
			result << self.random_bytes(max_len - 3, osc_ascii_alphabet)!
		}
	}
	return result
}

fn (mut self Osc) next_unwrapped_invalid_exact(kind OscInvalidKind, max_len usize) ![]u8 {
	return match kind {
		.random { self.random_bytes(max_len, [])! }
		.good_prefix {
			mut result := '133;'.bytes()
			if max_len > 4 {
				result << self.random_bytes(max_len - 4, [])!
			}
			result
		}
	}
}

fn (mut self Osc) random_bytes(max_len usize, alphabet []u8) ![]u8 {
	if max_len < 1 {
		return []u8{}
	}
	mut bytes := Bytes.init(self.rng)
	if alphabet.len > 0 {
		bytes.alphabet = alphabet
	} else {
		bytes.alphabet = osc_alphabet
	}
	mut bounded := bytes.at_most(max_len)
	return bounded.write()
}

fn (mut self Osc) random_bool() bool {
	return self.rng.u8() & 1 == 1
}

fn osc_weighted_index(mut rng rand.PRNG, weights []f64) !int {
	mut total := f64(0)
	for weight in weights {
		if weight < 0 {
			return error('OSC weights must be non-negative')
		}
		total += weight
	}
	if total <= 0 {
		return error('at least one OSC weight must be positive')
	}
	pick := rng.f64() * total
	mut cumulative := f64(0)
	for i, weight in weights {
		cumulative += weight
		if pick < cumulative {
			return i
		}
	}
	return weights.len - 1
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
