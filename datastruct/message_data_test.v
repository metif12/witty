module datastruct

fn test_message_data_tag_source_layout_and_ordinals() {
	assert sizeof(MessageDataKind) == 1
	assert u8(MessageDataKind.small) == 0
	assert u8(MessageDataKind.stable) == 1
	assert u8(MessageDataKind.alloc) == 2
}

fn test_message_data_init_small() {
	mut input := 'hello!'.bytes()
	data := MessageData.init[u8](10, input)
	assert data is MessageDataSmall[u8]
	assert data.kind() == .small
	assert data.slice().bytestr() == 'hello!'
	input[0] = `j`
	assert data.slice().bytestr() == 'hello!'
}

fn test_message_data_init_alloc() {
	mut input := ('hello! '.repeat(100)).bytes()
	mut data := MessageData.init[u8](10, input)
	assert data is MessageDataAlloc[u8]
	assert data.kind() == .alloc
	assert data.slice() == input
	input[0] = `j`
	assert data.slice()[0] == `h`
	data.deinit()
	assert data.slice().len == 0
}

fn test_message_data_small_fits_large_inline_limit() {
	input := 'X'.repeat(500).bytes()
	data := MessageData.init[u8](500, input)
	assert data is MessageDataSmall[u8]
	assert data.kind() == .small
	assert data.slice() == input
}

fn test_message_data_stable_preserves_backing_storage() {
	mut input := 'stable'.bytes()
	data := MessageData.from_stable[u8](input)
	assert data is MessageDataStable[u8]
	assert data.kind() == .stable
	input[0] = `S`
	assert data.slice().bytestr() == 'Stable'
}
