test "main args" {
    const gpa = std.testing.allocator;
    const args = try sdl.mainFn.getArgs(gpa);
    defer sdl.mainFn.freeArgs(gpa, args);
}

const std = @import("std");

const sdl = @import("sdl.zig");
