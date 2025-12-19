### sdl-zig

Based on SDL3.2.28

### Get started
Clone SDL source.
```
git clone https://github.com/libsdl-org/SDL.git vendored/SDL
```

Build SDL3 from source.
```
cmake -S . -B build
cmake --build build --config RelWithDebInfo
cmake --install build --config RelWithDebInfo --prefix ..\..\sdl-out
```

Run `zig build`.

Append `C:\SDL3\bin` to PATH.

### features

* Provides SDL3 libraries.
