const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const zlm = @import("zlm");
const stbi = @cImport(@cInclude("stb_image.h"));

pub const Color = struct {
    r: f16 = 0.0,
    g: f16 = 0.0,
    b: f16 = 0.0,
    a: f16 = 1.0,

    pub const white = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
    pub const black = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    pub const red = Color{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    pub const green = Color{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 };
    pub const blue = Color{ .r = 0.0, .g = 0.0, .b = 1.0, .a = 1.0 };
};

pub const Pixel = struct {
    point: zlm.Vec2 = zlm.Vec2.zero,
    color: Color = Color.black,
};

pub const Renderer = struct {
    const log = std.log.scoped(.Renderer);
    var windowRendererMap = std.AutoHashMap(*const glfw.Window, *Renderer).init(std.heap.page_allocator);
    var drawPixelArray = std.ArrayList(zlm.Vec2).init(std.heap.page_allocator);

    const Error = error{
        InitializationError,
        CreateWindowError,
        LoadExtensionsError,
    };

    window: glfw.Window = undefined,
    windowWidth: u32 = 0,
    windowHeight: u32 = 0,

    pub fn initialize(self: *@This(), width: u32, height: u32, title: [:0]const u8) !void {
        if (!glfw.init(.{})) {
            self.terminate();
            return Error.InitializationError;
        }

        self.windowWidth = width;
        self.windowHeight = height;

        self.window = createWindow(width, height, title) orelse return Error.CreateWindowError;
        try windowRendererMap.put(&self.window, self);

        glfw.makeContextCurrent(self.window);
        glfw.setErrorCallback(comptime errorCallback);
        self.window.setFramebufferSizeCallback(framebufferSizeCallback);
        glfw.swapInterval(1);

        gl.load(self.window, glGetProcAddress) catch return Error.LoadExtensionsError;

        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.enable(gl.DEPTH_TEST);
        gl.depthFunc(gl.LEQUAL);

        gl.viewport(0, 0, @intCast(c_int, width), @intCast(c_int, height));

        log.info("GLFW initialized successfully.\n", .{});
    }

    pub fn terminate(_: @This()) void {
        glfw.terminate();
        drawPixelArray.deinit();
        log.info("GLFW terminated successfully.\n", .{});
    }

    pub fn pollEvents(_: @This()) void {
        glfw.pollEvents();
    }

    pub fn clearScreen(_: @This()) void {
        gl.clear(gl.COLOR_BUFFER_BIT);
    }

    pub fn swapBuffers(self: @This()) void {
        self.window.swapBuffers();
    }

    pub fn windowShouldClose(self: @This()) bool {
        return self.window.shouldClose();
    }

    pub fn createWindow(width: u32, height: u32, title: [:0]const u8) ?glfw.Window {
        const windowHints = glfw.Window.Hints{
            .resizable = false,
            .opengl_profile = .opengl_core_profile,
            .context_version_major = 3,
            .context_version_minor = 3,
        };

        const window = glfw.Window.create(width, height, title, null, null, windowHints);
        return window;
    }

    pub fn setClearColor(_: @This(), color: Color) void {
        gl.clearColor(color.r, color.g, color.b, color.a);
    }

    pub fn putPixel(self: @This(), pixel: Pixel) void {
        // TODO: Implement this function using transparent window sized texture.
        _ = self;
        _ = pixel;
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

pub const VertexBuffer = struct {
    glId: u32 = 0,
    layout: VertexBufferLayout = VertexBufferLayout{},

    pub fn init(data: []u8, layout: VertexBufferLayout) VertexBuffer {
        var id: u32 = 0;
        gl.genBuffers(1, &id);
        gl.bindBuffer(gl.ARRAY_BUFFER, id);
        gl.bufferData(gl.ARRAY_BUFFER, data.len, @ptrCast(?*anyopaque, data.prt), gl.STATIC_DRAW);
        layout.bind();
        return VertexBuffer{
            .glId = id,
            .layout = layout,
        };
    }

    pub fn destroy(self: *@This()) void {
        if (self.glId > 0) {
            self.unbind();
            gl.deleteBuffers(1, &self.glId);
            self.glId = 0;
            self.layout.destroy();
        }
    }

    pub fn bind(self: @This()) void {
        if (self.glId > 0) gl.bindVertexArray(self.glId);
    }

    pub fn unbind(_: @This()) void {
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    }
};

pub const VertexBufferLayout = struct {
    elements: std.ArrayList(VertexBufferElement) = std.ArrayList(VertexBufferElement).init(std.heap.page_allocator),
    stride: u32 = 0,

    pub fn destroy(self: @This()) void {
        self.elements.deinit();
    }

    pub fn push(self: *@This(), comptime T: type, count: u32, normalized: bool) void {
        const glType: u32 = switch (T) {
            @TypeOf(i32) => gl.INT,
            @TypeOf(f32) => gl.FLOAT,
            @TypeOf(u8) => gl.UNSIGNED_BYTE,
            _ => @compileError("Failed to match value type in vertex buffer layout."),
        };

        self.elements.append(.{ glType, count, @boolToInt(normalized) });
        self.stride += VertexBufferElement.getSizeOfType(glType) * count;
    }

    pub fn bind(self: @This()) void {
        var offset: u32 = 0;
        for (0..self.elements.items.len) |i| {
            const element: VertexBufferElement = self.elements[i];
            gl.enableVertexAttribArray(i);
            gl.vertexAttribPointer(i, element.count, element.type, element.normalized, self.stride, @ptrCast(?*const anyopaque, &offset));
            offset += element.count * VertexBufferElement.getSizeOfType(element.type);
        }
    }
};

pub const VertexBufferElement = struct {
    type: u32,
    count: u32,
    normalized: u8,

    pub fn getSizeOfType(glType: u32) usize {
        return switch (glType) {
            gl.FLOAT => 4,
            gl.INT => 4,
            gl.UNSIGNED_BYTE => 1,
            _ => 0,
        };
    }
};

pub const IndexBuffer = struct {
    glId: u32 = 0,
    count: u32 = 0,

    pub fn init(data: []u32) IndexBuffer {
        var id: u32 = 0;
        gl.genBuffers(1, &id);
        gl.bindBuffers(gl.ELEMENT_ARRAY_BUFFER, id);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, data.len * @sizeOf(u32), @ptrCast(?*const anyopaque, data.ptr), gl.STATIC_DRAW);
        return IndexBuffer{
            .glId = id,
            .count = data.len,
        };
    }

    pub fn destroy(self: @This()) void {
        if (self.glId > 0) {
            self.unbind();
            gl.deleteBuffers(1, &self.glId);
            self.glId = 0;
        }
    }

    pub fn bind(self: @This()) void {
        if (self.glId > 0) gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.glId);
    }

    pub fn unbind(_: @This()) void {
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
    }
};

const Texture = struct {
    const Error = error{BindError};

    glId: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    channelCount: u32 = 0,

    pub fn initFromFile(filepath: []const u8) !Texture {
        const image = try Image.loadFromFile(filepath);
        defer image.destroy();
        return try initFromImage(image);
    }

    pub fn initFromImage(image: Image) !Texture {
        var texture = Texture{};
        try texture.loadIntoGpu(image.data, image.width, image.height, image.format);
        texture.width = image.width;
        texture.height = image.height;
        texture.channelCount = Image.getChannelCount(image.format);
        return texture;
    }

    pub fn initFromMemory(data: []u8, format: Image.Format) !Texture {
        const image = try Image.loadFromMemory(data, format);
        defer image.destroy();
        return try initFromImage(image);
    }

    pub fn destroy(self: *@This()) void {
        if (self.glId > 0) {
            self.unbind();
            gl.deleteTextures(1, &self.glId);
            self.glId = 0;
            self.width = 0;
            self.height = 0;
            self.channelCount = 0;
        }
    }

    pub fn bind(self: @This()) !void {
        if (self.glId == 0) return Error.BindError;
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, self.glId);
    }

    pub fn unbind(_: @This()) void {
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, 0);
    }

    fn loadIntoGpu(self: *@This(), data: []u8, width: u32, height: u32, format: Image.Format) !void {
        gl.genTextures(1, &self.glId);
        gl.bindTexture(gl.TEXTURE_2D, self.glId);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
        const glImageFormat: u32 = Image.getGLFormat(format);
        gl.texImage2D(gl.TEXTURE_2D, 0, glImageFormat, width, height, 0, glImageFormat, gl.UNSIGNED_BYTE, @ptrCast(?*const anyopaque, data.ptr));
        gl.bindTexture(gl.TEXTURE_2D, 0);
    }
};

