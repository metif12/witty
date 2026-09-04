module internal_os

// CgroupCurrentResult preserves the source error-union-of-optional result in
// V: value is none when the proc file has no cgroup field, while I/O failures
// are returned separately by cgroup_current on Linux.
pub struct CgroupCurrentResult {
pub:
	value ?string
}

// cgroup_path_from_contents extracts everything after the final colon and
// trims only the trailing characters ignored by the cgroup v2 proc format.
pub fn cgroup_path_from_contents(contents string) CgroupCurrentResult {
	idx := contents.last_index_u8(`:`)
	if idx < 0 {
		return CgroupCurrentResult{}
	}
	return CgroupCurrentResult{
		value: contents[idx + 1..].trim_right(' \r\n')
	}
}

pub enum CgroupLimitKind {
	memory_high
	pids_max
}

pub struct CgroupLimit {
pub:
	kind  CgroupLimitKind
	value u64
}
