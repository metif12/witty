module cli

import configpkg
import crash
import os
import time

struct CrashReportOptions {}

// crash_report_output lists crash reports newest-first. An empty non-TTY
// output stays silent for scripting, while an interactive terminal receives
// Ghostty's friendly empty-state message.
pub fn crash_report_output(path string, now_ns i64, is_tty bool) !string {
	reports := crash.Dir{ path: path }.reports()!
	return format_crash_reports(reports, now_ns, is_tty)
}

fn format_crash_reports(reports []crash.Report, now_ns i64, is_tty bool) string {
	if reports.len == 0 {
		return if is_tty { 'No crash reports! 👻\n' } else { '' }
	}
	mut sorted := reports.clone()
	sorted.sort(a.mtime > b.mtime)
	mut lines := []string{cap: sorted.len}
	for report in sorted {
		diff := now_ns - report.mtime
		since := if diff <= 0 {
			'now'
		} else {
			rounded := u64(diff) / u64(1_000_000_000) * u64(1_000_000_000)
			'${configpkg.Duration{ duration: rounded }.format()} ago'
		}
		lines << '${report.name} (${since})'
	}
	return output_lines(lines)
}

pub fn run_crash_report(args []string) !int {
	_ := parse_action_options[CrashReportOptions](args)!
	print(crash_report_output(crash.default_dir()!.path, time.now().unix_nano(), os.is_atty(1) > 0)!)
	return 0
}
