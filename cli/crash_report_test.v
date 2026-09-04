module cli

import crash
import os

fn test_crash_report_empty_output_depends_on_tty() {
	dir := os.join_path(os.temp_dir(), 'witty-crash-report-empty-${os.getpid()}')
	os.rmdir_all(dir) or {}
	defer {
		os.rmdir_all(dir) or {}
	}
	assert crash_report_output(dir, 0, false)! == ''
	assert crash_report_output(dir, 0, true)! == 'No crash reports! 👻\n'
}

fn test_crash_report_lists_newest_first_with_duration() {
	output := format_crash_reports([
		crash.Report{
			name: 'old.dmp'
			mtime: 30_000_000_000
		},
		crash.Report{
			name: 'new.dmp'
			mtime: 90_000_000_000
		},
	], 120_000_000_000, false)
	assert output == 'new.dmp (30s ago)\nold.dmp (1m 30s ago)\n'
}

fn test_crash_report_future_timestamp_is_now() {
	output := format_crash_reports([
		crash.Report{
			name: 'future.dmp'
			mtime: 2
		},
	], 1, false)
	assert output == 'future.dmp (now)\n'
}
