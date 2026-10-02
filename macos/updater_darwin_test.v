@[has_globals]
module macos

import os

#insert "@VMODROOT/macos/updater_test_abi.h"
fn C.witty_update_test_block(kind int) voidptr
fn C.witty_update_test_count() int
fn C.witty_update_test_value() int
fn C.witty_update_test_reset()
fn C.witty_update_test_object() ObjId

fn audit_load_sparkle() {
	path := os.getenv_opt('WITTY_SPARKLE_TEST_FRAMEWORK') or {
		os.join_path(@VMODROOT, '.witty-build', 'native', 'Sparkle.xcframework', 'macos-arm64_x86_64', 'Sparkle.framework')
	}
	bundle := msg_id1(get_class('NSBundle'), 'bundleWithPath:', nsstring(path))
	assert msg_bool(bundle, 'load')
}

fn test_original_update_state_text_equality_and_cancel_rules() {
	assert UpdateState{}.text() == ''
	assert UpdateState{kind: .permission_request}.text() == 'Enable Automatic Updates?'
	assert UpdateState{kind: .checking}.is_installable()
	assert !UpdateState{kind: .not_found}.is_installable()
	assert UpdateState{kind: .update_available, version: '1.3.0'}.text() == 'Update Available: 1.3.0'
	assert UpdateState{kind: .downloading, expected_length: 200, downloaded: 25}.text() == 'Downloading: 12%'
	assert UpdateState{kind: .downloading, expected_length: 0}.text() == 'Downloading…'
	assert UpdateState{kind: .extracting, extraction_progress: 0.5}.text() == 'Preparing: 50%'
	assert UpdateState{kind: .installing, auto_update: true}.text() == 'Restart to Complete Update'
	assert UpdateState{kind: .extracting, extraction_progress: 1.5}.badge()? == '150%'
	assert UpdateState{kind: .update_available, version: '1.3.0'}.equals(UpdateState{kind: .update_available, version: '1.3.0'})
	assert !UpdateState{kind: .error, error_description: 'a'}.equals(UpdateState{kind: .error, error_description: 'b'})
	assert !UpdateState{kind: .downloading, expected_length: none}.equals(UpdateState{kind: .downloading, expected_length: 0})
	C.witty_update_test_reset()
	choice := UpdateCallback{call: update_native_choice, context: C.witty_update_test_block(1)}
	UpdateState{kind: .update_available, reply: choice}.cancel()
	assert C.witty_update_test_value() == int(UpdateChoice.dismiss)
	UpdateState{kind: .update_available, reply: choice}.confirm()
	assert C.witty_update_test_value() == int(UpdateChoice.install)
	UpdateState{kind: .extracting, reply: choice}.confirm()
	assert C.witty_update_test_count() == 2
}

fn test_original_release_note_regex_order_and_urls() {
	url, label := update_release_notes('1.3.0', 'deadbeef')
	assert url == 'https://ghostty.org/docs/install/release-notes/1-3-0'
	assert label == 'View Release Notes'
	compare, _ := update_release_notes('1.3.0+abcdef123', 'deadbeef')
	assert compare == 'https://github.com/ghostty-org/ghostty/compare/deadbeef...abcdef123'
	commit, _ := update_release_notes('tip-abcdef123', '')
	assert commit == 'https://github.com/ghostty-org/ghostty/commit/abcdef123'
	missing, _ := update_release_notes('unversioned', '')
	assert missing == ''
}

fn test_native_update_install_chain_and_protocol_driver_callbacks() {
	app_init()
	audit_load_sparkle()
	view := create_window(640, 480, 'Updater audit')
	apply_native_window_config(view, NativeWindowConfig{}, true, 0, 1, false)
	// Use the real runtime-registered protocol implementation. Native blocks below
	// stand in only for the callbacks Sparkle hands to its SPUUserDriver.
	driver := msg_id(msg_id(register_update_driver(), 'alloc'), 'init')
	g_update_controller = &NativeUpdateController{driver: driver}
	defer { stop_native_updater(); close_tab(view) }
	C.witty_update_test_reset()
	block := ObjId(C.witty_update_test_block(1))
	update_show_checking(driver, sel(''), ObjId(C.witty_update_test_block(0)))
	native_update_install()
	assert g_update_controller.is_installing()
	assert !termination_requires_confirmation(true)
	update_show_found(driver, sel(''), nil_obj(), nil_obj(), block)
	assert C.witty_update_test_count() == 1
	assert C.witty_update_test_value() == int(UpdateChoice.install)
	update_show_downloading(driver, sel(''), ObjId(C.witty_update_test_block(0)))
	update_download_expected(driver, sel(''), 100)
	update_download_received(driver, sel(''), 42)
	assert native_update_text() == 'Downloading: 42%'
	update_download_expected(driver, sel(''), 200)
	assert native_update_text() == 'Downloading: 0%'
	update_start_extracting(driver, sel(''))
	update_extracting_progress(driver, sel(''), 0.75)
	assert native_update_text() == 'Preparing: 75%'
	update_show_ready(driver, sel(''), block)
	assert C.witty_update_test_count() == 2
	assert update_install_on_quit(driver, sel(''), nil_obj(), nil_obj(), ObjId(C.witty_update_test_block(0)))
	assert native_update_text() == 'Restart to Complete Update'
	update_show_installing(driver, sel(''), false, ObjId(C.witty_update_test_block(0)))
	assert native_update_text() == 'Installing…'
	update_show_error(driver, sel(''), nil_obj(), ObjId(C.witty_update_test_block(0)))
	assert !g_update_controller.is_installing()
	assert !g_update_is_installing
	assert C.witty_update_test_count() == 3
	assert g_update_controller.pills.len == 1
	update_pill_action(driver, sel(''), g_update_controller.pills[u64(view_window(view))])
	assert msg_bool(g_update_controller.popover, 'isShown')
	assert native_update_is_available() == false
	update_will_relaunch(driver, sel(''), nil_obj())
	update_dismiss_installation(driver, sel(''))
	assert native_update_text() == ''
	// The source's cancel retains its canceled installCancellable optional.
	update_show_checking(driver, sel(''), ObjId(C.witty_update_test_block(0)))
	native_update_install()
	g_update_controller.check_for_updates()
	g_update_controller.set_state(UpdateState{})
	assert g_update_controller.is_installing()
}

fn test_permission_reply_publishes_idle_before_native_response() {
	app_init()
	// Load the actual pinned Sparkle framework so the permission response is the
	// native SUUpdatePermissionResponse, rather than a test replacement class.
	audit_load_sparkle()
	driver := msg_id(msg_id(register_update_driver(), 'alloc'), 'init')
	g_update_controller = &NativeUpdateController{driver: driver}
	defer { stop_native_updater() }
	g_update_controller.set_state(UpdateState{kind: .permission_request, reply: UpdateCallback{call: update_native_permission, context: C.witty_update_test_block(2)}})
	g_update_controller.state.reply.invoke(1)
	assert g_update_controller.state.kind == .idle
	response := C.witty_update_test_object()
	assert msg_bool(response, 'automaticUpdateChecks')
	assert !msg_bool(response, 'sendSystemProfile')
	msg_void(response, 'release')
}
