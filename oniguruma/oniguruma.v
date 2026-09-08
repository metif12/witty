module oniguruma

// Ghostty uses the same system dependency when system integration is enabled.
#flag darwin -I/opt/homebrew/include

#flag darwin -L/opt/homebrew/lib

#flag linux -I/usr/include

#flag -lonig

#include "bridge.h"

fn C.witty_onig_initialize(encoding_ids &int, count usize) int

fn C.onig_end() int

fn C.witty_onig_new(out &voidptr, pattern &u8, pattern_len usize, options u32, encoding_id int, syntax_id int, error_par &voidptr, error_par_end &voidptr, error_message &u8) int

fn C.onig_free(regex voidptr)

fn C.onig_region_new() voidptr

fn C.onig_region_free(region voidptr, free_self int)

fn C.witty_onig_error_string(error_message &u8, code int) int

fn C.witty_onig_search(regex voidptr, string &u8, string_len usize, start usize, end usize, region voidptr, options u32) int

fn C.witty_onig_region_count(region voidptr) int

fn C.witty_onig_region_start(region voidptr, index int) int

fn C.witty_onig_region_end(region voidptr, index int) int

pub const max_error_len = 90
pub const mismatch_error = 'oniguruma mismatch'

// Options is Oniguruma's packed OnigOptionType. Field order and bit positions
// match pkg/oniguruma/types.zig.
pub struct Options {
pub:
	ignorecase                             bool
	extend                                 bool
	multiline                              bool
	singleline                             bool
	find_longest                           bool
	find_not_empty                         bool
	negate_singleline                      bool
	dont_capture_group                     bool
	capture_group                          bool
	notbol                                 bool
	noteol                                 bool
	posix_region                           bool
	check_validity_of_string               bool
	ignorecase_is_ascii                    bool
	word_is_ascii                          bool
	digit_is_ascii                         bool
	space_is_ascii                         bool
	posix_is_ascii                         bool
	text_segment_extended_grapheme_cluster bool
	text_segment_word                      bool
	not_begin_string                       bool
	not_end_string                         bool
	not_begin_position                     bool
	callback_each_match                    bool
	match_whole_string                     bool
}

pub fn (o Options) int() u32 {
	return u32(o.ignorecase) | (u32(o.extend) << 1) | (u32(o.multiline) << 2) | (u32(o.singleline) << 3) | (u32(o.find_longest) << 4) | (u32(o.find_not_empty) << 5) | (u32(o.negate_singleline) << 6) | (u32(o.dont_capture_group) << 7) | (u32(o.capture_group) << 8) | (u32(o.notbol) << 9) | (u32(o.noteol) << 10) | (u32(o.posix_region) << 11) | (u32(o.check_validity_of_string) << 12) | (u32(o.ignorecase_is_ascii) << 13) | (u32(o.word_is_ascii) << 14) | (u32(o.digit_is_ascii) << 15) | (u32(o.space_is_ascii) << 16) | (u32(o.posix_is_ascii) << 17) | (u32(o.text_segment_extended_grapheme_cluster) << 18) | (u32(o.text_segment_word) << 19) | (u32(o.not_begin_string) << 20) | (u32(o.not_end_string) << 21) | (u32(o.not_begin_position) << 22) | (u32(o.callback_each_match) << 23) | (u32(o.match_whole_string) << 24)
}

pub enum Encoding {
	ascii
	iso_8859_1
	iso_8859_2
	iso_8859_3
	iso_8859_4
	iso_8859_5
	iso_8859_6
	iso_8859_7
	iso_8859_8
	iso_8859_9
	iso_8859_10
	iso_8859_11
	iso_8859_13
	iso_8859_14
	iso_8859_15
	iso_8859_16
	utf8
	utf16_be
	utf16_le
	utf32_be
	utf32_le
	euc_jp
	euc_tw
	euc_kr
	euc_cn
	sjis
	koi8
	koi8_r
	cp1251
	big5
	gb18030
}

pub enum Syntax {
	default_
	asis
	posix_basic
	posix_extended
	emacs
	grep
	gnu_regex
	java
	perl
	perl_ng
	ruby
	oniguruma
}

pub struct ErrorInfo {
pub mut:
	encoding Encoding
	par      &u8 = unsafe { nil }
	par_end  &u8 = unsafe { nil }
}

