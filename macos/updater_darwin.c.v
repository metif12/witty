@[has_globals]
module macos

import os

#insert "@VMODROOT/macos/updater_abi.h"
fn C.witty_update_block_copy(block voidptr) voidptr
fn C.witty_update_block_release(block voidptr)
fn C.witty_update_block_void(block voidptr)
fn C.witty_update_block_choice(block voidptr, value int)
fn C.witty_update_block_object(block voidptr, value voidptr)
fn C.witty_update_init(object ObjId, host ObjId, application ObjId, driver ObjId, delegate ObjId) ObjId
fn C.witty_update_start(object ObjId, error &ObjId) bool
fn C.witty_update_message_bool_object(object ObjId, selector Sel, value bool, other ObjId)
fn C.witty_update_permission(checks bool) ObjId
fn C.witty_update_regex(text ObjId, pattern ObjId) ObjId
fn C.witty_update_blend(color ObjId, fraction f64, other ObjId) ObjId
fn C.witty_update_text_width(text ObjId, font ObjId) f64
fn C.witty_update_message3(object ObjId, selector Sel, a ObjId, b ObjId, c ObjId)

@[heap]
pub struct NativeUpdateController {
pub mut:
	state UpdateState
mut:
	updater ObjId
	driver ObjId
	standard ObjId
	install_subscription bool
	install_listening bool
	channel string = 'stable'
	pills map[u64]ObjId
	popover ObjId
	reset_timer ObjId
}

__global ( g_update_controller &NativeUpdateController )

fn update_native_void(context voidptr, _value int) { C.witty_update_block_void(context) }
fn update_native_choice(context voidptr, value int) { C.witty_update_block_choice(context, value) }
fn update_native_permission(context voidptr, value int) {
	// The permission wrapper publishes idle before replying, as in UpdateDriver.
	block := C.witty_update_block_copy(context)
	defer { C.witty_update_block_release(block) }
	if g_update_controller != unsafe { nil } { g_update_controller.set_state(UpdateState{}) }
	response := C.witty_update_permission(value != 0)
	C.witty_update_block_object(block, response)
	msg_void(response, 'release')
}
fn update_dismiss(_context voidptr, _value int) {
	if g_update_controller != unsafe { nil } { g_update_controller.set_state(UpdateState{}) }
}
fn update_retry_start(_context voidptr, _value int) {
	if g_update_controller != unsafe { nil } {
		g_update_controller.set_state(UpdateState{})
		g_update_controller.start()
	}
}
fn update_retry_check(_context voidptr, _value int) {
	if g_update_controller != unsafe { nil } {
		g_update_controller.set_state(UpdateState{})
		dispatch_main(update_check_later, unsafe { nil })
	}
}
fn update_check_later(_context voidptr) {
	if g_update_controller != unsafe { nil } { msg_void(g_update_controller.updater, 'checkForUpdates') }
}

fn retained_update_callback(callback UpdateCallback) UpdateCallback {
	return UpdateCallback{call: callback.call, context: C.witty_update_block_copy(callback.context)}
}
fn retained_update_state(state UpdateState) UpdateState {
	return UpdateState{
		...state
		object: voidptr(msg_id(ObjId(state.object), 'retain'))
		cancel_callback: retained_update_callback(state.cancel_callback)
		reply: retained_update_callback(state.reply)
		acknowledgement: retained_update_callback(state.acknowledgement)
		retry: retained_update_callback(state.retry)
		dismiss: retained_update_callback(state.dismiss)
	}
}
fn release_update_state(state UpdateState) {
	msg_void(ObjId(state.object), 'release')
	for callback in [state.cancel_callback, state.reply, state.acknowledgement, state.retry, state.dismiss] {
		C.witty_update_block_release(callback.context)
	}
}

pub fn (controller &NativeUpdateController) is_installing() bool { return controller.install_subscription }

pub fn (mut controller NativeUpdateController) set_state(state UpdateState) {
	old := controller.state
	changed := !old.equals(state)
	controller.state = retained_update_state(state)
	if changed {
		msg_void(controller.reset_timer, 'invalidate')
		controller.reset_timer = nil_obj()
		if state.kind == .not_found {
			controller.reset_timer = ObjId(C.witty_action_timer(5, controller.driver,
				sel('resetNotFound:'), nil_obj(), false))
		}
	}
	controller.refresh_presentation()
	if controller.install_listening {
		if !state.is_installable() {
			controller.install_subscription = false
			controller.install_listening = false
			set_update_is_installing(false)
		} else {
			state.confirm()
		}
	}
	release_update_state(old)
}

