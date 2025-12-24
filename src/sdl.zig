// cannot use main otherwise zig will treat this as main function
pub const mainFn = @import("main.zig");

pub const atomic = @import("atomic.zig");
pub const Atomic = atomic.Atomic;

/// c.SDL_AppResult
pub const AppResult = enum(u32) {
    /// c.SDL_APP_CONTINUE
    run = c.SDL_APP_CONTINUE,
    /// c.SDL_APP_SUCCESS
    success = c.SDL_APP_SUCCESS,
    /// c.SDL_APP_FAILURE
    failure = c.SDL_APP_FAILURE,
};

/// Leftover definitions
pub const c = @import("c");

const std = @import("std");
