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

    // dependencies
    const dep_sdl = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = preferred_linkage,
    });

    // module c
    // contents of SDL_main.h is defined in sdl.main
    const write_file = b.addWriteFiles();
    const header = write_file.add(
        "sdl_header.c",
        b.fmt(
            \\#include <SDL3/SDL.h>
            \\
            \\#define SDL_MAIN_NOIMPL
            \\#include <SDL3/SDL_main.h>
        , .{}),
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

    // module test
    const module_test = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    module_test.addImport("sdl", module_sdl);

    // modules --> artifacts(compile)
    const lib_sdl = b.addLibrary(.{
        .linkage = .static,
        .name = "sdl",
        .root_module = module_sdl,
    });
    const test_test = b.addTest(.{
        .name = "test",
        .root_module = module_test,
    });

    // docs(step)
    const docs = b.addInstallDirectory(.{
        .source_dir = lib_sdl.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    // artifacts(compile) --> steps
    const install_test = b.addInstallArtifact(test_test, .{});
    const run_test = b.addRunArtifact(test_test);

    // steps and dependencies
    const step_install = b.getInstallStep();
    const step_test = b.step("test", "Do tests");
    const step_docs = b.step("docs", "Generate documentation");
    step_install.dependOn(&install_test.step);
    step_test.dependOn(step_install);
    step_test.dependOn(&run_test.step);
    step_docs.dependOn(step_test);
    step_docs.dependOn(&docs.step);
}

const std = @import("std");
