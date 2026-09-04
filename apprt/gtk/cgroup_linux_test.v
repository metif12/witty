module gtk

fn test_cgroup_uint32_array_variant_type() {
	value := new_uint32_array(123)
	assert unsafe { cstring_to_vstring(C.g_variant_get_type_string(value)) } == 'au'
	C.g_variant_unref(value)
}

fn test_cgroup_systemd_properties_are_tuple_array() {
	value := new_property_array('Delegate', C.g_variant_new_boolean(1))
	assert unsafe { cstring_to_vstring(C.g_variant_get_type_string(value)) } == 'a(sv)'
	C.g_variant_unref(value)
}
