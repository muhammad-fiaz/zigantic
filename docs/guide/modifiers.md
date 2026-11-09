---
title: Modifiers
description: Reference for optional, nullable, default, fallback, refine, transform, lazy and custom schemas in zigantic.
keywords: zigantic optional, zigantic nullable, default value, fallback, refine, transform, lazy schema, custom validator
---

# Modifiers

Modifiers wrap an existing schema. They are constructor functions, so they
compose in any order and can be nested inside objects and arrays.

```zig
const MaybeName = z.optional(z.string(.{ .min = 1 }));
const NullableName = z.nullable(z.string(.{ .min = 1 }));
const Retries = z.withDefault(z.integer(u8, .{ .max = 10 }), 3);
const Port = z.fallback(z.integer(u16, .{ .max = 1024 }), 8080);
const Even = z.refine(z.integer(u32, .{}), .{ .check = isEven, .message = "must be even" });
```

## Optional and nullable

| Constructor | Value | Accepts absent key | Accepts JSON `null` |
| --- | --- | --- | --- |
| `z.optional(S)` | `?S.Value` | yes | no, unless `S` accepts it |
| `z.nullable(S)` | `?S.Value` | only when the model field is optional | yes |
| `z.optional(z.nullable(S))` | `?S.Value` | yes | yes |

They model different situations. An absent key means "the client did not send
this field"; a `null` value means "the client explicitly cleared it". Keeping
them separate lets a `PATCH` endpoint distinguish the two.

`z.optional` rejects an explicit `null` as `E001: invalid type`, because the
field is present with the wrong value. Use `z.nullable` alone when `null` must
be accepted but the key must still be present, and combine both when the key is
optional and `null` is meaningful.

## Defaults

`z.withDefault(S, value)` substitutes a compile-time value when the key is
missing. The value must be valid for `S.Value`.

```zig
const Page = z.withDefault(z.integer(u16, .{ .min = 1 }), 1);
```

`z.withDefaultFactory(S, factory)` calls `factory()` for every missing field.
Use it when the default must be a fresh allocation or a value that is cheap to
construct but not suitable as a shared constant.

```zig
fn emptyTags() []const []const u8 {
    return &.{};
}

const Tags = z.withDefaultFactory(z.array(z.string(.{}), .{}), emptyTags);
```

Defaults never run during `z.validate` or `encode`; the value is already typed.

## Fallbacks

`z.fallback(S, value)` tries the inner schema, discards any issues it recorded,
and returns `value` when decoding fails. It is useful for tolerant readers of
third-party data.

```zig
const LegacyFlag = z.fallback(z.boolean(.{}), false);
```

A fallback hides real problems, so prefer a default for missing data and a
fallback only when invalid data is expected and safe to ignore.

## Refinements

`z.refine(S, .{ .check = predicate, .message = "..." })` runs a predicate after
the inner schema succeeds. The predicate takes `S.Value` and returns `bool`.

```zig
fn isEven(value: u32) bool {
    return value % 2 == 0;
}

const Even = z.refine(z.integer(u32, .{}), .{
    .check = isEven,
    .message = "must be even",
});
```

A failure is `E012` with the configured message. Refinements compose, and the
outermost failing refinement owns the message. Refinements run for `decode`,
`check` and query decoding; they do not run during `encode`.

## Transformations

`z.transform(S, .{ .decode = ..., .encode = ..., .check = ... })` converts a
validated value. `.decode` is required and takes
`(std.mem.Allocator, S.Value) error!Output`.

```zig
const Timestamp = z.transform(z.string(.{}), struct {
    fn decode(arena: std.mem.Allocator, text: []const u8) !i64 {
        _ = arena;
        return std.fmt.parseInt(i64, text, 10);
    }
}.decode);
```

The allocator is the result arena, so a transform may allocate and return
slices that live as long as the result. A returned error becomes `E013`.

Supply `.encode` to make the mapping reversible and `.check` to validate an
already-typed output. `.encode` takes `(Allocator, Output) error!S.Value` and is
used by `z.stringify`; `.check` takes `Output` and returns `bool`.

```zig
const Flag = z.transform(z.string(.{}), .{
    .decode = struct {
        fn decode(arena: std.mem.Allocator, text: []const u8) !bool {
            _ = arena;
            return std.mem.eql(u8, text, "yes");
        }
    }.decode,
    .encode = struct {
        fn encode(arena: std.mem.Allocator, value: bool) ![]const u8 {
            _ = arena;
            return if (value) "yes" else "no";
        }
    }.encode,
});
```

Without `.encode`, `encode` reports `error.Unsupported`. Without either
`.encode` or `.check`, `check` also reports `error.Unsupported` rather than
silently accepting a value it cannot verify.

## Lazy schemas

`z.lazy(get)` breaks recursive type cycles. `get` is a function returning a
schema type, and the resulting value is `*const Inner.Value`.

```zig
const Node = struct {
    value: i32,
    children: []const *const Node,
};

fn NodeSchema() type {
    return z.object(Node, .{
        .value = z.integer(i32, .{}),
        .children = z.array(z.lazy(NodeSchema), .{}),
    }, .{});
}
```

Each node is allocated in the result arena. `Options.max_depth` bounds
recursion and reports `E021` instead of overflowing the stack.

Recursive schemas have a real JSON Schema representation: the generator emits
deduplicated `$defs` entries and `#/$defs/...` references instead of an
unconstrained placeholder.

## Custom typed schemas

`z.custom(T, .{ .check = predicate, .message = "..." })` validates values that
have no JSON representation of their own, such as handles or opaque ids.

```zig
const Handle = z.custom(HandleType, .{
    .check = HandleType.isValid,
    .message = "invalid handle",
});
```

Custom schemas support `check`; a failing predicate is `E012` with the
configured message. `decode` reports `E021` and `encode` returns
`error.Unsupported`. Use them for typed validation, or wrap a string schema
with `refine` when the value must also cross the JSON boundary.

## Composition rules

- Modifiers preserve `Value` except `optional`/`nullable` (add `?`) and
  `transform` (uses the callback's payload type).
- `optional`, `nullable`, `default`, `fallback` and `refine` forward
  `encode`. `transform`, `lazy` and `custom` have their own rules described
  above.
- Any schema may be used as a field schema, including another object or union.
