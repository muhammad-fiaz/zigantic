---
title: Unions
description: Decode tagged and untagged Zig unions from JSON with unionOf and discriminatedUnion in zigantic.
keywords: zigantic union, discriminated union, json oneOf, tagged union, zig union validation
---

# Unions

Zig unions keep the active variant in the type. Both union schemas return that
union unchanged, so callers use a normal `switch` and the compiler enforces
exhaustiveness.

## Untagged unions

`z.unionOf(U, variants, .{})` tries each variant schema in declaration order
against the same JSON value and returns the first success.

```zig
const Payload = union(enum) {
    text: []const u8,
    count: i64,
};

const PayloadSchema = z.unionOf(Payload, .{
    .text = z.string(.{ .min = 1 }),
    .count = z.integer(i64, .{}),
}, .{});
```

- Every field of `U` must have a variant schema, and every variant schema must
  produce the field's payload type. Both are checked at compile time.
- Issues recorded by failing variants are rolled back, so a successful decode
  leaves no diagnostics behind.
- When no variant matches, one `E015` is recorded with the list of variant names
  as the expected value.

Use untagged unions when variants have distinguishable JSON shapes. If two
variants accept the same shape, declaration order decides the winner; a
discriminator is clearer.

## Discriminated unions

`z.discriminatedUnion(U, field, variants, .{})` reads a string field, selects
the matching variant, then validates the entire document against that variant's
schema.

```zig
const Created = struct { type: []const u8, id: u64 };
const Deleted = struct { type: []const u8, id: u64 };

const Event = union(enum) {
    created: Created,
    deleted: Deleted,
};

const EventSchema = z.discriminatedUnion(Event, "type", .{
    .created = z.object(Created, .{
        .type = z.literal("created"),
        .id = z.integer(u64, .{}),
    }, .{}),
    .deleted = z.object(Deleted, .{
        .type = z.literal("deleted"),
        .id = z.integer(u64, .{}),
    }, .{}),
}, .{});
```

- `field` names the discriminator key. It is matched before any variant runs.
- The discriminator stays in the document, so each variant declares it. A
  `z.literal` keeps a document from being accepted by the wrong variant.
- A missing discriminator is `E019` at the discriminator path.
- A non-string or unknown discriminator is `E020`, with the allowed names as the
  expected value.
- Variant names must match the union field names exactly.

## Checking and encoding

Both union schemas implement `check` and `encode` by dispatching on the active
tag:

```zig
var issues = try z.validate(EventSchema, allocator, event, .{});
defer issues.deinit();

const text = try z.stringify(EventSchema, allocator, event, .{});
defer allocator.free(text);
```

`check` runs the variant schema for the active payload, and `encode` writes that
payload. JSON Schema output uses `oneOf` for both constructors.

## Choosing a representation

| Need | Use |
| --- | --- |
| Variants with clearly different JSON types | `unionOf` |
| Variants that are all objects | `discriminatedUnion` |
| A stable client-facing tag | `discriminatedUnion` with `z.literal` |
| Minimal schema work | `unionOf` |

Discriminated unions produce better errors and do not depend on declaration
order, so prefer them for API payloads.
