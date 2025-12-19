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

    // steps
    const copy_lib = CopyLib.create(b);

    // dependencies
    const step_install = b.getInstallStep();
    step_install.dependOn(&copy_lib.step);
}

// TODO only works in windows.
const CopyLib = struct {
    step: Step,

    pub fn create(owner: *std.Build) *CopyLib {
        const self = owner.allocator.create(CopyLib) catch @panic("OOM");
        self.* = .{
            .step = .init(.{
                .id = .custom,
                .name = owner.fmt("CopyLib", .{}),
                .owner = owner,
                .makeFn = make,
            }),
        };
        return self;
    }

    fn make(step: *Step, options: Step.MakeOptions) !void {
        _ = options;
        const b = step.owner;
        const root_dir = b.build_root.handle;
        const path_src: []const u8 = "sdl-out/lib/SDL3.lib";
        const path_dst: []const u8 = "lib/SDL3.lib";
        try root_dir.copyFile(path_src, root_dir, path_dst, .{});
    }
};

const std = @import("std");
const Step = std.Build.Step;
