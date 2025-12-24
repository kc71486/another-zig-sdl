// cannot use main otherwise zig will treat this as main function
pub const mainFn = @import("main.zig");

pub const atomic = @import("atomic.zig");
pub const Atomic = atomic.Atomic;

/// Leftover definitions
pub const c = @import("c");

const std = @import("std");
