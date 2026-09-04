module crash

import strconv
import strings
import encoding.utf8

const envelope_line_limit = 1024 * 1024

// EnvelopeHeader stores a decoded key and a minified JSON value. Keeping the
// value encoded preserves arbitrary Sentry headers without a dynamic JSON sum.
pub struct EnvelopeHeader {
pub:
	key string
pub mut:
	value string
}

// EnvelopeHeaders is an insertion-ordered JSON object.
pub struct EnvelopeHeaders {
pub mut:
	fields []EnvelopeHeader
}

pub fn (self EnvelopeHeaders) get_raw(key string) ?string {
	for field in self.fields {
		if field.key == key {
			return field.value
		}
	}
	return none
}

pub fn (self EnvelopeHeaders) get_string(key string) !string {
	raw := self.get_raw(key) or { return error('JSON field is missing') }
	return decode_json_string(raw)!
}

pub fn (mut self EnvelopeHeaders) set_raw(key string, value string) ! {
	minified := minify_json_fragment(value)!
	for mut field in self.fields {
		if field.key == key {
			field.value = minified
			return
		}
	}
	self.fields << EnvelopeHeader{
		key: key
		value: minified
	}
}

pub fn (mut self EnvelopeHeaders) set_string(key string, value string) {
	encoded := encode_json_string(value)
	for mut field in self.fields {
		if field.key == key {
			field.value = encoded
			return
		}
	}
	self.fields << EnvelopeHeader{
		key: key
		value: encoded
	}
}

pub fn (mut self EnvelopeHeaders) delete(key string) {
	for idx, field in self.fields {
		if field.key == key {
			self.fields.delete(idx)
			return
		}
	}
}

pub fn (self EnvelopeHeaders) clone() EnvelopeHeaders {
	return EnvelopeHeaders{
		fields: self.fields.clone()
	}
}

fn (self EnvelopeHeaders) encode() string {
	mut result := strings.new_builder(2 + self.fields.len * 16)
	result.write_u8(`{`)
	for idx, field in self.fields {
		if idx > 0 {
			result.write_u8(`,`)
		}
		result.write_string(encode_json_string(field.key))
		result.write_u8(`:`)
		result.write_string(field.value)
	}
	result.write_u8(`}`)
	return result.str()
}

// Envelope is the in-memory representation of Sentry's open envelope format.
// Item payloads stay encoded until requested.
pub struct Envelope {
pub mut:
	headers EnvelopeHeaders
	items   []Item
}

// ItemType is the point-in-time set of documented Sentry envelope item types.
pub enum ItemType {
	unknown
	event
	transaction
	attachment
	session
	sessions
	statsd
	metric_meta
	user_feedback
	client_report
	replay_event
	replay_recording
	profile
	check_in
}

// EncodedItem retains its payload bytes while its headers are decoded.
pub struct EncodedItem {
pub mut:
	headers EnvelopeHeaders
	typ     ItemType
	payload []u8
}

// Attachment is the decoded representation of an attachment item.
pub struct Attachment {
pub mut:
	filename      string
	typ           ?string
	headers_extra EnvelopeHeaders
	payload       []u8
}

pub type Item = Attachment | EncodedItem

struct EnvelopeReader {
	data []u8
mut:
	pos int
}

// parse reads a complete envelope. Input is copied so callers may immediately
// release or reuse their source buffer.
pub fn Envelope.parse(data []u8) !Envelope {
	mut reader := EnvelopeReader{
		data: data.clone()
	}
	header_line := reader.read_line(envelope_line_limit)!
	headers := parse_json_object(header_line.bytestr(), 'envelope headers')!
	mut items := []Item{}
	for reader.pos < reader.data.len {
		item := parse_envelope_item(mut reader) or {
			if err.msg() == 'end of envelope' {
				break
			}
			return err
		}
		items << item
	}
	return Envelope{
		headers: headers
		items: items
	}
}

pub fn (mut self Envelope) deinit() {
	self.headers.fields.clear()
	self.items.clear()
}

