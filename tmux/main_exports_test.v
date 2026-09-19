module tmux

fn test_tmux_control_notification_alias() {
	notification := ControlNotification(NotifExit{})
	assert notification is NotifExit
}
