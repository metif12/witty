@[has_globals]
module main

import apprt
import core
import json
import macos
import os

#insert "@VMODROOT/native_clipboard_darwin_test_abi.h"

fn C.witty_clipboard_begin()
fn C.witty_clipboard_end()
fn C.witty_clipboard_clear()
fn C.witty_clipboard_text(bytes &char, length usize)
fn C.witty_clipboard_urls(scenario int)
fn C.witty_clipboard_type() &char
fn C.witty_clipboard_has_type(type_ &char) bool
fn C.witty_clipboard_value(type_ &char) &char
fn C.witty_clipboard_accept(value bool)
fn C.witty_clipboard_alert_count() int
fn C.witty_clipboard_prompt_text() &char
fn C.witty_clipboard_before_text() &char

struct ClipboardProbeRecord {
	name string
	value string
	type_ string
	confirmed bool
}

__global clipboard_completed []ClipboardProbeRecord

fn clipboard_completion(_backend voidptr, request apprt.ClipboardRequest, value string, confirmed bool) ! {
	assert request is apprt.ClipboardRequestOsc52Read
	clipboard_completed << ClipboardProbeRecord{ value: value, confirmed: confirmed }
}

fn clipboard_request() &apprt.ClipboardRequest {
	mut request := unsafe { &apprt.ClipboardRequest(voidptr(malloc(sizeof(apprt.ClipboardRequest)))) }
	unsafe { *request = apprt.ClipboardRequest(apprt.ClipboardRequestOsc52Read{ clipboard: .selection }) }
	return request
}

fn clipboard_c_string(value &char) string {
	return if value == unsafe { nil } { '' } else { unsafe { value.vstring().clone() } }
}

fn clipboard_fixture_text(value string) {
	C.witty_clipboard_text(&char(value.str), usize(value.len))
}

