module crash

fn test_envelope_item_type_source_layout_and_ordinals() {
	assert sizeof(ItemType) == 1
	mut item_count := 0
	$for enum_value in ItemType.values {
		assert u8(enum_value.value) == u8(item_count)
		item_count++
	}
	assert item_count == 14
	assert u8(ItemType.unknown) == 0
	assert u8(ItemType.check_in) == 13
}

fn test_envelope_parse_empty() {
	mut envelope := Envelope.parse('{}'.bytes())!
	defer { envelope.deinit() }
	assert envelope.items.len == 0
	assert envelope.serialize()!.bytestr() == '{}\n'
}

fn test_envelope_parse_session() {
	data := '{}\n{"type":"session","length":2}\n{}'.bytes()
	mut envelope := Envelope.parse(data)!
	defer { envelope.deinit() }
	assert envelope.items.len == 1
	assert envelope.items[0].item_type() == .session
}

fn test_envelope_parse_multiple_and_decode_attachment() {
	data := '{}\n{"type":"session"}\n{}\n{"type":"attachment","length":4,"filename":"test.txt"}\nABCD'.bytes()
	mut envelope := Envelope.parse(data)!
	defer { envelope.deinit() }
	assert envelope.items.len == 2
	assert envelope.items[0].item_type() == .session
	assert envelope.items[1].item_type() == .attachment

	mut attachment_item := envelope.items[1]
	attachment_item.decode()!
	envelope.items[1] = attachment_item
	match attachment_item {
		Attachment {
			assert attachment_item.filename == 'test.txt'
			assert attachment_item.payload == 'ABCD'.bytes()
		}
		else {
			assert false, 'attachment was not decoded'
		}
	}

	serialized := envelope.serialize()!
	assert serialized.bytestr().trim('\n') == data.bytestr().trim('\n')
}

fn test_envelope_parse_unknown_type() {
	mut envelope := Envelope.parse('{}\n{"type":"future"}\ndata'.bytes())!
	defer { envelope.deinit() }
	assert envelope.items[0].item_type() == .unknown
}

fn test_envelope_preserves_and_minifies_arbitrary_headers() {
	data := '{ "dsn": "x", "meta": { "values": [1, true, null], "label": "a b" } }\n{"type":"session","length":2,"extra":{"nested":true}}\n{}'.bytes()
	mut envelope := Envelope.parse(data)!
	defer { envelope.deinit() }
	assert envelope.headers.get_string('dsn')! == 'x'
	assert envelope.headers.get_raw('meta')? == '{"values":[1,true,null],"label":"a b"}'
	assert envelope.serialize()!.bytestr() == '{"dsn":"x","meta":{"values":[1,true,null],"label":"a b"}}\n{"type":"session","length":2,"extra":{"nested":true}}\n{}'
}

fn test_envelope_attachment_json_string_escapes() {
	data := '{}\n{"type":"attachment","length":1,"filename":"snowman-\\u2603-\\uD83D\\uDE00","attachment_type":"event.attachment"}\nx'.bytes()
	mut envelope := Envelope.parse(data)!
	defer { envelope.deinit() }
	mut item := envelope.items[0]
	item.decode()!
	match item {
		Attachment {
			assert item.filename == 'snowman-☃-😀'
			assert item.typ? == 'event.attachment'
		}
		else {
			assert false, 'attachment was not decoded'
		}
	}
}

fn test_attachment_public_encode_contract() {
	mut headers := ObjectMapUnmanaged{}
	headers.set_raw('extra', 'true')!
	mut attachment := Attachment{
		filename:      'report.dmp'
		typ:           'event.attachment'
		headers_extra: headers
		payload:       'data'.bytes()
	}
	encoded := attachment.encode()!
	assert encoded.typ == .attachment
	assert encoded.payload == 'data'.bytes()
	assert encoded.headers.get_string('filename')! == 'report.dmp'
	assert encoded.headers.get_string('attachment_type')! == 'event.attachment'
	assert encoded.headers.get_raw('extra')? == 'true'

	attachment.typ = none
	encoded_without_type := attachment.encode()!
	assert encoded_without_type.headers.get_raw('attachment_type') == none
}

fn test_envelope_rejects_malformed_json_headers() {
	for data in ['[]', '{"nested":[1,]}', '{"bad":"\\uD800"}'] {
		if _ := Envelope.parse(data.bytes()) {
			assert false, 'malformed envelope header was accepted: ${data}'
		}
	}
	for length in ['-1', '1.5', '1e2', '9223372036854775808', '18446744073709551616'] {
		if _ := Envelope.parse('{}\n{"type":"session","length":${length}}\nx'.bytes()) {
			assert false, 'malformed item length was accepted: ${length}'
		} else {
			assert err.msg() == 'envelope item length is malformed'
		}
	}
}

fn test_envelope_rejects_short_and_unframed_payloads() {
	if _ := Envelope.parse('{}\n{"type":"attachment","length":4}\nABC'.bytes()) {
		assert false, 'short payload was accepted'
	}
	if _ := Envelope.parse('{}\n{"type":"attachment","length":3}\nABCx'.bytes()) {
		assert false, 'payload without newline was accepted'
	}
}