// serialize converts decoded items back to encoded items in place and emits
// the line-oriented envelope framing.
pub fn (mut self Envelope) serialize() ![]u8 {
	mut output := []u8{}
	output << self.headers.encode().bytes()
	output << `\n`
	for idx in 0 .. self.items.len {
		if idx > 0 {
			output << `\n`
		}
		mut item := self.items[idx]
		encoded := item.encode()!
		self.items[idx] = item
		output << encoded.headers.encode().bytes()
		output << `\n`
		output << encoded.payload
	}
	return output
}

// item_type returns the type without forcing payload decoding.
pub fn (self Item) item_type() ItemType {
	return match self {
		EncodedItem { self.typ }
		Attachment { .attachment }
	}
}

// decode converts an encoded attachment in place. Other item types are not
// decoded, matching Ghostty's partial decoder.
pub fn (mut self Item) decode() ! {
	match mut self {
		EncodedItem {
			if self.typ != .attachment {
				return error('unsupported envelope item type')
			}
			attachment := Attachment.decode(self)!
			self = Item(attachment)
		}
		Attachment {}
	}
}

// encode converts a decoded attachment in place and returns the encoded item.
pub fn (mut self Item) encode() !EncodedItem {
	match mut self {
		EncodedItem {
			return self
		}
		Attachment {
			encoded := self.encode_attachment()!
			self = Item(encoded)
			return encoded
		}
	}
}

pub fn Attachment.decode(item EncodedItem) !Attachment {
	filename := item.headers.get_string('filename') or {
		if item.headers.get_raw('filename') == none {
			return error('attachment filename is missing')
		}
		return error('attachment filename has invalid type')
	}
	mut attachment_type := ?string(none)
	if item.headers.get_raw('attachment_type') != none {
		attachment_type = item.headers.get_string('attachment_type') or {
			return error('attachment type has invalid type')
		}
	}
	return Attachment{
		filename: filename
		typ: attachment_type
		headers_extra: item.headers.clone()
		payload: item.payload
	}
}

fn (mut self Attachment) encode_attachment() !EncodedItem {
	self.headers_extra.set_string('filename', self.filename)
	if value := self.typ {
		self.headers_extra.set_string('attachment_type', value)
	} else {
		self.headers_extra.delete('attachment_type')
	}
	return EncodedItem{
		headers: self.headers_extra
		typ: .attachment
		payload: self.payload
	}
}

fn parse_envelope_item(mut reader EnvelopeReader) !Item {
	header_line := reader.read_line(envelope_line_limit) or {
		if err.msg() == 'envelope line is too long' {
			return error('end of envelope')
		}
		return err
	}
	line := header_line.bytestr().trim(' \t')
	if line.len == 0 {
		return error('end of envelope')
	}
	headers := parse_json_object(line, 'envelope item headers')!
	type_name := headers.get_string('type') or {
		return error('envelope item type is missing')
	}
	typ := item_type_from_string(type_name)

	mut payload := []u8{}
	if length_value := headers.get_raw('length') {
		length := json_nonnegative_int(length_value) or {
			return error('envelope item length is malformed')
		}
		if length > u64(max_int) || reader.pos + int(length) > reader.data.len {
			return error('envelope item payload is too short')
		}
		payload = reader.data[reader.pos..reader.pos + int(length)].clone()
		reader.pos += int(length)
		if reader.pos < reader.data.len {
			if reader.data[reader.pos] != `\n` {
				return error('envelope item payload has no newline')
			}
			reader.pos++
		}
	} else {
		payload = reader.read_line(envelope_line_limit) or {
			return error('envelope item payload is too short')
		}
	}
	return Item(EncodedItem{
		headers: headers
		typ: typ
		payload: payload
	})
}

fn (mut reader EnvelopeReader) read_line(limit int) ![]u8 {
	if reader.pos >= reader.data.len {
		return error('end of stream')
	}
	start := reader.pos
	for reader.pos < reader.data.len && reader.data[reader.pos] != `\n` {
		reader.pos++
		if reader.pos - start > limit {
			return error('envelope line is too long')
		}
	}
	line := reader.data[start..reader.pos].clone()
	if reader.pos < reader.data.len {
		reader.pos++
	}
	return line
}