pub fn (mut controller NativeUpdateController) install_update() {
	if !controller.state.is_installable() || controller.install_subscription { return }
	controller.install_subscription = true
	controller.install_listening = true
	set_update_is_installing(true)
	// Combine's Published sink immediately receives the current state.
	controller.state.confirm()
}

pub fn (mut controller NativeUpdateController) check_for_updates() {
	if controller.state.kind == .idle { msg_void(controller.updater, 'checkForUpdates'); return }
	// AnyCancellable.cancel() stops delivery but leaves the stored optional intact.
	// Preserve that distinction from the source rather than clearing isInstalling.
	controller.install_listening = false
	controller.state.cancel()
	dispatch_after(0.1, update_check_later, unsafe { nil })
}

pub fn (mut controller NativeUpdateController) start() {
	mut error := nil_obj()
	if C.witty_update_start(controller.updater, &error) { return }
	controller.set_state(UpdateState{
		kind: .error
		object: voidptr(error)
		error_description: objc_utf8_string(msg_id(error, 'localizedDescription'))
		retry: UpdateCallback{call: update_retry_start}
		dismiss: UpdateCallback{call: update_dismiss}
	})
}

pub fn (mut controller NativeUpdateController) deinit() {
	controller.install_listening = false
	controller.install_subscription = false
	set_update_is_installing(false)
	center := msg_id(get_class('NSNotificationCenter'), 'defaultCenter')
	msg_void1(center, 'removeObserver:', controller.driver)
	msg_void(controller.reset_timer, 'invalidate')
	msg_void(controller.popover, 'close')
	msg_void(controller.popover, 'release')
	for _, pill in controller.pills { msg_void(pill, 'removeFromSuperview'); msg_void(pill, 'release') }
	controller.pills.clear()
	release_update_state(controller.state)
	msg_void(controller.updater, 'release')
	msg_void(controller.standard, 'release')
	msg_void(controller.driver, 'release')
	if g_update_controller == &controller { g_update_controller = unsafe { nil } }
}

fn update_has_unobtrusive_target() bool {
	windows := msg_id(shared_app(), 'windows')
	for i in 0 .. int(msg_u64(windows, 'count')) {
		window := msg_id_u64(windows, 'objectAtIndex:', u64(i))
		if native_window_data(window) != none && msg_bool(window, 'isVisible') { return true }
	}
	return false
}

