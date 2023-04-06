const std = @import("std");

pub fn gpalloc() std.heap.Allocator {
    return std.heap.GeneralPurposeAllocator(.{ .safety = true }).allocator();
}
