module cli

import apprt
import apprt.gtk

fn perform_new_window_ipc(opts NewWindowOptions) !bool {
	target := if class := opts.class {
		apprt.IpcTarget(apprt.IpcTargetClass{ class: class })
	} else {
		apprt.IpcTarget(apprt.IpcTargetDetect{})
	}
	arguments := opts.arguments or { []string{} }
	action := apprt.IpcAction(apprt.IpcNewWindow{
		arguments: arguments
	})
	return gtk.App.perform_ipc(target, action)
}
