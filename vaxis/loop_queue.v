module vaxis

import datastruct
import sync

// The bounded ring and blocking operations from pinned vaxis queue.zig.
// V receives the source comptime capacity at construction.
@[heap]
pub struct EventQueue[T] {
mut:
	buf         []T
	read_index  uint
	write_index uint
	mutex       &sync.Mutex = unsafe { nil }
	not_full    datastruct.Condition
	not_empty   datastruct.Condition
}

pub fn EventQueue.new[T](capacity int) &EventQueue[T] {
	assert capacity > 0
	return &EventQueue[T]{
		buf:       unsafe { []T{len: capacity} }
		mutex:     sync.new_mutex()
		not_full:  datastruct.Condition.init()
		not_empty: datastruct.Condition.init()
	}
}

pub fn (mut q EventQueue[T]) deinit() {
	q.not_full.deinit()
	q.not_empty.deinit()
	q.mutex.destroy()
	q.buf = []T{}
}

pub fn (mut q EventQueue[T]) pop() T {
	q.mutex.lock()
	defer { q.mutex.unlock() }
	for q.is_empty_lh() {
		q.not_empty.wait(mut q.mutex)
	}
	assert !q.is_empty_lh()
	if q.is_full_lh() {
		q.not_full.signal()
	}
	return q.pop_lh()
}

pub fn (mut q EventQueue[T]) push(item T) {
	q.mutex.lock()
	defer { q.mutex.unlock() }
	for q.is_full_lh() {
		q.not_full.wait(mut q.mutex)
	}
	assert !q.is_full_lh()
	was_empty := q.is_empty_lh()
	q.buf[q.mask(q.write_index)] = item
	q.write_index = q.mask2(q.write_index + 1)
	if was_empty {
		q.not_empty.signal()
	}
}

pub fn (mut q EventQueue[T]) try_push(item T) bool {
	q.mutex.lock()
	if q.is_full_lh() {
		q.mutex.unlock()
		return false
	}
	q.mutex.unlock()
	q.push(item)
	return true
}

pub fn (mut q EventQueue[T]) try_pop() ?T {
	q.mutex.lock()
	if q.is_empty_lh() {
		q.mutex.unlock()
		return none
	}
	q.mutex.unlock()
	return q.pop()
}

pub fn (mut q EventQueue[T]) poll() {
	q.mutex.lock()
	defer { q.mutex.unlock() }
	for q.is_empty_lh() {
		q.not_empty.wait(mut q.mutex)
	}
	assert !q.is_empty_lh()
}

pub fn (mut q EventQueue[T]) lock() {
	q.mutex.lock()
}

pub fn (mut q EventQueue[T]) unlock() {
	q.mutex.unlock()
}

pub fn (mut q EventQueue[T]) drain() ?T {
	if q.is_empty_lh() {
		return none
	}
	return q.pop_lh()
}

pub fn (mut q EventQueue[T]) is_empty() bool {
	q.mutex.lock()
	defer { q.mutex.unlock() }
	return q.is_empty_lh()
}

pub fn (mut q EventQueue[T]) is_full() bool {
	q.mutex.lock()
	defer { q.mutex.unlock() }
	return q.is_full_lh()
}

pub fn (q &EventQueue[T]) len() uint {
	wrap_offset := uint(2) * uint(q.buf.len) * uint(q.write_index < q.read_index)
	return q.write_index + wrap_offset - q.read_index
}

fn (q &EventQueue[T]) is_empty_lh() bool {
	return q.write_index == q.read_index
}

fn (q &EventQueue[T]) is_full_lh() bool {
	return q.mask2(q.write_index + uint(q.buf.len)) == q.read_index
}

fn (q &EventQueue[T]) mask(index uint) uint {
	return index % uint(q.buf.len)
}

fn (q &EventQueue[T]) mask2(index uint) uint {
	return index % (2 * uint(q.buf.len))
}

fn (mut q EventQueue[T]) pop_lh() T {
	result := q.buf[q.mask(q.read_index)]
	q.read_index = q.mask2(q.read_index + 1)
	return result
}
