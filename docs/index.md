---
layout: home
hero:
  name: zigantic
  text: Pydantic-like validation for Zig
  tagline: Type-safe data validation and JSON serialization with 102 tests
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: API Reference
      link: /api/types
features:
  - icon: ⚡
    title: Compile-Time Driven
    details: Validation logic is types. No runtime overhead for unused features.
  - icon: 🦎
    title: Idiomatic Zig
    details: No macros, no DSLs. Just types and functions you already know.
  - icon: 📝
    title: Human-Readable Errors
    details: Field-aware messages with error codes for debugging and APIs.
  - icon: 🚀
    title: 40+ Built-in Types
    details: String, number, format, and collection types with rich utilities.
---

## Quick Example

```zig
const z = @import("zigantic");

// Direct validation with utilities
const email = try z.Email.init("user@company.com");
email.domain()         // "company.com"
email.isBusinessEmail() // true

// Password with strength check
const pwd = try z.Secret(8, 100).init("MyP@ss123!");
pwd.strength()  // 5/6

// Parsed JSON with defaults
const User = struct {
    name: z.String(1, 50),
    age: z.Int(i32, 18, 120),
    role: z.Default([]const u8, "user"),
};

var result = try z.fromJson(User, json, allocator);
defer result.deinit();
```
