---
title: Collections
description: Validate arrays with size and uniqueness rules and records backed by std.array_hash_map.String in zigantic.
keywords: zigantic array, zig record validation, unique array, array_hash_map, collection schema
---

# Collections

`z.array` decodes a JSON array into `[]const T`, and `z.record` decodes a JSON
object into `std.array_hash_map.String(T)`. Both own their memory through
the result arena.

## The schema

```zig
const Inventory = struct {
    tags: []const []const u8,
    scores: std.array_hash_map.String(u16),
};

const InventorySchema = z.object(Inventory, .{
    .tags = z.array(z.string(.{ .min = 1 }), .{ .max = 8, .unique = true }),
    .scores = z.record(z.integer(u16, .{ .max = 1000 }), .{}),
}, .{});
```

Array options are `min`, `max`, `len`, `unique` and `description`. Record
options are `min`, `max`, `key_min`, `key_max` and `description`, where the
length limits count entries and the key limits bound each key's byte length.

## The program

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const document =
        \\{"tags":["math","logic"],"scores":{"ada":95,"grace":99}}
    ;

    var result = try z.parse(InventorySchema, allocator, document, .{});
    defer result.deinit();

    if (result.value) |inventory| {
        std.debug.print("{d} tags, {d} scores\n", .{ inventory.tags.len, inventory.scores.count() });
        var iterator = inventory.scores.iterator();
        while (iterator.next()) |entry| {
            std.debug.print("  {s}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var duplicate = try z.parse(InventorySchema, allocator,
        \\{"tags":["a","a"],"scores":{}}
    , .{});
    defer duplicate.deinit();
    std.debug.print("duplicate tags accepted: {any}\n", .{duplicate.ok()});

    const Point = z.fixedArray(z.float(f64, .{}), 2, .{});
    var point = try z.parse(Point, allocator, "[1.5,2.5]", .{});
    defer point.deinit();
    if (point.value) |coords| std.debug.print("point: {d},{d}\n", .{ coords[0], coords[1] });

    const Tags = z.set(z.string(.{ .min = 1 }), .{});
    var tags = try z.parse(Tags, allocator, "[\"fast\",\"safe\"]", .{});
    defer tags.deinit();
    std.debug.print("set accepted: {any}\n", .{tags.ok()});
}
```

## Output

```text
2 tags, 2 scores
  ada: 95
  grace: 99
duplicate tags accepted: false
point: 1.5,2.5
set accepted: true
```

## What to notice

- `z.array` keeps document order. `.unique = true` compares decoded values, so
  `"a"` and `"a"` collide even though they are separate JSON strings.
- `z.record` preserves insertion order because the target map is an
  `ArrayHashMap`, which makes output deterministic for the same input.
- The record's key constraints are checked before the value is decoded, so a
  key outside `key_min..key_max` reports `E004` at the record path with the
  offending key as the received value.
- A record is only produced from a JSON object. Arrays of `{"key": ..., "value":
  ...}` pairs are not accepted; use an array schema with an object item schema.
- All decoded slices and maps belong to the result arena. Do not free them
  individually; call `result.deinit()` once.
