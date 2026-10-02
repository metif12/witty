module main
import apprt
import input
import macos
fn native_inspector_callbacks() macos.NativeInspectorCallbacks {
 return macos.NativeInspectorCallbacks{init:native_inspector_init,alive:native_inspector_alive,destroy:native_inspector_free,render:native_inspector_render,size:native_inspector_size,focus:native_inspector_focus,button:native_inspector_button,motion:native_inspector_motion,scroll:native_inspector_scroll,key:native_inspector_key,text:native_inspector_text}
}
fn native_inspector_init(userdata voidptr,device voidptr) voidptr {
 mut state := state_from_userdata(userdata) or{return unsafe{nil}}
 if state.closed || state.surface == unsafe{nil} { return unsafe{nil} }
 mut inspector := apprt.ghostty_surface_inspector(mut state.surface) or{return unsafe{nil}}
 if !apprt.ghostty_inspector_metal_init(mut inspector,device) { return unsafe{nil} }
 return voidptr(inspector)
}
fn native_inspector_alive(userdata voidptr) bool { state := state_from_userdata(userdata) or{return false}; return !state.closed && state.surface != unsafe{nil} }
fn native_inspector_free(userdata voidptr) { if mut state := state_from_userdata(userdata) { if state.surface != unsafe{nil} { apprt.ghostty_inspector_free(mut state.surface) } } }
fn native_inspector_render(backend voidptr,command voidptr,descriptor voidptr) { mut inspector := unsafe{&apprt.TerminalInspector(backend)}; apprt.ghostty_inspector_metal_render(mut inspector,command,descriptor) }
fn native_inspector_size(backend voidptr,w u32,h u32,x f64,y f64) { mut inspector := unsafe{&apprt.TerminalInspector(backend)}; apprt.ghostty_inspector_set_content_scale(mut inspector,x,y); apprt.ghostty_inspector_set_size(mut inspector,w,h) }
fn native_inspector_focus(backend voidptr,focused bool) { mut inspector := unsafe{&apprt.TerminalInspector(backend)}; apprt.ghostty_inspector_set_focus(mut inspector,focused) }
fn native_inspector_button(backend voidptr,action input.MouseButtonState,button input.MouseButton,mods int) { mut inspector := unsafe{&apprt.TerminalInspector(backend)}; apprt.ghostty_inspector_mouse_button(mut inspector,action,button,mods) }
fn native_inspector_motion(backend voidptr,x f64,y f64) { mut inspector := unsafe{&apprt.TerminalInspector(backend)}; apprt.ghostty_inspector_mouse_pos(mut inspector,x,y) }
fn native_inspector_scroll(backend voidptr,x f64,y f64,mods int) { mut inspector := unsafe{&apprt.TerminalInspector(backend)}; apprt.ghostty_inspector_mouse_scroll(mut inspector,x,y,mods) }
fn native_inspector_key(backend voidptr,action input.KeyAction,key input.Key,mods int) { mut inspector := unsafe{&apprt.TerminalInspector(backend)}; apprt.ghostty_inspector_key(mut inspector,action,key,mods) }
fn native_inspector_text(backend voidptr,text string) { mut inspector := unsafe{&apprt.TerminalInspector(backend)}; apprt.ghostty_inspector_text(mut inspector,text) }
