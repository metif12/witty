module apprt

fn test_none_app_perform_ipc_reports_unhandled() {
	target := IpcTarget(IpcTargetDetect{})
	action := IpcAction{ new_window: IpcNewWindow{} }
	assert NoneApp{}.perform_ipc(target, action)! == false
}
