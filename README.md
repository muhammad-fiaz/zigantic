<div align="center">
<img alt="logo" src="https://github.com/user-attachments/assets/90082000-30ab-4ca6-992d-247d1b1e706b" />

<a href="https://muhammad-fiaz.github.io/zigantic/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.16.0+-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/zigantic"><img src="https://img.shields.io/github/stars/muhammad-fiaz/zigantic" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/zigantic/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/zigantic" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/zigantic/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/zigantic" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/zigantic"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/zigantic" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/zigantic/blob/main/LICENSE"><img src="https://img.shields.io/github/license/muhammad-fiaz/zigantic" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/zigantic/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/zigantic/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/zigantic/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/zigantic?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-💖-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/github.com/muhammad-fiaz/zigantic/"><img src="https://hits.sh/github.com/muhammad-fiaz/zigantic.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>Type-safe data validation and JSON serialization for Zig with compile-time guarantees.</em></p>

<b> <a href="https://muhammad-fiaz.github.io/zigantic/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/api/types">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/guide/quick-start">Quick Start</a> |
<a href="https://github.com/muhammad-fiaz/zigantic/blob/main/CONTRIBUTING.md">Contributing</a></b>

</div>

---

zigantic is a data validation library for Zig, using the type system for compile-time guarantees. Define validation rules as types, parse JSON with automatic error handling, and serialize with zero runtime overhead for unused features.

## Features

