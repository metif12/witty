module cli_args

import internal_os

fn process_args_snapshot() []string {
	return internal_os.process_args()
}
