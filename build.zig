// reference: https://codeberg.org/7Games/zig-sdl3
pub fn build(b: *std.Build) void {
    // hyperparams
    const target = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = b.standardOptimizeOption(.{});

    // options
    const preferred_linkage = b.option(
        std.builtin.LinkMode,
        "preferred_linkage",
        "Prefer building statically or dynamically linked libraries (default: static)",
    ) orelse .static;
    const sdl_main = b.option(
        bool,
        "sdl_main",
        "Use SDL provided main, doesn't really work when true (default: false)",
    ) orelse false;

    // dependencies
    const dep_sdl = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = preferred_linkage,
    });

    // module c
    const write_file = b.addWriteFiles();
    const header = write_file.add(
        "sdl_header.c",
        b.fmt(
            \\#include <SDL3/SDL.h>
            \\
            \\{s}
            \\#include <SDL3/SDL_main.h>
        , .{
            if (sdl_main) "" else "#define SDL_MAIN_NOIMPL",
        }),
    );
    const translate_c = b.addTranslateC(.{
        .root_source_file = header,
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(dep_sdl.path("include"));
    const module_c = translate_c.createModule();

    // module sdl
    const module_sdl = b.addModule("sdl", .{
        .root_source_file = b.path("src/sdl.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = module_c },
        },
    });
    module_sdl.linkLibrary(dep_sdl.artifact("SDL3"));
}

const std = @import("std");
