module zigimg

fn test_gif_packed_field_mutations_preserve_other_bits_and_copies() {
	for raw in 0 .. 256 {
		mut header := GifHeaderFlags{
			raw: u8(raw)
		}
		header_copy := header
		header.set_global_color_table_size(7 - header.global_color_table_size())
		header.set_sorted(!header.sorted())
		header.set_color_resolution(7 - header.color_resolution())
		header.set_use_global_color_table(!header.use_global_color_table())
		assert header.raw == u8(raw ^ 255) && header_copy.raw == u8(raw)
		mut descriptor := GifImageDescriptorFlags{
			raw: u8(raw)
		}
		descriptor_copy := descriptor
		descriptor.set_local_color_table_size(7 - descriptor.local_color_table_size())
		descriptor.set_reserved(3 - descriptor.reserved())
		descriptor.set_sort(!descriptor.sort())
		descriptor.set_is_interlaced(!descriptor.is_interlaced())
		descriptor.set_has_local_color_table(!descriptor.has_local_color_table())
		assert descriptor.raw == u8(raw ^ 255) && descriptor_copy.raw == u8(raw)
		mut control := GifGraphicControlExtensionFlags{
			raw: u8(raw)
		}
		control_copy := control
		control.set_has_transparent_color(!control.has_transparent_color())
		control.set_user_input(!control.user_input())
		control.set_disposal_method(unsafe { GifDisposeMethod(7 - u8(control.disposal_method())) })
		control.set_reserved(7 - control.reserved())
		assert control.raw == u8(raw ^ 255) && control_copy.raw == u8(raw)
	}
}

fn test_gif_required_extensions_keep_inline_copies_and_borrowed_data() {
	mut data := [u8(1), 2, 3]
	mut application := GifApplicationExtension{
		application_identifier: [8]u8{}
		authentification_code:  [3]u8{}
		data:                   data
	}
	copied := application
	application.application_identifier[0] = `N`
	application.authentification_code[0] = `2`
	data[1] = 42
	application.data = application.data[..1]
	assert copied.application_identifier[0] == 0 && copied.authentification_code[0] == 0
	assert copied.data == [u8(1), 42, 3] && application.data == [u8(1)]
	comment := GifCommentExtension{
		comment: data
	}
	data[2] = 9
	assert comment.comment == [u8(1), 42, 9]
}
