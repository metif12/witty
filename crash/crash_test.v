module crash

import os

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
	report := iter.next() or {
		assert false, 'expected crash report'
		return
	}
	assert report.name == 'one.dmp'
	assert report.mtime > 0
	assert iter.next() == none

	reports := dir.reports()!
	assert reports.len == 1
	assert reports[0].name == 'one.dmp'
	assert reports[0].mtime > 0
}
