const zlm = @import("zlm");
const Color = @import("color.zig").Color;

pub const Pixel = struct {
    point: zlm.Vec2 = zlm.Vec2.zero,
    color: Color = Color.black,
};
