const std = @import("std");
const primaryApp = @import("primary_app.zig");
const image = @import("graphics/image.zig");

pub fn main() !void {
    const settings = primaryApp.AppSettings{
        .windowWidth = 600,
        .windowHeight = 600,
        .windowTitle = "This is the window, my man",
    };
    var app = try primaryApp.App.init(settings);
    defer app.terminate();
    app.run();
}
