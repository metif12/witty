module main

import apprt
import macos

fn do_new_split(current &TermState, direction apprt.SplitDirection) bool {
	if current.controller == unsafe { nil } || current.closed { return false }
	mut controller := current.controller
	if _ := controller.host.tree.root.find(current.view) {} else { return false }
	view := macos.create_split_surface_view(controller.host)
	mut added := create_surface(view, inherited_options(current, .split)) or { return false }
	added.controller = controller
	new_tree := controller.host.tree.inserting(view, current.view, match direction { .left { macos.SplitNewDirection.left } .right { .right } .up { .up } .down { .down } }) or {
		eprintln('failed to insert split: ${err}')
		return false
	}
	replace_controller_tree(controller, new_tree, view, current.view, 'New Split')
	controller.focused = added
	macos.focus_split_view(view)
	return true
}
fn do_goto_split(current &TermState, direction apprt.GotoSplit) bool {
	if current.controller == unsafe { nil } { return false }
	mut host := current.controller.host
	node := host.tree.root.find(current.view) or { return false }
	view := host.tree.focus_target(match direction { .previous { macos.SplitFocusDirection.previous } .next { .next } .left { .left } .right { .right } .up { .up } .down { .down } }, node) or { return true }
	if host.tree.zoomed != unsafe { nil } {
		host.replace_tree(macos.NativeSplitTree{root: host.tree.root, zoomed: host.tree.root.find(view) or { unsafe { &macos.NativeSplitNode(nil) } }})
	}
	macos.focus_split_view(view)
	return true
}
fn do_resize_split(current &TermState, data apprt.ResizeSplit) bool {
	if current.controller == unsafe { nil } { return false }
	mut host := current.controller.host
	node := host.tree.root.find(current.view) or { return false }
	tree := host.tree.resizing(node, data.amount, match data.direction { .left { macos.SplitFocusDirection.left } .right { .right } .up { .up } .down { .down } }, macos.SplitBounds{width: macos.view_width(host.container), height: macos.view_height(host.container)}) or { return false }
	host.replace_tree(tree)
	return true
}
