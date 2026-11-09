---
title: Collections
description: Array and record schemas in zigantic, with every size, uniqueness and key option documented.
keywords: zigantic array schema, record schema, unique array, string keyed map, min max len
---

# Collections

`z.array` covers ordered lists, `z.record` covers string-keyed maps,
`z.fixedArray` fixes the element count in the type, `z.set` stores ordered
unique values, and `z.tuple` covers fixed heterogeneous arrays. This page
documents the first four; see
[Inferred Objects, Tuples & Intersections](/guide/inference) for tuples.

## Arrays

```zig
const Tags = z.array(z.string(.{ .min = 1 }), .{
    .min = 1,
    .max = 8,
    .unique = true,
    .description = "content tags",
});
```

`z.array(S, .{})` produces `[]const S.Value`.

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `min` | `usize` | `0` | minimum number of items |
| `max` | `usize` | `maxInt(usize)` | maximum number of items |
| `len` | `?usize` | `null` | exact number of items; overrides `min`/`max` when set |
| `unique` | `bool` | `false` | reject duplicate decoded values |
| `description` | `[]const u8` | `""` | JSON Schema description |

Failures use `E002` (too few), `E003` (too many), `E004` (exact length) and
`E009` (duplicate) with the index in the path, for example `$.tags[2]`.

Uniqueness compares decoded values, so `1`, `1.0` and `"1"` are distinct if the
item schema produces different types, while two identical strings collide.
Comparison is `schema.valuesEqual`: strings by content, other values with
`std.meta.eql` (IEEE `==` for floats). Two consequences follow: `-0.0` and
`+0.0` collide (they compare equal), while two `NaN`s never collide (`NaN !=
NaN`). Nested arrays and structs compare element-wise with the same rules.

The fixed-array container itself is stack-inline, so it adds no allocation for
the container — but decoding elements that own memory (strings, maps, nested
slices) still allocates in the result arena like any other collection.

## Fixed arrays and sets

`z.fixedArray(S, N, .{})` produces `[N]S.Value` and always rejects a document
whose array length is not exactly `N`. `z.set(S, .{})` produces `[]const
S.Value`, preserves input order and rejects duplicates. `z.set` accepts the
same `z.ArrayConfig` options as `z.array` (and always sets `unique = true`).
`z.fixedArray` accepts only `z.FixedConfig` (a single `description` field);
its length comes from the `N` parameter, not from a `len`/`min`/`max` option.

```zig
const Point = z.fixedArray(z.float(f64, .{}), 3, .{});
const Tags = z.set(z.string(.{ .min = 1 }), .{ .max = 8 });
```

## Records

```zig
const Scores = z.record(z.integer(u16, .{ .max = 1000 }), .{
    .min = 1,
    .max = 100,
    .key_min = 1,
    .key_max = 32,
});
```

`z.record(S, .{})` produces `std.array_hash_map.String(S.Value)`, which
preserves insertion order. Keys are copied into the result arena; values are
decoded with `S`. The map, its keys and its values are all owned by the
`ParseResult` arena: do not call `map.deinit(allocator)` on a decoded record;
`result.deinit()` releases everything once.

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `min` | `usize` | `0` | minimum number of entries |
| `max` | `usize` | `maxInt(usize)` | maximum number of entries |
| `key_min` | `usize` | `1` | minimum key length in bytes |
| `key_max` | `usize` | `256` | maximum key length in bytes |
| `description` | `[]const u8` | `""` | JSON Schema description |

`min`/`max` map to `minProperties`/`maxProperties` in generated JSON Schema,
and key length limits map to `propertyNames`. Key length failures are `E004`;
entry count failures are `E002`/`E003`.

## Encoding

```zig
const text = try z.stringify(InventorySchema, allocator, inventory, .{});
defer allocator.free(text);
```

Arrays encode in order. Records encode in map iteration order, which for the
array hash map is insertion order. Both handle nested objects and unions
through the same schema protocol.

## Empty collections

A missing key is not an empty collection. Use `z.withDefault` to supply an
empty value when the document may omit the field:

```zig
const Tags = z.withDefault(z.array(z.string(.{}), .{}), &.{});
```

A present but empty JSON array is valid for any `min = 0` schema; a present but
empty object is valid for any `min = 0` record.
