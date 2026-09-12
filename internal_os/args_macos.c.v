module internal_os

import macos

fn platform_args() []string {
	return macos.process_arguments()
}
