module vxfw

fn test_center_border_padding_and_sized_box_source_constraints() {
	DrawContext.init(.unicode)
	text := &Text{
		text: 'abc'
	}
	ctx := DrawContext{
		max: MaxSize{
			width:  10
			height: 10
		}
	}
	center := Center{
		child: text.widget()
	}.draw(ctx)!
	assert center.size == Size{
		width:  10
		height: 10
	}
	assert center.children[0].origin == RelativePoint{
		row: 4
		col: 3
	}
	pad := Padding{
		child:   text.widget()
		padding: Padding.horizontal(1)
	}.draw(ctx)!
	assert pad.size == Size{
		width:  5
		height: 1
	}
	assert pad.children[0].origin == RelativePoint{
		col: 1
	}
	assert pad.buffer.len == 0
	assert Padding.all(3) == PadValues{
		left:   3
		right:  3
		top:    1
		bottom: 1
	}
	border := Border{
		child:  text.widget()
		labels: [BorderLabel{ text: 'Z', alignment: .top_right }]
	}.draw(ctx)!
	assert border.size == Size{
		width:  5
		height: 3
	}
	assert border.children[0].origin == RelativePoint{
		row: 1
		col: 1
	}
	assert border.read_cell(0, 0).char_.grapheme == '╭'
	assert border.read_cell(3, 0).char_.grapheme == 'Z'
	assert border.read_cell(4, 2).char_.grapheme == '╯'
	box := SizedBox{
		child: text.widget()
		size:  Size{
			width:  10
			height: 10
		}
	}
	boxed := box.widget().draw(DrawContext{
		max: MaxSize{
			width:  8
			height: 8
		}
	})!
	assert boxed.size == Size{
		width:  8
		height: 8
	}
	assert boxed.widget.eql(text.widget())
}

fn test_pinned_flex_row_and_column_distribute_different_inherent_sizes() {
	DrawContext.init(.unicode)
	a := &Text{
		text: 'abc'
	}
	b := &Text{
		text: 'def'
	}
	c := &Text{
		text: 'ghi'
	}
	d := &Text{
		text: 'jkl\nmno'
	}
	children := [FlexItem.init(a.widget(), 0), FlexItem.init(b.widget(), 1),
		FlexItem.init(c.widget(), 1), FlexItem.init(d.widget(), 1)]
	ctx := DrawContext{
		max: MaxSize{
			width:  16
			height: 16
		}
	}
	column := FlexColumn{
		children: children
	}.draw(ctx)!
	assert column.size == Size{
		width:  3
		height: 16
	}
	assert column.children.map(it.surface.size.height) == [u16(1), 4, 4, 7]
	assert column.children.map(it.origin.row) == [i32(0), 1, 5, 9]
	row := FlexRow{
		children: children
	}.draw(ctx)!
	assert row.size == Size{
		width:  16
		height: 2
	}
	assert row.children.map(it.surface.size.width) == [u16(3), 4, 4, 5]
	assert row.children.map(it.origin.col) == [i32(0), 3, 7, 11]
}
