module main
import zigimg
type Zero = [0]u8
fn main(){_=zigimg.simd_load[Zero,u8]([]u8{},0)}
