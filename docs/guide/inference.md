---
title: Inferred Objects, Tuples & Intersections
description: Build Zig structs and tuples at compile time with z.objectOf and z.tuple, and combine compatible schemas with z.intersection.
keywords: zigantic objectOf, inferred struct, zig tuple schema, intersection schema, allOf, compile-time inference
---

# Inferred Objects, Tuples & Intersections

Three constructors derive their `Value` from the schemas themselves. No parallel
Zig model is required, and every field keeps static typing.

## Inferred objects

`z.objectOf(fields, .{})` builds a struct with Zig 0.17's `@Struct`. The result
is a real Zig type available as `S.Value`:

```zig
const Profile = z.objectOf(.{
    .name = z.string(.{ .min = 1, .max = 64 }),
    .age = z.optional(z.integer(u8, .{ .min = 18 })),
    .role = z.withDefault(z.enumType(enum { user, admin }, .{}), .user),
}, .{});

var result = try z.parse(Profile, allocator, document, .{});
defer result.deinit();
if (result.value) |profile| {
    std.debug.print("{s} ({d})\n", .{ profile.name, profile.age orelse 0 });
}
```

The configuration is `z.ObjectConfig`, the same one accepted by `z.object`:
naming, aliases, unknown-field policy, `partial` and description. A missing field
follows the normal rules: optional, schema default, inferred struct default, or
`E007`.

Inference has two extra compile-time rules:

- Naming policies must produce unique keys; a collision fails the build.
- A partial inferred object is rejected unless every field is optional or has a
  default, because an inferred value is never left uninitialized.

Use `z.object(Model, ...)` when the model already exists or when a type mismatch
should be reported against a named field. Use `z.objectOf` for small transport
payloads, generated shapes and tests.

### Composing field sets

`z.merge(A, B, .{})` (also `z.extend`) combines the `.fields` of two inferred
objects into a new inferred object. Duplicate field names are a compile error,
so an accidental override cannot silently change a schema. `z.pick(S, names,
.{})` selects fields and `z.omit(S, names, .{})` removes them; pick rejects an
unknown name, while omit ignores one.

```zig
const Name = z.objectOf(.{ .name = z.string(.{}) }, .{});
const Age = z.objectOf(.{ .age = z.integer(u8, .{}) }, .{});
const Both = z.merge(Name, Age, .{});
const OnlyName = z.pick(Both, &.{"name"}, .{});
const WithoutName = z.omit(Both, &.{"name"}, .{});
```

These helpers operate on inferred schemas, not declared models; a declared
model already has a fixed field set.

## Tuples

`z.tuple(.{...}, .{})` synthesizes `@Tuple` from named field schemas. Positions
keep their individual types, so a tuple can mix strings, numbers and nested
objects:

```zig
const Point = z.tuple(.{
    .x = z.float(f64, .{}),
    .y = z.float(f64, .{}),
    .label = z.optional(z.string(.{})),
}, .{});

var result = try z.parse(Point, allocator, "[1.5, -2, \"origin\"]", .{});
defer result.deinit();
const point = result.value.?;
std.debug.print("{d}, {d}\n", .{ point[0], point[1] });
```

A tuple expects a JSON array with exactly the declared number of items. Each
item error uses its index in the path (`$[1]`). Encoding writes the items in
order. JSON Schema uses `prefixItems`, `minItems` and `maxItems` on Draft
2020-12; earlier drafts use the tuple form of `items` (plus
`additionalItems: false`) with the same `minItems`/`maxItems`.

## Intersections

`z.intersection(.{...}, .{})` requires every member to produce the same `Value`.
It decodes with the first member and checks the decoded value against every
other member:

```zig
const Bounded = z.integer(u16, .{ .min = 10, .max = 100 });
const Even = z.refine(z.integer(u16, .{}), .{
    .check = struct {
        fn check(value: u16) bool {
            return value % 2 == 0;
        }
    }.check,
    .message = "must be even",
});

const Order = z.intersection(.{
    .bounded = Bounded,
    .even = Even,
}, .{});
```

`Order.Value` is `u16`. All members must agree at compile time; a mismatch is a
build error rather than a runtime branch. Decoding allocates only once, and
failure diagnostics from every member are reported. Encoding uses the first
member. JSON Schema output is `allOf` with each member schema.

## JSON Schema

All three constructors describe themselves:

| Constructor | JSON Schema |
| --- | --- |
| `z.objectOf` | `type: "object"` with `properties`, `required` and `additionalProperties` |
| `z.tuple` | `type: "array"` with `prefixItems` (Draft 2020-12) or the `items` array form (earlier drafts), plus `minItems`/`maxItems` |
| `z.intersection` | `allOf` containing every member |

`z.jsonSchema` wraps the root in `$defs` and links it with `$ref`, so these
schemas compose with recursive models without inventing placeholders.

## Query strings

Objects and tuples also participate in query serialization. An object field
uses `address[city]=London`; a tuple position uses `point[0]=1.5`. Decoding
accepts the same bracket notation and numeric segments. See
[JSON, Query & Forms](/guide/json-parsing).
