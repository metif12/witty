module main
import os
import strconv
import strings
import encoding.hex
import vaxis
import zigimg
fn number(value string) u32 {return u32(strconv.parse_uint(value,10,32) or {panic(err)})}
fn main() {
	if os.args[1].starts_with('trap') {
		mut bytes:=[]u8{len:16}; mut writer:=zigimg.WriteStream.init_memory(mut bytes)
		vaxis.terminal_key_encode(mut writer,vaxis.Key{codepoint:u32(`a`),text:''},true,vaxis.KittyFlags.from_int(u8(number(os.args[1][4..])))) or {eprintln('UNEXPECTED: ${err}');return}
		eprintln('UNEXPECTED: returned');return
	}
	mut output:=strings.new_builder(4096)
	text:=os.read_file(os.args[1]) or {panic(err)}
	for line in text.split_into_lines() {
		p:=line.split('|'); mut bytes:=[]u8{len:int(number(p[5]))}; mut writer:=zigimg.WriteStream.init_memory(mut bytes)
		initial:=hex.decode(p[6]) or {panic(err)};writer.write_all(initial) or {panic(err)}
		mut key:=vaxis.Key{codepoint:number(p[0]),mods:vaxis.Modifiers.from_int(u8(number(p[1]))),shifted_codepoint:65,base_layout_codepoint:97}
		if p[4]!='-' {key.text=(hex.decode(p[4]) or {panic(err)}).bytestr()}
		mut error_:='ok';vaxis.terminal_key_encode(mut writer,key,p[2]=='1',vaxis.KittyFlags.from_int(u8(number(p[3])))) or {error_=err.msg()}
		output.write_string('${error_}|${writer.get_pos()}|${hex.encode(writer.buffered())}\n')
	}
	print(output.str())
}