| Feature                  | Description                                                         | Docs                                                                                      |
| ------------------------ | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Compile-Time Driven**  | Validation logic is types. Constraints are checked at compile time. | [Philosophy](https://muhammad-fiaz.github.io/zigantic/guide/philosophy)                   |
| **Idiomatic Zig**        | No macros, no DSLs, no magic. Just types and functions.             | [Getting Started](https://muhammad-fiaz.github.io/zigantic/guide/getting-started)         |
| **Human-Readable Errors**| Field-aware messages with error codes (E001, E010, etc.)            | [Error Handling](https://muhammad-fiaz.github.io/zigantic/guide/error-handling)           |
| **Zero Overhead**        | Unused features have zero runtime cost.                             | [Benchmarks](https://muhammad-fiaz.github.io/zigantic/guide/benchmarks)                   |
| **60+ Built-in Types**   | Strings, numbers, formats, dates, geo, crypto, and collections.    | [Types API](https://muhammad-fiaz.github.io/zigantic/api/types)                           |
| **JSON Serialization**   | Parse and serialize JSON with automatic validation.                 | [JSON API](https://muhammad-fiaz.github.io/zigantic/api/json)                             |
| **Custom Validators**    | Define custom validation functions and transformations.             | [Validators](https://muhammad-fiaz.github.io/zigantic/api/validators)                     |
| **Custom Messages**      | Override error messages per-type with comptime config.              | [Error Handling](https://muhammad-fiaz.github.io/zigantic/guide/error-handling)           |
| **Lifecycle Callbacks**  | Hooks for validation and serialization lifecycle events.           | [Callbacks](https://muhammad-fiaz.github.io/zigantic/guide/error-handling)                |
| **Color Overrides**      | Customize terminal colors per validation error type.              | [Error Handling](https://muhammad-fiaz.github.io/zigantic/guide/error-handling)           |
| **Schemas**              | Define complex data structures with nested validation.              | [Schemas](https://muhammad-fiaz.github.io/zigantic/guide/schemas)                         |
| **Auto Updates**         | Automatic version checking (can be disabled).                       | [Version & Updates](https://muhammad-fiaz.github.io/zigantic/guide/version-updates)       |

## Installation

### Release Installation (Recommended)

Install the latest stable release for zig 0.16+ (use v0.0.3 or newer):

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/0.0.3.tar.gz
```

### Nightly Installation

Install the latest development version:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zigantic
```

### Configure build.zig

Then in your `build.zig`:

```zig
const zigantic_dep = b.dependency("zigantic", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zigantic", zigantic_dep.module("zigantic"));
```

## Quick Start

### Direct Validation

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // String with length constraints
    const name = try z.String(1, 50).init("Alice");
    std.debug.print("Name: {s} (len: {d})\n", .{name.get(), name.len()});

    // Email with domain parsing
    const email = try z.Email.init("alice@company.com");
    std.debug.print("Email: {s}\n", .{email.get()});
    std.debug.print("Domain: {s}\n", .{email.domain()});
    std.debug.print("Business email: {}\n", .{email.isBusinessEmail()});

    // Password with strength checking
    const pwd = try z.Secret(8, 100).init("MyP@ssw0rd!");
    std.debug.print("Password: {s}\n", .{pwd.masked()});
    std.debug.print("Strength: {d}/6\n", .{pwd.strength()});

    // Integer with range and utilities
    const age = try z.Int(i32, 18, 120).init(25);
    std.debug.print("Age: {d} (even: {}, positive: {})\n", .{
        age.get(), age.isEven(), age.isPositive()
    });

    // IP address with network utilities
    const ip = try z.Ipv4.init("192.168.1.1");
    std.debug.print("IP: {s} (private: {})\n", .{ip.get(), ip.isPrivate()});
}
```

> **Note:** zigantic automatically checks for updates when using JSON functions. To disable, call `z.disableUpdateCheck()` at the start of your program.

Custom validation messages can be set per-type via the `f` suffix variants:

```zig
const Name = z.Stringf(3, 50, .{ .too_short = "name must be at least 3 chars" });
const err = Name.init("Jo") catch |e| e;
std.debug.print("{s}\n", .{Name.messageFor(err).?});
```

Or globally via the message formatter in Config:

### JSON Parsing with Validation

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Define a validated struct
    const User = struct {
        id: z.PositiveInt(u32),
        name: z.String(1, 50),
        age: z.Int(i32, 18, 120),
        email: z.Email,
        role: z.Default([]const u8, "user"),
        website: ?z.Url = null,
    };

    const json =
        \\{"id": 1, "name": "Alice", "age": 25, "email": "alice@example.com"}
    ;

    var result = try z.fromJson(User, json, allocator);
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("Welcome, {s}!\n", .{user.name.get()});
        std.debug.print("Role: {s} (default)\n", .{user.role.get()});
    }

    if (!result.isValid()) {
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

### URL Query Parameters & Form URL-Encoded Parsing

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const SearchQuery = struct {
        query: z.String(1, 100),
        page: z.Default(u32, 1),
        active_only: bool,
    };

    const qs = "query=Mechanical+Keyboard&page=2&active_only=true";
    var result = try z.fromQueryString(SearchQuery, qs, allocator);
    defer result.deinit();

    if (result.isValid()) {
        const q = result.value.?;
        std.debug.print("Query: {s}, Page: {d}\n", .{q.query.get(), q.page.get()});
        
        // Serialize back to query string!
        const serialized = try z.toQueryString(q, allocator);
        defer allocator.free(serialized);
        std.debug.print("Serialized query string: {s}\n", .{serialized});
    }
}
```

### Compile-Time Field Aliases & Naming Policies

Map custom aliases or use automatic naming policies (like `snake_case` or `camelCase`) completely at compile time with zero runtime cost.

```zig
const std = @import("std");
const z = @import("zigantic");

const User = struct {
    firstName: []const u8,
    lastName: []const u8,

    // Automatically convert camelCase struct fields to snake_case in JSON/Query strings
    pub const zigantic_naming = z.utils.NamingPolicy.snake_case;
    
    // Explicit field aliases (overrides naming policies)
    pub const zigantic_aliases = .{
        .firstName = "first",
    };
};
```

### Advanced Features

zigantic supports high-value features including dynamic default factories, field-level validation, and model-level cross-field validation.

#### Dynamic Default Factories (`DefaultFactory`)

Use `DefaultFactory` when default values need to be dynamically generated at instantiation/parsing time (e.g. unique IDs or dynamic timestamps).

```zig
const std = @import("std");
const z = @import("zigantic");

var call_counter: i32 = 0;
fn nextId() i32 {
    call_counter += 1;
    return call_counter;
}

const Device = struct {
    name: []const u8,
    id: z.DefaultFactory(i32, nextId),
};
```

#### Field-Level Validators (`validate_[field_name]`)

Structs can define field-level validator methods to run custom validation or coercion/normalization logic for specific fields. A field validator receives the parsed field value and returns the final value (or an error).

```zig
const User = struct {
    username: z.String(3, 50),
    age: i32,

    // Runs after basic parsing succeeds for 'age'
    pub fn validate_age(val: i32) !i32 {
        if (val < 18) return error.AgeTooYoung;
        // Cap age at 100 as a coercion/normalization
        if (val > 100) return 100;
        return val;
    }
};
```

#### Model-Level Validation (`validateModel`)

Structs can define a `validateModel` method to perform cross-field validation after all individual fields have successfully parsed and validated.

```zig
const Order = struct {
    item: []const u8,
    quantity: i32,
    discount_code: ?[]const u8,

    pub fn validateModel(self: *const @This()) !void {
        if (self.discount_code != null and self.quantity < 5) {
            return error.DiscountRequiresMinimumQuantity;
        }
    }
};
```

## All Types

### String Types (9)

| Type                       | Description                        | Example                  |
| -------------------------- | ---------------------------------- | ------------------------ |
| `String(min, max)`         | Length-constrained string          | `String(1, 50)`          |
| `NonEmptyString(max)`      | Non-empty string                   | `NonEmptyString(100)`    |
| `Trimmed(min, max)`        | Auto-trim whitespace               | `Trimmed(1, 50)`         |
| `Lowercase(max)`           | Lowercase only                     | `Lowercase(50)`          |
| `Uppercase(max)`           | Uppercase only                     | `Uppercase(50)`          |
| `Alphanumeric(min, max)`   | Letters and digits                 | `Alphanumeric(1, 20)`    |
| `AsciiString(min, max)`    | ASCII only (0-127)                 | `AsciiString(1, 100)`    |
| `Secret(min, max)`         | Password with strength             | `Secret(8, 100)`         |
| `StrongPassword(min, max)` | Requires upper+lower+digit+special | `StrongPassword(8, 100)` |

**String Methods:**

```zig
str.get()           // Get value
str.len()           // Length
str.isEmpty()       // Check empty
str.startsWith("A") // Prefix check
str.endsWith("z")   // Suffix check
str.contains("bc")  // Contains check
str.charAt(0)       // Character at index
str.slice(0, 5)     // Substring

// Secret-specific
pwd.masked()        // "********"
pwd.strength()      // 0-6 score
pwd.hasUppercase()  // bool
pwd.hasLowercase()  // bool
pwd.hasDigit()      // bool
pwd.hasSpecial()    // bool
```

### Number Types (14)

| Type                     | Description            | Example                |
| ------------------------ | ---------------------- | ---------------------- |
| `Int(T, min, max)`       | Signed integer range   | `Int(i32, 0, 100)`     |
| `UInt(T, min, max)`      | Unsigned integer range | `UInt(u32, 1, 1000)`   |
| `PositiveInt(T)`         | > 0                    | `PositiveInt(i32)`     |
| `NonNegativeInt(T)`      | >= 0                   | `NonNegativeInt(i32)`  |
| `NegativeInt(T)`         | < 0                    | `NegativeInt(i32)`     |
| `EvenInt(T, min, max)`   | Even numbers only      | `EvenInt(i32, 0, 100)` |
| `OddInt(T, min, max)`    | Odd numbers only       | `OddInt(i32, 1, 99)`   |
| `MultipleOf(T, divisor)` | Must be multiple of N  | `MultipleOf(i32, 5)`   |
| `Float(T, min, max)`     | Float range            | `Float(f64, 0.0, 1.0)` |
| `Percentage(T)`          | 0-100                  | `Percentage(f64)`      |
| `Probability(T)`         | 0-1                    | `Probability(f64)`     |
| `PositiveFloat(T)`       | > 0                    | `PositiveFloat(f64)`   |
| `NegativeFloat(T)`       | < 0                    | `NegativeFloat(f64)`   |
| `FiniteFloat(T)`         | No NaN/Infinity        | `FiniteFloat(f64)`     |

**Number Methods:**

```zig
n.get()          // Get value
n.isPositive()   // > 0
n.isNegative()   // < 0
n.isZero()       // == 0
n.isEven()       // Even check
n.isOdd()        // Odd check
n.abs()          // Absolute value
n.clamp(0, 50)   // Clamp to range

// Float-specific
f.floor()        // Floor
f.ceil()         // Ceiling
f.round()        // Round
f.trunc()        // Truncate
```

### Format Types (11)

| Type             | Description        | Methods                                        |
| ---------------- | ------------------ | ---------------------------------------------- |
| `Email`          | Email address      | `domain()`, `localPart()`, `isBusinessEmail()` |
| `Url`            | HTTP/HTTPS URL     | `isHttps()`, `protocol()`, `host()`            |
| `HttpsUrl`       | HTTPS only         | -                                              |
| `Uuid`           | UUID format        | `version()`                                    |
| `Ipv4`           | IPv4 address       | `isPrivate()`, `isLoopback()`                  |
| `Ipv6`           | IPv6 address       | `isLoopback()`                                 |
| `Slug`           | URL slug           | -                                              |
| `Semver`         | Semantic version   | -                                              |
| `PhoneNumber`    | Phone number       | `hasCountryCode()`                             |
| `CreditCard`     | Credit card (Luhn) | `cardType()`, `masked()`                       |
| `Regex(pattern)` | Pattern matching   | -                                              |

### Collection Types (3)

| Type                   | Description      | Methods                               |
| ---------------------- | ---------------- | ------------------------------------- |
| `List(T, min, max)`    | List with length | `len()`, `first()`, `last()`, `at(i)` |
| `NonEmptyList(T, max)` | Non-empty list   | Same as List                          |
| `FixedList(T, len)`    | Exact size       | `at(i)`                               |

### Special Types (11)

| Type                      | Description         | Methods                         |
| ------------------------- | ------------------- | ------------------------------- |
| `Default(T, value)`       | Default value       | `isDefault()`, `getOrDefault()` |
| `DefaultFactory(T, fn)`   | Dynamic default     | `initDefault()`, `getOrDefault()`|
| `Custom(T, fn)`           | Custom validator    | -                               |
| `Transform(T, fn)`        | Transform value     | `getOriginal()`                 |
| `Coerce(From, To)`        | Type conversion     | -                               |
| `Literal(T, value)`       | Exact value match   | -                               |
| `Partial(T)`              | All fields optional | -                               |
| `OneOf(T, values)`        | Allowed values      | `isFirst()`, `isLast()`         |
| `Range(T, s, e, step)`    | Range with step     | -                               |
| `Nullable(T)`             | Explicit null       | `isNull()`, `unwrapOr()`        |
| `Lazy(T)`                 | Lazy evaluation     | `isComputed()`, `reset()`       |

## Validators

Direct validation functions without types:

```zig
const v = z.validators;

// Format validators
v.isValidEmail("user@example.com")     // true
v.isValidUrl("https://example.com")    // true
v.isUuid("550e8400-...")               // true
v.isIpv4("192.168.1.1")                // true
v.isIpv6("::1")                        // true
v.isSlug("hello-world")                // true
v.isSemver("1.2.3")                    // true
v.isPhoneNumber("+1234567890")         // true
v.isJwt("header.payload.signature")    // true
v.isValidCreditCard("4111...")         // true

// String validators
v.isAlphanumeric("abc123")             // true
v.isAlpha("hello")                     // true
v.isNumeric("12345")                   // true
v.isLowercase("hello")                 // true
v.isUppercase("HELLO")                 // true
v.isHexString("0123abcdef")            // true

// Pattern matching
v.matchesPattern("[0-9][0-9][0-9]", "123")  // true
```

## Error Handling

```zig
// Error messages and codes
if (z.String(3, 50).init("Jo")) |_| {} else |err| {
    z.errorMessage(err)  // "value is too short"
    z.errorCode(err)     // "E001"
}

// ErrorList for collecting multiple errors
var errors = z.errors.ErrorList.init(allocator);
defer errors.deinit();

try errors.add("name", error.TooShort, "too short", "Jo");
errors.count()           // 1
errors.containsField("name")  // true

// JSON output
const json = try errors.toJsonArray(allocator);
// [{"field":"name","message":"too short","value":"Jo"}]
```

### Custom Error Messages

Override error messages per-type via the comptime `messages` parameter:

```zig
const Name = z.Stringf(3, 50, .{ .too_short = "name is required" });
const Age = z.Intf(i32, 18, 120, .{ .too_small = "must be 18+" });
const Pwd = z.StrongPasswordf(8, 100, .{
    .too_short = "password too short",
    .weak_password = "needs upper, lower, digit, special",
});
```

The `messageFor(err)` method returns the custom message for the given error, or `null` if no override was set.

For global message formatting (works with all types including Email, Url, etc.), use the config formatter:

```zig
var cfg = z.getConfig();
cfg.validation_message_formatter = struct {
    fn f(err: z.errors.ValidationError) []const u8 {
        return switch (err) {
            error.InvalidEmail => "please enter a valid email address",
            else => z.errorMessage(err),
        };
    }
}.f;
z.setConfig(cfg);
```

### Lifecycle Callbacks

Register callbacks for validation and serialization lifecycle events:

```zig
var cfg = z.getConfig();
cfg.before_validation_callback = struct {
    fn call(type_name: []const u8) void {
        std.debug.print("Validating: {s}\n", .{type_name});
    }
}.call;
cfg.on_field_validated_callback = struct {
    fn call(field: []const u8, field_type: []const u8, success: bool) void { }
}.call;
cfg.on_field_error_callback = struct {
    fn call(field: []const u8, msg: []const u8) void { }
}.call;
cfg.on_validation_complete_callback = struct {
    fn call(valid: bool, error_count: usize) void { }
}.call;
cfg.before_serialize_callback = struct {
    fn call() void { }
}.call;
cfg.after_serialize_callback = struct {
    fn call(result: []const u8) void { }
}.call;
z.setConfig(cfg);
```

### Error Codes

| Code | Error                  | Message               |
| ---- | ---------------------- | --------------------- |
| E001 | TooShort               | value is too short    |
| E002 | TooLong                | value is too long     |
| E003 | TooSmall               | value is too small    |
| E004 | TooLarge               | value is too large    |
| E010 | InvalidEmail           | must be a valid email |
| E011 | InvalidUrl             | must be a valid URL   |
| E020 | MissingField           | field is required     |
| E021 | TypeMismatch           | wrong type            |
| E099 | CustomValidationFailed | validation failed     |

## Examples

The library includes 8 comprehensive examples:

```bash
zig build run-basic               # Direct validation + JSON
zig build run-advanced_types      # All 50+ types demo
zig build run-validators          # Validator functions
zig build run-json_example        # Full JSON workflow
zig build run-error_handling      # Error management
zig build run-naming_conventions  # Compile-time Casing conventions and explicit Aliases
zig build run-custom_messages     # Custom validation messages
zig build run-callbacks           # Lifecycle callbacks
```

## Building

```bash
zig build            # Build library
zig build test       # Run 148+ tests
zig build example    # Run basic example
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
