// come from src/main/SDL_main_callbacks.c and src/main/generic/SDL_sysmain_callbacks.c

var SDL_main_event_callback: c.SDL_AppEvent_func = null;
var SDL_main_iteration_callback: c.SDL_AppIterate_func = null;
var SDL_main_quit_callback: c.SDL_AppQuit_func = null;
// use an atomic, since events might land from any thread and we don't want to wrap this all in a mutex. A CAS makes sure we only move from zero once.
var apprc: Atomic(i32) = .{ .value = 0 };
var SDL_main_appstate: ?*anyopaque = null;

var callback_rate_increment: u32 = 0;
var iterate_after_waitevent: bool = false;

// Return true if this event needs to be processed before returning from the event watcher
fn ShouldDispatchImmediately(event: *c.SDL_Event) bool {
    switch (event.type) {
        c.SDL_EVENT_TERMINATING,
        c.SDL_EVENT_LOW_MEMORY,
        c.SDL_EVENT_WILL_ENTER_BACKGROUND,
        c.SDL_EVENT_DID_ENTER_BACKGROUND,
        c.SDL_EVENT_WILL_ENTER_FOREGROUND,
        c.SDL_EVENT_DID_ENTER_FOREGROUND,
        => return true,
        else => return false,
    }
}

fn SDL_DispatchMainCallbackEvent(event: *c.SDL_Event) void {
    if (apprc.get() == c.SDL_APP_CONTINUE) { // if already quitting, don't send the event to the app.
        _ = apprc.compareAndSwap(c.SDL_APP_CONTINUE, @intCast(SDL_main_event_callback.?(SDL_main_appstate, event)));
    }
}

fn SDL_DispatchMainCallbackEvents() void {
    var events: [16]c.SDL_Event = undefined;

    while (true) {
        const count: i32 = c.SDL_PeepEvents(&events, events.len, c.SDL_GETEVENT, c.SDL_EVENT_FIRST, c.SDL_EVENT_LAST);
        if (count <= 0) {
            break;
        }
        for (0..@intCast(count)) |i| {
            const event: *c.SDL_Event = &events[i];
            if (!ShouldDispatchImmediately(event)) {
                SDL_DispatchMainCallbackEvent(event);
            }
        }
    }
}

// still need callconv(.c) because it is callback
fn SDL_MainCallbackEventWatcher(userdata: ?*anyopaque, event: ?*c.SDL_Event) callconv(.c) bool {
    _ = userdata;
    if (ShouldDispatchImmediately(event.?)) {
        // Make sure any currently queued events are processed then dispatch this before continuing
        SDL_DispatchMainCallbackEvents();
        SDL_DispatchMainCallbackEvent(event.?);

        // Make sure that we quit if we get a terminating event
        if (event.?.*.type == c.SDL_EVENT_TERMINATING) {
            _ = apprc.compareAndSwap(c.SDL_APP_CONTINUE, c.SDL_APP_SUCCESS);
        }
    } else {
        // We'll process this event later from the main event queue
    }
    return true;
}

pub fn SDL_HasMainCallbacks() callconv(.c) bool {
    return SDL_main_iteration_callback != null;
}

pub fn SDL_InitMainCallbacks(
    argc: i32,
    argv: [*c][*c]u8,
    appinit: c.SDL_AppInit_func,
    appiter: c.SDL_AppIterate_func,
    appevent: c.SDL_AppEvent_func,
    appquit: c.SDL_AppQuit_func,
) callconv(.c) c.SDL_AppResult {
    SDL_main_iteration_callback = appiter;
    SDL_main_event_callback = appevent;
    SDL_main_quit_callback = appquit;
    _ = apprc.set(c.SDL_APP_CONTINUE);

    const rc: c.SDL_AppResult = appinit.?(&SDL_main_appstate, argc, argv);
    // bounce if SDL_AppInit already said abort, otherwise...
    if (apprc.compareAndSwap(c.SDL_APP_CONTINUE, @intCast(rc)) and (rc == c.SDL_APP_CONTINUE)) {
        // make sure we definitely have events initialized, even if the app didn't do it.
        if (!c.SDL_InitSubSystem(c.SDL_INIT_EVENTS)) {
            _ = apprc.set(c.SDL_APP_FAILURE);
            return c.SDL_APP_FAILURE;
        }

        if (!c.SDL_AddEventWatch(SDL_MainCallbackEventWatcher, null)) {
            _ = apprc.set(c.SDL_APP_FAILURE);
            return c.SDL_APP_FAILURE;
        }
    }

    return @intCast(apprc.get());
}

