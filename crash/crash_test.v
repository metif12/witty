module crash

import os

fn read_thread_state(result chan ThreadState) {
	set_thread_state(ThreadState{
		kind: .io
		surface: voidptr(usize(0x5678))
	})
	state := thread_state() or { ThreadState{} }
	result <- state
	clear_thread_state()
}

fn test_thread_state_is_installed_and_cleared() {
	state := ThreadState{
		kind: .renderer
		surface: voidptr(usize(0x1234))
	}
	set_thread_state(state)
	stored := thread_state() or {
		assert false, 'expected thread state'
		return
	}
	assert stored.kind == .renderer
	assert stored.surface == state.surface
	clear_thread_state()
	assert thread_state() == none
}

fn test_thread_state_is_thread_local() {
	set_thread_state(ThreadState{
		kind: .main
		surface: voidptr(usize(0x1234))
	})
	result := chan ThreadState{ cap: 1 }
	worker := spawn read_thread_state(result)
	worker_state := <-result
	worker.wait()

	assert worker_state.kind == .io
	assert worker_state.surface == voidptr(usize(0x5678))
	main_state := thread_state() or {
		assert false, 'expected main thread state'
		return
	}
	assert main_state.kind == .main
	assert main_state.surface == voidptr(usize(0x1234))
	clear_thread_state()
}

fn test_crash_dir_reports_regular_files_and_missing_directory() {
	root := os.join_path(os.temp_dir(), 'witty-crash-dir-${os.getpid()}')
	os.rmdir_all(root) or {}
	defer {
		os.rmdir_all(root) or {}
	}
	dir := Dir{ path: root }
	assert dir.reports()!.len == 0
	os.mkdir_all(os.join_path(root, 'nested'))!
	os.write_file(os.join_path(root, 'one.dmp'), 'report')!

	mut iter := dir.iterator()!
	defer {
		iter.deinit()
	}
	next := iter.next()!
	report := next.value or {
		assert false, 'expected crash report'
		return
	}
	assert report.name == 'one.dmp'
	assert report.mtime > 0
	assert iter.next()!.value == none

	reports := dir.reports()!
	assert reports.len == 1
	assert reports[0].name == 'one.dmp'
	assert reports[0].mtime > 0
}

fn test_crash_report_iterator_propagates_metadata_errors() {
	root := os.join_path(os.temp_dir(), 'witty-crash-dir-error-${os.getpid()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root)!
	defer {
		os.rmdir_all(root) or {}
	}
	mut iter := ReportIterator{
		path: root
		entries: ['vanished.dmp']
	}
	if _ := iter.next() {
		assert false, 'metadata errors must not become end-of-iteration'
	}
}

fn test_crash_thread_type_uses_compact_storage() {
	assert sizeof(ThreadType) == 1
}

fn test_sentry_transport_discards_non_crash_envelopes() {
	root := os.join_path(os.temp_dir(), 'witty-sentry-discard-${os.getpid()}')
	os.rmdir_all(root) or {}
	defer {
		os.rmdir_all(root) or {}
	}

	result := persist_sentry_envelope('{}\n{"type":"session"}\n{}'.bytes(), Dir{
		path: root
	})!
	assert result.path == none
	assert !os.exists(root)
}

fn test_sentry_transport_persists_event_envelopes_locally() {
	root := os.join_path(os.temp_dir(), 'witty-sentry-event-${os.getpid()}')
	os.rmdir_all(root) or {}
	defer {
		os.rmdir_all(root) or {}
	}
	data := '{}\n{"type":"event"}\n{"message":"boom"}'.bytes()
	result := persist_sentry_envelope(data, Dir{
		path: root
	}) or {
		assert false, 'event envelope was discarded: ${err}'
		return
	}
	stored := result.path or {
		assert false, 'event envelope was discarded'
		return
	}
	assert stored.ends_with('.ghosttycrash')
	assert os.read_bytes(stored)! == data
}
