module themepkg

import os

fn test_location_user_uses_translated_xdg_resolution() {
	previous_xdg := os.getenv_opt('XDG_CONFIG_HOME')
	previous_home := os.getenv_opt('HOME')
	defer {
		if value := previous_xdg {
			os.setenv('XDG_CONFIG_HOME', value, true)
		} else {
			os.unsetenv('XDG_CONFIG_HOME')
		}
		if value := previous_home {
			os.setenv('HOME', value, true)
		} else {
			os.unsetenv('HOME')
		}
	}

	os.setenv('XDG_CONFIG_HOME', '/tmp/witty-theme-xdg', true)
	assert Location.user.dir() == os.join_path('/tmp/witty-theme-xdg', 'ghostty', 'themes')

	os.unsetenv('XDG_CONFIG_HOME')
	os.setenv('HOME', '/tmp/witty-theme-home/', true)
	assert Location.user.dir() == os.join_path('/tmp/witty-theme-home/', '.config', 'ghostty', 'themes')
}

fn test_location_iterator_order_and_reset() {
	previous_xdg := os.getenv_opt('XDG_CONFIG_HOME')
	defer {
		if value := previous_xdg {
			os.setenv('XDG_CONFIG_HOME', value, true)
		} else {
			os.unsetenv('XDG_CONFIG_HOME')
		}
	}
	os.setenv('XDG_CONFIG_HOME', '/tmp/witty-theme-iterator', true)

	mut it := LocationIterator.new()
	first := it.next() or { panic('missing user theme location') }
	assert first.location == .user
	assert first.dir == os.join_path('/tmp/witty-theme-iterator', 'ghostty', 'themes')
	it.reset()
	assert (it.next() or { panic('missing reset user theme location') }).location == .user
}
