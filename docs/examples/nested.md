---
title: Nested Objects
description: Compose object schemas inside other object schemas and read precise nested error paths from zigantic.
keywords: zigantic nested schema, nested object validation, error path, zig struct composition
---

# Nested Objects

Object schemas compose directly: a field whose value is another object schema
gets validated recursively, and issues carry the full path from the document
root.

## The schemas

```zig
const Address = struct {
    city: []const u8,
    postal_code: []const u8,
};

const AddressSchema = z.object(Address, .{
    .city = z.string(.{ .min = 1, .max = 80 }),
    .postal_code = z.string(.{ .len = 5, .charset = .numeric }),
}, .{});

const User = struct {
    name: []const u8,
    address: Address,
};

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1, .trim = true }),
    .address = AddressSchema,
}, .{});
```

The compiler checks that `AddressSchema.Value` is exactly `Address`, so a
mismatch is a build error rather than a runtime surprise.

## The program

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const document =
        \\{"name":"Ada","address":{"city":"London","postal_code":"12345"}}
    ;

    var result = try z.parse(UserSchema, allocator, document, .{});
    defer result.deinit();
    if (result.value) |user| {
        std.debug.print("{s} lives in {s} ({s})\n", .{ user.name, user.address.city, user.address.postal_code });
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var broken = try z.parse(UserSchema, allocator,
        \\{"name":"Ada","address":{"city":"London","postal_code":"AB12"}}
    , .{});
    defer broken.deinit();
    if (!broken.ok()) {
        std.debug.print("nested path: {s}\n", .{broken.errors().first().?.path});
    }
}
```

## Output

```text
Ada lives in London (12345)
nested path: $.address.postal_code
```

## What to notice

- Paths use a JSONPath-like syntax: `$` is the document root, `.field` selects
  an object member and `[n]` selects an array element.
- The nested failure is reported against `$.address.postal_code`, not against
  the parent object, so a UI can highlight the exact input that failed.
- `errors().first()` returns `?Issue`; the path, code, expected and received
  strings live in the result arena and are valid until `deinit`.
- Validation stops descending when nesting exceeds `Options.max_depth` (128 by
  default) and reports `E021` with the expected value `shallower nesting`.
  Recursive schemas use the same counter, so a cyclic document fails instead of
  overflowing the stack.
