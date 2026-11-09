---
title: Basic Validation
description: Validate an email, a bounded integer and a fixed-length numeric code with zigantic, then render the failures as plain text or with ANSI colours.
keywords: zigantic basic example, zig email validation, zig integer validation, ansi colour errors
---

# Basic Validation

This example is the smallest complete zigantic program. It parses three
independent values, prints the accepted one and renders the two failures.

## The program

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const Email = z.email(.{});
    var good = try z.parse(Email, allocator, "\"ada@example.com\"", .{});
    defer good.deinit();
    std.debug.print("email: {s}\n", .{good.value.?});

    const Age = z.integer(u8, .{ .min = 18, .max = 120 });
    var bad = try z.parse(Age, allocator, "12", .{});
    defer bad.deinit();
    if (!bad.ok()) {
        const text = try bad.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    const Code = z.string(.{ .len = 4, .charset = .numeric });
    var result = try z.parse(Code, allocator, "\"12a4\"", .{});
    defer result.deinit();
    if (!result.ok()) {
        const text = try result.errors().render(allocator, .{ .capability = .ansi16 });
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }
}
```

## Output

```text
email: ada@example.com
error[E002]: value is too small
  $
    expected: 18..120
    received: 12
error[E005]: invalid value
  $
    expected: numeric text
    received: "12a4"
```

With `.ansi16` the error code, path and expected/received labels are wrapped in
ANSI escapes. The documentation shows them without escapes because colour is
resolved per call and never enabled implicitly.

## What to notice

- `z.email(.{})` is a schema **type**, not a value. Its validated form is
  `[]const u8`, available as `Email.Value`.
- `z.parse` returns a `ParseResult`, not the value directly. `result.value` is
  an optional and is `null` when validation failed.
- Invalid input is not an error return. `parse` only returns `error.InvalidJson`
  for malformed JSON and `error.OutOfMemory` for allocation failure; schema
  violations are issues stored in the result.
- `render(allocator, .{})` allocates the text; the caller frees it. Passing
  `.capability = .ansi16` is the only way to get colour, so redirecting output
  to a file stays plain by default.
- `.len = 4` means exactly four characters, and `.charset = .numeric` rejects
  anything outside `0-9`. Both constraints share one issue path, `$`.
