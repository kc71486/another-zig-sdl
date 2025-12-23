test "main args" {
    const gpa = std.testing.allocator;
    const args = try sdl.main.getArgs(gpa);
    defer sdl.main.freeArgs(gpa, args);
}

const std = @import("std");

const sdl = @import("sdl.zig");