fn register_update_driver() ObjId {
	mut cls := get_class('WittyUpdateDriver')
	if !is_nil(cls) { return cls }
	cls = C.macos_objc_allocate_class_pair(get_class('NSObject'), cstr('WittyUpdateDriver'), 0)
	for name in ['SPUUserDriver', 'SPUUpdaterDelegate'] {
		protocol := get_protocol(name)
		if !is_nil(protocol) { C.macos_class_add_protocol(cls, protocol) }
	}
	add_method(cls, 'showUpdatePermissionRequest:reply:', voidptr(update_show_permission), 'v@:@@')
	add_method(cls, 'showUserInitiatedUpdateCheckWithCancellation:', voidptr(update_show_checking), 'v@:@')
	add_method(cls, 'showUpdateFoundWithAppcastItem:state:reply:', voidptr(update_show_found), 'v@:@@@')
	add_method(cls, 'showUpdateReleaseNotesWithDownloadData:', voidptr(update_ignore_release_notes), 'v@:@')
	add_method(cls, 'showUpdateReleaseNotesFailedToDownloadWithError:', voidptr(update_ignore_release_notes), 'v@:@')
	add_method(cls, 'showUpdateNotFoundWithError:acknowledgement:', voidptr(update_show_not_found), 'v@:@@')
	add_method(cls, 'showUpdaterError:acknowledgement:', voidptr(update_show_error), 'v@:@@')
	add_method(cls, 'showDownloadInitiatedWithCancellation:', voidptr(update_show_downloading), 'v@:@')
	add_method(cls, 'showDownloadDidReceiveExpectedContentLength:', voidptr(update_download_expected), 'v@:Q')
	add_method(cls, 'showDownloadDidReceiveDataOfLength:', voidptr(update_download_received), 'v@:Q')
	add_method(cls, 'showDownloadDidStartExtractingUpdate', voidptr(update_start_extracting), 'v@:')
	add_method(cls, 'showExtractionReceivedProgress:', voidptr(update_extracting_progress), 'v@:d')
	add_method(cls, 'showReadyToInstallAndRelaunch:', voidptr(update_show_ready), 'v@:@')
	add_method(cls, 'showInstallingUpdateWithApplicationTerminated:retryTerminatingApplication:', voidptr(update_show_installing), 'v@:B@')
	add_method(cls, 'showUpdateInstalledAndRelaunched:acknowledgement:', voidptr(update_show_installed), 'v@:B@')
	add_method(cls, 'showUpdateInFocus', voidptr(update_show_focus), 'v@:')
	add_method(cls, 'dismissUpdateInstallation', voidptr(update_dismiss_installation), 'v@:')
	add_method(cls, 'feedURLStringForUpdater:', voidptr(update_feed_url), '@@:@')
	add_method(cls, 'updater:willInstallUpdateOnQuit:immediateInstallationBlock:', voidptr(update_install_on_quit), 'B@:@@@')
	add_method(cls, 'updaterWillRelaunchApplication:', voidptr(update_will_relaunch), 'v@:@')
	add_method(cls, 'terminalWindowWillClose:', voidptr(update_terminal_will_close), 'v@:@')
	add_method(cls, 'refreshWindows:', voidptr(update_refresh_windows), 'v@:@')
	add_method(cls, 'resetNotFound:', voidptr(update_reset_not_found), 'v@:@')
	add_method(cls, 'checkForUpdates:', voidptr(update_check_action), 'v@:@')
	add_method(cls, 'installUpdate:', voidptr(update_install_action), 'v@:@')
	add_method(cls, 'validateMenuItem:', voidptr(update_validate_menu), 'B@:@')
	add_method(cls, 'pill:', voidptr(update_pill_action), 'v@:@')
	add_method(cls, 'popoverAction:', voidptr(update_popover_action), 'v@:@')
	C.macos_objc_register_class_pair(cls)
	return cls
}

// Sparkle remains the original native dependency. Resolve it from the app bundle
// (production), or its managed source build cache when running from the repository.
pub fn start_native_updater(cfg NativeUpdateConfig) ! {
	if g_update_controller != unsafe { nil } { sync_native_updater_config(cfg); return }
	host := msg_id(get_class('NSBundle'), 'mainBundle')
	if is_nil(get_class('SPUUpdater')) {
		frameworks := objc_utf8_string(msg_id(host, 'privateFrameworksPath'))
		mut path := os.join_path(frameworks, 'Sparkle.framework')
		if !os.exists(path) {
			path = os.join_path(@VMODROOT, '.witty-build', 'native', 'Sparkle.xcframework',
				'macos-arm64_x86_64', 'Sparkle.framework')
		}
		bundle := msg_id1(get_class('NSBundle'), 'bundleWithPath:', nsstring(path))
		if is_nil(bundle) || !msg_bool(bundle, 'load') { return error('Unable to load the pinned Sparkle framework: ${path}') }
	}
	driver := msg_id(msg_id(register_update_driver(), 'alloc'), 'init')
	standard := msg_id2(alloc('SPUStandardUserDriver'), 'initWithHostBundle:delegate:', host, nil_obj())
	updater := C.witty_update_init(alloc('SPUUpdater'), host, host, driver, driver)
	if is_nil(updater) { msg_void(driver, 'release'); msg_void(standard, 'release'); return error('Unable to initialize Sparkle updater') }
	g_update_controller = &NativeUpdateController{updater: updater, driver: driver, standard: standard}
	center := msg_id(get_class('NSNotificationCenter'), 'defaultCenter')
	C.witty_macos_observe(center, driver, sel('terminalWindowWillClose:'), nsstring('NSWindowWillCloseNotification'), nil_obj())
	for event in ['NSWindowDidBecomeVisibleNotification', 'NSWindowDidBecomeKeyNotification', 'NSWindowDidResizeNotification'] {
		C.witty_macos_observe(center, driver, sel('refreshWindows:'), nsstring(event), nil_obj())
	}
	install_update_menu()
	sync_native_updater_config(cfg)
	g_update_controller.start()
}