fn item_type_from_string(value string) ItemType {
	return match value {
		'event' { .event }
		'transaction' { .transaction }
		'attachment' { .attachment }
		'session' { .session }
		'sessions' { .sessions }
		'statsd' { .statsd }
		'metric_meta' { .metric_meta }
		'user_feedback' { .user_feedback }
		'client_report' { .client_report }
		'replay_event' { .replay_event }
		'replay_recording' { .replay_recording }
		'profile' { .profile }
		'check_in' { .check_in }
		else { .unknown }
	}
}

fn json_nonnegative_int(raw string) ?u64 {
	if raw.len == 0 || raw[0] == `-` || raw.contains('.') || raw.contains('e')
		|| raw.contains('E') {
		return none
	}
	return strconv.parse_uint(raw, 10, 64) or { none }
}

struct JsonCursor {
	text string
mut:
	pos int
}

fn parse_json_object(text string, description string) !EnvelopeHeaders {
	if !utf8.validate_str(text) {
		return error('malformed ${description}: invalid UTF-8')
	}
	mut cursor := JsonCursor{
		text: text
	}
	cursor.skip_space()
	if cursor.pos >= text.len || text[cursor.pos] != `{` {
		return error('malformed ${description}')
	}
	cursor.pos++
	mut headers := EnvelopeHeaders{}
	cursor.skip_space()
	if cursor.take_if(`}`) {
		cursor.skip_space()
		if cursor.pos != text.len {
			return error('malformed ${description}')
		}
		return headers
	}
	for {
		cursor.skip_space()
		key_start := cursor.pos
		cursor.parse_string() or { return error('malformed ${description}: ${err}') }
		key_raw := text[key_start..cursor.pos]
		key := decode_json_string(key_raw) or {
			return error('malformed ${description}: ${err}')
		}
		cursor.skip_space()
		if !cursor.take_if(`:`) {
			return error('malformed ${description}')
		}
		cursor.skip_space()
		value_start := cursor.pos
		cursor.parse_value() or { return error('malformed ${description}: ${err}') }
		value := minify_json_fragment(text[value_start..cursor.pos]) or {
			return error('malformed ${description}: ${err}')
		}
		headers.set_raw(key, value)!
		cursor.skip_space()
		if cursor.take_if(`}`) {
			break
		}
		if !cursor.take_if(`,`) {
			return error('malformed ${description}')
		}
	}
	cursor.skip_space()
	if cursor.pos != text.len {
		return error('malformed ${description}')
	}
	return headers
}

fn minify_json_fragment(text string) !string {
	mut cursor := JsonCursor{
		text: text
	}
	cursor.skip_space()
	start := cursor.pos
	cursor.parse_value()!
	end := cursor.pos
	cursor.skip_space()
	if cursor.pos != text.len {
		return error('invalid JSON value')
	}
	mut result := strings.new_builder(end - start)
	mut in_string := false
	mut escaped := false
	for ch in text[start..end].bytes() {
		if in_string {
			result.write_u8(ch)
			if escaped {
				escaped = false
			} else if ch == `\\` {
				escaped = true
			} else if ch == `"` {
				in_string = false
			}
		} else if ch == `"` {
			in_string = true
			result.write_u8(ch)
		} else if !is_json_space(ch) {
			result.write_u8(ch)
		}
	}
	return result.str()
}

fn decode_json_string(raw string) !string {
	if raw.len < 2 || raw[0] != `"` || raw[raw.len - 1] != `"` {
		return error('JSON value is not a string')
	}
	mut result := strings.new_builder(raw.len - 2)
	mut pos := 1
	for pos < raw.len - 1 {
		ch := raw[pos]
		pos++
		if ch != `\\` {
			if ch < 0x20 {
				return error('control character in JSON string')
			}
			result.write_u8(ch)
			continue
		}
		if pos >= raw.len - 1 {
			return error('unterminated JSON escape')
		}
		escape := raw[pos]
		pos++
		match escape {
			`"`, `\\`, `/` { result.write_u8(escape) }
			`b` { result.write_u8(8) }
			`f` { result.write_u8(12) }
			`n` { result.write_u8(`\n`) }
			`r` { result.write_u8(`\r`) }
			`t` { result.write_u8(`\t`) }
			`u` {
				mut codepoint := decode_hex_quad(raw, pos)!
				pos += 4
				if codepoint >= 0xd800 && codepoint <= 0xdbff {
					if pos + 6 > raw.len - 1 || raw[pos] != `\\` || raw[pos + 1] != `u` {
						return error('high unicode surrogate has no low surrogate')
					}
					low := decode_hex_quad(raw, pos + 2)!
					if low < 0xdc00 || low > 0xdfff {
						return error('invalid low unicode surrogate')
					}
					pos += 6
					high := codepoint - 0xd800
					codepoint = 0x10000 + (high << 10) + (low - 0xdc00)
				} else if codepoint >= 0xdc00 && codepoint <= 0xdfff {
					return error('low unicode surrogate has no high surrogate')
				}
				result.write_rune(rune(codepoint))
			}
			else {
				return error('invalid JSON escape')
			}
		}
	}
	return result.str()
}

