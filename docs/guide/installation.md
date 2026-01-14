# Installation

This guide covers all the ways to install zigantic in your Zig project.

## Requirements

- **Zig 0.15.0** or later

## Release Installation (Recommended)

Install the latest stable release (v0.0.2):

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/v0.0.2.tar.gz
```

This downloads the package and adds it to your `build.zig.zon`.

## Nightly Installation

Install the latest development version from the main branch:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zigantic.git
```

> **Note:** Nightly builds may contain breaking changes or experimental features.

## Configure build.zig

After fetching, add zigantic to your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add zigantic dependency
    const zigantic_dep = b.dependency("zigantic", .{
        .target = target,
        .optimize = optimize,
    });

    // Create your executable
    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import zigantic module
    exe.root_module.addImport("zigantic", zigantic_dep.module("zigantic"));

    b.installArtifact(exe);
}
```

## Verify Installation

Create a test file `src/main.zig`:

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    const email = try z.Email.init("test@example.com");
    std.debug.print("Installed successfully! Email domain: {s}\n", .{email.domain()});
    std.debug.print("zigantic version: {s}\n", .{z.getVersion()});
}
```

Run it:

```bash
zig build run
```

You should see:

```
Installed successfully! Email domain: example.com
zigantic version: 0.0.2
```

## Using Prebuilt Libraries

If you prefer to use prebuilt static libraries instead of building from source:

1. Download the library for your platform from the [releases page](https://github.com/muhammad-fiaz/zigantic/releases)
2. Place it in your project (e.g., in a `libs/` folder)
3. Link it in your `build.zig`:

```zig
exe.addLibraryPath(b.path("libs"));
exe.linkSystemLibrary("zigantic");
```

### Available Platforms

| Platform | File |
|----------|------|
| Windows x86_64 | `zigantic-x86_64-windows.lib` |
| Windows x86 | `zigantic-x86-windows.lib` |
| Linux x86_64 | `libzigantic-x86_64-linux.a` |
| Linux x86 | `libzigantic-x86-linux.a` |
| Linux aarch64 | `libzigantic-aarch64-linux.a` |
| macOS x86_64 | `libzigantic-x86_64-macos.a` |
| macOS aarch64 | `libzigantic-aarch64-macos.a` |

## Disabling Auto-Update Check

By default, zigantic checks for updates in the background on first use. To disable this:

```zig
const z = @import("zigantic");

pub fn main() !void {
    // Disable update checking before using any other functions
    z.disableUpdateCheck();
    
    // Now use the library normally...
}
```

## Troubleshooting

### Package Not Found

If you get an error about the package not being found:

1. Make sure you ran `zig fetch --save` successfully
2. Check that `build.zig.zon` contains the zigantic dependency
3. Verify the hash in `build.zig.zon` matches the package

### Build Errors

If you encounter build errors:

1. Ensure you're using Zig 0.15.0 or later: `zig version`
2. Try deleting `.zig-cache` and rebuilding
3. Check the [issues page](https://github.com/muhammad-fiaz/zigantic/issues) for known problems

## Next Steps

- [Getting Started](/guide/getting-started) - Create your first validation
- [Quick Start](/guide/quick-start) - Jump into examples