pub fn sync_native_updater_config(cfg NativeUpdateConfig) {
	if g_update_controller == unsafe { nil } { return }
	g_update_controller.channel = cfg.channel
	host := msg_id(get_class('NSBundle'), 'mainBundle')
	info := msg_id(host, 'infoDictionary')
	automatic := msg_id1(info, 'objectForKey:', nsstring('SUEnableAutomaticChecks'))
	if !is_nil(automatic) && !msg_bool(automatic, 'boolValue') {
		msg_void_bool(g_update_controller.updater, 'setAutomaticallyChecksForUpdates:', false)
		msg_void_bool(g_update_controller.updater, 'setAutomaticallyDownloadsUpdates:', false)
	} else if policy := cfg.auto_update {
		msg_void_bool(g_update_controller.updater, 'setAutomaticallyChecksForUpdates:', policy in [1, 2])
		msg_void_bool(g_update_controller.updater, 'setAutomaticallyDownloadsUpdates:', policy == 2)
	}
}

fn update_show_permission(_self ObjId, _cmd Sel, request ObjId, reply ObjId) {
	g_update_controller.set_state(UpdateState{kind: .permission_request, object: voidptr(request),
		reply: UpdateCallback{call: update_native_permission, context: voidptr(reply)}})
	if !update_has_unobtrusive_target() { msg_void2(g_update_controller.standard, 'showUpdatePermissionRequest:reply:', request, reply) }
}
fn update_show_checking(_self ObjId, _cmd Sel, cancellation ObjId) {
	g_update_controller.set_state(UpdateState{kind: .checking, cancel_callback: UpdateCallback{call: update_native_void, context: voidptr(cancellation)}})
	if !update_has_unobtrusive_target() { msg_void1(g_update_controller.standard, 'showUserInitiatedUpdateCheckWithCancellation:', cancellation) }
}
fn update_release_notes(version string, current_commit string) (string, string) {
	semver := C.witty_update_regex(nsstring(version), nsstring(r'^\d+\.\d+\.\d+$'))
	if !is_nil(semver) { return 'https://ghostty.org/docs/install/release-notes/${version.replace('.', '-')}', 'View Release Notes' }
	hash := C.witty_update_regex(nsstring(version), nsstring('[0-9a-f]{7,40}'))
	if is_nil(hash) { return '', '' }
	new_hash := objc_utf8_string(hash)
	if current_commit.len > 0 { return 'https://github.com/ghostty-org/ghostty/compare/${current_commit}...${new_hash}', 'Changes Since This Tip Release' }
	return 'https://github.com/ghostty-org/ghostty/commit/${new_hash}', 'View GitHub Commit'
}
fn update_show_found(_self ObjId, _cmd Sel, item ObjId, state ObjId, reply ObjId) {
	version := objc_utf8_string(msg_id(item, 'displayVersionString'))
	info := msg_id(msg_id(get_class('NSBundle'), 'mainBundle'), 'infoDictionary')
	commit := objc_utf8_string(msg_id1(info, 'objectForKey:', nsstring('GhosttyCommit')))
	url, label := update_release_notes(version, commit)
	g_update_controller.set_state(UpdateState{kind: .update_available, version: version, object: voidptr(item),
		release_notes_url: url, release_notes_label: label, reply: UpdateCallback{call: update_native_choice, context: voidptr(reply)}})
	if !update_has_unobtrusive_target() {
		C.witty_update_message3(g_update_controller.standard, sel('showUpdateFoundWithAppcastItem:state:reply:'), item, state, reply)
	}
}
fn update_ignore_release_notes(_self ObjId, _cmd Sel, _data ObjId) {
	// Both release-notes driver methods are intentionally empty in the source.
}
fn update_show_not_found(_self ObjId, _cmd Sel, error ObjId, acknowledgement ObjId) {
	g_update_controller.set_state(UpdateState{kind: .not_found, acknowledgement: UpdateCallback{call: update_native_void, context: voidptr(acknowledgement)}})
	if !update_has_unobtrusive_target() { msg_void2(g_update_controller.standard, 'showUpdateNotFoundWithError:acknowledgement:', error, acknowledgement) }
}
fn update_show_error(_self ObjId, _cmd Sel, error ObjId, acknowledgement ObjId) {
	g_update_controller.set_state(UpdateState{kind: .error, object: voidptr(error),
		error_description: objc_utf8_string(msg_id(error, 'localizedDescription')),
		retry: UpdateCallback{call: update_retry_check}, dismiss: UpdateCallback{call: update_dismiss}})
	if !update_has_unobtrusive_target() { msg_void2(g_update_controller.standard, 'showUpdaterError:acknowledgement:', error, acknowledgement) }
	else { C.witty_update_block_void(acknowledgement) }
}
fn update_show_downloading(_self ObjId, _cmd Sel, cancellation ObjId) {
	g_update_controller.set_state(UpdateState{kind: .downloading, cancel_callback: UpdateCallback{call: update_native_void, context: voidptr(cancellation)}})
	if !update_has_unobtrusive_target() { msg_void1(g_update_controller.standard, 'showDownloadInitiatedWithCancellation:', cancellation) }
}
fn update_download_expected(_self ObjId, _cmd Sel, length u64) {
	old := g_update_controller.state
	if old.kind != .downloading { return }
	g_update_controller.set_state(UpdateState{...old, expected_length: length, downloaded: 0})
	if !update_has_unobtrusive_target() { msg_void_u64(g_update_controller.standard, 'showDownloadDidReceiveExpectedContentLength:', length) }
}
fn update_download_received(_self ObjId, _cmd Sel, length u64) {
	old := g_update_controller.state
	if old.kind != .downloading { return }
	g_update_controller.set_state(UpdateState{...old, downloaded: old.downloaded + length})
	if !update_has_unobtrusive_target() { msg_void_u64(g_update_controller.standard, 'showDownloadDidReceiveDataOfLength:', length) }
}
fn update_start_extracting(_self ObjId, _cmd Sel) {
	g_update_controller.set_state(UpdateState{kind: .extracting})
	if !update_has_unobtrusive_target() { msg_void(g_update_controller.standard, 'showDownloadDidStartExtractingUpdate') }
}
fn update_extracting_progress(_self ObjId, _cmd Sel, progress f64) {
	g_update_controller.set_state(UpdateState{kind: .extracting, extraction_progress: progress})
	if !update_has_unobtrusive_target() { msg_void_f64(g_update_controller.standard, 'showExtractionReceivedProgress:', progress) }
}
fn update_show_ready(_self ObjId, _cmd Sel, reply ObjId) {
	if !update_has_unobtrusive_target() { msg_void1(g_update_controller.standard, 'showReadyToInstallAndRelaunch:', reply) }
	else { C.witty_update_block_choice(reply, int(UpdateChoice.install)) }
}
fn update_show_installing(_self ObjId, _cmd Sel, terminated bool, retry ObjId) {
	g_update_controller.set_state(UpdateState{kind: .installing, retry: UpdateCallback{call: update_native_void, context: voidptr(retry)}, dismiss: UpdateCallback{call: update_dismiss}})
	if !update_has_unobtrusive_target() { C.witty_update_message_bool_object(g_update_controller.standard, sel('showInstallingUpdateWithApplicationTerminated:retryTerminatingApplication:'), terminated, retry) }
}
fn update_show_installed(_self ObjId, _cmd Sel, relaunched bool, acknowledgement ObjId) {
	C.witty_update_message_bool_object(g_update_controller.standard, sel('showUpdateInstalledAndRelaunched:acknowledgement:'), relaunched, acknowledgement)
	g_update_controller.set_state(UpdateState{})
}
fn update_show_focus(_self ObjId, _cmd Sel) { if !update_has_unobtrusive_target() { msg_void(g_update_controller.standard, 'showUpdateInFocus') } }
fn update_dismiss_installation(_self ObjId, _cmd Sel) {
	g_update_controller.set_state(UpdateState{})
	msg_void(g_update_controller.standard, 'dismissUpdateInstallation')
}
fn update_feed_url(_self ObjId, _cmd Sel, _updater ObjId) ObjId {
	return nsstring(if g_update_controller.channel == 'tip' { 'https://tip.files.ghostty.org/appcast.xml' } else { 'https://release.files.ghostty.org/appcast.xml' })
}
fn update_install_on_quit(_self ObjId, _cmd Sel, _updater ObjId, _item ObjId, immediate ObjId) bool {
	g_update_controller.set_state(UpdateState{kind: .installing, auto_update: true,
		retry: UpdateCallback{call: update_native_void, context: voidptr(immediate)}, dismiss: UpdateCallback{call: update_dismiss}})
	return true
}
fn update_will_relaunch(_self ObjId, _cmd Sel, _updater ObjId) {
	msg_void(shared_app(), 'invalidateRestorableState')
	windows := msg_id(shared_app(), 'windows')
	for i in 0 .. int(msg_u64(windows, 'count')) { msg_void(msg_id_u64(windows, 'objectAtIndex:', u64(i)), 'invalidateRestorableState') }
}
fn update_terminal_will_close(_self ObjId, _cmd Sel, notification ObjId) {
	if native_window_data(msg_id(notification, 'object')) == none { return }
	dispatch_after(0.05, update_window_closed, unsafe { nil })
}
fn update_window_closed(_context voidptr) {
	if g_update_controller == unsafe { nil } || update_has_unobtrusive_target() { return }
	g_update_controller.state.cancel()
	g_update_controller.set_state(UpdateState{})
}
fn update_refresh_windows(_self ObjId, _cmd Sel, _notification ObjId) {
	if g_update_controller != unsafe { nil } { g_update_controller.refresh_presentation() }
}
fn update_reset_not_found(_self ObjId, _cmd Sel, _timer ObjId) {
	if g_update_controller == unsafe { nil } || g_update_controller.state.kind != .not_found { return }
	old := retained_update_state(g_update_controller.state)
	g_update_controller.set_state(UpdateState{})
	old.acknowledgement.invoke(0)
	release_update_state(old)
}
fn update_check_action(_self ObjId, _cmd Sel, _sender ObjId) { if g_update_controller != unsafe { nil } { g_update_controller.check_for_updates() } }
fn update_install_action(_self ObjId, _cmd Sel, _sender ObjId) { if g_update_controller != unsafe { nil } { g_update_controller.install_update() } }
fn update_validate_menu(_self ObjId, _cmd Sel, item ObjId) bool {
	if msg_id(item, 'action') == ObjId(sel('checkForUpdates:')) { return msg_bool(g_update_controller.updater, 'canCheckForUpdates') }
	return true
}

