const std = @import("std");
const primaryApp = @import("primary_app.zig");

const windowWidth = 600;
const windowHeight = 600;
const windowTitle = "This is the window, my man";

pub fn main() !void {
    var app = try primaryApp.App.init(windowWidth, windowHeight, windowTitle);
    defer app.terminate();
    app.run();
}
