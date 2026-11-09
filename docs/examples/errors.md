---
title: Structured Errors
description: Render zigantic validation failures as annotated text and JSON, and check typed values with z.validate.
keywords: zigantic errors, validation error json, error codes, zig validate, structured diagnostics
---

# Structured Errors

A failed parse holds an issue list. Each issue has a stable code, a JSON path,
a message and optional expected/received text. The same list renders as
annotated text or as JSON.

## The schema

```zig
const Order = struct {
    id: []const u8,
    quantity: u16,
    email: []const u8,
};

const OrderSchema = z.object(Order, .{
    .id = z.uuid(.{}),
    .quantity = z.integer(u16, .{ .min = 1, .max = 100 }),
    .email = z.email(.{}),
}, .{});
```

## The program

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const document =
        \\{"id":"not-a-uuid","quantity":0,"email":"missing-at-sign"}
    ;

    var result = try z.parse(OrderSchema, allocator, document, .{});
    defer result.deinit();

    const text = try result.errors().render(allocator, .{});
    defer allocator.free(text);
    std.debug.print("{s}", .{text});

    const json_text = try result.errors().toJson(allocator);
    defer allocator.free(json_text);
    std.debug.print("{s}\n", .{json_text});

    const Age = z.integer(u8, .{ .min = 18 });
    var accepted = try z.validate(Age, allocator, 30, .{});
    defer accepted.deinit();
    var rejected = try z.validate(Age, allocator, 12, .{});
    defer rejected.deinit();
    std.debug.print("typed check: {any} then {any}, {d} issue(s)\n", .{ accepted.isEmpty(), rejected.isEmpty(), rejected.count() });
}
```

## Output

```text
error[E006]: invalid format
  $.id
    expected: UUID
    received: "not-a-uuid"

error[E002]: value is too small
  $.quantity
    expected: 1..100
    received: 0

error[E006]: invalid format
  $.email
    expected: email address
    received: "missing-at-sign"
[{"code":"E006","path":"$.id","message":"invalid format","expected":"UUID","received":"\"not-a-uuid\""},{"code":"E002","path":"$.quantity","message":"value is too small","expected":"1..100","received":"0"},{"code":"E006","path":"$.email","message":"invalid format","expected":"email address","received":"\"missing-at-sign\""}]
typed check: true then false, 1 issue(s)
```

## What to notice

- Parsing collects every failing field instead of stopping at the first one.
  That is why all three issues appear in one result.
- `render` separates issues with a blank line and indents the path and details
  according to `RenderOptions`. `.capability = .none` is the default, so the
  output above contains no escape sequences.
- Codes are stable identifiers. `E002` always means "too small", regardless of
  the message text, so clients can translate messages without parsing prose.
- `received` for a string is quoted, which makes an empty string visible and
  distinguishes it from a missing value.
- `toJson` writes a compact array with the same fields. It is suitable for an
  API response, an editor diagnostic or a test assertion.
- `z.validate` checks a value that is already typed. It returns `IssueList`
  directly; `isEmpty`, `count`, `first` and `render` work the same way as on a
  parse result.
