---
title: Custom Validators
description: Add cross-field refinements, transformations and typed custom checks to zigantic schemas, including recursive models.
keywords: zigantic custom validator, refine, transform, custom schema, cross-field validation, recursive schema
---

# Custom Validators

## Refinement

`refine` runs a predicate after the inner schema succeeds. The predicate receives
the typed value, which makes cross-field rules straightforward.

```zig
fn passwordsMatch(user: User) bool {
    return std.mem.eql(u8, user.password, user.confirmation);
}

const UserSchema = z.refine(z.object(User, .{
    .password = z.string(.{ .min = 8 }),
    .confirmation = z.string(.{ .min = 8 }),
}, .{}), .{
    .check = passwordsMatch,
    .message = "passwords do not match",
});
```

Refinements compose: `refine(refine(S, ...), ...)`.

## Transformation

`transform` converts a validated value. `.decode` receives the result arena and
may return an error union; a failure records an `E013` issue and the decode
returns `error.Reported`. Add `.encode` to make the conversion reversible.

```zig
const Timestamp = z.transform(z.string(.{}), .{
    .decode = struct {
        fn decode(arena: std.mem.Allocator, text: []const u8) !i64 {
            _ = arena;
            return std.fmt.parseInt(i64, text, 10);
        }
    }.decode,
    .encode = struct {
        fn encode(arena: std.mem.Allocator, value: i64) ![]const u8 {
            _ = arena;
            return std.fmt.allocPrint(arena, "{d}", .{value});
        }
    }.encode,
});
```

With `.encode`, `z.stringify` round-trips the transformed value. Without
`.encode`, `encode` reports `error.Unsupported`. Without either `.encode` or
`.check`, `check` also reports `error.Unsupported`, because the value cannot be
verified without an inverse.

```zig
const TextOnly = z.transform(z.string(.{}), .{
    .decode = struct {
        fn decode(arena: std.mem.Allocator, text: []const u8) !i64 {
            _ = arena;
            return std.fmt.parseInt(i64, text, 10);
        }
    }.decode,
});
```

## Custom typed checks

```zig
const Handle = z.custom(HandleType, .{
    .check = HandleType.isValid,
    .message = "invalid handle",
});
```

Custom schemas validate typed values only. `check` runs the predicate and
reports `E012` with the configured message when it returns false. `decode`
reports `E021` and `encode` returns `error.Unsupported`. Use them for values
that never cross the JSON boundary, such as handles and opaque identifiers.

## Recursive schemas

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

`lazy` returns `*const Inner.Value`, which breaks the type cycle. Nesting depth
is bounded by `Options.max_depth` (128 by default); exceeding it reports `E021`
with `shallower nesting` instead of overflowing the stack.

See [Modifiers](/guide/modifiers) for the complete behaviour of `optional`,
`nullable`, defaults, fallbacks and transforms.
