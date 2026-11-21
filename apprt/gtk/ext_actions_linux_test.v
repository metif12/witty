module gtk

fn test_action_name_validation_matches_gio_contract() {
	assert action_name_is_valid('ring-bell')
	assert action_name_is_valid('app.present-surface2')
	assert !action_name_is_valid('')
	assert !action_name_is_valid('ring_bell')
}

fn test_action_initializers_preserve_descriptor_fields() {
	callback := GCallback(unsafe { nil })
	parameter_type := GVariantType(voidptr(uint(1)))
	state := GVariant(voidptr(uint(2)))

	plain := Action.init('plain', callback, parameter_type)
	assert plain.name == 'plain'
	assert plain.callback == callback
	assert plain.parameter_type == parameter_type
	assert isnil(plain.state)

	stateful := Action.init_stateful('stateful', callback, parameter_type, state)
	assert stateful.name == 'stateful'
	assert stateful.callback == callback
	assert stateful.parameter_type == parameter_type
	assert stateful.state == state
}