fn encode_json_string(value string) string {
	mut result := strings.new_builder(value.len + 2)
	result.write_u8(`"`)
	for ch in value.bytes() {
		match ch {
			`"` { result.write_string('\\"') }
			`\\` { result.write_string('\\\\') }
			8 { result.write_string('\\b') }
			12 { result.write_string('\\f') }
			`\n` { result.write_string('\\n') }
			`\r` { result.write_string('\\r') }
			`\t` { result.write_string('\\t') }
			else {
				if ch < 0x20 {
					result.write_string('\\u00')
					result.write_u8(hex_lower(ch >> 4))
					result.write_u8(hex_lower(ch & 0x0f))
				} else {
					result.write_u8(ch)
				}
			}
		}
	}
	result.write_u8(`"`)
	return result.str()
}

fn decode_hex_quad(raw string, start int) !u32 {
	if start + 4 > raw.len {
		return error('incomplete JSON unicode escape')
	}
	mut value := u32(0)
	for pos in start .. start + 4 {
		digit := hex_value(raw[pos]) or { return error('invalid JSON unicode escape') }
		value = (value << 4) | u32(digit)
	}
	return value
}

fn (mut cursor JsonCursor) parse_value() ! {
	if cursor.pos >= cursor.text.len {
		return error('missing JSON value')
	}
	match cursor.text[cursor.pos] {
		`"` { cursor.parse_string()! }
		`{` { cursor.parse_object()! }
		`[` { cursor.parse_array()! }
		`t` { cursor.take_literal('true')! }
		`f` { cursor.take_literal('false')! }
		`n` { cursor.take_literal('null')! }
		else { cursor.parse_number()! }
	}
}

fn (mut cursor JsonCursor) parse_object() ! {
	cursor.pos++
	cursor.skip_space()
	if cursor.take_if(`}`) {
		return
	}
	for {
		cursor.skip_space()
		cursor.parse_string()!
		cursor.skip_space()
		if !cursor.take_if(`:`) {
			return error('expected JSON object colon')
		}
		cursor.skip_space()
		cursor.parse_value()!
		cursor.skip_space()
		if cursor.take_if(`}`) {
			return
		}
		if !cursor.take_if(`,`) {
			return error('expected JSON object comma')
		}
	}
}

fn (mut cursor JsonCursor) parse_array() ! {
	cursor.pos++
	cursor.skip_space()
	if cursor.take_if(`]`) {
		return
	}
	for {
		cursor.skip_space()
		cursor.parse_value()!
		cursor.skip_space()
		if cursor.take_if(`]`) {
			return
		}
		if !cursor.take_if(`,`) {
			return error('expected JSON array comma')
		}
	}
}

fn (mut cursor JsonCursor) parse_string() ! {
	if !cursor.take_if(`"`) {
		return error('expected JSON string')
	}
	for cursor.pos < cursor.text.len {
		ch := cursor.text[cursor.pos]
		cursor.pos++
		if ch == `"` {
			return
		}
		if ch < 0x20 {
			return error('control character in JSON string')
		}
		if ch != `\\` {
			continue
		}
		if cursor.pos >= cursor.text.len {
			return error('unterminated JSON escape')
		}
		escape := cursor.text[cursor.pos]
		cursor.pos++
		if escape == `u` {
			codepoint := cursor.parse_hex_quad()!
			if codepoint >= 0xd800 && codepoint <= 0xdbff {
				if cursor.pos + 2 > cursor.text.len || cursor.text[cursor.pos] != `\\`
					|| cursor.text[cursor.pos + 1] != `u` {
					return error('high unicode surrogate has no low surrogate')
				}
				cursor.pos += 2
				low := cursor.parse_hex_quad()!
				if low < 0xdc00 || low > 0xdfff {
					return error('invalid low unicode surrogate')
				}
			} else if codepoint >= 0xdc00 && codepoint <= 0xdfff {
				return error('low unicode surrogate has no high surrogate')
			}
		} else if escape !in [`"`, `\\`, `/`, `b`, `f`, `n`, `r`, `t`] {
			return error('invalid JSON escape')
		}
	}
	return error('unterminated JSON string')
}

