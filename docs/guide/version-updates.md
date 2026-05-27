# Version & Updates

zigantic includes automatic version checking and error reporting features to help you stay up-to-date and report issues easily.

## Automatic Update Checking

zigantic **automatically** checks for updates in the background when you first use JSON functions (`fromJson`, `toJson`, `toJsonPretty`). No initialization is needed!

When a new version is available, you'll see a log message:

```
info: [UPDATE] A newer release of zigantic is available: v0.0.4 (current 0.0.3)
```

### Basic Usage (Updates Enabled by Default)

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();

    // Just use the library - update check happens automatically!
    const name = try z.String(1, 50).init("Alice");
    std.debug.print("Hello, {s}!\n", .{name.get()});

    // Update check triggers on first JSON use
    const User = struct { name: z.String(1, 50) };
    var result = try z.fromJson(User, "{\"name\": \"Bob\"}", gpa.allocator());
    defer result.deinit();
}
```

## Disabling Automatic Updates

To disable automatic update checking, call `disableUpdateCheck()` **before** using any library functions:

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // Disable update checking (must be called before any other z.* functions)
    z.disableUpdateCheck();

    // Now use the library normally - no update checks will occur
    const name = try z.String(1, 50).init("Alice");
    std.debug.print("Hello, {s}!\n", .{name.get()});
}
```

### Custom Configuration

For more control, use `setConfig()`:

```zig
const z = @import("zigantic");

pub fn main() !void {
    // Customize configuration
    z.setConfig(.{
        .auto_update_check = false,      // Disable update checking
        .show_update_notifications = false, // Disable notifications
    });

    // Use library...
}
```

### Configuration Options

| Option                      | Type   | Default | Description                           |
| --------------------------- | ------ | ------- | ------------------------------------- |
| `auto_update_check`         | `bool` | `true`  | Enable/disable automatic update check |
| `show_update_notifications` | `bool` | `true`  | Show update notifications in log      |

## Library Version

Get the current version of zigantic:

```zig
const z = @import("zigantic");

const ver = z.getVersion();       // "0.0.3"
const full = z.getVersionString(); // "v0.0.3"
```

## Manual Update Checking

You can also check for updates manually:

### Background Check (Non-blocking)

```zig
const z = @import("zigantic");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();

    // Start background update check
    if (z.checkForUpdates(gpa.allocator())) |thread| {
        // Optional: wait for check to complete on shutdown
        defer thread.join();
    }
}
```

### Synchronous Check

```zig
const z = @import("zigantic");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();

    // Check for updates synchronously
    var info = try z.checkForUpdatesSync(gpa.allocator());
    defer info.deinit();

    if (info.update_available) {
        std.debug.print("Update available: {s} (current: {s})\n", .{
            info.latest_version,
            info.current_version,
        });
    }
}
```

## Internal Error Reporting

::: warning
The error reporting functions are for **library bugs only** - unexpected internal errors that might indicate a bug in zigantic itself.

**Do NOT use these for validation errors!** Validation errors (like "value is too short") are expected behavior when users provide invalid data.
:::

### When to Use Error Reporting

Use `reportInternalError` only when you encounter an unexpected situation in your own code that might be caused by a bug in zigantic:

```zig
const z = @import("zigantic");

fn myLibraryFunction() !void {
    // Some unexpected internal error occurred
    // This might be a bug in zigantic's internals
    z.reportInternalError("Unexpected null value in parsed result");
    return error.InternalError;
}
```

This prints:

```
[ZIGANTIC ERROR] Unexpected null value in parsed result

If you believe this is a bug in zigantic, please report it at:
  https://github.com/muhammad-fiaz/zigantic/issues
```

### Validation Errors (Do NOT Report)

Validation errors are **expected behavior** - don't report them as bugs:

```zig
const z = @import("zigantic");

pub fn main() void {
    // This is normal - validation errors are expected!
    if (z.String(3, 50).init("Jo")) |name| {
        std.debug.print("Valid: {s}\n", .{name.get()});
    } else |err| {
        // Handle normally - DO NOT call reportError()
        std.debug.print("Validation failed: {s}\n", .{z.errorMessage(err)});
    }
}
```

### Get Issues URL

```zig
const z = @import("zigantic");

const url = z.ISSUES_URL;  // "https://github.com/muhammad-fiaz/zigantic/issues"
```

## API Reference

### Functions

| Function                           | Description                                             |
| ---------------------------------- | ------------------------------------------------------- |
| `disableUpdateCheck()`             | Disable automatic update checking                       |
| `setConfig(config)`                | Set custom configuration                                |
| `getConfig()`                      | Get current configuration                               |
| `getVersion()`                     | Get version string (e.g., "0.0.3")                      |
| `getVersionString()`               | Get full version (e.g., "v0.0.3")                       |
| `checkForUpdates(allocator)`       | Manually check for updates in background                |
| `checkForUpdatesSync(allocator)`   | Manually check for updates synchronously                |
| `reportInternalError(msg)`         | Report internal library bug (not for validation errors) |
| `reportInternalErrorWithCode(err)` | Report internal library bug with error code             |

### Constants

| Constant     | Description                          |
| ------------ | ------------------------------------ |
| `ISSUES_URL` | GitHub issues URL for reporting bugs |
