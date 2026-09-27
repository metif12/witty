module cli

import apprt
import apprt.gtk

fn perform_new_window_ipc(opts NewWindowOptions) !bool {
	target := if class := opts.class {
		apprt.IpcTarget(apprt.IpcTargetClass{ class: class })
	} else {
		apprt.IpcTarget(apprt.IpcTargetDetect{})
	}
	action := apprt.IpcAction{
		new_window: apprt.IpcNewWindow{
			arguments: opts.arguments
		}
	}
	return gtk.App.perform_ipc(target, action)
}
