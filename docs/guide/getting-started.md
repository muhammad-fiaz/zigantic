# Getting Started

## Installation

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/v0.0.1.tar.gz
```

In `build.zig`:

```zig
const zigantic = b.dependency("zigantic", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zigantic", zigantic.module("zigantic"));
```

## Requirements

- Zig 0.15.0+

## First Example

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // Direct validation
    const name = try z.String(1, 50).init("Alice");
    const age = try z.PositiveInt(i32).init(25);
    const email = try z.Email.init("alice@example.com");

    std.debug.print("Name: {s} (len: {d})\n", .{name.get(), name.len()});
    std.debug.print("Domain: {s}\n", .{email.domain()});

    // Password with strength
    const pwd = try z.Secret(8, 100).init("MyP@ss123!");
    std.debug.print("Strength: {d}/6\n", .{pwd.strength()});

    // JSON parsing
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const User = struct {
        name: z.String(1, 50),
        age: z.Int(i32, 18, 120),
        role: z.Default([]const u8, "user"),
    };

    var result = try z.fromJson(User, "{\"name\": \"Bob\", \"age\": 30}", allocator);
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("Hello, {s}!\n", .{user.name.get()});
    }
}
```

## Examples

The library includes 5 comprehensive examples:

| Example          | Description              |
| ---------------- | ------------------------ |
| `basic`          | Direct validation + JSON |
| `advanced_types` | All 40+ types            |
| `validators`     | Validator functions      |
| `json_example`   | Full JSON workflow       |
| `error_handling` | Error management         |

```bash
zig build run-basic
zig build run-advanced_types
zig build run-validators
zig build run-json_example
zig build run-error_handling
```

## Building

```bash
zig build            # Build library
zig build test       # Run 102 tests
```
