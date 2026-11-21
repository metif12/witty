module main

import os
import strings
import zigimg as p

__global (
	observed_path  string
	observed_trace = &Trace(unsafe { nil })
	observed_node  = &p.OctTreeNode(unsafe { nil })
)

struct Trace {
mut:
	words []u32
}

struct Word8 {
mut:
	word  u32
	mode  u32
	trace &Trace
}

struct Word16 {
mut:
	word  u32
	mode  u32
	trace &Trace
}

struct Word32 {
mut:
	word  u32
	mode  u32
	trace &Trace
}

type Alias8 = Word8
type Alias16 = Word16
type Alias32 = Word32

fn resolve_word[W](word u32, mode u32, mut trace Trace) W {
	n := u32(trace.words.len)
	raw := match mode {
		0 { word }
		1 { word ^ (n * u32(0x010101)) }
		else { u32(u64(word) + u64(n) * 0x010307) }
	}

	result := W(raw)
	trace.words << u32(result)
	return result
}

pub fn (value Word8) to_u32_rgb() u8 {
	mut trace := unsafe { value.trace }
	return resolve_word[u8](value.word, value.mode, mut trace)
}

pub fn (value Word16) to_u32_rgb() u16 {
	mut trace := unsafe { value.trace }
	return resolve_word[u16](value.word, value.mode, mut trace)
}

pub fn (value Word32) to_u32_rgb() u32 {
	mut trace := unsafe { value.trace }
	return resolve_word[u32](value.word, value.mode, mut trace)
}

fn trace_output(mut out strings.Builder, trace Trace) {
	out.write_string('${trace.words.len}:')
	for word in trace.words {
		out.write_string('${word},')
	}
	out.write_string('|')
}

fn tree(mut out strings.Builder, node &p.OctTreeNode, path u32) {
	out.write_string('${path}:${node.red}:${node.green}:${node.blue}:${node.reference_count}:${node.palette_index};')
	for index, child in node.children {
		if child != unsafe { nil } { tree(mut out, child, path * 8 + u32(index)) }
	}
}

fn word_at(seed u32, i int) u32 {
	return u32(u64(seed) + u64(i) * 0x00130711)
}

fn run[T](mut out strings.Builder, prototype T, count int, budget u32) {
	mut trace := unsafe { prototype.trace }
	mut q := p.OctTreeQuantizer{}
	q.root_node.init(0, mut q)
	mut value := prototype
	for i in 0 .. count {
		value.word = word_at(prototype.word, i)
		q.add_color(value) or { panic(err) }
	}
	trace_output(mut out, trace)
	tree(mut out, &q.root_node, 1)
	out.write_string('|')
	mut palette := []p.Rgba32{len: 16, init: p.Rgba32{
		r: 17
		g: 18
		b: 19
		a: 20
	}}
	result := q.make_palette(budget, mut palette)
	out.write_string('${result.len}:')
	for c in palette {
		out.write_string('${c.r},${c.g},${c.b},${c.a};')
	}
	out.write_string('|')
	for i in 0 .. count + 1 {
		value.word = word_at(prototype.word, i)
		index := q.get_palette_index(value) or {
			out.write_string(err.msg() + ',')
			continue
		}
		out.write_string('${index},')
	}
	out.write_string('|')
	trace_output(mut out, trace)
	tree(mut out, &q.root_node, 1)
	out.write_string('|${prototype.word}:${value.word}\n')
}

fn observed_state() string {
	mut out := strings.new_builder(1024)
	trace_output(mut out, observed_trace)
	tree(mut out, observed_node, 1)
	return out.str()
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, observed_state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn node_run[T](mut out strings.Builder, value T, f []string) {
	mut q := p.OctTreeQuantizer{}
	q.root_node.init(0, mut q)
	q.root_node.red = f[6].u32()
	q.root_node.green = f[7].u32()
	q.root_node.blue = f[8].u32()
	q.root_node.reference_count = f[9].u32()
	q.root_node.palette_index = f[10].u32()
	observed_node = &q.root_node
	observed_trace = value.trace
	mut status := 'ok'
	if f[4] == '1' {
		q.root_node.add_color(value, f[5].i32(), mut q) or { status = err.msg() }
	} else {
		index := q.root_node.get_palette_index(value, f[5].i32()) or {
			status = err.msg()
			uint(0)
		}
		if status == 'ok' { status = 'index:${index}' }
	}
	out.write_string(status + '|' + observed_state() + '\n')
}

fn dispatch[T](mut out strings.Builder, value T, f []string, node_case bool) {
	if node_case {
		node_run(mut out, value, f)
	} else {
		run(mut out, value, f[3].int(), f[4].u32())
	}
}

fn line_case(mut out strings.Builder, line string) {
	f := line.split('|')
	node_case := f[0] == 'N'
	fields := if node_case { f[1..] } else { f }
	seed := fields[1].u32()
	mode := fields[2].u32()
	mut trace := Trace{}
	row := if node_case { f } else { fields }
	match fields[0].int() {
		0 { dispatch(mut out, Word8{ word: seed, mode: mode, trace: &trace }, row, node_case) }
		1 { dispatch(mut out, Word16{ word: seed, mode: mode, trace: &trace }, row, node_case) }
		2 { dispatch(mut out, Word32{ word: seed, mode: mode, trace: &trace }, row, node_case) }
		3 { dispatch(mut out, Alias8{ word: seed, mode: mode, trace: &trace }, row, node_case) }
		4 { dispatch(mut out, Alias16{ word: seed, mode: mode, trace: &trace }, row, node_case) }
		5 { dispatch(mut out, Alias32{ word: seed, mode: mode, trace: &trace }, row, node_case) }
		else { panic('invalid fixture kind') }
	}
}

fn main() {
	mut out := strings.new_builder(64 * 1024)
	if os.args[1] == '--case' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(mut out, os.args[3])
	} else {
		for line in os.read_lines(os.args[1]) or { panic(err) } {
			line_case(mut out, line)
		}
	}
	print(out.str())
}
