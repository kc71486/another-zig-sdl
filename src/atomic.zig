/// Atomic with strongest operation.
pub fn Atomic(T: type) type {
    return struct {
        value: T,

        /// Set an atomic variable to a new value if it is currently an old value.
        /// Returns true if the atomic variable was set, false otherwise.
        pub fn compareAndSwap(self: *Self, oldval: T, newval: T) bool {
            return @cmpxchgStrong(T, &self.value, oldval, newval, .seq_cst, .seq_cst) == null;
        }

        /// Set an atomic variable to a value. Returns the previous value.
        pub fn set(self: *Self, value: T) T {
            // atomic swap instead of store
            return @atomicRmw(T, &self.value, .Xchg, value, .seq_cst);
        }

        /// Get the value of an atomic variable.
        pub fn get(self: *Self) T {
            return @atomicLoad(T, &self.value, .seq_cst);
        }

        /// Add to an atomic variable. Returns the previous value.
        pub fn add(self: *Self, value: T) T {
            return @atomicRmw(T, &self.value, .Add, value, .seq_cst);
        }

        const Self = @This();
    };
}

const std = @import("std");

const sdl = @import("sdl.zig");
const c = sdl.c;
