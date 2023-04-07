const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl.zig");
const zlm = @import("zlm");
const utils = @import("../utilities.zig");
const String = @import("zig-string").String;
const log = std.log.scoped(.Graphics);
const stbi = @cImport(@cInclude("stb_image.h"));

//// *STATIC ////
var defaultShader: Shader = undefined;
var defaultTexture: Texture = undefined;
var uniformLocationCache: std.StringHashMap(i32) = undefined;

pub fn staticInit() !void {
    defaultShader = try Shader.initFromFile("res/shaders/default.glsl");
    defaultTexture = try Texture.initFromFile("res/img/SayGex.jpg");
    uniformLocationCache = std.StringHashMap(i32).init(utils.gpalloc());
    log.info("Static data initialized.\n", .{});
}

pub fn staticDeinit() void {
    defaultShader.destroy();
    defaultTexture.destroy();
    uniformLocationCache.deinit();
    log.info("Static data deinitialized.\n", .{});
}

pub fn getDefaultShader() *Shader {
    return &defaultShader;
}

//// STATIC* ////

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
    var windowRendererMap = std.AutoHashMap(*const glfw.Window, *Renderer).init(std.heap.page_allocator);
    var drawPixelArray = std.ArrayList(zlm.Vec2).init(std.heap.page_allocator);

    const Error = error{
        InitializationError,
        CreateWindowError,
        LoadExtensionsError,
    };
    //........................................................................

    window: glfw.Window = undefined,
    windowWidth: u32 = 0,
    windowHeight: u32 = 0,
    projectMat: zlm.Mat4 = zlm.Mat4.identity,
    viewMat: zlm.Mat4 = zlm.Mat4.identity,
    modelMat: zlm.Mat4 = zlm.Mat4.identity,

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

        gl.loadExtensions(self.window, glGetProcAddress) catch return Error.LoadExtensionsError;

        gl.enable(gl.blend);
        gl.blendFunc(gl.srcAlpha, gl.oneMinusSrcAlpha);
        gl.enable(gl.depthTest);
        gl.depthFunc(gl.lequal);

        gl.viewport(0, 0, width, height);

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
        gl.clear(gl.colorBufferBit);
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

    pub fn drawMesh(self: @This(), mesh: Mesh, shader: ?Shader) !void {
        try mesh.vb.bind();
        const mvp: zlm.Mat4 = self.projectMat.mul(self.viewMat).mul(self.modelMat);
        for (mesh.submeshes.items) |submesh| {
            try submesh.bind();
            if (shader) |sh| try sh.bind();
            try submesh.shader.setUniformMat4f("u_mvp", mvp);
            gl.drawElements(gl.triangles, submesh.ib.count, gl.unsingedInt);
        }
    }

    fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
        std.log.err("[RENDERER_ERROR] Code '{}': {s}", .{ error_code, description });
    }

    fn framebufferSizeCallback(window: glfw.Window, width: u32, height: u32) void {
        var renderer: *Renderer = windowRendererMap.get(&window).?;
        renderer.windowWidth = width;
        renderer.windowHeight = height;
        gl.viewport(0, 0, width, height);
    }

    fn glGetProcAddress(window: glfw.Window, proc: [:0]const u8) ?gl.FunctionPointer {
        _ = window;
        return glfw.getProcAddress(proc);
    }
};

pub const VertexBuffer = struct {
    const Error = error{BindError};
    //..................................

    glId: u32 = 0,
    layout: VertexBufferLayout = undefined,

    pub fn init(data: []const u8, layout: VertexBufferLayout) VertexBuffer {
        var id: u32 = 0;
        gl.genBuffers(1, .{&id});
        gl.bindBuffer(gl.arrayBuffer, id);
        gl.bufferData(gl.arrayBuffer, data, gl.staticDraw);
        layout.bind();
        return VertexBuffer{
            .glId = id,
            .layout = layout,
        };
    }

    pub fn destroy(self: *@This()) void {
        if (self.glId > 0) {
            self.unbind();
            gl.deleteBuffers(1, .{&self.glId});
            self.glId = 0;
            self.layout.destroy();
        }
    }

    pub fn bind(self: @This()) !void {
        if (self.glId == 0) return Error.BindError;
        gl.bindVertexArray(self.glId);
    }

    pub fn unbind(_: @This()) void {
        gl.bindBuffer(gl.arrayBuffer, 0);
    }
};