// init initializes Oniguruma for the encodings that the process will use.
pub fn init(encodings []Encoding) ! {
	mut values := []int{len: encodings.len}
	for i, encoding in encodings {
		values[i] = int(encoding)
	}
	result := if values.len == 0 {
		C.witty_onig_initialize(unsafe { nil }, 0)
	} else {
		unsafe { C.witty_onig_initialize(&values[0], usize(values.len)) }
	}
	if result < 0 {
		return error(error_string(result))
	}
}

pub fn deinit() {
	_ = C.onig_end()
}

pub fn error_string(code int) string {
	mut buffer := []u8{len: max_error_len}
	length := unsafe { C.witty_onig_error_string(&u8(buffer.data), code) }
	if length <= 0 {
		return 'Oniguruma error: ${code}'
	}
	return buffer[..length].bytestr()
}

pub struct Regex {
mut:
	value voidptr
}

pub fn Regex.init(pattern string, options Options, encoding Encoding, syntax Syntax, error_info ?&ErrorInfo) !Regex {
	mut value := voidptr(unsafe { nil })
	mut error_par := voidptr(unsafe { nil })
	mut error_par_end := voidptr(unsafe { nil })
	mut error_message := []u8{len: max_error_len}
	result := unsafe {
		C.witty_onig_new(&value, pattern.str, usize(pattern.len), options.int(), int(encoding), int(syntax), &error_par, &error_par_end, &u8(error_message.data))
	}
	if result < 0 {
		if mut info := error_info {
			info.encoding = encoding
			unsafe {
				info.par = &u8(error_par)
				info.par_end = &u8(error_par_end)
			}
		}
		message := unsafe { cstring_to_vstring(&char(error_message.data)) }
		if message.len > 0 {
			return error(message)
		}
		return error(error_string(result))
	}
	return Regex{
		value: value
	}
}

pub fn (mut r Regex) deinit() {
	if r.value != unsafe { nil } {
		C.onig_free(r.value)
		r.value = unsafe { nil }
	}
}

pub fn (r &Regex) search(str string, options Options) !Region {
	mut region := Region.new()!
	r.search_advanced(str, 0, usize(str.len), mut region, options) or {
		region.deinit()
		return err
	}
	return region
}

pub fn (r &Regex) search_advanced(str string, start usize, end usize, mut region Region, options Options) !usize {
	if r.value == unsafe { nil } {
		return error('Oniguruma regex is deinitialized')
	}
	if start > end || end > usize(str.len) {
		return error('invalid Oniguruma search range')
	}
	result := C.witty_onig_search(r.value, str.str, usize(str.len), start, end, region.value, options.int())
	if result == -1 {
		return error(mismatch_error)
	}
	if result < 0 {
		return error(error_string(result))
	}
	return usize(result)
}

@[heap]
pub struct Region {
mut:
	value voidptr
}

pub fn Region.new() !Region {
	value := C.onig_region_new()
	if value == unsafe { nil } {
		return error('Oniguruma region allocation failed')
	}
	return Region{
		value: value
	}
}

pub fn (mut r Region) deinit() {
	if r.value != unsafe { nil } {
		C.onig_region_free(r.value, 1)
		r.value = unsafe { nil }
	}
}

pub fn (r &Region) count() usize {
	return if r.value == unsafe { nil } {
		usize(0)
	} else {
		usize(C.witty_onig_region_count(r.value))
	}
}

pub fn (r &Region) starts() []int {
	mut result := []int{cap: int(r.count())}
	for i in 0 .. int(r.count()) {
		result << C.witty_onig_region_start(r.value, i)
	}
	return result
}

pub fn (r &Region) ends() []int {
	mut result := []int{cap: int(r.count())}
	for i in 0 .. int(r.count()) {
		result << C.witty_onig_region_end(r.value, i)
	}
	return result
}

pub fn (r &Region) iterator() RegionIterator {
	return RegionIterator{
		region: r
	}
}

pub struct RegionIterator {
	region &Region
mut:
	index int
}

pub fn (mut it RegionIterator) next() ?[2]usize {
	if it.index >= int(it.region.count()) {
		return none
	}
	result := [usize(C.witty_onig_region_start(it.region.value, it.index)),
		usize(C.witty_onig_region_end(it.region.value, it.index))]!
	it.index++
	return result
}
