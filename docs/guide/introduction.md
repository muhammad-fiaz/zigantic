# Introduction

**zigantic** is a Pydantic-like data validation library for Zig. It brings the power of type-safe validation to Zig, using the type system for compile-time guarantees.

## What is zigantic?

zigantic allows you to:

- **Define validation rules as types** - Instead of runtime checks, validation constraints are expressed as types
- **Parse JSON with automatic validation** - Convert JSON to validated Zig structs in one step
- **Serialize validated data** - Convert structs back to JSON easily
- **Get human-readable errors** - Field-aware error messages with error codes

## Why zigantic?

### Compile-Time Guarantees

Validation rules are expressed as types, so invalid constraints fail at compile time:

```zig
// This won't compile - min > max
const Invalid = z.String(100, 10); // Compile error!
```

### Self-Documenting Code

Types describe their own constraints:

```zig
const User = struct {
    name: z.String(1, 50),      // 1-50 characters
    age: z.Int(i32, 18, 120),   // 18-120
    email: z.Email,             // Valid email format
};
```

### Zero Runtime Overhead

Unused features have no cost. If you don't use JSON parsing, it's not compiled in.

### IDE Support

Full type information everywhere - autocomplete, hover documentation, and refactoring support.

## Quick Example

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // Direct validation
    const email = try z.Email.init("user@example.com");
    std.debug.print("Domain: {s}\n", .{email.domain()});

    // JSON parsing
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const User = struct {
        name: z.String(1, 50),
        age: z.Int(i32, 0, 150),
    };

    const json = 
        \\{"name": "Alice", "age": 25}
    ;

    var result = try z.fromJson(User, json, allocator);
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("User: {s}, Age: {d}\n", .{user.name.get(), user.age.get()});
    }
}
```

## Key Features

| Feature | Description |
|---------|-------------|
| **50+ Built-in Types** | Strings, numbers, emails, URLs, UUIDs, dates, coordinates, and more |
| **JSON Serialization** | Parse and serialize JSON with automatic validation |
| **Custom Validators** | Define your own validation logic with `Custom` type |
| **Transformations** | Transform values during validation with `Transform` type |
| **Default Values** | Specify defaults with `Default` type |
| **Partial Types** | Make all fields optional with `Partial` |
| **Human-Readable Errors** | Field-aware messages with error codes |

## Type Categories

### String Types
`String`, `NonEmptyString`, `Trimmed`, `Lowercase`, `Uppercase`, `Alphanumeric`, `AsciiString`, `Secret`, `StrongPassword`

### Number Types
`Int`, `UInt`, `PositiveInt`, `NonNegativeInt`, `NegativeInt`, `EvenInt`, `OddInt`, `MultipleOf`, `Float`, `Percentage`, `Probability`, `PositiveFloat`, `NegativeFloat`, `FiniteFloat`

### Format Types  
`Email`, `Url`, `HttpsUrl`, `Uuid`, `Ipv4`, `Ipv6`, `Slug`, `Semver`, `PhoneNumber`, `CreditCard`, `Regex`, `Base64`, `HexString`, `HexColor`, `MacAddress`, `IsoDateTime`, `IsoDate`, `CountryCode`, `CurrencyCode`, `Latitude`, `Longitude`, `Port`

### Collection Types
`List`, `NonEmptyList`, `FixedList`

### Special Types
`Default`, `Custom`, `Transform`, `Coerce`, `Literal`, `Partial`, `OneOf`, `Range`, `Nullable`, `Lazy`

## Next Steps

- [Installation](/guide/installation) - Install zigantic in your project
- [Getting Started](/guide/getting-started) - Create your first validation
- [Types API](/api/types) - Full reference for all types
- [JSON API](/api/json) - JSON serialization and deserialization
