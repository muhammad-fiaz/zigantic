---
layout: home
title: Home
description: Type-safe, allocator-explicit validation and schema composition for Zig 0.17. Parse JSON, query strings and forms into declared Zig types with structured errors and JSON Schema generation.
keywords: zigantic, zig validation, zig schema, json validation, query string validation, json schema, zig 0.17, allocator
hero:
  name: zigantic
  text: Validation and schemas for Zig
  tagline: Compile-time schema composition, explicit allocation, structured errors.
  actions:
    - theme: brand
      text: Get started
      link: /guide/quick-start
    - theme: alt
      text: API reference
      link: /api/reference
features:
  - title: Schemas are types
    details: Composition is checked by the compiler; invalid schema combinations fail the build.
  - title: Inferred models
    details: Bind a declared struct or synthesize one with @Struct, and build fixed tuples with @Tuple.
  - title: Explicit ownership
    details: Parsed values live in a result arena released by deinit. No hidden allocator or global state.
  - title: JSON, query and forms
    details: One schema validates JSON documents, nested query strings and form bodies with identical error paths.
  - title: Calendar-aware dates
    details: Allocation-free date and time parsing with leap-year, month-length and fixed-offset arithmetic.
  - title: Structured diagnostics
    details: Stable codes, precise paths, expected/received values, JSON output and optional tint colours.
---

## Quick example

```zig
const std = @import("std");
const z = @import("zigantic");

const User = struct { name: []const u8, email: []const u8, age: u8 };

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1, .trim = true }),
    .email = z.email(.{}),
    .age = z.integer(u8, .{ .min = 18 }),
}, .{});

pub fn main() !void {
    var result = try z.parse(UserSchema, std.heap.page_allocator,
        \{"name":"Ada","email":"ada@example.com","age":36}
    , .{});
    defer result.deinit();
    if (result.value) |user| {
        std.debug.print("{s} <{s}>\n", .{ user.name, user.email });
    }
}
```

Install with the release tarball or nightly Git URL; see [installation](/guide/installation).

## Explore

- [Quick start](/guide/quick-start) builds and runs the first schema.
- [Examples](/examples/) walks through nine complete programs, each with its
  output.
- [API reference](/api/reference) documents every constructor, config struct and
  option.
