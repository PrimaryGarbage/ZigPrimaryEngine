pub const opengl = @import("opengl");
pub usingnamespace glEnum;
pub usingnamespace glBitField;
pub usingnamespace glParam;

pub const glEnum = enum(u32) {
    blend = opengl.BLEND,
    depthTest = opengl.DEPTH_TEST,
    srcAlpha = opengl.SRC_ALPHA,
    oneMinusSrcAlpha = opengl.ONE_MINUS_SRC_ALPHA,
    lequal = opengl.LEQUAL,
    triangles = opengl.TRIANGLES,
    float = opengl.FLOAT,
    int = opengl.INT,
    unsingedInt = opengl.UNSINGED_INT,
    unsignedByte = opengl.UNSINGED_BYTE,
    arrayBuffer = opengl.ARRAY_BUFFER,
    elementArrayBuffer = opengl.ELEMENT_ARRAY_BUFFER,
    staticDraw = opengl.STATIC_DRAW,
    dynamicDraw = opengl.DYNAMIC_DRAW,
    textureMinFilter = opengl.TEXTURE_MIN_FILTER,
    textureMagFilter = opengl.TEXTURE_MAG_FILTER,
    textureWrapS = opengl.TEXTURE_WRAP_S,
    textureWrapT = opengl.TEXTURE_WRAP_T,
    unpackAlignment = opengl.UNPACK_ALIGNMENT,
    rgba = opengl.RGBA,
    rgb = opengl.RGB,
    texture2d = opengl.TEXTURE_2D,
    texture0 = opengl.TEXTURE0,
    texture1 = opengl.TEXTURE1,
    texture2 = opengl.TEXTURE2,
    texture3 = opengl.TEXTURE3,
    texture4 = opengl.TEXTURE4,
    texture5 = opengl.TEXTURE5,
    texture6 = opengl.TEXTURE6,
    texture7 = opengl.TEXTURE7,
    texture8 = opengl.TEXTURE8,
    texture9 = opengl.TEXTURE9,

    pub fn toUint(self: @This()) u32 {
        return @enumToInt(self);
    }
};

pub const glBitField = enum(u32) {
    colorBufferBit = opengl.COLOR_BUFFER_BIT,

    pub fn toUint(self: @This()) u32 {
        return @enumToInt(self);
    }
};

pub const glParam = enum(i32) {
    linear = opengl.LINEAR,
    clampToEdge = opengl.CLAMP_TO_EDGE,
    clampToBorder = opengl.CLAMP_TO_BORDER,
    _,

    pub fn toInt(self: @This()) i32 {
        return @enumToInt(self);
    }
};

pub fn loadExtensions(loadCtx: anytype, getProcAddress: fn (@TypeOf(loadCtx), [:0]const u8) ?opengl.FunctionPointer) !void {
    try opengl.load(loadCtx, getProcAddress);
}

pub fn enable(glenum: glEnum) void {
    opengl.enable(glenum.toUint());
}

pub fn blendFunc(sfactor: glEnum, dfactor: glEnum) void {
    opengl.blendFunc(sfactor.toUint(), dfactor.toUint());
}

pub fn depthFunc(func: glEnum) void {
    opengl.depthFunc(func.toUint());
}

pub fn viewport(x: i32, y: i32, width: usize, height: usize) void {
    opengl.viewport(cint(x), cint(y), cint(width), cint(height));
}

pub fn clear(mask: glBitField) void {
    opengl.clear(mask.toUint());
}

pub fn clearColor(r: f32, g: f32, b: f32, a: f32) void {
    opengl.clearColor(r, g, b, a);
}

pub fn drawElements(mode: glEnum, count: usize, _type: glEnum) void {
    opengl.drawElements(mode.toUint(), cint(count), _type.toUint(), null);
}

pub fn genBuffers(n: usize, buffers: []u32) void {
    opengl.genBuffers(cint(n), @ptrCast([*c]c_uint, buffers.ptr));
}

pub fn deleteBuffers(n: usize, buffers: []const u32) void {
    opengl.deleteBuffers(cint(n), buffers.ptr);
}

pub fn bindBuffer(target: glEnum, buffer: u32) void {
    opengl.bindBuffer(target.toUint(), cuint(buffer));
}

pub fn bufferData(target: glEnum, data: []const u8, usage: glEnum) void {
    opengl.bufferData(target, @intCast(isize, data.len), @ptrCast(?*const anyopaque, data.ptr), usage);
}

pub fn bindVertexArray(array: u32) void {
    opengl.bindVertexArray(array);
}

pub fn enableVertexAttribArray(index: u32) void {
    opengl.enableVertexAttribArray(index);
}

pub fn vertexAttribPointer(index: u32, size: usize, _type: glEnum, normalized: bool, stride: usize, offset: usize) void {
    opengl.vertexAttribPointer(index, cint(size), _type.toUint(), @boolToInt(normalized), cint(stride), @intToPtr(?*const anyopaque, offset));
}

pub fn activeTexture(texture: glEnum) void {
    opengl.activeTexture(texture);
}

pub fn bindTexture(target: glEnum, texture: u32) void {
    opengl.bindTexture(target.toUint(), texture);
}

pub fn deleteTextures(n: usize, textures: []const u32) void {
    opengl.deleteTextures(n, textures.ptr);
}

pub fn genTextures(n: usize, textures: []const u32) void {
    opengl.genTextures(n, textures.ptr);
}

pub fn texParameteri(target: glEnum, pname: glEnum, param: glParam) void {
    opengl.texParameteri(target.toUint(), pname.toUint(), param.toInt());
}

pub fn pixelStorei(pname: glEnum, param: glParam) void {
    opengl.pixelStorei(pname.toUint(), param.toInt());
}

// helpers
fn cint(comptime T: type, x: T) c_int {
    return @intCast(c_int, x);
}

fn cuint(comptime T: type, x: T) c_uint {
    return @intCast(c_uint, x);
}
