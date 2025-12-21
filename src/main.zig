//! Zig version of <SDL3/SDL_main.h>. Instead of using macro to autoreplace
//! the main function (which zig doesn't allow), it provides 2 variant of main
//! function.
//!
//! Usage:
//! ```
//! pub const main = sdl.main.main;
//! pub export fn SDL_main(argc: c_int, argv: [*c][*c]u8) c_int { ... }
//! ```
//!

/// SDL provided main function using SDL_main.
pub fn main() MainError!void {
    const args: [:0][*:0]u8 = try getArgs();
    const result = c.SDL_RunApp(
        args.argc,
        args.argv,
        SDL_main,
        null,
    );
    if (result != 0) {
        std.log.err("{s}\n", .{c.SDL_GetError()});
        return error.RunApp;
    }
}

/// SDL provided main function using callbacks.
pub fn callbacks() MainError!void {
    const args: Args = try getArgs();
    const result = c.SDL_EnterAppMainCallbacks(
        args.argc,
        args.argv,
        SDL_AppInit,
        SDL_AppIterate,
        SDL_AppEvent,
        SDL_AppQuit,
    );
    if (result != 0) {
        std.log.err("{s}\n", .{c.SDL_GetError()});
        return error.AppMainCallbacks;
    }
}

pub const Args = struct {
    argc: i32,
    argv: [*c][*c]u8, // actual type: [*:null]?[*:0]u8
};

pub fn getArgs() MainError!Args {
    const gpa: Allocator = std.heap.smp_allocator;
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
    const argc: u31 = @intCast(arg_list.items.len);
    const result = try gpa.alloc(?[*:0]u8, argc + 1);
    @memcpy(result[0..argc], arg_list.items);
    result[argc] = null;
    // result.len = argc;
    return .{
        .argc = argc,
        .argv = @ptrCast(result),
    };
}

pub const MainError = Allocator.Error ||
    std.process.ArgIterator.InitError ||
    error{ RunApp, AppMainCallbacks };
pub const MainFunc = *const fn () MainError!void;

pub extern fn SDL_main(argc: c_int, argv: [*c][*c]u8) c_int;
pub extern fn SDL_AppInit([*c]?*anyopaque, c_int, [*c][*c]u8) callconv(.c) c.SDL_AppResult;
pub extern fn SDL_AppIterate(?*anyopaque) callconv(.c) c.SDL_AppResult;
pub extern fn SDL_AppEvent(?*anyopaque, [*c]c.SDL_Event) callconv(.c) c.SDL_AppResult;
pub extern fn SDL_AppQuit(?*anyopaque, c.SDL_AppResult) callconv(.c) void;

const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl.zig");
const c = sdl.c;
