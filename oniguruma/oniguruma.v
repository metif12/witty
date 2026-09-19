module oniguruma

// Ghostty uses the same system dependency when system integration is enabled.
#flag darwin -I/opt/homebrew/include

#flag darwin -L/opt/homebrew/lib

#flag linux -I/usr/include

#flag -lonig

#include "bridge.h"

fn C.witty_onig_initialize(encoding_ids &int, count usize) int

fn C.onig_end() int

fn C.witty_onig_new(out &voidptr, pattern &u8, pattern_len usize, options u32, encoding_id int, syntax_id int, error_par &voidptr, error_par_end &voidptr) int

fn C.onig_free(regex voidptr)

fn C.onig_region_free(region voidptr, free_self int)

fn C.witty_onig_error_string(error_message &u8, code int) int

fn C.witty_onig_search(regex voidptr, string &u8, string_len usize, start usize, end usize, region voidptr, options u32) int

pub const max_error_len = 90
pub const mismatch_error = 'oniguruma mismatch'

// Options is Oniguruma's canonical packed OnigOptionType word.
pub struct Options {
mut:
	value u32
}

// Option is the source-shaped name; Options remains for existing V callers.
pub type Option = Options

pub fn (o Options) int() u32 {
	return o.value
}

pub fn Options.from_int(value u32) Options {
	return Options{ value: value }
}

fn (o Options) bit(index u32) bool {
	return o.value & (u32(1) << index) != 0
}

fn (mut o Options) set_bit(index u32, enabled bool) {
	mask := u32(1) << index
	if enabled {
		o.value |= mask
	} else {
		o.value &= ~mask
	}
}

pub fn (o Options) ignorecase() bool {
	return o.bit(0)
}

pub fn (mut o Options) set_ignorecase(value bool) {
	o.set_bit(0, value)
}

pub fn (o Options) extend() bool {
	return o.bit(1)
}

pub fn (mut o Options) set_extend(value bool) {
	o.set_bit(1, value)
}

pub fn (o Options) multiline() bool {
	return o.bit(2)
}

pub fn (mut o Options) set_multiline(value bool) {
	o.set_bit(2, value)
}

pub fn (o Options) singleline() bool {
	return o.bit(3)
}

pub fn (mut o Options) set_singleline(value bool) {
	o.set_bit(3, value)
}

pub fn (o Options) find_longest() bool {
	return o.bit(4)
}

pub fn (mut o Options) set_find_longest(value bool) {
	o.set_bit(4, value)
}

pub fn (o Options) find_not_empty() bool {
	return o.bit(5)
}

pub fn (mut o Options) set_find_not_empty(value bool) {
	o.set_bit(5, value)
}

pub fn (o Options) negate_singleline() bool {
	return o.bit(6)
}

pub fn (mut o Options) set_negate_singleline(value bool) {
	o.set_bit(6, value)
}

pub fn (o Options) dont_capture_group() bool {
	return o.bit(7)
}

pub fn (mut o Options) set_dont_capture_group(value bool) {
	o.set_bit(7, value)
}

pub fn (o Options) capture_group() bool {
	return o.bit(8)
}

pub fn (mut o Options) set_capture_group(value bool) {
	o.set_bit(8, value)
}

pub fn (o Options) notbol() bool {
	return o.bit(9)
}

pub fn (mut o Options) set_notbol(value bool) {
	o.set_bit(9, value)
}

pub fn (o Options) noteol() bool {
	return o.bit(10)
}

pub fn (mut o Options) set_noteol(value bool) {
	o.set_bit(10, value)
}

pub fn (o Options) posix_region() bool {
	return o.bit(11)
}

pub fn (mut o Options) set_posix_region(value bool) {
	o.set_bit(11, value)
}

pub fn (o Options) check_validity_of_string() bool {
	return o.bit(12)
}

pub fn (mut o Options) set_check_validity_of_string(value bool) {
	o.set_bit(12, value)
}

pub fn (o Options) ignorecase_is_ascii() bool {
	return o.bit(13)
}

pub fn (mut o Options) set_ignorecase_is_ascii(value bool) {
	o.set_bit(13, value)
}

pub fn (o Options) word_is_ascii() bool {
	return o.bit(14)
}

pub fn (mut o Options) set_word_is_ascii(value bool) {
	o.set_bit(14, value)
}

pub fn (o Options) digit_is_ascii() bool {
	return o.bit(15)
}

pub fn (mut o Options) set_digit_is_ascii(value bool) {
	o.set_bit(15, value)
}

pub fn (o Options) space_is_ascii() bool {
	return o.bit(16)
}

pub fn (mut o Options) set_space_is_ascii(value bool) {
	o.set_bit(16, value)
}