fn (mut cursor JsonCursor) parse_hex_quad() !u32 {
	if cursor.pos + 4 > cursor.text.len {
		return error('incomplete JSON unicode escape')
	}
	mut value := u32(0)
	for _ in 0 .. 4 {
		digit := hex_value(cursor.text[cursor.pos]) or {
			return error('invalid JSON unicode escape')
		}
		value = (value << 4) | u32(digit)
		cursor.pos++
	}
	return value
}

fn (mut cursor JsonCursor) parse_number() ! {
	start := cursor.pos
	if cursor.take_if(`-`) && cursor.pos >= cursor.text.len {
		return error('invalid JSON number')
	}
	if cursor.take_if(`0`) {
		if cursor.pos < cursor.text.len && is_ascii_digit(cursor.text[cursor.pos]) {
			return error('invalid JSON number')
		}
	} else {
		if cursor.pos >= cursor.text.len || cursor.text[cursor.pos] < `1`
			|| cursor.text[cursor.pos] > `9` {
			return error('invalid JSON number')
		}
		for cursor.pos < cursor.text.len && is_ascii_digit(cursor.text[cursor.pos]) {
			cursor.pos++
		}
	}
	if cursor.take_if(`.`) {
		if cursor.pos >= cursor.text.len || !is_ascii_digit(cursor.text[cursor.pos]) {
			return error('invalid JSON number')
		}
		for cursor.pos < cursor.text.len && is_ascii_digit(cursor.text[cursor.pos]) {
			cursor.pos++
		}
	}
	if cursor.pos < cursor.text.len && cursor.text[cursor.pos] in [`e`, `E`] {
		cursor.pos++
		if cursor.pos < cursor.text.len && cursor.text[cursor.pos] in [`+`, `-`] {
			cursor.pos++
		}
		if cursor.pos >= cursor.text.len || !is_ascii_digit(cursor.text[cursor.pos]) {
			return error('invalid JSON number')
		}
		for cursor.pos < cursor.text.len && is_ascii_digit(cursor.text[cursor.pos]) {
			cursor.pos++
		}
	}
	if cursor.pos == start {
		return error('invalid JSON value')
	}
}

fn (mut cursor JsonCursor) take_literal(value string) ! {
	if cursor.pos + value.len > cursor.text.len
		|| cursor.text[cursor.pos..cursor.pos + value.len] != value {
		return error('invalid JSON literal')
	}
	cursor.pos += value.len
}

fn (mut cursor JsonCursor) take_if(ch u8) bool {
	if cursor.pos < cursor.text.len && cursor.text[cursor.pos] == ch {
		cursor.pos++
		return true
	}
	return false
}

fn (mut cursor JsonCursor) skip_space() {
	for cursor.pos < cursor.text.len && is_json_space(cursor.text[cursor.pos]) {
		cursor.pos++
	}
}

fn is_json_space(ch u8) bool {
	return ch in [` `, `\t`, `\r`, `\n`]
}

fn is_ascii_digit(ch u8) bool {
	return ch >= `0` && ch <= `9`
}

fn hex_value(ch u8) ?u8 {
	if ch >= `0` && ch <= `9` {
		return u8(ch - `0`)
	}
	if ch >= `a` && ch <= `f` {
		return u8(ch - `a` + 10)
	}
	if ch >= `A` && ch <= `F` {
		return u8(ch - `A` + 10)
	}
	return none
}

fn hex_lower(value u8) u8 {
	return if value < 10 { `0` + value } else { `a` + value - 10 }
}
