module cli_args

// VT has no process-argument API; retain the source lazy import boundary.
$if !ghostty_wasm_module ? {

import internal_os

fn process_args_snapshot() []string {
	return internal_os.process_args()
}

}