pub const Image = struct {
    pub const Format = enum { none, png, jpeg, bmp };
    pub const Error = error{LoadingError};

    data: ?[*]u8,
    width: u32 = 0,
    height: u32 = 0,
    channelCount: u32 = 0,
    format: Format = Format.none,

    pub fn loadFromFile(filepath: [:0]const u8, format: Format) !Image {
        try std.fs.cwd().access(filepath, .{});

        var x: c_int = 0;
        var y: c_int = 0;
        var c: c_int = 0;
        const loadedData = stbi.stbi_load(filepath, &x, &y, &c, getChannelCount(format));
        if (loadedData == null) return Error.LoadingError;

        return Image{
            .data = loadedData,
            .width = @intCast(u32, x),
            .height = @intCast(u32, y),
            .channelCount = @intCast(u32, c),
            .format = format,
        };
    }

    pub fn loadFromMemory(data: []u8, format: Format) !?Image {
        var x: c_int = 0;
        var y: c_int = 0;
        var c: c_int = 0;
        const loadedData = stbi.stbi_load_from_memory(data.ptr, data.len, &x, &y, &c, getChannelCount(format));
        if (loadedData == null) return Error.LoadingError;

        return Image{
            .data = loadedData,
            .width = @intCast(u32, x),
            .height = @intCast(u32, y),
            .channelCount = @intCast(u32, c),
            .format = format,
        };
    }

    pub fn destroy(self: *@This()) void {
        stbi.free(self.data);
        self.width = 0;
        self.height = 0;
        self.channelCount = 0;
    }

    pub fn getChannelCount(imageFormat: Format) i32 {
        return switch (imageFormat) {
            .png => 4,
            .jpeg, .bmp => 3,
            .none => 0,
        };
    }

    fn getGLFormat(format: Image.ImageFormat) u32 {
        return switch (format) {
            .png => gl.RGBA,
            .jpeg, .bmp => gl.RGB,
            _ => 0,
        };
    }
};
