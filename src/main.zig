//! Zig version of <SDL3/SDL_main.h>. Instead of using macro to autoreplace
//! the main function (which zig doesn't allow), it provides 2 variant of main
//! function.
//!
//! Using main requires passing CMainFn.
//! Usage:
//! ```
//! pub const main = sdl.main.main(c_main);
//! pub fn c_main(argc: c_int, argv: [*c][*c]u8) callconv(.c) c_int { ... }
//! ```
//!
//! Using callbacks requires passing appInit, appIterate, appEvent, appQuit.
//! Usage:
//! ```
//! pub const main = sdl.main.callbacks(.{
//!     .init = appInit,
//!     .iterate = appIterate,
//!     .event = appEvent,
//!     .quit = appQuit,
//! });
//! pub fn appInit(appstate: *?*anyopaque, argc: c_int, argv: [*c][*c]u8) callconv(.c) sdl.c.SDL_AppResult { ... }
//! pub fn appIterate(appstate: ?*anyopaque) callconv(.c) sdl.c.SDL_AppResult { ... }
//! pub fn appEvent(appstate: ?*anyopaque, event: *sdl.c.SDL_Event) callconv(.c) sdl.c.SDL_AppResult { ... }
//! pub fn appQuit(appstate: ?*anyopaque, result: sdl.c.SDL_AppResult) callconv(.c) void { ... }
//! ```
//!

const ZigMainFn = fn () MainError!void;
const CMainFn = fn (i32, [*c][*c]u8) callconv(.c) i32;
const CallbackFn = struct {
    init: *const fn (*?*anyopaque, c_int, [*c][*c]u8) callconv(.c) c.SDL_AppResult,
    iterate: *const fn (?*anyopaque) callconv(.c) c.SDL_AppResult,
    event: *const fn (?*anyopaque, *c.SDL_Event) callconv(.c) c.SDL_AppResult,
    quit: *const fn (?*anyopaque, c.SDL_AppResult) callconv(.c) void,
};

/// SDL provided main function using c main.
pub fn main(comptime mainfunction: *const CMainFn) ZigMainFn {
    // other os are not explored
    switch (builtin.os.tag) {
        .linux, .windows, .macos => {},
        else => @compileError("not supported"),
    }
    // using lambda, function pointer doesn't have lifetime problem
    const Wrap = struct {
        pub fn run() MainError!void {
            const gpa = std.heap.smp_allocator;
            const args: Args = try getArgs(gpa);
            defer freeArgs(gpa, args);

            if (builtin.os.tag == .windows) {
                c.SDL_SetMainReady();
            }
            const result = mainfunction(args.argc, args.argv);

            if (result != 0) {
                std.log.err("{s}\n", .{c.SDL_GetError()});
                return error.RunApp;
            }
        }
    };
    return Wrap.run;
}

/// SDL provided main function using callbacks.
pub fn callbacks(comptime callbackfn: CallbackFn) ZigMainFn {
    // other os are not explored
    switch (builtin.os.tag) {
        .linux, .windows, .macos => {},
        else => @compileError("not supported"),
    }
    // using lambda, function pointer doesn't have lifetime problem
    const Wrap = struct {
        pub fn run() MainError!void {
            const gpa = std.heap.smp_allocator;
            const args: Args = try getArgs(gpa);
            defer freeArgs(gpa, args);
            _ = switch (builtin.os.tag) {
                .linux, .macos => {},
                .windows => {},
                else => @compileError("not supported"),
            };
            const result = callback.SDL_EnterAppMainCallbacks(
                args.argc,
                args.argv,
                @ptrCast(callbackfn.init), // appdata is never null
                callbackfn.iterate,
                @ptrCast(callbackfn.event), // event is never null
                callbackfn.quit,
            );
            if (result != 0) {
                std.log.err("{s}\n", .{c.SDL_GetError()});
                return error.AppMainCallbacks;
            }
        }
    };
    return Wrap.run;
}

pub const Args = struct {
    argc: u31,
    argv: [*c][*c]u8, // actual type: [*:null]?[*:0]u8
};

/// Args should successfully pass into windows/linux/macos without issue.
pub fn getArgs(gpa: Allocator) MainError!Args {
    var arg_iterator: std.process.ArgIterator = try .initWithAllocator(gpa);
    defer arg_iterator.deinit();
    var arg_list: std.ArrayList([*:0]u8) = .empty;
    defer arg_list.deinit(gpa);
    // elements are returned
    while (true) {
        const arg_opt = arg_iterator.next();
        if (arg_opt) |arg| {
            const arg_copy = try gpa.dupeZ(u8, arg);
            try arg_list.append(gpa, arg_copy);
        } else {
            break;
        }
    }
    // make sure arg_list has at least 1 element, in case some user code doesn't like that.
    if (arg_list.items.len == 0) {
        const arg_copy = try gpa.dupeZ(u8, "SDL_app");
        try arg_list.append(gpa, arg_copy);
    }
    const argc: u31 = @intCast(arg_list.items.len);
    // result should include sentinel array
    const result = try gpa.alloc(?[*:0]u8, argc + 1);
    @memcpy(result[0..argc], arg_list.items);
    result[argc] = null;
    return .{
        .argc = argc,
        .argv = @ptrCast(result),
    };
}

pub fn freeArgs(gpa: Allocator, args: Args) void {
    for (args.argv[0..args.argc]) |arg| {
        gpa.free(std.mem.span(arg));
    }
    const argv_extra = args.argv[0 .. args.argc + 1];
    gpa.free(argv_extra);
}

pub const MainError = Allocator.Error ||
    std.process.ArgIterator.InitError ||
    error{ RunApp, AppMainCallbacks };
pub const MainFunc = *const fn () MainError!void;

pub const callback = @import("main/callback.zig");

const builtin = @import("builtin");

const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl.zig");
const c = sdl.c;