pub const VertexBufferLayout = struct {
    elements: std.ArrayList(VertexBufferElement),
    stride: usize = 0,

    pub fn init() VertexBufferLayout {
        return VertexBufferLayout{
            .elements = std.ArrayList(VertexBufferElement).init(utils.gpalloc()),
        };
    }

    pub fn destroy(self: @This()) void {
        self.elements.deinit();
    }

    pub fn push(self: *@This(), comptime T: type, count: u32, normalized: bool) void {
        const glType: u32 = switch (T) {
            i32 => gl.INT,
            f32 => gl.FLOAT,
            u8 => gl.UNSIGNED_BYTE,
            else => @compileError("Failed to match value type in vertex buffer layout."),
        };

        self.elements.append(.{ .type = glType, .count = count, .normalized = normalized }) catch unreachable;
        self.stride += VertexBufferElement.getSizeOfType(glType) * count;
    }

    pub fn bind(self: @This()) void {
        var offset: usize = 0;
        for (self.elements.items, 0..) |element, i| {
            const idx = @intCast(c_uint, i);
            gl.enableVertexAttribArray(idx);
            gl.vertexAttribPointer(idx, element.count, element._type, element.normalized, self.stride, offset);
            offset += element.count * VertexBufferElement.getSizeOfType(element.type);
        }
    }
};

pub const VertexBufferElement = struct {
    _type: gl.glEnum,
    count: usize,
    normalized: bool,

    pub fn getSizeOfType(glType: gl.glEnum) usize {
        return switch (glType) {
            gl.float => 4,
            gl.int => 4,
            gl.unsignedByte => 1,
            else => 0,
        };
    }
};

pub const IndexBuffer = struct {
    const Error = error{BindError};
    //..................................

    glId: u32 = 0,
    count: u32 = 0,

    pub fn init(data: []const u32) IndexBuffer {
        var id: u32 = 0;
        gl.genBuffers(1, &id);
        gl.bindBuffer(gl.elementArrayBuffer, id);
        gl.bufferData(gl.elementArrayBuffer, data, gl.staticDraw);
        return IndexBuffer{
            .glId = id,
            .count = data.len,
        };
    }

    pub fn destroy(self: @This()) void {
        if (self.glId > 0) {
            self.unbind();
            gl.deleteBuffers(1, .{self.glId});
            self.glId = 0;
        }
    }

    pub fn bind(self: @This()) !void {
        if (self.glId == 0) return Error.BindError;
        gl.bindBuffer(gl.elementArrayBuffer, self.glId);
    }

    pub fn unbind(_: @This()) void {
        gl.bindBuffer(gl.elementArrayBuffer, 0);
    }
};

pub const Texture = struct {
    const Error = error{BindError};
    //.......................................................

    glId: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    channelCount: u32 = 0,

    pub fn initFromFile(filepath: [:0]const u8) !Texture {
        var image = try Image.loadFromFile(filepath);
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
            gl.deleteTextures(1, .{self.glId});
            self.glId = 0;
            self.width = 0;
            self.height = 0;
            self.channelCount = 0;
        }
    }

    pub fn bind(self: @This()) !void {
        if (self.glId == 0) return Error.BindError;
        gl.activeTexture(gl.texture0);
        gl.bindTexture(gl.texture2d, self.glId);
    }

    pub fn unbind(_: @This()) void {
        gl.activeTexture(gl.texture0);
        gl.bindTexture(gl.texture2d, 0);
    }

    fn loadIntoGpu(self: *@This(), data: []u8, width: u32, height: u32, format: Image.Format) !void {
        gl.genTextures(1, .{self.glId});
        gl.bindTexture(gl.texture2d, self.glId);
        gl.texParameteri(gl.texture2d, gl.textureMinFilter, gl.linear);
        gl.texParameteri(gl.texture2d, gl.textureMagFilter, gl.linear);
        gl.texParameteri(gl.texture2d, gl.textureWrapS, gl.clampToEdge);
        gl.texParameteri(gl.texture2d, gl.textureWrapT, gl.clampToEdge);
        gl.pixelStorei(gl.unpackAlignment, 1);
        const glImageFormat = Image.getGLFormat(format);
        gl.texImage2D(gl.TEXTURE_2D, 0, glImageFormat, @intCast(c_int, width), @intCast(c_int, height), 0, @intCast(c_uint, glImageFormat), gl.UNSIGNED_BYTE, @ptrCast(?*const anyopaque, data.ptr));
        gl.bindTexture(gl.TEXTURE_2D, 0);
    }
};

