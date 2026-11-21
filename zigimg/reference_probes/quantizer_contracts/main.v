module main

import os
import zigimg as p

__global (
	observed_path    string
	observed_q       = &p.OctTreeQuantizer(unsafe { nil })
	observed_nodes   []&p.OctTreeNode
	observed_context = &p.OctTreePaletteContext(unsafe { nil })
	observed_palette []p.Rgba32
)
fn pointer_id(node &p.OctTreeNode) u64 {
	if node == unsafe { nil } { return 0 }
	for index, known in observed_nodes {
		if voidptr(node) == voidptr(known) { return u64(index + 1) }
	}
	panic('OBSERVER ERROR: unknown node')
}

fn mix(current u64, value u64) u64 {
	mut hash := current
	for shift in 0 .. 8 {
		hash = (hash ^ u8(value >> (shift * 8))) * u64(1099511628211)
	}
	return hash
}

fn node_hash(node &p.OctTreeNode, current u64) u64 {
	mut hash := current
	for word in [u64(node.red), node.green, node.blue, node.reference_count, node.palette_index] {
		hash = mix(hash, word)
	}
	for child in node.children {
		hash = mix(hash, pointer_id(child))
	}
	return mix(hash, pointer_id(node.level_next))
}

fn state() string {
	mut hash := u64(14695981039346656037)
	for node in observed_nodes {
		hash = node_hash(node, hash)
	}
	for level in observed_q.levels {
		hash = mix(hash, pointer_id(level))
	}
	mut colors := ''
	for c in observed_palette {
		colors += '${c.r:02x}${c.g:02x}${c.b:02x}${c.a:02x}'
	}
	return '${observed_context.palette_index}:${observed_context.color_count}|${hash}|${colors}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn scalar(node &p.OctTreeNode) string {
	return '${node.red}:${node.green}:${node.blue}:${node.reference_count}:${node.palette_index}'
}

fn line_case(line string) {
	f := line.split('|')
	mut q := p.OctTreeQuantizer{}
	q.root_node.init(0, mut q)
	q.root_node.red = f[2].u32()
	q.root_node.green = f[3].u32()
	q.root_node.blue = f[4].u32()
	q.root_node.reference_count = f[5].u32()
	q.root_node.palette_index = f[6].u32()
	mut a1 := p.OctTreeNode{
		red:             2
		green:           10
		blue:            20
		reference_count: 1
		palette_index:   5
	}
	mut a2 := p.OctTreeNode{
		red:             3
		green:           20
		blue:            30
		reference_count: 1
		palette_index:   7
	}
	mut a3 := p.OctTreeNode{
		red:             4
		green:           30
		blue:            40
		reference_count: 1
		palette_index:   9
	}
	mut a4 := p.OctTreeNode{}
	q.levels[2] = &a2
	a2.level_next = &a3
	graph := f[10].int()
	if graph == 1 { q.root_node.children[0] = &a1 }
	if graph == 2 {
		q.root_node.children[0] = &a1
		q.root_node.children[7] = &a2
	}
	if graph == 3 {
		q.root_node.children[0] = &a4
		a4.children[0] = &a1
		a4.children[7] = &a2
	}
	if graph == 4 {
		q.root_node.children[0] = &a1
		q.root_node.children[7] = &a1
	}
	if graph in [5, 6] {
		q.root_node.children[0] = &a4
		q.levels[7] = &a4
		if graph == 6 {
			a1.reference_count = 0
			a2.reference_count = 0
			a4.children[0] = &a1
			a4.children[7] = &a2
		}
	}
	mut palette := []p.Rgba32{len: f[9].int(), init: p.Rgba32{
		r: 17
		g: 18
		b: 19
	}}
	mut context := p.OctTreePaletteContext{
		palette:       unsafe { palette[..] }
		palette_index: f[8].u32()
		color_count:   f[7].u32()
	}
	observed_q = &q
	observed_nodes = [&q.root_node, &a1, &a2, &a3, &a4]
	observed_context = &context
	observed_palette = unsafe { palette[..] }
	c := f[11].split(':')
	color := p.Rgb24{
		r: c[0].u8()
		g: c[1].u8()
		b: c[2].u8()
	}
	mut status := 'ok'
	match f[0].int() {
		0 {
			value := q.root_node.get_color()
			status = 'color:${value.r}:${value.g}:${value.b}:${value.a}'
		}
		1 {
			q.root_node.add_color(color, f[1].i32(), mut q) or { status = err.msg() }
		}
		2 {
			q.add_level_node(f[1].i32(), mut a1)
		}
		3 {
			q.root_node.init(f[1].i32(), mut q)
		}
		4 {
			status = 'removed:${q.root_node.remove_leaves()}'
		}
		5 {
			q.root_node.make_palette(mut context)
		}
		6 {
			value := q.root_node.get_palette_index(color, f[1].i32()) or {
				status = err.msg()
				uint(0)
			}
			if status == 'ok' { status = 'index:${value}' }
		}
		7 {
			view := q.make_palette(f[7].u32(), mut palette)
			status = 'palette:${view.len}'
			if view.len > 0 {
				mut borrowed := unsafe { view[..] }
				borrowed[0].r ^= 85
			}
		}
		8 {
			mut copied := q
			copied.root_node.red ^= 0x55aa55aa
			copied.root_node.palette_index ^= 0xffffffff
			if copied.root_node.children[0] != unsafe { nil } {
				copied.root_node.children[0].green ^= 85
			}
			status = 'copy:${scalar(&q.root_node)}:${scalar(&copied.root_node)}'
		}
		9 {
			mut copied := q.root_node
			copied.blue ^= 0x55aa55aa
			copied.palette_index ^= 0xffffffff
			if copied.children[0] != unsafe { nil } { copied.children[0].red ^= 85 }
			status = 'copy:${scalar(&q.root_node)}:${scalar(&copied)}'
		}
		10 {
			mut copied := context
			copied.palette_index ^= 0xffffffff
			copied.color_count ^= 0x55aa55aa
			if copied.palette.len > 0 { copied.palette[0].b ^= 85 }
			status = 'copy:${copied.palette_index}:${copied.color_count}'
		}
		11 {
			factory := p.OctTreeQuantizer.init()
			mut count := 0
			for level in 1 .. 8 {
				if factory.levels[level] != unsafe { nil } { count++ }
			}
			status = 'factory:${scalar(&factory.root_node)}:${count}'
		}
		else {
			panic('invalid operation')
		}
	}

	println(status + '|' + state())
}

fn main() {
	if os.args[1] == '--corpus' {
		for line in os.read_lines(os.args[2]) or { panic(err) } {
			line_case(line)
		}
	} else {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(os.args[3])
	}
}
