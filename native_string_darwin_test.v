module main

import apprt
import macos

#insert "@VMODROOT/native_string_darwin_test_abi.h"

fn C.witty_native_string_test_pump(delay f64)

fn native_string_target(state &TermState) apprt.SurfaceTarget {
	runtime := &apprt.Surface{
		userdata: voidptr(state)
	}
	core := &apprt.CoreSurface{
		runtime_surface: voidptr(runtime)
	}
	return apprt.SurfaceTarget{
		surface: voidptr(core)
	}
}

fn test_native_action_strings_preserve_source_decoding_boundaries() {
	macos.app_init()
	view := macos.create_window(640, 480, 'native string boundaries')
	mut actions := macos.new_action_surface(view, unsafe { nil }, macos.ActionCallbacks{})
	state := &TermState{
		view:    view
		actions: actions
	}
	target := native_string_target(state)
	defer {
		actions.deinit()
		macos.close_tab(view)
	}
	invalid := [u8(0xff)].bytestr()
	actions.title = 'before'
	assert runtime_action(unsafe { nil }, target, apprt.RuntimeAction{
		action: .set_title
		data:   apprt.SetTitle{
			title: invalid
		}
	})
	C.witty_native_string_test_pump(0.1)
	assert actions.title == 'before'
	assert runtime_action(unsafe { nil }, target, apprt.RuntimeAction{
		action: .set_title
		data:   apprt.SetTitle{
			title: [u8(0x6f), 0x6b, 0, 0xff].bytestr()
		}
	})
	C.witty_native_string_test_pump(0.1)
	assert actions.title == 'ok'
	actions.set_pwd('/preserved', false)
	assert runtime_action(unsafe { nil }, target, apprt.RuntimeAction{
		action: .pwd
		data:   apprt.PwdValue{
			pwd: invalid
		}
	})
	assert actions.pwd or { '' } == '/preserved'
	// Invalid notification strings must return before accessing authorization
	// or settings, as in App.showDesktopNotification's two UTF-8 guards.
	for notification in [apprt.DesktopNotificationValue{ title: invalid, body: 'body' },
		apprt.DesktopNotificationValue{ title: 'title', body: invalid }] {
		assert runtime_action(unsafe { nil }, target, apprt.RuntimeAction{
			action: .desktop_notification
			data:   notification
		})
	}
	assert actions.notification_identifiers.len == 0
	assert runtime_action(unsafe { nil }, target, apprt.RuntimeAction{
		action: .start_search
		data:   apprt.StartSearch{
			needle: invalid
		}
	})
	assert actions.search_active
	assert actions.search_needle == '�'
	assert runtime_action(unsafe { nil }, target, apprt.RuntimeAction{
		action: .key_table
		data:   apprt.KeyTable(apprt.KeyTableActivate{
			name: invalid
		})
	})
	assert actions.key_tables == ['']
	name := [u8(0x74), 0, 0xcf, 0x80].bytestr()
	assert runtime_action(unsafe { nil }, target, apprt.RuntimeAction{
		action: .key_table
		data:   apprt.KeyTable(apprt.KeyTableActivate{
			name: name
		})
	})
	assert actions.key_tables == ['', name]
	assert runtime_action(unsafe { nil }, target, apprt.RuntimeAction{
		action: .mouse_over_link
		data:   apprt.MouseOverLink{
			url: invalid
		}
	})
}
