pub fn build(b: *std.Build) void {
    // hyperparams
    const target = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = b.standardOptimizeOption(.{});

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/sdl_header.c"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(b.path("include"));
    const module_c = translate_c.createModule();

    const module_sdl = b.addModule("sdl", .{
        .root_source_file = b.path("src/sdl.zig"),
        .target = target,
        .optimize = optimize,
    });
    module_sdl.addImport("c", module_c);
    module_sdl.addLibraryPath(b.path("lib"));
    module_sdl.linkSystemLibrary("SDL3", .{});
}

const std = @import("std");