pub fn (o Options) posix_is_ascii() bool {
	return o.bit(17)
}

pub fn (mut o Options) set_posix_is_ascii(value bool) {
	o.set_bit(17, value)
}

pub fn (o Options) text_segment_extended_grapheme_cluster() bool {
	return o.bit(18)
}

pub fn (mut o Options) set_text_segment_extended_grapheme_cluster(value bool) {
	o.set_bit(18, value)
}

pub fn (o Options) text_segment_word() bool {
	return o.bit(19)
}

pub fn (mut o Options) set_text_segment_word(value bool) {
	o.set_bit(19, value)
}

pub fn (o Options) not_begin_string() bool {
	return o.bit(20)
}

pub fn (mut o Options) set_not_begin_string(value bool) {
	o.set_bit(20, value)
}

pub fn (o Options) not_end_string() bool {
	return o.bit(21)
}

pub fn (mut o Options) set_not_end_string(value bool) {
	o.set_bit(21, value)
}

pub fn (o Options) not_begin_position() bool {
	return o.bit(22)
}

pub fn (mut o Options) set_not_begin_position(value bool) {
	o.set_bit(22, value)
}

pub fn (o Options) callback_each_match() bool {
	return o.bit(23)
}

pub fn (mut o Options) set_callback_each_match(value bool) {
	o.set_bit(23, value)
}

pub fn (o Options) match_whole_string() bool {
	return o.bit(24)
}

pub fn (mut o Options) set_match_whole_string(value bool) {
	o.set_bit(24, value)
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
	_ = convert_error(result)!
}

pub fn deinit() {
	_ = C.onig_end()
}

pub fn error_string(mut buffer []u8, code int) ![]u8 {
	length := unsafe { C.witty_onig_error_string(&u8(buffer.data), code) }
	if length <= 0 {
		return buffer[..0]
	}
	return buffer[..length]
}

pub struct Regex {
mut:
	value voidptr
}

pub fn Regex.init(pattern string, options Options, encoding Encoding, syntax Syntax, error_info ?&ErrorInfo) !Regex {
	mut value := voidptr(unsafe { nil })
	mut error_par := voidptr(unsafe { nil })
	mut error_par_end := voidptr(unsafe { nil })
	result := unsafe {
		C.witty_onig_new(&value, pattern.str, usize(pattern.len), options.int(), int(encoding), int(syntax), &error_par, &error_par_end)
	}
	if result < 0 {
		if mut info := error_info {
			info.encoding = encoding
			unsafe {
				info.par = &u8(error_par)
				info.par_end = &u8(error_par_end)
			}
		}
		_ = convert_error(result)!
	}
	return Regex{
		value: value
	}
}

pub fn (mut r Regex) deinit() {
	C.onig_free(r.value)
}

pub fn (r &Regex) search(str string, options Options) !Region {
	mut region := Region{}
	r.search_advanced(str, 0, usize(str.len), mut region, options) or {
		region.deinit()
		return err
	}
	return region
}

pub fn (r &Regex) search_advanced(str string, start usize, end usize, mut region Region, options Options) !usize {
	result := C.witty_onig_search(r.value, str.str, usize(str.len), start, end, voidptr(&region),
		options.int())
	return usize(convert_error(result)!)
}

pub struct Region {
mut:
	allocated    int
	num_regs     int
	beg          &int = unsafe { nil }
	end          &int = unsafe { nil }
	history_root voidptr
}

pub fn (mut r Region) deinit() {
	C.onig_region_free(voidptr(&r), 0)
}

pub fn (r &Region) count() usize {
	return usize(r.num_regs)
}

pub fn (r &Region) starts() []int {
	if r.num_regs == 0 {
		return []
	}
	mut result := []int{}
	unsafe {
		result.data = voidptr(r.beg)
		result.len = r.num_regs
		result.cap = r.num_regs
		result.flags = .nogrow | .noshrink | .nofree
	}
	return result
}

pub fn (r &Region) ends() []int {
	if r.num_regs == 0 {
		return []
	}
	mut result := []int{}
	unsafe {
		result.data = voidptr(r.end)
		result.len = r.num_regs
		result.cap = r.num_regs
		result.flags = .nogrow | .noshrink | .nofree
	}
	return result
}

pub fn (r &Region) iterator() RegionIterator {
	return RegionIterator{
		region: unsafe { r }
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
	start := unsafe { it.region.beg[it.index] }
	end := unsafe { it.region.end[it.index] }
	if start < 0 || end < 0 {
		panic('negative Oniguruma capture boundary')
	}
	result := [usize(start), usize(end)]!
	it.index++
	return result
}