fn install_update_menu() {
	menu := msg_id(shared_app(), 'mainMenu')
	application := msg_id(msg_id_u64(menu, 'itemAtIndex:', 0), 'submenu')
	item := msg_id(alloc('NSMenuItem'), 'init')
	msg_void1(item, 'setTitle:', nsstring('Check for Updates…'))
	msg_void1(item, 'setAction:', sel('checkForUpdates:'))
	msg_void1(item, 'setTarget:', g_update_controller.driver)
	msg_void1(application, 'addItem:', item)
	msg_void(item, 'release')
}

fn update_color(name string) ObjId {
	return match name {
		'white' { msg_id(get_class('NSColor'), 'whiteColor') }
		'accent' { msg_id(get_class('NSColor'), 'controlAccentColor') }
		'orange' { msg_id(get_class('NSColor'), 'systemOrangeColor') }
		'secondary' { msg_id(get_class('NSColor'), 'secondaryLabelColor') }
		'primary' { msg_id(get_class('NSColor'), 'labelColor') }
		'blue_black_0.3', 'blue_black_0.5' {
			blue := msg_id(get_class('NSColor'), 'systemBlueColor')
			blended := C.witty_update_blend(blue, if name == 'blue_black_0.3' { 0.3 } else { 0.5 }, msg_id(get_class('NSColor'), 'blackColor'))
			if is_nil(blended) { blue } else { blended }
		}
		'orange_0.2' { msg_id_f64(msg_id(get_class('NSColor'), 'systemOrangeColor'), 'colorWithAlphaComponent:', 0.2) }
		else { msg_id(get_class('NSColor'), 'controlBackgroundColor') }
	}
}

