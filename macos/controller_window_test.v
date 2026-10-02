module macos

fn test_native_window_inherited_overrides_use_defining_class_super() {
	app_init()
	register_native_window_class()
	cls:=C.macos_objc_allocate_class_pair(get_class('VTTerminalWindow'),cstr('VTInheritedWindowProbe'),0)
	C.macos_objc_register_class_pair(cls)
	window:=msg_id_rect_u64_u64_bool(msg_id(cls,'alloc'),'initWithContentRect:styleMask:backing:defer:',objc_rect(0,0,100,100),ns_window_style_titled|ns_window_style_closable|ns_window_style_resizable,ns_backing_store_buffered,false)
	defaults:=msg_id(get_class('NSUserDefaults'),'standardUserDefaults')
	previous:=msg_id1(defaults,'objectForKey:',nsstring('NSWindowLastPosition'))
	msg_void(previous,'retain')
	defer {
		if is_nil(previous) { msg_void1(defaults,'removeObjectForKey:',nsstring('NSWindowLastPosition')) }
		else { msg_void2(defaults,'setObject:forKey:',previous,nsstring('NSWindowLastPosition')) }
		msg_void(previous,'release')
	}
	msg_void_bool(window,'setReleasedWhenClosed:',false)
	msg_void(window,'update')
	accessory:=msg_id(alloc('NSTitlebarAccessoryViewController'),'init')
	msg_void1(accessory,'setView:',msg_id_rect(alloc('NSView'),'initWithFrame:',objc_rect(0,0,20,20)))
	msg_void1(window,'addTitlebarAccessoryViewController:',accessory)
	assert msg_u64(msg_id(window,'titlebarAccessoryViewControllers'),'count')==1
	msg_void_u64(window,'removeTitlebarAccessoryViewControllerAtIndex:',0)
	assert msg_u64(msg_id(window,'titlebarAccessoryViewControllers'),'count')==0
	msg_void(window,'close')
	msg_void(window,'release')
}
fn test_native_restoration_class_and_secure_archive_protocol_are_live() {
	app_init()
	view:=create_restorable_window(100,100,'restoration probe')
	assert !msg_bool(msg_id(view,'window'),'isVisible')
	configure_native_restoration(view,true)
	window:=msg_id(view,'window')
	assert msg_bool(window,'isRestorable')
	assert objc_utf8_string(msg_id(window,'identifier'))=='TerminalWindowRestoration'
	assert msg_bool1(msg_id(window,'restorationClass'),'respondsToSelector:',sel('restoreWindowWithIdentifier:state:completionHandler:'))
	assert msg_bool(codable_bridge_class(),'supportsSecureCoding')
	configure_native_restoration(view,false)
	assert !msg_bool(window,'isRestorable')
	msg_void(window,'close')
}
