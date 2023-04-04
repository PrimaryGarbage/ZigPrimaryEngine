const std = @import("std");
const rend = @import("graphics/renderer.zig");

const windowWidth = 600;
const windowHeight = 600;

pub fn main() !void {
    var renderer = rend.Renderer{};
    try renderer.initialize(windowWidth, windowHeight, "This is my window, bitches!");
    defer renderer.terminate();
    while (!renderer.windowShouldClose()) {
        renderer.pollEvents();
    }
}
