---
layout: home
hero:
  name: zigantic
  text: Pydantic-like validation for Zig
  tagline: Type-safe data validation with 50+ built-in types, human-readable errors, and zero runtime overhead.
  image:
    src: /logo.png
    alt: zigantic
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/zigantic
    - theme: alt
      text: API Reference
      link: /api/types
features:
  - icon: ⚡
    title: Compile-Time Driven
    details: Validation logic is types. Constraints are baked in at compile time with zero runtime reflection.
  - icon: 🦎
    title: Idiomatic Zig
    details: No macros, no DSLs, no magic. Just types and functions that any Zig developer understands immediately.
  - icon: 📝
    title: Human-Readable Errors
    details: Field-aware error messages with error codes (E001, E010, etc.) for debugging and API responses.
  - icon: 🚀
    title: 50+ Built-in Types
    details: Strings, numbers, emails, URLs, UUIDs, IPs, dates, geo coordinates, and more with rich utility methods.
  - icon: 🔄
    title: JSON Serialization
    details: Parse and serialize JSON with automatic validation, nested struct support, and default values.
  - icon: 🔧
    title: Custom Validators
    details: Define custom validation functions, transformations, and type coercion for any use case.
---

<style>
:root {
  --vp-home-hero-name-color: transparent;
  --vp-home-hero-name-background: linear-gradient(135deg, #f7a41d 0%, #ff6b6b 100%);
  --vp-home-hero-image-background-image: linear-gradient(135deg, #f7a41d40 0%, #ff6b6b40 100%);
  --vp-home-hero-image-filter: blur(40px);
}
</style>

## Quick Example

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // Direct validation with rich utilities
    const email = try z.Email.init("alice@company.com");
    std.debug.print("Domain: {s}\n", .{email.domain()});           // "company.com"
    std.debug.print("Business: {}\n", .{email.isBusinessEmail()}); // true

    // Password with strength checking
    const pwd = try z.Secret(8, 100).init("MyP@ss123!");
    std.debug.print("Strength: {d}/6\n", .{pwd.strength()}); // 5

    // Numbers with utilities
    const age = try z.Int(i32, 18, 120).init(25);
    std.debug.print("Even: {}, Positive: {}\n", .{age.isEven(), age.isPositive()});

    // IP with network utilities
    const ip = try z.Ipv4.init("192.168.1.1");
    std.debug.print("Private: {}\n", .{ip.isPrivate()}); // true
}
```

## Installation

### Release Installation (Recommended)

Install the latest stable release (v0.0.2):

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/v0.0.2.tar.gz
```

### Nightly Installation

Install the latest development version:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zigantic.git
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

## Type Categories

<div class="type-grid">

### String Types (9)

`String` `NonEmptyString` `Trimmed` `Lowercase` `Uppercase` `Alphanumeric` `AsciiString` `Secret` `StrongPassword`

### Number Types (14)

`Int` `UInt` `PositiveInt` `NonNegativeInt` `NegativeInt` `EvenInt` `OddInt` `MultipleOf` `Float` `Percentage` `Probability` `PositiveFloat` `NegativeFloat` `FiniteFloat`

### Format Types (22)

`Email` `Url` `HttpsUrl` `Uuid` `Ipv4` `Ipv6` `Slug` `Semver` `PhoneNumber` `CreditCard` `Regex` `Base64` `HexString` `HexColor` `MacAddress` `IsoDateTime` `IsoDate` `CountryCode` `CurrencyCode` `Latitude` `Longitude` `Port`

### Collection Types (3)

`List` `NonEmptyList` `FixedList`

### Special Types (10)

`Default` `Custom` `Transform` `Coerce` `Literal` `Partial` `OneOf` `Range` `Nullable` `Lazy`

</div>

## Examples

Run the included examples:

```bash
zig build run-basic           # Direct validation + JSON
zig build run-advanced_types  # All 50+ types demo
zig build run-validators      # Validator functions
zig build run-json_example    # Full JSON workflow
zig build run-error_handling  # Error management
zig build bench               # Run benchmarks
```

## Made with love for the Zig community

<div style="text-align: center; margin-top: 2rem;">
  <a href="https://github.com/muhammad-fiaz/zigantic/stargazers" style="margin: 0 0.5rem;">⭐ Star</a>
  <a href="https://github.com/muhammad-fiaz/zigantic/issues" style="margin: 0 0.5rem;">🐛 Issues</a>
  <a href="https://github.com/muhammad-fiaz/zigantic/blob/main/CONTRIBUTING.md" style="margin: 0 0.5rem;">🤝 Contribute</a>
</div>
