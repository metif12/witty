module cli_args

import os

fn process_args_snapshot() []string {
	return os.args.clone()
}
