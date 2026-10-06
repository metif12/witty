const vaxis=@import("vaxis");pub fn main()void{if(vaxis.tty.global_tty!=null)@panic("UNEXPECTED global tty");}
