<div align="center">

<h1>zigantic</h1>

<a href="https://muhammad-fiaz.github.io/zigantic/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.15.0-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/zigantic"><img src="https://img.shields.io/github/stars/muhammad-fiaz/zigantic" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/zigantic/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/zigantic" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/zigantic"><img src="https://img.shields.io/github/license/muhammad-fiaz/zigantic" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/zigantic/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/zigantic/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<img src="https://img.shields.io/badge/tests-102%20passing-brightgreen" alt="Tests">

<p><em>Pydantic-like data validation and serialization for Zig.</em></p>

<b>📚 <a href="https://muhammad-fiaz.github.io/zigantic/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/api/types">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/guide/quick-start">Quick Start</a></b>

</div>

---

> **If you understand Zig structs, you already understand zigantic.**

## Features

- ⚡ **Compile-Time Driven** - Validation as types
- 🦎 **Idiomatic Zig** - No DSLs, no macros
- 📝 **Human-Readable Errors** - Field-aware messages with error codes
- 🚀 **Zero Overhead** - Unused features cost nothing
- ✅ **102 Tests** - Comprehensive test coverage

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

## Quick Start

```zig
const z = @import("zigantic");

// Direct validation
const name = try z.String(1, 50).init("Alice");
const age = try z.PositiveInt(i32).init(25);
const email = try z.Email.init("alice@example.com");

std.debug.print("Name: {s}, Domain: {s}\n", .{name.get(), email.domain()});

// Strong password with strength check
const pwd = try z.Secret(8, 100).init("MyP@ss123");
std.debug.print("Strength: {d}/6\n", .{pwd.strength()});

// JSON parsing with validation
const User = struct {
    name: z.String(1, 50),
    age: z.Int(i32, 18, 120),
    role: z.Default([]const u8, "user"),
};

var result = try z.fromJson(User, json, allocator);
defer result.deinit();
```

## All Types

| Category       | Types                                                                                                                                                                                   |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **String**     | `String`, `NonEmptyString`, `Trimmed`, `Lowercase`, `Uppercase`, `Alphanumeric`, `AsciiString`, `Secret`, `StrongPassword`                                                              |
| **Number**     | `Int`, `UInt`, `PositiveInt`, `NonNegativeInt`, `NegativeInt`, `EvenInt`, `OddInt`, `MultipleOf`, `Float`, `Percentage`, `Probability`, `PositiveFloat`, `NegativeFloat`, `FiniteFloat` |
| **Format**     | `Email`, `Url`, `HttpsUrl`, `Uuid`, `Ipv4`, `Ipv6`, `Slug`, `Semver`, `PhoneNumber`, `CreditCard`, `Regex`                                                                              |
| **Collection** | `List`, `NonEmptyList`, `FixedList`                                                                                                                                                     |
| **Special**    | `Default`, `Custom`, `Transform`, `Coerce`, `Literal`, `Partial`, `OneOf`, `Range`, `Nullable`, `Lazy`                                                                                  |

## Type Features

```zig
// Password strength
const pwd = try z.Secret(8, 100).init("MyP@ss123");
pwd.strength()      // 0-6 score
pwd.hasUppercase()  // true
pwd.hasDigit()      // true

// Email parsing
const email = try z.Email.init("user@company.com");
email.domain()         // "company.com"
email.isBusinessEmail() // true (not gmail/yahoo)

// IP utilities
const ip = try z.Ipv4.init("192.168.1.1");
ip.isPrivate()  // true
ip.isLoopback() // false

// Credit card
const card = try z.CreditCard.init("4111111111111111");
card.cardType() // "visa"
card.masked()   // "1111"

// Number utilities
const n = try z.Int(i32, -100, 100).init(42);
n.isEven()   // true
n.clamp(0, 50) // 42
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
try errors.add("name", error.TooShort, "too short", "Jo");
errors.toJsonArray(allocator)  // JSON output
```

## Examples

```bash
zig build run-basic           # Direct validation + JSON
zig build run-advanced_types  # All 40+ types demos
zig build run-validators      # Validator functions
zig build run-json_example    # Full JSON workflow
zig build run-error_handling  # Error management
```

## Building

```bash
zig build            # Build library
zig build test       # Run 102 tests
zig build example    # Run basic example
```

## License

MIT License - Copyright (c) 2025 Muhammad Fiaz
