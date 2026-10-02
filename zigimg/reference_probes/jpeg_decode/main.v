import os
import zigimg
fn main() {
 for path in os.args[1..] {
  data := os.read_bytes(path)!
  for mode in 0..2 {
   mut file := os.open(path)!
   mut buffer := []u8{len:4096}
   mut stream := if mode==0 { zigimg.ReadStream.init_memory(data) } else { zigimg.ReadStream.init_file(file, mut buffer) }
   mut jpeg := zigimg.JPEG.init()
   mut pixels := zigimg.JpegPixels{}
   frame := jpeg.read(mut stream, mut pixels) or {println('${os.file_name(path)}|${mode}|${err.msg()}|${stream.get_pos()}');file.close();continue}
   decoded := pixels.value or {panic('none')}
   mut hash := u64(14695981039346656037)
   for byte in decoded.as_bytes() { hash = (hash ^ byte) * u64(1099511628211) }
   println('${os.file_name(path)}|${mode}|ok|${stream.get_pos()}|${frame.frame_header.width}|${frame.frame_header.height}|${decoded.pixel_format()}|${hash:016x}')
   file.close()
  }
 }
}
