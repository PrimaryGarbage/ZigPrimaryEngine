pub const image = @import("graphics/image.zig");
pub const main = @import("main.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
