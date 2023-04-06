const std = @import("std");
const graphics = @import("graphics/graphics.zig");
const zlm = @import("zlm");
const log = std.log.scoped(.PrimaryApp);

pub const App = struct {
    renderer: graphics.Renderer,

    pub fn init(settings: AppSettings) !App {
        try graphics.staticInit();
        return App{
            .renderer = blk: {
                var renderer = graphics.Renderer{};
                try renderer.initialize(settings.windowWidth, settings.windowHeight, settings.windowTitle);
                renderer.projectMat = zlm.Mat4.createOrthogonal(0.0, @intToFloat(f32, settings.windowWidth), 0.0, @intToFloat(f32, settings.windowHeight), -1.0, 1.0);
                break :blk renderer;
            },
        };
    }

    pub fn terminate(self: @This()) void {
        self.renderer.terminate();
        graphics.staticDeinit();
        log.info("App terminated successfully.\n", .{});
    }

    pub fn run(self: @This()) !void {
        try self.mainLoop();
    }

    fn mainLoop(self: @This()) !void {
        var angle: f16 = 0.0;
        const delta = 0.01;
        const mesh = graphics.Primitives.createRectangleMesh(100, 100);
        while (!self.renderer.windowShouldClose()) {
            angle = if (angle > std.math.pi) 0.0 else angle + delta;
            const sin = @sin(angle); //@sin(@intToFloat(f16, @divTrunc(std.time.timestamp(), 10000)));
            self.renderer.setClearColor(.{ .r = 1.0, .b = sin });
            self.renderer.clearScreen();

            self.renderer.pollEvents();

            try self.renderer.drawMesh(mesh, null);

            self.renderer.swapBuffers();
        }
    }
};

pub const AppSettings = struct {
    windowWidth: u32 = 600,
    windowHeight: u32 = 600,
    windowTitle: [:0]const u8,
};