fn test_native_clipboard_source_consumers_and_isolated_pasteboard() {
	macos.app_init()
	C.witty_clipboard_begin()
	apprt.install_core_bridge(apprt.CoreBridge{ surface_clipboard: clipboard_completion })
	defer {
		core.install_embedded_bridge()
		C.witty_clipboard_end()
	}
	mut state := &TermState{ surface: &apprt.Surface{ app: &apprt.App{}, core_surface: apprt.CoreSurface{ backend: voidptr(usize(1)) } } }
	mut records := []ClipboardProbeRecord{}
	for scenario, name in ['empty', 'text', 'file', 'file-and-text', 'web', 'mixed'] {
		C.witty_clipboard_clear()
		match scenario {
			1 { clipboard_fixture_text('ordinary text') }
			2, 3 { C.witty_clipboard_urls(0) }
			4 { C.witty_clipboard_urls(1) }
			5 { C.witty_clipboard_urls(2) }
			else {}
		}
		if scenario == 3 { clipboard_fixture_text('fallback') }
		read := macos.clipboard_get_text_for(1) or { '' }
		records << ClipboardProbeRecord{ name: name, value: read }
		runtime_read_clipboard(voidptr(state), 1, clipboard_request())
		assert clipboard_completed.last().value == read
		assert !clipboard_completed.last().confirmed
		// The returned V string owns its bytes after the pasteboard is replaced.
		C.witty_clipboard_clear()
		assert read == records.last().value
	}
	assert records[2].value == '/tmp/a\\ b\\;\\$\\?.txt'
	assert records[3].value == records[2].value
	assert records[5].value == '/tmp/a\\ b https://example.org/c?x=1&y=2'
	assert macos.clipboard_get_text_for(99) == none
	for mime in ['text/plain', 'text/html', 'text/rtf', 'application/json', 'application/xml', 'image/png', 'application/x-witty-unknown', '', 'invalid mime'] {
		runtime_write_clipboard(voidptr(state), 1, [apprt.ClipboardContent{ mime: mime, data: 'payload' }], false)
		type_ := clipboard_c_string(C.witty_clipboard_type())
		value := clipboard_c_string(C.witty_clipboard_value(&char(type_.str)))
		assert value == 'payload'
		records << ClipboardProbeRecord{ name: 'mime:' + mime, value: value, type_: type_ }
	}
	C.witty_clipboard_clear()
	clipboard_fixture_text('before\x00after')
	runtime_read_clipboard(voidptr(state), 1, clipboard_request())
	assert clipboard_completed.last().value == 'before'
	records << ClipboardProbeRecord{ name: 'read-c-prefix', value: clipboard_completed.last().value }
	malformed := [u8(0x61), 0xff, 0x62, 0x00, 0x63].bytestr()
	runtime_write_clipboard(voidptr(state), 1, [apprt.ClipboardContent{ mime: 'application/json\x00text/plain', data: malformed }], false)
	assert clipboard_c_string(C.witty_clipboard_type()) == 'public.json'
	assert clipboard_c_string(C.witty_clipboard_value(c'public.json')) == 'a�b'
	records << ClipboardProbeRecord{ name: 'write-c-prefix-repair', value: clipboard_c_string(C.witty_clipboard_value(c'public.json')), type_: 'public.json' }
	runtime_write_clipboard(voidptr(state), 1, [apprt.ClipboardContent{ mime: 'text/plain', data: 'untouched' }], false)
	alerts := C.witty_clipboard_alert_count()
	runtime_write_clipboard(voidptr(state), 1, [apprt.ClipboardContent{ mime: 'text/html', data: 'rich' }], true)
	runtime_write_clipboard(voidptr(state), 99, [apprt.ClipboardContent{ mime: 'text/plain', data: 'invalid' }], true)
	assert C.witty_clipboard_alert_count() == alerts
	assert macos.clipboard_get_text_for(1) or { '' } == 'untouched'
	approved := [apprt.ClipboardContent{ mime: 'text/plain\x00ignored', data: malformed }, apprt.ClipboardContent{ mime: 'text/html', data: 'rich' }]
	C.witty_clipboard_accept(false)
	runtime_write_clipboard(voidptr(state), 1, approved, true)
	assert macos.clipboard_get_text_for(1) or { '' } == 'untouched'
	assert clipboard_c_string(C.witty_clipboard_before_text()) == 'untouched'
	assert clipboard_c_string(C.witty_clipboard_prompt_text()).ends_with('\n\na�b')
	records << ClipboardProbeRecord{ name: 'write-denied', value: macos.clipboard_get_text_for(1) or { '' }, type_: clipboard_c_string(C.witty_clipboard_type()) }
	C.witty_clipboard_accept(true)
	runtime_write_clipboard(voidptr(state), 1, approved, true)
	assert !C.witty_clipboard_has_type(c'public.html')
	assert clipboard_c_string(C.witty_clipboard_before_text()) == 'untouched'
	assert macos.clipboard_get_text_for(1) or { '' } == 'a�b'
	records << ClipboardProbeRecord{ name: 'write-approved', value: macos.clipboard_get_text_for(1) or { '' }, type_: clipboard_c_string(C.witty_clipboard_type()) }
	// Malformed confirmation input has the source's early-return/state-lifetime
	// behavior; the fixture frees this deliberately uncompleted request itself.
	bad_request := clipboard_request()
	before := clipboard_completed.len
	runtime_confirm_read_clipboard(voidptr(state), malformed, bad_request, .osc_52_read)
	assert clipboard_completed.len == before
	unsafe { free(bad_request) }
	invalid_request := clipboard_request()
	invalid_alerts := C.witty_clipboard_alert_count()
	runtime_confirm_read_clipboard(voidptr(state), 'read', invalid_request, unsafe { apprt.ClipboardRequestType(255) })
	assert clipboard_completed.len == before
	assert C.witty_clipboard_alert_count() == invalid_alerts
	unsafe { free(invalid_request) }
	runtime_confirm_read_clipboard(voidptr(state), 'read\x00ignored', clipboard_request(), .osc_52_read)
	assert clipboard_completed.last().value == 'read'
	assert clipboard_completed.last().confirmed
	records << ClipboardProbeRecord{ name: 'read-approved', value: clipboard_completed.last().value, confirmed: true }
	C.witty_clipboard_accept(false)
	runtime_confirm_read_clipboard(voidptr(state), 'read', clipboard_request(), .osc_52_read)
	assert clipboard_completed.last().value == ''
	assert clipboard_completed.last().confirmed
	records << ClipboardProbeRecord{ name: 'read-denied', confirmed: true }
	if output := os.getenv_opt('WITTY_CLIPBOARD_MODEL_OUTPUT') {
		os.write_file(output, json.encode(records)) or { panic(err) }
	}
}
