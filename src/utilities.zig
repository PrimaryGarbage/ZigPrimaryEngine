const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn gpalloc() Allocator {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    return gpa.allocator();
}
