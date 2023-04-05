const std = @import("std");
const stbi = @cImport(@cInclude("stb_image.h"));

pub const ImageFormat = enum { none, png, jpeg, bmp };

pub const ImageError = error{LoadingError};

pub const Image = struct {
    data: ?[*]u8,
    width: u32 = 0,
    height: u32 = 0,
    channelCount: u32 = 0,
    format: ImageFormat = ImageFormat.none,

    pub fn loadFromFile(filepath: [:0]const u8, format: ImageFormat) !Image {
        try std.fs.cwd().access(filepath, .{});

        var x: c_int = 0;
        var y: c_int = 0;
        var c: c_int = 0;
        const loadedData = stbi.stbi_load(filepath, &x, &y, &c, getComponentsPerPixel(format));
        if (loadedData == null) return ImageError.LoadingError;

        return Image{
            .data = loadedData,
            .width = @intCast(u32, x),
            .height = @intCast(u32, y),
            .channelCount = @intCast(u32, c),
            .format = format,
        };
    }

    pub fn loadFromMemory(data: []u8, format: ImageFormat) !?Image {
        var x: c_int = 0;
        var y: c_int = 0;
        var c: c_int = 0;
        const loadedData = stbi.stbi_load_from_memory(data.ptr, data.len, &x, &y, &c, getComponentsPerPixel(format));
        if (loadedData == null) return ImageError.LoadingError;

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

    fn getComponentsPerPixel(imageFormat: ImageFormat) i32 {
        return switch (imageFormat) {
            .png => 4,
            .jpeg, .bmp => 3,
            .none => 0,
        };
    }
};

// Tests:
test "Load image from valid file" {
    const testImagePath = "./res/img/SayGex.jpg";
    var image = try Image.loadFromFile(testImagePath, ImageFormat.jpeg);
    image.destroy();
}

test "Load image from invalid file" {
    const testImagePath = "./res/img/SayGexINVALID.jpg";
    var image = try Image.loadFromFile(testImagePath, ImageFormat.jpeg);
    image.destroy();
}
