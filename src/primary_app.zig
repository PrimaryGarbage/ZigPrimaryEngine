const std = @import("std");
const graphics = @import("graphics/graphics.zig");
const log = std.log.scoped(.PrimaryApp);

pub const App = struct {
    renderer: graphics.Renderer,

    pub fn init(settings: AppSettings) !App {
        return App{
            .renderer = blk: {
                var renderer = graphics.Renderer{};
                try renderer.initialize(settings.windowWidth, settings.windowHeight, settings.windowTitle);
                break :blk renderer;
            },
        };
    }

    pub fn terminate(self: @This()) void {
        self.renderer.terminate();
        log.info("App terminated successfully.\n", .{});
    }

    pub fn run(self: @This()) void {
        self.mainLoop();
    }

    fn mainLoop(self: @This()) void {
        var angle: f16 = 0.0;
        const delta = 0.01;
        while (!self.renderer.windowShouldClose()) {
            angle = if (angle > std.math.pi) 0.0 else angle + delta;
            const sin = @sin(angle); //@sin(@intToFloat(f16, @divTrunc(std.time.timestamp(), 10000)));
            self.renderer.setClearColor(.{ .r = 1.0, .b = sin });
            self.renderer.clearScreen();

            self.renderer.pollEvents();

            self.renderer.swapBuffers();
        }
    }
};

pub const AppSettings = struct {
    windowWidth: u32 = 600,
    windowHeight: u32 = 600,
    windowTitle: [:0]const u8,
};
