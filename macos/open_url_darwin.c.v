module macos

#flag darwin -framework CoreServices
#flag darwin -framework UniformTypeIdentifiers
#insert "@VMODROOT/macos/open_url_abi.h"
fn C.witty_open_url_plain_text_type() ObjId
fn C.witty_open_url_default_application(identifier ObjId) ObjId
fn C.witty_open_urls_with_application(workspace ObjId, urls ObjId, application ObjId, configuration ObjId)

// Ghostty.App.openURL and NSWorkspace+Extension.swift, pinned 6c0e02d.
// The source falls back to a file URL when URL(string:) has no scheme.
fn source_url(value string) ObjId {
	candidate := msg_id1(get_class('NSURL'), 'URLWithString:', nsstring(value))
	if !is_nil(candidate) && !is_nil(msg_id(candidate, 'scheme')) { return candidate }
	// URL(filePath: "") resolves the current directory. NSURL's older constructor
	// rejects an empty string; its "." path performs the same native resolution.
	return msg_id1(get_class('NSURL'), 'fileURLWithPath:', nsstring(if value.len == 0 { '.' } else { value }))
}

fn source_default_application(content_type ObjId) ObjId {
	// takeRetainedValue() becomes an autoreleased Foundation object.
	return msg_id(C.witty_open_url_default_application(content_type), 'autorelease')
}

fn source_default_application_for_extension(extension ObjId) ObjId {
	uti := msg_id1(get_class('UTType'), 'typeWithFilenameExtension:', extension)
	if is_nil(uti) { return nil_obj() }
	return source_default_application(msg_id(uti, 'identifier'))
}

fn source_text_editor(url ObjId) ObjId {
	// Swift URL.pathExtension is nonoptional even for scheme-only URLs. NSURL
	// returns nil for those paths, so preserve Swift's empty-string projection.
	editor := source_default_application_for_extension(nsstring(objc_utf8_string(msg_id(url, 'pathExtension'))))
	if !is_nil(editor) { return editor }
	return source_default_application(msg_id(C.witty_open_url_plain_text_type(), 'identifier'))
}

fn source_open_url_with_workspace(value string, kind i32, workspace ObjId) bool {
	url := source_url(value)
	if kind == 1 {
		editor := source_text_editor(url)
		if !is_nil(editor) {
			configuration := msg_id(alloc('NSWorkspaceOpenConfiguration'), 'init')
			defer { msg_void(configuration, 'release') }
			C.witty_open_urls_with_application(workspace,
				msg_id1(get_class('NSArray'), 'arrayWithObject:', url), editor, configuration)
			return true
		}
	}
	// Source HTML/unknown actions and text without an editor use the default app.
	// The action is handled even if NSWorkspace declines or fails to open it.
	msg_bool1(workspace, 'openURL:', url)
	return true
}

// kind uses ghostty_action_open_url_kind_e: unknown=0, text=1, html=2.
pub fn source_open_url(value string, kind i32) bool {
	return source_open_url_with_workspace(value, kind,
		msg_id(get_class('NSWorkspace'), 'sharedWorkspace'))
}

// Ghostty.App.openConfig first converts config_open_path to an absolute file URL.
pub fn source_config_file_url(path string) string {
	return objc_utf8_string(msg_id(msg_id1(get_class('NSURL'), 'fileURLWithPath:',
		nsstring(path)), 'absoluteString'))
}
