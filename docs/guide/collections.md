---
title: Collections
description: Array and record schemas in zigantic, with every size, uniqueness and key option documented.
keywords: zigantic array schema, record schema, unique array, string keyed map, min max len
---

# Collections

`z.array` covers ordered lists, `z.record` covers string-keyed maps and
`z.tuple` covers fixed heterogeneous arrays. This page documents the first two;
see [Inferred Objects, Tuples & Intersections](/guide/inference) for tuples.

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
decoded with `S`.

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `min` | `usize` | `0` | minimum number of entries |
| `max` | `usize` | `maxInt(usize)` | maximum number of entries |
| `key_min` | `usize` | `1` | minimum key length in bytes |
| `key_max` | `usize` | `256` | maximum key length in bytes |
| `description` | `[]const u8` | `""` | JSON Schema description |

`min`/`max` map to `minProperties`/`maxProperties` in generated JSON Schema.
Key length failures are `E004`; entry count failures are `E002`/`E003`.

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
