const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const log = std.log.scoped(.Renderer);

var windowRendererMap = std.AutoHashMap(*const glfw.Window, *Renderer).init(std.heap.page_allocator);

pub const Renderer = struct {
    window: glfw.Window = undefined,
    windowWidth: u32 = 0,
    windowHeight: u32 = 0,

    const RendererError = error{InitializionError};

    pub fn initialize(self: *@This(), width: u32, height: u32, title: [:0]const u8) !void {
        if (!glfw.init(.{})) {
            self.terminate();
            return RendererError.InitializionError;
        }

        self.windowWidth = width;
        self.windowHeight = height;

        self.window = createWindow(width, height, title) orelse @panic("Failed to init window.");
        try windowRendererMap.put(&self.window, self);

        glfw.makeContextCurrent(self.window);
        glfw.setErrorCallback(comptime errorCallback);
        self.window.setFramebufferSizeCallback(framebufferSizeCallback);
        glfw.swapInterval(1);

        gl.load(self.window, glGetProcAddress) catch @panic("Failed to load opengl extensions.");

        gl.viewport(0, 0, @intCast(c_int, width), @intCast(c_int, height));

        log.info("GLFW initialized successfully.\n", .{});
    }

    pub fn terminate(_: @This()) void {
        glfw.terminate();
        log.info("GLFW terminated successfully.\n", .{});
    }

    pub fn pollEvents(_: @This()) void {
        glfw.pollEvents();
    }

    pub fn windowShouldClose(self: @This()) bool {
        return self.window.shouldClose();
    }

    fn createWindow(width: u32, height: u32, title: [:0]const u8) ?glfw.Window {
        const windowHints = glfw.Window.Hints{
            .resizable = false,
        };

        const window = glfw.Window.create(width, height, title, null, null, windowHints);
        return window;
    }

    fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
        std.log.err("[RENDERER_ERROR] Code '{}': {s}", .{ error_code, description });
    }

    fn framebufferSizeCallback(window: glfw.Window, width: u32, height: u32) void {
        var renderer: *Renderer = windowRendererMap.get(&window).?;
        renderer.windowWidth = width;
        renderer.windowHeight = height;
        gl.viewport(0, 0, @intCast(c_int, width), @intCast(c_int, height));
    }

    fn glGetProcAddress(window: glfw.Window, proc: [:0]const u8) ?gl.FunctionPointer {
        _ = window;
        return glfw.getProcAddress(proc);
    }
};
