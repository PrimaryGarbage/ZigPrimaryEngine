pub const image = @import("graphics/ggraphics_tests.zig");
pub const main = @import("main.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
