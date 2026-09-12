module cli

import apprt.gtk
import internal_os

fn platform_version_lines() []string {
	kernel := internal_os.get_kernel_info() or { 'Kernel information unavailable' }
	return [
		'  - kernel version: ${kernel}',
		'  - desktop env   : ${internal_os.desktop_environment()}',
		'  - GTK version   :',
		'    build         : ${gtk.gtk_comptime_version}',
		'    runtime       : ${gtk.gtk_runtime_version()}',
		'  - libadwaita    : enabled',
		'    build         : ${gtk.adw_comptime_version}',
		'    runtime       : ${gtk.adw_runtime_version()}',
		'  - libX11        : enabled',
		'  - libwayland    : enabled',
	]
}
