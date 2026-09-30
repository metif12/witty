const zigimg = @import("zigimg");

pub fn main() !void {
    var stream = zigimg.io.ReadStream.initMemory("#define w 8\n");
    _ = try zigimg.formats.xbm.XBM.formatDetect(&stream);
    @panic("XBM detection unexpectedly returned");
}
