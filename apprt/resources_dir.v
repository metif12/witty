module apprt

import internal_os

// resources_dir is the resource-directory export shared by the merged
// browser, none, and embedded runtimes. Each corresponding Ghostty backend
// aliases this function from internal_os.
pub fn resources_dir() internal_os.ResourcesDir {
	return internal_os.resources_dir()
}
