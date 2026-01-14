# Getting Started

This guide walks you through creating your first validated types with zigantic.

## Prerequisites

- zigantic installed (see [Installation](/guide/installation))
- Basic knowledge of Zig

## Your First Validation

Let's validate a simple string:

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // Define a type: string between 1 and 50 characters
    const Name = z.String(1, 50);
    
    // Valid input
    const name = try Name.init("Alice");
    std.debug.print("Name: {s}\n", .{name.get()});
    
    // Invalid input - will return error
    const invalid = Name.init(""); // Returns error.TooShort
    _ = invalid catch |err| {
        std.debug.print("Error: {s}\n", .{z.errorMessage(err)});
    };
}
```

Output:
```
Name: Alice
Error: value is too short
```

## Understanding Validation Types

Every zigantic type follows this pattern:

1. **Define the type** with compile-time parameters
2. **Initialize** with `init()` which validates and returns the value or an error
3. **Access the value** with `get()` and use utility methods

```zig
// 1. Define: Age must be between 18 and 120
const Age = z.Int(i32, 18, 120);

// 2. Initialize: Validates the value
const age = try Age.init(25);

// 3. Access: Get the value and use utilities
std.debug.print("Age: {d}\n", .{age.get()});
std.debug.print("Is even: {}\n", .{age.isEven()});
```

## Common Validation Types

### Strings

```zig
// Length-constrained string
const Name = z.String(1, 100);

// Non-empty string
const Title = z.NonEmptyString(200);

// Auto-trimmed string
const Input = z.Trimmed(1, 100);
const input = try Input.init("  hello  ");
std.debug.print("{s}\n", .{input.get()}); // "hello"
```

### Numbers

```zig
// Integer with range
const Age = z.Int(i32, 0, 150);

// Positive integer only
const Count = z.PositiveInt(u32);

// Percentage (0-100)
const Score = z.Percentage(f64);
const score = try Score.init(85.5);
```

### Formats

```zig
// Email with utilities
const email = try z.Email.init("user@example.com");
std.debug.print("Domain: {s}\n", .{email.domain()});

// URL with protocol check
const url = try z.Url.init("https://example.com");
std.debug.print("Is HTTPS: {}\n", .{url.isHttps()});

// IP address with network utilities
const ip = try z.Ipv4.init("192.168.1.1");
std.debug.print("Is private: {}\n", .{ip.isPrivate()});
```

## Handling Errors

zigantic provides rich error information:

```zig
const z = @import("zigantic");

pub fn main() !void {
    const Email = z.Email;
    
    Email.init("invalid-email") catch |err| {
        // Get human-readable message
        const message = z.errorMessage(err);
        std.debug.print("Error: {s}\n", .{message});
        
        // Get error code
        const code = z.errorCode(err);
        std.debug.print("Code: {s}\n", .{code});
    };
}
```

Output:
```
Error: must be a valid email address
Code: E010
```

## JSON Parsing

Parse JSON directly into validated structs:

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Define a validated struct
    const User = struct {
        name: z.String(1, 50),
        email: z.Email,
        age: z.Int(i32, 0, 150),
    };

    const json = 
        \\{"name": "Alice", "email": "alice@example.com", "age": 30}
    ;

    var result = try z.fromJson(User, json, allocator);
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("Name: {s}\n", .{user.name.get()});
        std.debug.print("Email: {s}\n", .{user.email.get()});
        std.debug.print("Age: {d}\n", .{user.age.get()});
    } else {
        // Handle validation errors
        for (result.error_list.errors.items) |err| {
            std.debug.print("[{s}] {s}: {s}\n", .{
                z.errorCode(err.error_type),
                err.field,
                err.message,
            });
        }
    }
}
```

## JSON Serialization

Convert validated structs back to JSON:

```zig
const user = User{
    .name = try z.String(1, 50).init("Bob"),
    .email = try z.Email.init("bob@example.com"),
    .age = try z.Int(i32, 0, 150).init(25),
};

// Compact JSON
const json = try z.toJson(user, allocator);
defer allocator.free(json);

// Pretty-printed JSON
const pretty = try z.toJsonPretty(user, allocator);
defer allocator.free(pretty);
```

## Custom Validators

Create your own validation logic:

```zig
// Custom validator function
const isEven = struct {
    fn f(n: i32) bool {
        return @mod(n, 2) == 0;
    }
}.f;

// Use it as a type
const EvenNumber = z.Custom(i32, isEven);

const n = try EvenNumber.init(42); // OK
_ = EvenNumber.init(43); // Returns error.CustomValidationFailed
```

## Default Values

Provide defaults for optional fields:

```zig
const Config = struct {
    host: z.String(1, 100),
    port: z.Default(u16, 8080),
    debug: z.Default(bool, false),
};
```

## Next Steps

- [Validation Types](/guide/validation-types) - Deep dive into all types
- [JSON Parsing](/guide/json-parsing) - Advanced JSON features
- [Error Handling](/guide/error-handling) - Error management patterns
- [Schemas](/guide/schemas) - Complex data structures
- [Types API](/api/types) - Full API reference