fn (mut controller NativeUpdateController) refresh_presentation() {
	windows := msg_id(shared_app(), 'windows')
	mut live := []u64{}
	for i in 0 .. int(msg_u64(windows, 'count')) {
		window := msg_id_u64(windows, 'objectAtIndex:', u64(i))
		if native_window_data(window) == none { continue }
		live << u64(window)
		content := msg_id(window, 'contentView')
		mut pill := controller.pills[u64(window)] or { nil_obj() }
		if is_nil(pill) {
			pill = msg_id_rect(alloc('NSButton'), 'initWithFrame:', objc_rect(0, 0, 200, 28))
			msg_void1(pill, 'setTarget:', controller.driver)
			msg_void1(pill, 'setAction:', sel('pill:'))
			msg_void_u64(pill, 'setBezelStyle:', 13)
			msg_void_bool(pill, 'setBordered:', false)
			msg_void_bool(pill, 'setWantsLayer:', true)
			msg_void1(content, 'addSubview:', pill)
			controller.pills[u64(window)] = pill
		}
		msg_void_bool(pill, 'setHidden:', controller.state.kind == .idle)
		msg_void1(pill, 'setTitle:', nsstring(controller.state.text()))
		msg_void1(pill, 'setToolTip:', nsstring(controller.state.text()))
		msg_void1(pill, 'setAccessibilityLabel:', nsstring(controller.state.text()))
		font := msg_id_f64(get_class('NSFont'), 'systemFontOfSize:', 11)
		msg_void1(pill, 'setFont:', font)
		width := C.witty_update_text_width(nsstring(controller.state.max_width_text()), font) + 44
		bounds := msg_rect(content, 'bounds')
		msg_void_rect(pill, 'setFrame:', objc_rect(bounds.width - width - 12, bounds.height - 38, width, 28))
		layer := msg_id(pill, 'layer')
		msg_void_f64(layer, 'setCornerRadius:', 14)
		msg_void1(layer, 'setBackgroundColor:', msg_id(update_color(controller.state.background_color()), 'CGColor'))
		msg_void1(pill, 'setContentTintColor:', update_color(controller.state.foreground_color()))
		if icon := controller.state.icon_name() {
			image := msg_id2(get_class('NSImage'), 'imageWithSystemSymbolName:accessibilityDescription:', nsstring(icon), nsstring(controller.state.text()))
			msg_void1(pill, 'setImage:', image)
			msg_void_u64(pill, 'setImagePosition:', 2)
		} else { msg_void1(pill, 'setImage:', nil_obj()) }
	}
	mut removed := []u64{}
	for key, pill in controller.pills {
		if key !in live { msg_void(pill, 'removeFromSuperview'); msg_void(pill, 'release'); removed << key }
	}
	for key in removed { controller.pills.delete(key) }
	if !is_nil(controller.popover) && msg_bool(controller.popover, 'isShown') { controller.build_popover() }
}

