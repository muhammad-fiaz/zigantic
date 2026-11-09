---
title: Schemas
description: How zigantic schemas work as Zig types, from primitives and objects to collections, unions and modifiers.
keywords: zigantic schemas, zig schema types, object schema, array schema, union schema, schema composition
---

# Schemas

Every constructor returns a type. Use it directly as a field schema, or refer to
`S.Value` for the validated Zig type.

## Primitives

```zig
const Name = z.string(.{ .min = 1, .max = 64, .trim = true, .case = .lower });
const Age = z.integer(u8, .{ .min = 18, .max = 120, .even = true });
const Score = z.float(f64, .{ .min = 0, .max = 1, .finite = true });
const Active = z.boolean(.{});
const Role = z.enumType(enum { user, admin }, .{});
const Kind = z.literal("user");
const Nothing = z.nullValue(.{});
```

## Objects

```zig
const UserSchema = z.object(User, .{
    .name = z.string(.{}),
    .email = z.email(.{}),
}, .{
    .naming = .snake_case,
    .unknown_fields = .reject,
    .aliases = &.{.{ .field = "name", .keys = &.{"full_name"} }},
    .partial = false,
});
```

`unknown_fields` may be `.reject` (default) or `.strip`. `.partial` allows any
field to be missing; omitted fields keep their model default or the model's zero
value.

When a separate Zig model is unnecessary, `z.objectOf` infers the struct with
Zig 0.17's `@Struct` builtin. The inferred type is available as `S.Value`.

```zig
const Profile = z.objectOf(.{
    .name = z.string(.{ .min = 1 }),
    .age = z.optional(z.integer(u8, .{ .min = 18 })),
}, .{});
```

`z.object` still verifies field types and reports a build error when a schema
does not produce the declared model field. `z.objectOf` derives every field
type, default and optionality from the schemas themselves.

## Tuples and intersections

```zig
const Point = z.tuple(.{
    .x = z.float(f64, .{}),
    .y = z.float(f64, .{}),
}, .{});

const Range = z.intersection(.{
    .bounded = z.integer(u16, .{ .min = 10, .max = 100 }),
    .even = z.refine(z.integer(u16, .{}), .{ .check = isEven, .message = "must be even" }),
}, .{});
```

`z.tuple` synthesizes a real Zig tuple with `@Tuple`; each position keeps its
own schema type. `z.intersection` requires every member to produce the same
`Value`, decodes once and checks the result against every member.
See [Inferred Objects, Tuples & Intersections](/guide/inference) for their
compile-time rules, query encoding and JSON Schema output.

## Collections

```zig
const Tags = z.array(z.string(.{ .min = 1 }), .{ .max = 8, .unique = true });
const Scores = z.record(z.integer(u16, .{}), .{ .max = 100 });
```

`array` produces `[]const T`; `record` produces
`std.array_hash_map.String(T)`. See [Collections](/guide/collections) for
all size, uniqueness and key options.

## Unions

```zig
const Payload = union(enum) { text: []const u8, count: i64 };
const PayloadSchema = z.unionOf(Payload, .{
    .text = z.string(.{}),
    .count = z.integer(i64, .{}),
}, .{});

const Event = union(enum) { created: Created, deleted: Deleted };
const EventSchema = z.discriminatedUnion(Event, "type", .{
    .created = z.object(Created, .{ .type = z.literal("created"), .id = z.integer(u64, .{}) }, .{}),
    .deleted = z.object(Deleted, .{ .type = z.literal("deleted"), .id = z.integer(u64, .{}) }, .{}),
}, .{});
```

The union type is declared by the user, so the decoded value keeps its Zig
representation and exhaustive `switch` handling. See [Unions](/guide/unions)
for discriminator errors and encoding rules.

## Modifiers

```zig
const Maybe = z.optional(z.string(.{}));          // ?[]const u8, absence allowed
const Nullable = z.nullable(z.string(.{}));       // ?[]const u8, explicit null
const Retries = z.withDefault(z.integer(u8, .{}), 3);
const Created = z.withDefaultFactory(z.string(.{}), makeId);
const Port = z.fallback(z.integer(u16, .{ .max = 1024 }), 8080);
const Even = z.refine(z.integer(u32, .{}), .{ .check = isEven, .message = "must be even" });
const Parsed = z.transform(z.string(.{}), .{ .decode = parseUuid });
const Tree = z.lazy(NodeSchema);
```

`optional` accepts a missing field and rejects an explicit `null`; `nullable`
accepts JSON `null`. They are not interchangeable. A `transform` is reversible
only when it supplies `.encode`; without one, `encode` returns
`error.Unsupported`. See [Modifiers](/guide/modifiers) for defaults, fallbacks
and recursive schemas.
