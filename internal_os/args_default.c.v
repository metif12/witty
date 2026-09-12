module internal_os

import os

fn platform_args() []string {
	return os.args.clone()
}
