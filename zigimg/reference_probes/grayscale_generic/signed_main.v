module main

import zigimg as c

fn main() {
	{
		x := c.GrayscaleAlpha.init(i8(-1))
		mut copy := x
		copy.alpha = i8(-1)
		println('${x.value},${x.alpha};${copy.value},${copy.alpha}')
	}
	{
		x := c.GrayscaleAlpha.init(i16(-1))
		mut copy := x
		copy.alpha = i16(-1)
		println('${x.value},${x.alpha};${copy.value},${copy.alpha}')
	}
	{
		x := c.GrayscaleAlpha.init(int(-1))
		mut copy := x
		copy.alpha = int(-1)
		println('${x.value},${x.alpha};${copy.value},${copy.alpha}')
	}
	{
		x := c.GrayscaleAlpha.init(i64(-1))
		mut copy := x
		copy.alpha = i64(-1)
		println('${x.value},${x.alpha};${copy.value},${copy.alpha}')
	}
	{
		x := c.GrayscaleAlpha.init(int(-1))
		mut copy := x
		copy.alpha = int(-1)
		println('${x.value},${x.alpha};${copy.value},${copy.alpha}')
	}
}
