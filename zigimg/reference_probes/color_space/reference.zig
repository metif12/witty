const std = @import("std");
const color = @import("src/color.zig");
const image_math = @import("src/math.zig");
fn emit(writer: *std.Io.Writer, value: f32) !void {
    const raw: u32 = if(std.math.isNan(value)) 0x7fc00000 else @bitCast(value);
    try writer.print("{d},", .{raw});
}
fn record(writer: *std.Io.Writer, value: anytype) !void {
    inline for (@typeInfo(@TypeOf(value)).@"struct".fields) |field| {if(field.type == f32) try emit(writer,@field(value,field.name));}
}
fn matrix(writer: *std.Io.Writer, value: image_math.float4x4) !void {
    for(value.matrix) |row| {inline for(0..4) |column| try emit(writer,row[column]);}
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    const contents = try std.fs.cwd().readFileAlloc(allocator,args[1],16*1024*1024);
    var lines = std.mem.tokenizeScalar(u8,contents,'\n');
    var output_buffer: [64 * 1024]u8 = undefined;
    var output = std.fs.File.stdout().writer(&output_buffer);
    const writer = &output.interface;
    const presets = [_]color.RgbColorspace{color.BT601_NTSC,color.BT601_PAL,color.BT709,color.sRGB,color.DCIP3.Display,
        color.DCIP3.Theater,color.DCIP3.ACES,color.BT2020,color.AdobeRGB,color.AdobeWideGamutRGB,color.ProPhotoRGB,
        color.RgbColorspace.init(.{})};
    while(lines.next()) |line| {
        var parts = std.mem.splitScalar(u8,line,'|');
        const space = presets[try std.fmt.parseInt(usize,parts.next().?,10)];
        const target = presets[try std.fmt.parseInt(usize,parts.next().?,10)];
        var vals: [4]f32 = undefined;
        for(&vals) |*item| item.* = @bitCast(try std.fmt.parseInt(u32,parts.next().?,10));
        const value = color.Colorf32{.r=vals[0],.g=vals[1],.b=vals[2],.a=vals[3]};
        
        try matrix(writer,space.rgba_to_xyza);
        try matrix(writer,space.xyza_to_rgba);
        try record(writer,space.toGamma(value));
        try record(writer,space.toGammaFast(value));
        try record(writer,space.toLinear(value));
        try record(writer,space.toLinearFast(value));
        try record(writer,space.toXYZ(value));
        try record(writer,space.toXYZAlpha(value));
        try record(writer,space.fromXYZ(color.CIEXYZ{.x=vals[0],.y=vals[1],.z=vals[2]}));
        try record(writer,space.fromXYZAlpha(color.CIEXYZAlpha{.x=vals[0],.y=vals[1],.z=vals[2],.a=vals[3]}));
        try record(writer,space.fromLab(color.CIELab{.l=vals[0],.a=vals[1],.b=vals[2]},.none));
        try record(writer,space.fromLab(color.CIELab{.l=vals[0],.a=vals[1],.b=vals[2]},.clamp));
        try record(writer,space.toLab(value));
        try record(writer,space.fromLabAlpha(color.CIELabAlpha{.l=vals[0],.a=vals[1],.b=vals[2],.alpha=vals[3]},.none));
        try record(writer,space.fromLabAlpha(color.CIELabAlpha{.l=vals[0],.a=vals[1],.b=vals[2],.alpha=vals[3]},.clamp));
        try record(writer,space.toLabAlpha(value));
        try record(writer,space.fromLuv(color.CIELuv{.l=vals[0],.u=vals[1],.v=vals[2]},.none));
        try record(writer,space.fromLuv(color.CIELuv{.l=vals[0],.u=vals[1],.v=vals[2]},.clamp));
        try record(writer,space.toLuv(value));
        try record(writer,space.fromLuvAlpha(color.CIELuvAlpha{.l=vals[0],.u=vals[1],.v=vals[2],.alpha=vals[3]},.none));
        try record(writer,space.fromLuvAlpha(color.CIELuvAlpha{.l=vals[0],.u=vals[1],.v=vals[2],.alpha=vals[3]},.clamp));
        try record(writer,space.toLuvAlpha(value));
        try record(writer,space.fromLCHab(color.CIELCHab{.l=vals[0],.c=vals[1],.h=vals[2]},.none));
        try record(writer,space.fromLCHab(color.CIELCHab{.l=vals[0],.c=vals[1],.h=vals[2]},.clamp));
        try record(writer,space.toLCHab(value));
        try record(writer,space.fromLCHabAlpha(color.CIELCHabAlpha{.l=vals[0],.c=vals[1],.h=vals[2],.alpha=vals[3]},.none));
        try record(writer,space.fromLCHabAlpha(color.CIELCHabAlpha{.l=vals[0],.c=vals[1],.h=vals[2],.alpha=vals[3]},.clamp));
        try record(writer,space.toLCHabAlpha(value));
        try record(writer,space.fromLCHuv(color.CIELCHuv{.l=vals[0],.c=vals[1],.h=vals[2]},.none));
        try record(writer,space.fromLCHuv(color.CIELCHuv{.l=vals[0],.c=vals[1],.h=vals[2]},.clamp));
        try record(writer,space.toLCHuv(value));
        try record(writer,space.fromLCHuvAlpha(color.CIELCHuvAlpha{.l=vals[0],.c=vals[1],.h=vals[2],.alpha=vals[3]},.none));
        try record(writer,space.fromLCHuvAlpha(color.CIELCHuvAlpha{.l=vals[0],.c=vals[1],.h=vals[2],.alpha=vals[3]},.clamp));
        try record(writer,space.toLCHuvAlpha(value));
        try record(writer,space.fromHSLuv(color.HSLuv{.h=vals[0],.s=vals[1],.l=vals[2]},.none));
        try record(writer,space.fromHSLuv(color.HSLuv{.h=vals[0],.s=vals[1],.l=vals[2]},.clamp));
        try record(writer,space.toHSLuv(value));
        try record(writer,space.fromHSLuvAlpha(color.HSLuvAlpha{.h=vals[0],.s=vals[1],.l=vals[2],.alpha=vals[3]},.none));
        try record(writer,space.fromHSLuvAlpha(color.HSLuvAlpha{.h=vals[0],.s=vals[1],.l=vals[2],.alpha=vals[3]},.clamp));
        try record(writer,space.toHSLuvAlpha(value));
        try record(writer,space.fromOkLab(color.Oklab{.l=vals[0],.a=vals[1],.b=vals[2]},.none));
        try record(writer,space.fromOkLab(color.Oklab{.l=vals[0],.a=vals[1],.b=vals[2]},.clamp));
        try record(writer,space.toOklab(value));
        try record(writer,space.fromOkLabAlpha(color.OklabAlpha{.l=vals[0],.a=vals[1],.b=vals[2],.alpha=vals[3]},.none));
        try record(writer,space.fromOkLabAlpha(color.OklabAlpha{.l=vals[0],.a=vals[1],.b=vals[2],.alpha=vals[3]},.clamp));
        try record(writer,space.toOklabAlpha(value));
        try record(writer,space.fromOkLCh(color.OkLCh{.l=vals[0],.c=vals[1],.h=vals[2]},.none));
        try record(writer,space.fromOkLCh(color.OkLCh{.l=vals[0],.c=vals[1],.h=vals[2]},.clamp));
        try record(writer,space.toOkLCh(value));
        try record(writer,space.fromOkLChAlpha(color.OkLChAlpha{.l=vals[0],.c=vals[1],.h=vals[2],.alpha=vals[3]},.none));
        try record(writer,space.fromOkLChAlpha(color.OkLChAlpha{.l=vals[0],.c=vals[1],.h=vals[2],.alpha=vals[3]},.clamp));
        try record(writer,space.toOkLChAlpha(value));
        try record(writer,color.RgbColorspace.convertColor(space,target,value));
        var conversions = [_]color.Colorf32{value,value};
        color.RgbColorspace.convertColors(space,target,&conversions);
        for(conversions) |actual| try record(writer,actual);
        var xyz_colors = [_]color.Colorf32{value,value};
        const xyz_copy = try space.sliceToXYZAlphaCopy(allocator,&xyz_colors);
        for(xyz_copy) |actual| try record(writer,actual);
        for(xyz_colors) |original| try record(writer,original);
        const xyz_inplace = space.sliceToXYZAlphaInPlace(&xyz_colors);
        try emit(writer,if (@intFromPtr(xyz_inplace.ptr)==@intFromPtr(&xyz_colors)) 1 else 0);
        try emit(writer,if (@intFromPtr(xyz_copy.ptr)!=@intFromPtr(&xyz_colors)) 1 else 0);
        for(xyz_inplace) |actual| try record(writer,actual);
        const xyz_back = try space.sliceFromXYZAlphaCopy(allocator,xyz_copy);
        for(xyz_back) |actual| try record(writer,actual);
        const xyz_back_inplace = space.sliceFromXYZAlphaInPlace(xyz_inplace);
        try emit(writer,if (@intFromPtr(xyz_back_inplace.ptr)==@intFromPtr(&xyz_colors)) 1 else 0);
        for(xyz_back_inplace) |actual| try record(writer,actual);
        try emit(writer,@floatFromInt(space.sliceFromXYZAlphaInPlace(&.{}).len));
        var lab_colors = [_]color.Colorf32{value,value};
        const lab_copy = try space.sliceToLabAlphaCopy(allocator,&lab_colors);
        for(lab_copy) |actual| try record(writer,actual);
        for(lab_colors) |original| try record(writer,original);
        const lab_inplace = space.sliceToLabAlphaInPlace(&lab_colors);
        try emit(writer,if (@intFromPtr(lab_inplace.ptr)==@intFromPtr(&lab_colors)) 1 else 0);
        try emit(writer,if (@intFromPtr(lab_copy.ptr)!=@intFromPtr(&lab_colors)) 1 else 0);
        for(lab_inplace) |actual| try record(writer,actual);
        const lab_back_none = try space.sliceFromLabAlphaCopy(allocator,lab_copy,.none);
        for(lab_back_none) |actual| try record(writer,actual);
        const lab_back_clamp = try space.sliceFromLabAlphaCopy(allocator,lab_copy,.clamp);
        for(lab_back_clamp) |actual| try record(writer,actual);
        const lab_back_inplace = space.sliceFromLabAlphaInPlace(lab_inplace,.clamp);
        try emit(writer,if (@intFromPtr(lab_back_inplace.ptr)==@intFromPtr(&lab_colors)) 1 else 0);
        for(lab_back_inplace) |actual| try record(writer,actual);
        try emit(writer,@floatFromInt(space.sliceFromLabAlphaInPlace(&.{},.clamp).len));
        var luv_colors = [_]color.Colorf32{value,value};
        const luv_copy = try space.sliceToLuvAlphaCopy(allocator,&luv_colors);
        for(luv_copy) |actual| try record(writer,actual);
        for(luv_colors) |original| try record(writer,original);
        const luv_inplace = space.sliceToLuvAlphaInPlace(&luv_colors);
        try emit(writer,if (@intFromPtr(luv_inplace.ptr)==@intFromPtr(&luv_colors)) 1 else 0);
        try emit(writer,if (@intFromPtr(luv_copy.ptr)!=@intFromPtr(&luv_colors)) 1 else 0);
        for(luv_inplace) |actual| try record(writer,actual);
        const luv_back_none = try space.sliceFromLuvAlphaCopy(allocator,luv_copy,.none);
        for(luv_back_none) |actual| try record(writer,actual);
        const luv_back_clamp = try space.sliceFromLuvAlphaCopy(allocator,luv_copy,.clamp);
        for(luv_back_clamp) |actual| try record(writer,actual);
        const luv_back_inplace = space.sliceFromLuvAlphaInPlace(luv_inplace,.clamp);
        try emit(writer,if (@intFromPtr(luv_back_inplace.ptr)==@intFromPtr(&luv_colors)) 1 else 0);
        for(luv_back_inplace) |actual| try record(writer,actual);
        try emit(writer,@floatFromInt(space.sliceFromLuvAlphaInPlace(&.{},.clamp).len));
        var oklab_colors = [_]color.Colorf32{value,value};
        const oklab_copy = try space.sliceToOklabAlphaCopy(allocator,&oklab_colors);
        for(oklab_copy) |actual| try record(writer,actual);
        for(oklab_colors) |original| try record(writer,original);
        const oklab_inplace = space.sliceToOklabAlphaInPlace(&oklab_colors);
        try emit(writer,if (@intFromPtr(oklab_inplace.ptr)==@intFromPtr(&oklab_colors)) 1 else 0);
        try emit(writer,if (@intFromPtr(oklab_copy.ptr)!=@intFromPtr(&oklab_colors)) 1 else 0);
        for(oklab_inplace) |actual| try record(writer,actual);
        const oklab_back_none = try space.sliceFromOkLabAlphaCopy(allocator,oklab_copy,.none);
        for(oklab_back_none) |actual| try record(writer,actual);
        const oklab_back_clamp = try space.sliceFromOkLabAlphaCopy(allocator,oklab_copy,.clamp);
        for(oklab_back_clamp) |actual| try record(writer,actual);
        const oklab_back_inplace = space.sliceFromOkLabAlphaInPlace(oklab_inplace,.clamp);
        try emit(writer,if (@intFromPtr(oklab_back_inplace.ptr)==@intFromPtr(&oklab_colors)) 1 else 0);
        for(oklab_back_inplace) |actual| try record(writer,actual);
        try emit(writer,@floatFromInt(space.sliceFromOkLabAlphaInPlace(&.{},.clamp).len));
        inline for(.{color.sRGB_TransferFunctions,color.Rec601_TransferFunctions,color.Rec709_TransferFunctions,
            color.BT2020_TransferFunctions,color.ProPhotoRGB_TransferFunctions,color.NonLinearGammaTransferFunctions(.{}),
            color.DCIP3_TransferFuntions,color.AdobeRGB_TransferFunctions,color.CurveGammaTransferFunctions(0),color.CurveGammaTransferFunctions(-2)}) |Transfer| {
            try emit(writer,Transfer.toGamma(value.r));
            try emit(writer,Transfer.toGammaFast(value.r));
            try emit(writer,Transfer.toLinear(value.r));
            try emit(writer,Transfer.toLinearFast(value.r));
        }
        try emit(writer,color.applyGamma(value.r,value.g));
        try emit(writer,color.removeGamma(value.r,value.g));
        inline for(@typeInfo(color.WhitePoints).@"struct".decls) |declaration| try record(writer,@field(color.WhitePoints,declaration.name));
        try writer.writeByte('\n');
    }
    try writer.flush();
}
