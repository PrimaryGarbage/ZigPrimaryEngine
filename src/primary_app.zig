const std = @import("std");
const graphics = @import("graphics/graphics.zig");
const log = std.log.scoped(.PrimaryApp);

pub const App = struct {
    renderer: graphics.Renderer,

    pub fn init(windowWidth: u32, windowHeight: u32, windowTitle: [:0]const u8) !App {
        return App{
            .renderer = blk: {
                var renderer = graphics.Renderer{};
                try renderer.initialize(windowWidth, windowHeight, windowTitle);
                break :blk renderer;
            },
        };
    }

    pub fn terminate(self: @This()) void {
        self.renderer.terminate();
        log.info("App terminated successfully.\n", .{});
    }

    pub fn run(self: @This()) void {
        self.renderer.setClearColor(.{ .r = 1.0, .b = 1.0 });
        self.mainLoop();
    }

    fn mainLoop(self: @This()) void {
        while (!self.renderer.windowShouldClose()) {
            self.renderer.clearScreen();

            self.renderer.pollEvents();

            self.renderer.swapBuffers();
        }
    }
};
