---
title: Modifiers
description: Use defaults, optional fields, nullable fields, refinements and typed validation together in zigantic, including error messages and z.validate.
keywords: zigantic modifiers, optional vs nullable, default value, refine, typed validation, zig validation
---

# Modifiers

Modifiers wrap a schema without changing its value type. They are ordinary
constructors, so they compose with objects, arrays and each other.

## The schema

```zig
const Settings = struct {
    retries: u8,
    label: ?[]const u8,
    timeout: u16,
    ratio: ?f64,
};

const evenTimeout = struct {
    fn check(value: u16) bool {
        return value % 2 == 0;
    }
}.check;

const SettingsSchema = z.object(Settings, .{
    .retries = z.withDefault(z.integer(u8, .{ .max = 10 }), 3),
    .label = z.optional(z.string(.{ .min = 1 })),
    .timeout = z.refine(z.integer(u16, .{ .min = 100 }), .{
        .check = evenTimeout,
        .message = "timeout must be an even number of milliseconds",
    }),
    .ratio = z.nullable(z.probability(f64, .{})),
}, .{});
```

`optional` accepts an absent field, `nullable` accepts an explicit JSON `null`.
The first changes whether the object requires the key; the second changes
whether `null` is a valid value. A field may need both, and then the schema is
`z.optional(z.nullable(S))`.

## The program

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var result = try z.parse(SettingsSchema, allocator,
        \\{"timeout":200,"ratio":null}
    , .{});
    defer result.deinit();
    if (result.value) |settings| {
        std.debug.print("retries={d} label={any} timeout={d} ratio={any}\n", .{
            settings.retries, settings.label, settings.timeout, settings.ratio,
        });
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var invalid = try z.parse(SettingsSchema, allocator,
        \\{"timeout":101}
    , .{});
    defer invalid.deinit();
    if (!invalid.ok()) {
        std.debug.print("refinement: {s}\n", .{invalid.errors().first().?.message});
    }

    var issues = try z.validate(SettingsSchema, allocator, .{
        .retries = 5,
        .label = "prod",
        .timeout = 200,
        .ratio = 0.5,
    }, .{});
    defer issues.deinit();
    std.debug.print("typed check: {any}\n", .{issues.isEmpty()});
}
```

## Output

```text
retries=3 label=null timeout=200 ratio=null
refinement: timeout must be an even number of milliseconds
typed check: true
```

## What to notice

- `retries` is missing from the document and receives `3` from `withDefault`.
  The value is produced without allocating, so defaults must be compile-time
  values; use `withDefaultFactory` when a fresh array or map is needed.
- `label` is missing and becomes `null` because the schema is optional. It is
  not the same as a document that contains `"label": null`; that document fails
  unless the schema is nullable as well.
- `ratio` is present and `null`, which the nullable schema accepts.
- `refine` runs after the inner integer succeeds. The custom message replaces
  the code's default text but keeps `E012` and the path, so clients can branch on
  the code and still show a domain-specific message.
- `z.validate` runs the same schema against an already-typed value. It returns
  an owning issue list, not a parse result, and has no `init`/`deinit` session.
- `z.probability(f64, .{})` is shorthand for a float bounded to `0..1`; like
  every constructor it takes its options as a trailing `.{}`.
