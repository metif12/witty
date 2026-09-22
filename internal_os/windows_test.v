module internal_os

fn test_proc_thread_attribute_value_matches_winbase_layout() {
	assert sizeof(ProcThreadAttributeNumber) == 4
	assert u32(ProcThreadAttributeNumber.pseudo_console) == 22
	assert proc_thread_attribute_value(.pseudo_console, false, false, false) == u32(0x00000016)
	assert proc_thread_attribute_value(.pseudo_console, true, false, false) == u32(0x00010016)
	assert proc_thread_attribute_value(.pseudo_console, false, true, false) == u32(0x00020016)
	assert proc_thread_attribute_value(.pseudo_console, false, false, true) == u32(0x00040016)
	assert proc_thread_attribute_value(.pseudo_console, true, true, true) == u32(0x00070016)
	assert proc_thread_attribute_pseudoconsole == u32(0x00020016)
}

fn test_proc_thread_attribute_value_masks_unknown_number_bits() {
	attribute := unsafe { ProcThreadAttributeNumber(u32(0xabcd0016)) }
	assert proc_thread_attribute_value(attribute, false, true, false) == u32(0x00020016)
}