fn update_pill_action(_self ObjId, _cmd Sel, sender ObjId) {
	if g_update_controller.state.kind == .not_found { update_reset_not_found(nil_obj(), sel(''), nil_obj()); return }
	if is_nil(g_update_controller.popover) {
		g_update_controller.popover = msg_id(alloc('NSPopover'), 'init')
		msg_void_u64(g_update_controller.popover, 'setBehavior:', 1)
	}
	if msg_bool(g_update_controller.popover, 'isShown') { msg_void(g_update_controller.popover, 'close'); return }
	g_update_controller.build_popover()
	C.witty_action_show_popover(g_update_controller.popover, sender, 1)
}

fn update_popover_button(controller &NativeUpdateController, text string, tag u64, x f64, y f64, width f64, view ObjId) {
	button := msg_id_rect(alloc('NSButton'), 'initWithFrame:', objc_rect(x, y, width, 28))
	msg_void1(button, 'setTitle:', nsstring(text))
	msg_void1(button, 'setTarget:', controller.driver)
	msg_void1(button, 'setAction:', sel('popoverAction:'))
	msg_void_u64(button, 'setTag:', tag)
	msg_void_u64(button, 'setBezelStyle:', 1)
	msg_void1(view, 'addSubview:', button)
	msg_void(button, 'release')
}

