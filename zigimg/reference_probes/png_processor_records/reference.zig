const std = @import("std");
const r = @import("src/formats/png/reader.zig");
const p = @import("src/formats/png/types.zig");
const color = @import("src/color.zig");
const io = @import("src/io.zig");
const Format = @import("src/pixel_format.zig").PixelFormat;
const ReadError = @import("src/ImageUnmanaged.zig").ReadError;
const allocator = std.heap.page_allocator;
const VTable = @typeInfo(@FieldType(r.ReaderProcessor, "vtable")).pointer.child;

const Context = struct { calls: u32 = 0, fail: bool = false, bias: u8 = 0 };
fn chunk(ctx: *anyopaque, data: *r.ChunkProcessData) ReadError!Format {
    const self: *Context = @ptrCast(@alignCast(ctx));
    self.calls += 1;
    _ = try data.read_stream.reader().take(1);
    data.chunk_id += self.bias;
    data.chunk_length = 17;
    data.current_format = .rgba32;
    if (self.fail) return error.Unsupported;
    return .rgba64;
}
fn palette(ctx: *anyopaque, data: *r.PaletteProcessData) ReadError!void {
    const self: *Context = @ptrCast(@alignCast(ctx));
    self.calls += 1;
    data.palette[0].a = self.bias;
    if (self.fail) return error.Unsupported;
    data.palette = data.palette[0..1];
}
fn row(ctx: *anyopaque, data: *r.RowProcessData) ReadError!Format {
    const self: *Context = @ptrCast(@alignCast(ctx));
    self.calls += 1;
    data.dest_row[0] = self.bias;
    data.src_format = .rgb24;
    if (self.fail) return error.Unsupported;
    data.dest_row = data.dest_row[0..1];
    data.dest_format = .rgba64;
    return .rgba32;
}

