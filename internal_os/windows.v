module internal_os

// Windows process-thread attribute constants translated from os/windows.zig.
// The surrounding Win32 declarations are supplied by V's Windows runtime;
// this helper is Ghostty's own WinBase.h bit-packing logic.
pub const proc_thread_attribute_number_mask = u32(0x0000ffff)
pub const proc_thread_attribute_thread = u32(0x00010000)
pub const proc_thread_attribute_input = u32(0x00020000)
pub const proc_thread_attribute_additive = u32(0x00040000)

pub enum ProcThreadAttributeNumber as u32 {
	pseudo_console = 22
}

// proc_thread_attribute_value corresponds to the ProcThreadAttributeValue
// macro in WinBase.h.
pub fn proc_thread_attribute_value(attribute ProcThreadAttributeNumber, thread_attr bool, input_attr bool, additive bool) u32 {
	return (u32(attribute) & proc_thread_attribute_number_mask)
		| (if thread_attr { proc_thread_attribute_thread } else { u32(0) })
		| (if input_attr { proc_thread_attribute_input } else { u32(0) })
		| (if additive { proc_thread_attribute_additive } else { u32(0) })
}

pub const proc_thread_attribute_pseudoconsole = proc_thread_attribute_value(.pseudo_console,
	false, true, false)