fn (mut controller NativeUpdateController) build_popover() {
	state := controller.state
	if state.kind == .idle { msg_void(controller.popover, 'close'); return }
	view_controller := msg_id(alloc('NSViewController'), 'init')
	view := msg_id_rect(alloc('NSView'), 'initWithFrame:', objc_rect(0, 0, 300, 164))
	label := action_label(state.text(), objc_rect(16, 116, 268, 32))
	msg_void1(view, 'addSubview:', label)
	msg_void(label, 'release')
	mut description := state.description()
	if state.kind == .permission_request { description = 'Ghostty can automatically check for updates in the background.' }
	if state.kind == .installing { description = 'The update is ready. Please restart the application to complete the installation.' }
	if state.kind == .update_available {
		description = 'Version: ${state.version}'
		length := msg_u64(ObjId(state.object), 'contentLength')
		if length > 0 { description += '\nSize: ' + objc_utf8_string(msg_id2(get_class('NSByteCountFormatter'), 'stringFromByteCount:countStyle:', ObjId(length), ObjId(1))) }
		date := msg_id(ObjId(state.object), 'date')
		if !is_nil(date) {
			formatter := msg_id(alloc('NSDateFormatter'), 'init')
			msg_void_u64(formatter, 'setDateStyle:', 2)
			description += '\nReleased: ' + objc_utf8_string(msg_id1(formatter, 'stringFromDate:', date))
			msg_void(formatter, 'release')
		}
	}
	info := action_label(description, objc_rect(16, 56, 268, 60))
	msg_void_bool(info, 'setSelectable:', state.kind == .update_available)
	msg_void1(view, 'addSubview:', info)
	msg_void(info, 'release')
	match state.kind {
		.permission_request { update_popover_button(controller, 'Not Now', 1, 16, 12, 90, view); update_popover_button(controller, 'Allow', 2, 210, 12, 74, view) }
		.checking, .downloading { update_popover_button(controller, 'Cancel', 3, 208, 12, 76, view) }
		.update_available {
			update_popover_button(controller, 'Skip', 4, 12, 12, 48, view)
			update_popover_button(controller, 'Later', 5, 62, 12, 52, view)
			update_popover_button(controller, 'Install and Relaunch', 6, 122, 12, 166, view)
			if state.release_notes_url.len > 0 { update_popover_button(controller, state.release_notes_label, 10, 16, 46, 268, view) }
		}
		.installing { update_popover_button(controller, 'Restart Later', 7, 12, 12, 120, view); update_popover_button(controller, 'Restart Now', 8, 168, 12, 120, view) }
		.not_found { update_popover_button(controller, 'OK', 9, 212, 12, 72, view) }
		.error { update_popover_button(controller, 'OK', 7, 16, 12, 72, view); update_popover_button(controller, 'Retry', 8, 212, 12, 72, view) }
		else {}
	}
	if state.kind in [.checking, .downloading, .extracting] {
		progress := msg_id_rect(alloc('NSProgressIndicator'), 'initWithFrame:', objc_rect(16, 86, 268, 12))
		mut determinate := state.kind == .extracting
		mut value := state.extraction_progress
		if state.kind == .downloading { if expected := state.expected_length { if expected > 0 { determinate = true; value = f64(state.downloaded) / f64(expected) } } }
		msg_void_bool(progress, 'setIndeterminate:', !determinate)
		msg_void_f64(progress, 'setMinValue:', 0)
		msg_void_f64(progress, 'setMaxValue:', 1)
		msg_void_f64(progress, 'setDoubleValue:', if value < 0 { 0 } else if value > 1 { 1 } else { value })
		msg_void1(progress, 'startAnimation:', nil_obj())
		msg_void1(view, 'addSubview:', progress)
		msg_void(progress, 'release')
	}
	msg_void1(view_controller, 'setView:', view)
	msg_void1(controller.popover, 'setContentViewController:', view_controller)
	msg_void(view, 'release')
	msg_void(view_controller, 'release')
}

fn update_popover_action(_self ObjId, _cmd Sel, sender ObjId) {
	state := retained_update_state(g_update_controller.state)
	defer { release_update_state(state) }
	match msg_u64(sender, 'tag') {
		1 { state.reply.invoke(0) }
		2 { state.reply.invoke(1) }
		3 { state.cancel_callback.invoke(0) }
		4 { state.reply.invoke(int(UpdateChoice.skip)) }
		5 { state.reply.invoke(int(UpdateChoice.dismiss)) }
		6 { state.reply.invoke(int(UpdateChoice.install)) }
		7 { state.dismiss.invoke(0) }
		8 { state.retry.invoke(0) }
		9 { state.acknowledgement.invoke(0) }
		10 {
			url := msg_id1(get_class('NSURL'), 'URLWithString:', nsstring(state.release_notes_url))
			msg_bool1(msg_id(get_class('NSWorkspace'), 'sharedWorkspace'), 'openURL:', url)
		}
		else {}
	}
	msg_void(g_update_controller.popover, 'close')
}

pub fn native_update_is_installable() bool { return g_update_controller != unsafe { nil } && g_update_controller.state.is_installable() }
pub fn native_update_is_available() bool { return g_update_controller != unsafe { nil } && g_update_controller.state.kind == .update_available }
pub fn native_update_text() string { return if g_update_controller != unsafe { nil } { g_update_controller.state.text() } else { '' } }
pub fn native_update_install() { if g_update_controller != unsafe { nil } { g_update_controller.install_update() } }
pub fn native_update_cancel() { if g_update_controller != unsafe { nil } { g_update_controller.state.cancel() } }
pub fn stop_native_updater() { if g_update_controller != unsafe { nil } { g_update_controller.deinit() } }
