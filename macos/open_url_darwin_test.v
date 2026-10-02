@[has_globals]
module macos

import json
import os

__global (
	g_url_probe_calls int
	g_url_probe_target string
	g_url_probe_application string
	g_url_probe_configuration bool
)

fn url_probe_general(_self ObjId, _cmd Sel, url ObjId) bool {
	g_url_probe_calls++
	g_url_probe_target = objc_utf8_string(msg_id(url, 'absoluteString'))
	g_url_probe_application = ''
	g_url_probe_configuration = false
	return false // The source ignores this result and still handles the action.
}
fn url_probe_editor(_self ObjId, _cmd Sel, urls ObjId, application ObjId, configuration ObjId, completion ObjId) {
	g_url_probe_calls++
	assert msg_u64(urls, 'count') == 1
	assert is_nil(completion)
	g_url_probe_target = objc_utf8_string(msg_id(msg_id_u64(urls, 'objectAtIndex:', 0), 'absoluteString'))
	g_url_probe_application = objc_utf8_string(msg_id(application, 'absoluteString'))
	g_url_probe_configuration = msg_bool1(configuration, 'isKindOfClass:', get_class('NSWorkspaceOpenConfiguration'))
}
fn url_probe_workspace() ObjId {
	if is_nil(get_class('VTURLWorkspaceProbe')) {
		cls := C.macos_objc_allocate_class_pair(get_class('NSObject'), cstr('VTURLWorkspaceProbe'), 0)
		add_method(cls, 'openURL:', voidptr(url_probe_general), 'B@:@')
		add_method(cls, 'openURLs:withApplicationAtURL:configuration:completionHandler:', voidptr(url_probe_editor), 'v@:@@@@')
		C.macos_objc_register_class_pair(cls)
	}
	return msg_id(alloc('VTURLWorkspaceProbe'), 'init')
}

struct URLProbeRecord {
	input string
	kind i32
	url string
	editor string
}
fn test_source_url_editor_selection_and_real_native_workspace_selectors() {
	app_init()
	workspace := url_probe_workspace()
	defer { msg_void(workspace, 'release') }
	mut records := []URLProbeRecord{}
	inputs := ['https://ghostty.org/docs?query=hello world', 'https://ghostty.org/docs/a%20b',
		'/tmp/witty config.ghostty', 'relative config.txt', 'file:///tmp/witty%20config.txt',
		'/tmp/readme.md', '/tmp/unknown-extension.witty-ultra-nonexistent-extension',
		'/tmp/no-extension', '', 'mailto:alex@example.test', '/tmp/native.html']
	for value in inputs {
		for kind in [i32(0), i32(1), i32(2)] {
			before := g_url_probe_calls
			assert source_open_url_with_workspace(value, kind, workspace)
			assert g_url_probe_calls == before + 1
			url := source_url(value)
			assert g_url_probe_target == objc_utf8_string(msg_id(url, 'absoluteString'))
			editor := if kind == 1 { source_text_editor(url) } else { nil_obj() }
			assert g_url_probe_application == objc_utf8_string(msg_id(editor, 'absoluteString'))
			assert g_url_probe_configuration == !is_nil(editor)
			records << URLProbeRecord{value, kind, g_url_probe_target, g_url_probe_application}
		}
	}
	if path := os.getenv_opt('WITTY_URL_MODEL_OUTPUT') { os.write_file(path, json.encode(records))! }
}
fn test_source_config_open_path_conversion() {
	assert source_config_file_url('/tmp/witty config.ghostty') == 'file:///tmp/witty%20config.ghostty'
	assert source_config_file_url('relative config.txt') == objc_utf8_string(msg_id(source_url('relative config.txt'), 'absoluteString'))
}
