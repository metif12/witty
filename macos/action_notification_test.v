module macos

fn test_native_user_notification_content_has_source_identity_and_sound() {
	surface := &NativeActionSurface{
		uuid:  '550e8400-e29b-41d4-a716-446655440000'
		title: 'terminal title'
	}
	content := notification_content(surface, 'event title', 'event body')
	defer { msg_void(content, 'release') }
	assert objc_utf8_string(msg_id(content, 'title')) == 'event title'
	assert objc_utf8_string(msg_id(content, 'subtitle')) == 'terminal title'
	assert objc_utf8_string(msg_id(content, 'body')) == 'event body'
	assert objc_utf8_string(msg_id(content, 'categoryIdentifier')) == 'com.mitchellh.ghostty.userNotification'
	assert !is_nil(msg_id(content, 'sound'))
	info := msg_id(content, 'userInfo')
	assert objc_utf8_string(msg_id1(info, 'objectForKey:', nsstring('surface'))) == surface.uuid
}
