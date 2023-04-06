pub const image = @import("graphics/graphics_tests.zig");
pub const main = @import("main.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
