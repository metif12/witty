module internal_os

// cgroup_clone_into is never selected away from Linux. Keeping the platform
// surface available lets shared subprocess code type-check on Darwin.
pub fn cgroup_clone_into(cgroup string) !int {
	_ = cgroup
	return error('cgroup cloning is only supported on Linux')
}