pub fn main() !void {
    var output = std.fs.File.stdout().writer(&.{});
    const writer = &output.interface;
    const options = r.ReaderOptions{};
    const initialized = r.ReaderOptions.init(allocator);
    const trns = r.TrnsProcessor{};
    const plte = r.PlteProcessor{};
    try writer.print("D|{d}|{d}|{}|{}|{}\n", .{ options.processors.len, initialized.processors.len, trns.trns_data == .unset, trns.processed, plte.processed });

    // Mutable payloads correspond to tagged-union members, not extra structs.
    var gray = r.TrnsProcessor{ .trns_data = .{ .gray = 7 } };
    const gray_copy = gray;
    gray.trns_data = .{ .gray = 65535 };
    var rgb = r.TrnsProcessor{ .trns_data = .{ .rgb = color.Rgb48.from.rgb(1, 2, 3) } };
    const rgb_copy = rgb;
    rgb.trns_data = .{ .rgb = color.Rgb48.from.rgb(42, 2, 3) };
    var alpha = [_]u8{ 11, 22 };
    var indexed = r.TrnsProcessor{ .trns_data = .{ .index_alpha = &alpha } };
    const indexed_copy = indexed;
    indexed.trns_data.index_alpha[0] = 33;
    indexed.trns_data = .{ .index_alpha = indexed.trns_data.index_alpha[0..1] };
    try writer.print("U|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}\n", .{ gray_copy.trns_data.gray, gray.trns_data.gray, rgb_copy.trns_data.rgb.r, rgb.trns_data.rgb.r, indexed_copy.trns_data.index_alpha[0], alpha[0], indexed_copy.trns_data.index_alpha.len, indexed.trns_data.index_alpha.len });

    for (0..8) |mask| for ([_]bool{ false, true }) |fail| for ([_]u8{ 0, 1, 127, 255 }) |bias| {
        var bytes = [_]u8{ 1, 2, 3, 4 };
        var stream = io.ReadStream.initMemory(&bytes);
        var header = p.HeaderData{ .width = 3, .height = 4, .bit_depth = 8, .color_type = .grayscale, .compression_method = .deflate, .filter_method = .adaptive, .interlace_method = .none };
        var ctx = Context{ .fail = fail, .bias = bias };
        var table = VTable{ .chunk_processor = if (mask & 1 != 0) chunk else null, .palette_processor = if (mask & 2 != 0) palette else null, .data_row_processor = if (mask & 4 != 0) row else null };
        var processor = r.ReaderProcessor{ .id = 1, .context = &ctx, .vtable = &table };
        var copied = processor;
        processor.id = 99;
        var cdata = r.ChunkProcessData{ .read_stream = &stream, .chunk_id = 100, .chunk_length = 3, .current_format = .grayscale8, .header = &header, .temp_allocator = allocator };
        var ccopy = cdata;
        cdata.chunk_id = 200;
        header.width = 42;
        var cstatus: []const u8 = "ok";
        const cresult = copied.processChunk(&ccopy) catch |err| blk: {
            cstatus = @errorName(err);
            break :blk .invalid;
        };
        var colors = [_]color.Rgba32{ color.Rgba32.from.rgba(1, 2, 3, 4), color.Rgba32.from.rgba(5, 6, 7, 8) };
        var pdata = r.PaletteProcessData{ .palette = &colors, .temp_allocator = allocator };
        const pcopy = pdata;
        var pstatus: []const u8 = "ok";
        copied.processPalette(&pdata) catch |err| {
            pstatus = @errorName(err);
        };
        var values = [_]u8{ 10, 20, 30, 40 };
        var rdata = r.RowProcessData{ .dest_row = &values, .src_format = .grayscale8, .dest_format = .rgba32, .header = &header, .temp_allocator = allocator };
        const rcopy = rdata;
        var rstatus: []const u8 = "ok";
        const rresult = copied.processDataRow(&rdata) catch |err| blk: {
            rstatus = @errorName(err);
            break :blk .invalid;
        };
        try writer.print("C|{d}|{}|{d}|{s}|{d}|{s}|{s}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{d}|{}|{}\n", .{ mask, fail, bias, cstatus, @intFromEnum(cresult), pstatus, rstatus, @intFromEnum(rresult), ctx.calls, stream.getPos(), processor.id, copied.id, cdata.chunk_id, ccopy.chunk_id, ccopy.chunk_length, @intFromEnum(ccopy.current_format), ccopy.header.width, pdata.palette.len, pcopy.palette.len, pcopy.palette[0].a, rdata.dest_row.len, rcopy.dest_row[0], @intFromEnum(rdata.src_format), @intFromEnum(rcopy.src_format), copied.context == @as(*anyopaque, @ptrCast(&ctx)), copied.vtable == &table });
        // A copied processor continues to borrow its caller-owned vtable.
        table.chunk_processor = null;
        table.palette_processor = null;
        table.data_row_processor = null;
        const cafter = try copied.processChunk(&ccopy);
        try copied.processPalette(&pdata);
        const rafter = try copied.processDataRow(&rdata);
        try writer.print("V|{d}|{d}|{d}|{d}\n", .{ mask, @intFromEnum(cafter), @intFromEnum(rafter), ctx.calls });
        var processors = [_]r.ReaderProcessor{copied};
        const with_processors = r.ReaderOptions.initWithProcessors(allocator, &processors);
        var options_copy = with_processors;
        options_copy.processors = options_copy.processors[0..0];
        processors[0].id = 123;
        try writer.print("O|{d}|{d}|{d}|{}\n", .{ with_processors.processors.len, options_copy.processors.len, with_processors.processors[0].id, @intFromPtr(with_processors.processors.ptr) == @intFromPtr(&processors[0]) });
    };

    var one = r.CustomReaderOptions1(r.TrnsProcessor).init(.{});
    var one_view = one.get();
    var one_copy = one;
    one.processors[0].id = 123;
    var colors = [_]color.Rgba32{color.Rgba32.from.rgba(1, 2, 3, 4)};
    var data = r.PaletteProcessData{ .palette = &colors, .temp_allocator = allocator };
    try one_copy.processors[0].processPalette(&data);
    try writer.print("G1|{d}|{d}|{}|{}|{}|{}\n", .{ one_view.processors.len, one_view.processors[0].id, @intFromPtr(one_view.processors.ptr) == @intFromPtr(&one.processors[0]), one_view.processors[0].context == @as(*anyopaque, @ptrCast(&one.processor)), one.processor.processed, one_copy.processor.processed });
    one_view = one.get();
    try writer.print("G1R|{d}|{}\n", .{ one_view.processors[0].id, one_view.processors[0].context == @as(*anyopaque, @ptrCast(&one.processor)) });
    var two = r.CustomReaderOptions2(r.TrnsProcessor, r.PlteProcessor).init(.{}, .{});
    const two_view = two.get();
    try two.processors[1].processPalette(&data);
    try writer.print("G2|{d}|{d}|{d}|{}|{}|{}|{d}\n", .{ two_view.processors.len, two_view.processors[0].id, two_view.processors[1].id, @intFromPtr(two_view.processors.ptr) == @intFromPtr(&two.processors[0]), two_view.processors[0].context == @as(*anyopaque, @ptrCast(&two.processor1)), two_view.processors[1].context == @as(*anyopaque, @ptrCast(&two.processor2)), two.processor2.palette[0].a });
    colors[0].a = 77;
    try writer.print("GB|{d}|{}\n", .{ two.processor2.palette[0].a, two.processor2.processed });
    var defaults = r.DefaultOptions.init(.{});
    const default_view = defaults.get();
    try writer.print("GD|{d}|{d}|{}\n", .{ default_view.processors.len, default_view.processors[0].id, default_view.processors[0].context == @as(*anyopaque, @ptrCast(&defaults.processor)) });
}
