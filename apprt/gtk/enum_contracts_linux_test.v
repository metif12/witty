module gtk

fn test_gtk_enum_layouts_and_source_values() {
	assert sizeof(AdwColorScheme) == 4
	assert [AdwColorScheme.default_, .force_light, .prefer_light, .prefer_dark, .force_dark].map(i32(it)) == [
		i32(0),
		1,
		2,
		3,
		4,
	]
	assert sizeof(GBusType) == 4
	assert [GBusType.starter, .@none, .system, .session].map(i32(it)) == [i32(-1), 0, 1, 2]
	assert sizeof(Align) == 4
	assert [Align.fill, .start, .end, .center, .baseline].map(i32(it)) == [i32(0), 1, 2, 3, 4]
	assert sizeof(GtkScrollablePolicy) == 4
	assert [GtkScrollablePolicy.minimum, .natural].map(i32(it)) == [i32(0), 1]
	assert sizeof(PolicyType) == 4
	assert [PolicyType.always, .automatic, .never, .external].map(i32(it)) == [i32(0), 1, 2, 3]
	assert sizeof(AdwToolbarStyle) == 4
	assert [AdwToolbarStyle.flat, .raised, .raised_border].map(i32(it)) == [i32(0), 1, 2]
	assert sizeof(CloseTarget) == 4
	assert [CloseTarget.app, .tab, .window, .surface].map(i32(it)) == [i32(0), 1, 2, 3]
	assert sizeof(CloseTabMode) == 4
	assert [CloseTabMode.this, .other, .right].map(i32(it)) == [i32(0), 1, 2]
	assert sizeof(KdeKwinServerDecorationMode) == 4
	assert [KdeKwinServerDecorationMode.none_, .client, .server].map(u32(it)) == [
		u32(0),
		1,
		2,
	]

	assert sizeof(QuitTimerState) == 1
	assert [QuitTimerState.off, .active, .expired].map(u8(it)) == [u8(0), 1, 2]
	assert sizeof(CommandDataKind) == 1
	assert [CommandDataKind.regular, .jump].map(u8(it)) == [u8(0), 1]
	assert sizeof(Method) == 1
	assert [Method.create_session, .bind_shortcuts].map(u8(it)) == [u8(0), 1]
	assert sizeof(IMKeyEvent) == 1
	assert [IMKeyEvent.false_, .composing, .not_composing].map(u8(it)) == [u8(0), 1, 2]
	assert sizeof(SelectTabKind) == 1
	assert [SelectTabKind.previous, .next, .last, .n].map(u8(it)) == [u8(0), 1, 2, 3]
	assert sizeof(Protocol) == 1
	assert [Protocol.none_, .wayland, .x11].map(u8(it)) == [u8(0), 1, 2]
}