pub fn SDL_IterateMainCallbacks(pump_events: bool) callconv(.c) c.SDL_AppResult {
    if (pump_events) {
        c.SDL_PumpEvents();
    }
    SDL_DispatchMainCallbackEvents();

    var rc: c.SDL_AppResult = @intCast(apprc.get());
    if (rc == c.SDL_APP_CONTINUE) {
        rc = SDL_main_iteration_callback.?(SDL_main_appstate);
        if (!apprc.compareAndSwap(c.SDL_APP_CONTINUE, @intCast(rc))) {
            rc = @intCast(apprc.get()); // something else already set a quit result, keep that.
        }
    }
    return rc;
}

pub fn SDL_QuitMainCallbacks(result: c.SDL_AppResult) callconv(.c) void {
    c.SDL_RemoveEventWatch(SDL_MainCallbackEventWatcher, null);
    SDL_main_quit_callback.?(SDL_main_appstate, result);
    SDL_main_appstate = null; // just in case.

    c.SDL_Quit();
}

// ===============SDL_sysmain_callback.c================== //

// TODO #include "../../video/SDL_sysvideo.h"

fn MainCallbackRateHintChanged(userdata: ?*anyopaque, name: [*c]const u8, oldValue: [*c]const u8, newValue: [*c]const u8) callconv(.c) void {
    _ = userdata;
    _ = name;
    _ = oldValue;
    iterate_after_waitevent = (newValue != null) and (c.SDL_strcmp(newValue.?, "waitevent") == 0);
    if (iterate_after_waitevent) {
        callback_rate_increment = 0;
    } else {
        const callback_rate: i32 = if (newValue != null) c.SDL_atoi(newValue.?) else 0;
        if (callback_rate > 0) {
            callback_rate_increment = @intCast(1000000000 / (@as(u64, @intCast(callback_rate))));
        } else {
            callback_rate_increment = 0;
        }
    }
}

fn GenericIterateMainCallbacks() callconv(.c) c.SDL_AppResult {
    if (iterate_after_waitevent) {
        _ = c.SDL_WaitEvent(null);
    }
    return SDL_IterateMainCallbacks(!iterate_after_waitevent);
}

pub fn SDL_EnterAppMainCallbacks(
    argc: i32,
    argv: [*c][*c]u8,
    appinit: c.SDL_AppInit_func,
    appiter: c.SDL_AppIterate_func,
    appevent: c.SDL_AppEvent_func,
    appquit: c.SDL_AppQuit_func,
) callconv(.c) i32 {
    var rc: c.SDL_AppResult = SDL_InitMainCallbacks(argc, argv, appinit, appiter, appevent, appquit);
    if (rc == 0) {
        _ = c.SDL_AddHintCallback(c.SDL_HINT_MAIN_CALLBACK_RATE, MainCallbackRateHintChanged, null);

        var next_iteration: u64 = if (callback_rate_increment != 0) (c.SDL_GetTicksNS() + callback_rate_increment) else 0;

        while (true) {
            rc = GenericIterateMainCallbacks();
            if (rc != c.SDL_APP_CONTINUE) {
                break;
            }
            // Try to run at whatever rate the hint requested.
            if (callback_rate_increment == 0) {
                next_iteration = 0; // just clear the timer and run at the pace the video subsystem allows.
            } else {
                const now: u64 = c.SDL_GetTicksNS();
                if (next_iteration > now) { // Running faster than the limit, sleep a little.
                    c.SDL_DelayPrecise(next_iteration - now);
                } else {
                    next_iteration = now; // if running behind, reset the timer. If right on time, `next_iteration` already equals `now`.
                }
                next_iteration += callback_rate_increment;
            }
        }

        c.SDL_RemoveHintCallback(c.SDL_HINT_MAIN_CALLBACK_RATE, MainCallbackRateHintChanged, null);
    }
    SDL_QuitMainCallbacks(rc);

    return if (rc == c.SDL_APP_FAILURE) 1 else 0;
}

const std = @import("std");

const sdl = @import("../sdl.zig");
const mainFn = sdl.mainFn;
const Atomic = sdl.Atomic;
const c = sdl.c;
