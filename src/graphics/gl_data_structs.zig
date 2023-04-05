const std = @import("std");
const gl = @import("gl");

pub const VertexBuffer = struct {
    glId: u32 = 0,
    layout: VertexBufferLayout = VertexBufferLayout{},

    pub fn init(data: []u8, layout: VertexBufferLayout) VertexBuffer {
        var id: u32 = 0;
        gl.genBuffers(1, &id);
        gl.bindBuffer(gl.ARRAY_BUFFER, id);
        gl.bufferData(gl.ARRAY_BUFFER, data.len, @ptrCast(?*anyopaque, data.prt), gl.STATIC_DRAW);
        layout.bind();
        return VertexBuffer {
            .glId = id,
            .layout = layout,
        };
    }

    pub fn destroy(self: *@This()) void {
        if(glId > 0) {
            self.unbind();
            gl.deleteBuffers(1, &glId);
            self.glId = 0;
            self.layout.destroy();
        }
    }

    pub fn bind(self: @This()) void {
        if(self.glId > 0) gl.bindVertexArray(self.glId);
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
        const glType: u32 = switch (type) {
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
        return IndexBuffer {
            .glId = id,
            .count = data.len,
        };
    }
    
    pub fn destroy(self: @This()) void {
        if(self.glId > 0) {
            self.unbind();
            gl.deleteBuffers(1, &self.glId);
            self.glId = 0;
        }
    }

    pub fn bind(self: @This()) void {
        if(self.glId > 0) gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.glId);
    }

    pub fn unbind(_: @This()) void {
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
    }
}
