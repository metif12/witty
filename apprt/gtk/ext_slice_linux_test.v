module gtk

fn test_string_list_create_owns_copies() {
	mut input := ['hello', 'world']
	mut list := StringList.create(input)
	input[0] = 'changed'
	assert list.strings == ['hello', 'world']
	list.destroy()
	assert list.strings.len == 0
}

fn test_string_list_boxed_copy_is_deep() {
	mut original := StringList.create(['foo', 'bar', 'baz'])
	mut copied := unsafe { &StringList(string_list_boxed_copy(voidptr(original))) }
	assert copied.strings == original.strings
	copied.strings[0] = 'changed'
	assert original.strings[0] == 'foo'
	string_list_boxed_free(voidptr(copied))
	original.destroy()
}

fn test_string_list_registers_boxed_type() {
	assert StringList.get_gobject_type() != GType(0)
	assert StringList.get_gobject_type() == StringList.get_gobject_type()
}
