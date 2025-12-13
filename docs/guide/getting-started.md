# Getting Started

Welcome to **zigantic** - Pydantic-like data validation for Zig! 🦎

## What is zigantic?

zigantic brings the power of Pydantic-style validation to Zig. Instead of runtime annotations, validation rules are expressed as **types**. This gives you:

- **Compile-time guarantees** - Invalid constraints fail at compile time
- **Self-documenting code** - Types describe their own constraints
- **Zero runtime overhead** - Unused features have no cost
- **IDE support** - Full type information everywhere

## Requirements

- **Zig 0.15.0** or later

## Installation

### Step 1: Fetch the package

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/v0.0.1.tar.gz
```

### Step 2: Configure build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add zigantic dependency
    const zigantic = b.dependency("zigantic", .{
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
    exe.root_module.addImport("zigantic", zigantic.module("zigantic"));

    b.installArtifact(exe);
}
```

### Step 3: Import and use

```zig
const z = @import("zigantic");

pub fn main() !void {
    const name = try z.String(1, 50).init("Alice");
    std.debug.print("Hello, {s}!\n", .{name.get()});
}
```

## Your First Validation

Let's validate some data:

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // String with length constraints
    const name = try z.String(1, 50).init("Alice");
    std.debug.print("Name: {s} (length: {d})\n", .{name.get(), name.len()});

    // Integer with range
    const age = try z.Int(i32, 18, 120).init(25);
    std.debug.print("Age: {d} (positive: {})\n", .{age.get(), age.isPositive()});

    // Email with domain parsing
    const email = try z.Email.init("alice@example.com");
    std.debug.print("Email: {s}\n", .{email.get()});
    std.debug.print("Domain: {s}\n", .{email.domain()});

    // Password with strength
    const pwd = try z.Secret(8, 100).init("MyP@ss123!");
    std.debug.print("Password: {s} (strength: {d}/6)\n", .{pwd.masked(), pwd.strength()});
}
```

Output:

```
Name: Alice (length: 5)
Age: 25 (positive: true)
Email: alice@example.com
Domain: example.com
Password: ******** (strength: 5/6)
```

## JSON Parsing

Parse JSON with automatic validation:

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const User = struct {
        name: z.String(1, 50),
        age: z.Int(i32, 18, 120),
        email: z.Email,
        role: z.Default([]const u8, "user"),
    };

    const json =
        \\{"name": "Bob", "age": 30, "email": "bob@example.com"}
    ;

    var result = try z.fromJson(User, json, allocator);
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("Welcome, {s}!\n", .{user.name.get()});
        std.debug.print("Role: {s} (default)\n", .{user.role.get()});
    }
}
```

## Error Handling

Handle validation errors gracefully:

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // Catch validation errors
    if (z.String(3, 50).init("Jo")) |name| {
        std.debug.print("Valid: {s}\n", .{name.get()});
    } else |err| {
        std.debug.print("Error: {s}\n", .{z.errorMessage(err)});
        std.debug.print("Code: {s}\n", .{z.errorCode(err)});
    }

    // Output:
    // Error: value is too short
    // Code: E001
}
```

## Running Examples

The library includes 5 comprehensive examples:

| Example        | Command                        | Description              |
| -------------- | ------------------------------ | ------------------------ |
| Basic          | `zig build run-basic`          | Direct validation + JSON |
| Advanced Types | `zig build run-advanced_types` | All 40+ types            |
| Validators     | `zig build run-validators`     | Validator functions      |
| JSON           | `zig build run-json_example`   | Full JSON workflow       |
| Errors         | `zig build run-error_handling` | Error management         |

## Building the Library

```bash
zig build            # Build the library
zig build test       # Run all 102 tests
zig build example    # Run basic example
```

## Next Steps

- **[Quick Start](/guide/quick-start)** - Learn all 40+ types
- **[Validation Types](/guide/validation-types)** - Complete type reference
- **[JSON Parsing](/guide/json-parsing)** - Parse and serialize JSON
- **[Error Handling](/guide/error-handling)** - Handle errors with codes
- **[API Reference](/api/types)** - Full API documentation