pub const Image = struct {
    pub const Format = enum {
        none,
        png,
        jpeg,
        jpg,
        bmp,

        const nameTable = [_][]const u8{
            "none", "png", "jpeg", "jpg", "bmp",
        };

        pub fn fromStr(str: []const u8) Format {
            for (nameTable, 0..) |name, i| {
                if (std.mem.eql(u8, str, name)) return @intToEnum(Format, i);
            }
            return Format.none;
        }
    };
    pub const Error = error{ LoadingError, FormatError };
    //...............................................................

    data: []u8,
    width: u32 = 0,
    height: u32 = 0,
    channelCount: u32 = 0,
    format: Format = Format.none,

    pub fn loadFromFile(filepath: [:0]const u8) !Image {
        try std.fs.cwd().access(filepath, .{});
        const format = extractFileFormat(filepath);
        if (format == Format.none) return Error.FormatError;

        var x: c_int = 0;
        var y: c_int = 0;
        var c: c_int = 0;
        const loadedData: [*c]u8 = stbi.stbi_load(filepath.ptr, &x, &y, &c, @intCast(c_int, getChannelCount(format)));
        const len = @intCast(usize, x * y);
        if (loadedData == null) return Error.LoadingError;

        return Image{
            .data = loadedData[0..len],
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
        const loadedData = stbi.stbi_load_from_memory(data.ptr, data.len, &x, &y, &c, @intCast(c_int, getChannelCount(format)));
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
        stbi.free(self.data.ptr);
        self.width = 0;
        self.height = 0;
        self.channelCount = 0;
    }

    pub fn getChannelCount(imageFormat: Format) u32 {
        return switch (imageFormat) {
            .png => 4,
            .jpeg, .bmp, .jpg => 3,
            .none => 0,
        };
    }

    fn getGLFormat(format: Format) c_int {
        return switch (format) {
            .png => gl.rgba,
            .jpeg, .bmp, .jpg => gl.rgb,
            .none => 0,
        };
    }

    fn extractFileFormat(filepath: []const u8) Format {
        const ext = std.mem.trimLeft(u8, std.fs.path.extension(filepath), ".");
        return Format.fromStr(ext);
    }
};

pub const Shader = struct {
    const ShaderProgramSource = struct {
        vertexSource: []const u8,
        fragmentSource: []const u8,
    };
    const Error = error{ parsingError, compileError, bindError };
    var currentBountShader: u32 = 0;
    //............................................................

    glId: u32 = 0,

    pub fn initFromFile(filepath: []const u8) !Shader {
        const alloc = utils.gpalloc();
        const file = try std.fs.cwd().openFile(filepath, .{});
        defer file.close();
        const fileContent = try file.reader().readAllAlloc(alloc, 9999999);
        defer alloc.free(fileContent);
        return try initFromText(fileContent);
    }

    pub fn initFromText(text: []const u8) !Shader {
        const source = try parseShader(text);
        return Shader{
            .glId = try createShaderProgram(source.vertexSource, source.fragmentSource),
        };
    }

    pub fn destroy(self: *@This()) void {
        if (self.glId > 0) {
            unbind();
            gl.deleteProgram(self.glId);
            self.glId = 0;
            self.uniformLocationCache.deinit();
        }
    }

    pub fn bind(self: @This()) !void {
        if (self.glId == 0) return Error.bindError;
        if (currentBountShader != self.glId) {
            gl.useProgram(self.glId);
            currentBountShader = self.glId;
        }
    }

    pub fn unbind(_: @This()) void {
        gl.useProgram(0);
        currentBountShader = 0;
    }

    pub fn setUniformMat4f(self: @This(), name: []const u8, matrix: zlm.Mat4) !void {
        try self.bind();
        gl.uniformMatrix4fv(self.getUniformLocation(name), 1, gl.FALSE, &matrix.fields[0][0]);
    }

    pub fn setUniform4f(self: @This(), name: []const u8, vec: zlm.Vec4) !void {
        try self.bind();
        gl.uniform4f(self.getUniformLocation(name), vec.x, vec.y, vec.z, vec.w);
    }

    pub fn setUniform2f(self: @This(), name: []const u8, vec: zlm.Vec2) !void {
        try self.bind();
        gl.uniform2f(self.getUniformLocation(name), vec.x, vec.y);
    }

    pub fn setUniform1f(self: @This(), name: []const u8, value: f32) !void {
        try self.bind();
        gl.uniform1f(self.getUniformLocation(name), value);
    }

    pub fn setUniform1i(self: @This(), name: []const u8, value: i32) !void {
        try self.bind();
        gl.uniform1i(self.getUniformLocation(name), value);
    }

    fn getUniformLocation(self: @This(), name: []const u8) i32 {
        const foundLocation: ?i32 = uniformLocationCache.get(name);
        if (foundLocation) |loc| {
            return loc;
        } else {
            const location: i32 = gl.getUniformLocation(self.glId, name.ptr);
            if (location == -1) {
                log.warn("Uniform {s} wasn't found in the shader program!", name);
            }
            uniformLocationCache.put(name, location) catch unreachable;
            return location;
        }
    }

    fn parseShader(text: []const u8) !ShaderProgramSource {
        const alloc = utils.gpalloc();
        const ShaderType = enum(i32) { none = -1, vertex = 0, fragment = 1 };
        var ss = [2]String{ String.init(alloc), String.init(alloc) };
        defer for (&ss) |*s| s.deinit();

        var shaderType = ShaderType.none;
        var currentLine = String.init(std.heap.page_allocator);
        defer currentLine.deinit();
        var lines = std.mem.split(u8, text, "\n");

        while (lines.next()) |line| {
            currentLine.clear();
            try currentLine.concat(line);
            currentLine.trim(&.{ ' ', '\r' });

            if (currentLine.isEmpty()) continue;

            if (currentLine.find("#shader") != null) {
                if (currentLine.find("vertex") != null) {
                    shaderType = ShaderType.vertex;
                } else if (currentLine.find("fragment") != null) {
                    shaderType = ShaderType.fragment;
                }
            } else {
                try currentLine.concat("\n");
                try ss[@intCast(usize, @enumToInt(shaderType))].concat(currentLine.str());
            }
        }

        return .{ .vertexSource = ss[0].str(), .fragmentSource = ss[1].str() };
    }

    fn compileShader(shaderType: u32, src: []const u8) !u32 {
        const alloc = utils.gpalloc();
        const id: u32 = gl.createShader(shaderType);
        gl.shaderSource(id, 1, &[_][*]const u8{src.ptr}, null);
        gl.compileShader(id);

        var result: i32 = 0;
        gl.getShaderiv(id, gl.COMPILE_STATUS, &result);
        if (result == gl.FALSE) {
            var length: i32 = 0;
            gl.getShaderiv(id, gl.INFO_LOG_LENGTH, &length);
            var message = try alloc.alloc(u8, @intCast(u32, length));
            defer alloc.free(message);
            gl.getShaderInfoLog(id, length, &length, message.ptr);
            log.err("Failed to compile shader. Shader type: {}", shaderType);
            log.err("{s}", message);
            gl.deleteShader(id);
            return Error.compileError;
        }

        return id;
    }

    fn createShaderProgram(vertexSrc: []const u8, fragmentSrc: []const u8) !u32 {
        const program: u32 = gl.createProgram();
        const vs: u32 = try compileShader(gl.VERTEX_SHADER, vertexSrc);
        const fs: u32 = try compileShader(gl.FRAGMENT_SHADER, fragmentSrc);

        gl.attachShader(program, vs);
        gl.attachShader(program, fs);
        gl.linkProgram(program);
        gl.validateProgram(program);

        gl.deleteShader(vs);
        gl.deleteShader(fs);

        return program;
    }
};

pub const SubMesh = struct {
    ib: IndexBuffer,
    shader: *const Shader,
    texture: *const Texture,

    pub fn init(indices: []const u32, shader: *const Shader, texture: *const Texture) SubMesh {
        return SubMesh{
            .ib = IndexBuffer.init(indices),
            .shader = shader,
            .texture = texture,
        };
    }

    pub fn destroy(self: *@This()) void {
        self.ib.destroy();
    }

    pub fn bind(self: @This()) !void {
        try self.ib.bind();
        try self.shader.bind();
        try self.texture.bind();
    }

    pub fn unbind(self: @This()) !void {
        try self.ib.unbind();
        try self.shader.unbind();
        try self.texture.unbind();
    }
};

pub const Mesh = struct {
    vb: VertexBuffer,
    submeshes: std.ArrayList(SubMesh),

    pub fn init(vb: VertexBuffer, submeshes: ?[]SubMesh) Mesh {
        const alloc = utils.gpalloc();
        var mesh = Mesh{
            .vb = vb,
            .submeshes = std.ArrayList(SubMesh).init(alloc),
        };
        if (submeshes) |subs| {
            mesh.submeshes.appendSlice(subs) catch unreachable;
        }
        return mesh;
    }

    pub fn destroy(self: *@This()) void {
        self.vb.destroy();
        for (self.submeshes.items) |sub| {
            sub.destroy();
        }
    }
};

pub const Primitives = struct {
    pub fn createRectangleMesh(width: f32, height: f32) Mesh {
        const vertices = [_]f32{
            0.0,   0.0,    0.0, 0.0,
            width, 0.0,    1.0, 0.0,
            width, height, 1.0, 1.0,
            0.0,   height, 0.0, 1.0,
        };
        const indices = [_]u32{
            0, 1, 2,
            0, 2, 3,
        };

        var layout = VertexBufferLayout.init();
        layout.push(f32, 2, false);
        layout.push(f32, 2, false);

        const vb = VertexBuffer.init(std.mem.sliceAsBytes(vertices[0..]), layout);
        const subMesh = SubMesh.init(indices[0..], &defaultShader, &defaultTexture);

        return Mesh.init(vb, &[_]SubMesh{subMesh});
    }
};
