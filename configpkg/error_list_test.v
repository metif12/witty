module configpkg

fn test_error_list_empty_and_add() {
	mut errors := ErrorList{}
	assert errors.empty()
	errors.add(ConfigError{
		message: 'invalid configuration'
	})
	assert !errors.empty()
	assert errors.list == [ConfigError{
		message: 'invalid configuration'
	}]
}
