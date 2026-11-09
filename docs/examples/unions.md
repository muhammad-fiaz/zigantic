---
title: Unions
description: Decode JSON into tagged Zig unions with unionOf and select variants by discriminator with discriminatedUnion in zigantic.
keywords: zigantic union, discriminated union, tagged union json, zig exhaustive switch
---

# Unions

Zig unions carry their active field in the type, so a decoded union keeps
exhaustive `switch` handling. `unionOf` tries each variant against the raw
document shape; `discriminatedUnion` selects a variant from a string field and
then validates the whole object against that variant's schema.

## The schemas

```zig
const Payload = union(enum) {
    text: []const u8,
    count: i64,
};

const PayloadSchema = z.unionOf(Payload, .{
    .text = z.string(.{ .min = 1 }),
    .count = z.integer(i64, .{}),
}, .{});

const Created = struct {
    type: []const u8,
    id: u64,
};

const Deleted = struct {
    type: []const u8,
    id: u64,
};

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

The variant map must name every union field, and each schema's `Value` must
match the corresponding payload type. Both conditions are compile-time checks.

## The program

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var payload = try z.parse(PayloadSchema, allocator, "\"hello\"", .{});
    defer payload.deinit();
    switch (payload.value.?) {
        .text => |text| std.debug.print("text payload: {s}\n", .{text}),
        .count => |count| std.debug.print("count payload: {d}\n", .{count}),
    }

    var event = try z.parse(EventSchema, allocator,
        \\{"type":"deleted","id":42}
    , .{});
    defer event.deinit();
    switch (event.value.?) {
        .created => |created| std.debug.print("created {d}\n", .{created.id}),
        .deleted => |deleted| std.debug.print("deleted {d}\n", .{deleted.id}),
    }
}
```

## Output

```text
text payload: hello
deleted 42
```

## What to notice

- `unionOf` tries variants in declaration order and records a single
  `E015: value does not match any union variant` when all of them fail. Use it
  when variants have distinct JSON shapes.
- `discriminatedUnion` reads the discriminator as a string before validating
  anything else. A missing discriminator is `E019`; a non-string or unknown one
  is `E020`.
- The discriminator is not removed from the document, so each variant schema
  declares it. A `z.literal` schema rejects a mismatched tag, which prevents an
  event from being decoded as the wrong variant.
- `Payload` is untagged; `Event` is tagged because the Zig type includes the
  active field. Both produce a value that supports exhaustive `switch`.
- Encoding a union writes the active variant's payload; JSON Schema output for
  a discriminated union describes each variant under `oneOf`.
