---
title: Quick Start
description: Build a real zigantic schema in a few minutes, parse JSON into a Zig struct and read the validation result.
keywords: zigantic quick start, zig json parsing, zig struct validation, parse result, allocator
---

# Quick Start

```zig
const std = @import("std");
const z = @import("zigantic");

const Address = struct { city: []const u8, postal_code: []const u8 };
const AddressSchema = z.object(Address, .{
    .city = z.string(.{ .min = 1 }),
    .postal_code = z.string(.{ .len = 5, .charset = .numeric }),
}, .{});

const User = struct {
    name: []const u8,
    email: []const u8,
    age: u8,
    address: Address,
};

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1, .trim = true }),
    .email = z.email(.{}),
    .age = z.integer(u8, .{ .min = 18 }),
    .address = AddressSchema,
}, .{});

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var result = try z.parse(UserSchema, allocator,
        \{"name":"Ada","email":"ada@example.com","age":36,"address":{"city":"London","postal_code":"12345"}}
    , .{});
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("{s} in {s}\n", .{ user.name, user.address.city });
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }
}
```

`parse` returns a `ParseResult`. A successful result holds the decoded value;
a failed one holds an issue list and a null value. The input text is not
referenced after `parse` returns.

## Run it

Save the program as `main.zig`, add the module to your `build.zig`, and run:

```bash
zig build run
```

Expected output:

```text
Ada in London
```

Break the document on purpose, for example by changing the postal code to
`"AB12"`, and the same program prints:

```text
error[E005]: invalid value
  $.address.postal_code
    expected: numeric text
    received: "AB12"
```

## Next steps

- [Schemas](/guide/schemas) explains the schema protocol and composition.
- [Inferred Objects, Tuples & Intersections](/guide/inference) shows how to
  derive models and fixed tuples at compile time.
- [Validation Types](/guide/validation-types) lists every built-in format and
  the complete string and number options.
- [Date & Time](/guide/datetime) covers calendar arithmetic, formatting and
  fixed-offset timestamps.
- [Examples](/examples/) walks through nine complete programs with output.
