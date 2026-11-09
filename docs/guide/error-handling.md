---
title: Error Handling
description: Understand zigantic issues, stable error codes, text and JSON rendering, message overrides, lifecycle hooks and error sets.
keywords: zigantic errors, validation error codes, structured errors, json error output, tint colour, hooks
---

# Error Handling

A schema violation is an **issue**, not a Zig error. `parse` returns a result
that holds every issue found, so a client can report all bad fields at once.

```zig
pub const Issue = struct {
    code: z.Code,
    path: []const u8,
    message: []const u8,
    expected: ?[]const u8,
    received: ?[]const u8,
};
```

`code` is stable and machine-readable, `path` locates the value in the input,
`message` is human-readable, and `expected`/`received` add context when it is
useful.

## Codes

| Code | Name | Category |
| --- | --- | --- |
| `E001` | `type_mismatch` | type_mismatch |
| `E002` | `too_small` | length |
| `E003` | `too_large` | length |
| `E004` | `length_mismatch` | length |
| `E005` | `invalid_value` | structure |
| `E006` | `invalid_format` | format |
| `E007` | `missing_field` | structure |
| `E008` | `unknown_field` | structure |
| `E009` | `duplicate_field` | structure |
| `E010` | `not_in_enum` | structure |
| `E011` | `invalid_literal` | structure |
| `E012` | `refinement_failed` | refinement |
| `E013` | `transform_failed` | coercion |
| `E014` | `coercion_failed` | coercion |
| `E015` | `union_mismatch` | structure |
| `E016` | `out_of_range` | length |
| `E017` | `not_finite` | range |
| `E018` | `not_integer` | type_mismatch |
| `E019` | `missing_discriminator` | structure |
| `E020` | `invalid_discriminator` | structure |
| `E021` | `unsupported` | unsupported |

`z.Code` exposes `label()`, `category()` and `message()`. Default messages and
the full table are also in the [API reference](/api/reference#error-codes).

## Allocation-free first errors

`z.checkFirst(S, value, buffer, .{})` checks an already-typed value and returns
`?Issue` using caller-provided scratch memory. It allocates nothing from the
heap when the buffer is large enough; check machinery (paths, quoted values)
also writes into the buffer, so even a valid value needs a realistically sized
buffer — a too-small buffer returns `error.OutOfMemory`. The returned issue
points into `buffer`, so it remains valid only while that buffer lives. Use
`z.validate` when you need owning, multiple or rendered issues.

```zig
var scratch: [4096]u8 = undefined;
if (try z.checkFirst(UserSchema, user, &scratch, .{})) |issue| {
    std.debug.print("{s} at {s}\n", .{ issue.code.label(), issue.path });
}
```

## Rendering

```zig
const text = try result.errors().render(allocator, .{ .capability = .ansi16 });
defer allocator.free(text);
```

```text
error[E002]: value is too small
  $.age
    expected: 18..120
    received: 12
```

`RenderOptions`:

| Field | Default | Meaning |
| --- | --- | --- |
| `capability` | `.none` | `.none`, `.ansi16`, `.ansi256`, `.trueColor` |
| `show_expected` | `true` | print the expected line |
| `show_received` | `true` | print the received line |
| `indent` | `2` | spaces before details |

Colours come from tint.zig and are selected per call. `.none` writes no escape
sequences, which keeps logs and redirected output clean. The library never
detects a terminal or reads the environment.

`toJson` returns a compact array with the same fields:

```json
[{"code":"E002","path":"$.age","message":"value is too small","expected":"18..120","received":"12"}]
```

Use `write`/`writeJson` to stream into an existing writer without an
intermediate allocation.

## Message overrides

Override text per call; nothing is global:

```zig
var result = try z.parse(Age, allocator, "12", .{
    .messages = .{ .too_small = "must be old enough" },
});
```

`z.Messages` has one optional field per code, named after the code. A `null`
field keeps the default message. The code and path are unchanged, so clients can
translate the category while the server customises wording.

## Paths

- `$` is the document root.
- `.field` selects an object member.
- `[0]` selects an array element.
- Paths use the output key, so a naming policy is applied.
- Duplicate-key failures point at the repeated key, for example `$.address.city`.

## Lifecycle hooks

```zig
var result = try z.parse(UserSchema, allocator, input, .{
    .hooks = .{
        .on_start = logStart,
        .on_field = logField,
        .on_issue = logIssue,
        .on_finish = logFinish,
    },
});
```

| Hook | Called |
| --- | --- |
| `on_start(schema_name)` | before decoding starts |
| `on_field(path, accepted)` | for each object field |
| `on_issue(issue)` | whenever an issue is recorded |
| `on_finish(ok, total_issues)` | after decoding, including failures |

Hooks are plain function pointers supplied per call, so there is no global
logger and no hidden state. They run on the calling thread.

## Error sets

`decode` returns `error.Reported` after recording an issue, or
`error.OutOfMemory`. `parse` converts JSON syntax failures and duplicate keys
under `.reject` into a result; malformed JSON surfaces as `error.InvalidJson`.
`z.validate` returns the issue list instead of an error, so a typed check has no
error branch beyond allocation failure.

`stringify` can return `error.Unsupported` when a schema has no encoder, such as
a transform without `.encode` or a custom value. A transform whose `.encode`
callback fails returns `error.TransformFailed`. `float` returns
`error.Unsupported` for non-finite numbers.
