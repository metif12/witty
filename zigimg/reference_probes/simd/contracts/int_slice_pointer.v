module main
import zigimg
type Floats = [4]f32
fn main(){a:=[u16(1),2,3,4];_=zigimg.simd_int_to_float[Floats,&[]u16](&a)}
