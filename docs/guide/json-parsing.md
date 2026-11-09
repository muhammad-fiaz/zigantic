---
title: JSON, Query & Forms
description: Parse and serialize JSON, URL query strings and form bodies with zigantic, including coercion, defaults and ownership.
keywords: zigantic json parsing, query string parsing, form body, urlencoded, json stringify, allocator ownership
---

# JSON, Query and Forms

All services take the allocator and a trailing `.{}` options value.

## JSON

```zig
var result = try z.parse(UserSchema, allocator, input, .{});
defer result.deinit();

if (result.ok()) {
    const text = try z.stringify(UserSchema, allocator, result.value.?, .{});
    defer allocator.free(text);
}
```

`parse` validates JSON syntax first (`error.InvalidJson`), then runs the schema.
Schema failures are issues, not errors. Decoded strings, arrays, records and
lazy nodes belong to the result arena, which `deinit` releases. The input is not
referenced afterwards.

Options are the same for every entry point:

```zig
var result = try z.parse(UserSchema, allocator, input, .{
    .messages = .{ .missing_field = "field is required" },
    .unknown_fields = .strip,
    .duplicates = .reject,
    .max_depth = 64,
});
```

`.duplicates` decides what happens when a JSON object repeats a key: `.reject`
(the default) reports `E009` at the exact nested path, `.first` keeps the first
occurrence and `.last` keeps the last. The duplicate scan happens before
decoding, so `{"a":{"b":1,"b":2}}` reports `$.a.b`. `.coerce` additionally
accepts strings for numbers, booleans and null in JSON documents; query
transports always enable it.

## Query strings and forms

```zig
var query = try z.parseQuery(SearchSchema, allocator, "q=zig&page=2&tag=a&tag=b", .{});
defer query.deinit();

const encoded = try z.stringifyQuery(SearchSchema, allocator, query.value.?, .{});
defer allocator.free(encoded);
```

Query values are text, so the decoder enables coercion for numbers and booleans.
Repeated keys become arrays. `parseForm` uses the same encoding. Serialization
supports nested objects, records, tuples, arrays, intersections, lazy nodes and
scalar leaves; pass `.emit_nulls = true` to write a literal `null` for empty
optional fields. Transforms without a query representation, unions and custom
values return `error.Unsupported` instead of emitting incomplete text.

Nested keys use bracket notation. The same syntax is accepted by `parseQuery`
and `parseForm`:

```zig
var query = try z.parseQuery(UserSchema, allocator,
    "name=Ada&address[city]=London&tags=fast&tags=safe", .{});
defer query.deinit();

const encoded = try z.stringifyQuery(UserSchema, allocator, query.value.?, .{});
defer allocator.free(encoded);
// name=Ada&address%5Bcity%5D=London&tags=fast&tags=safe
```

Numeric segments address array elements (`items[0][name]=Ada`), and dots are
accepted as separators (`address.city=London`). A trailing `[]` is optional for
repeated keys. Bracket characters in a literal record key are percent-encoded
by serialization; keep record keys free of `[`, `]` and `.` when they must round
trip through query strings.

Repeated keys are the query encoding for arrays, so they are not affected by
`Options.duplicates`. A key with one value still produces a one-element array
for an array field.

## JSON Schema

```zig
const schema_text = try z.jsonSchema(UserSchema, allocator, .{});
defer allocator.free(schema_text);
```

Generated documents describe types, bounds, formats, required fields and
`additionalProperties`. Recursive schemas emit deduplicated `$defs` entries and
`$ref` links. Custom schemas have no external representation, so generation
returns `error.Unsupported` rather than claiming they accept everything. See
[JSON Schema](/guide/json-schema) for the full mapping.

## Typed validation

```zig
var issues = try z.validate(UserSchema, allocator, user, .{});
defer issues.deinit();
if (!issues.isEmpty()) {
    const text = try issues.render(allocator, .{});
    defer allocator.free(text);
}
```

`validate` runs the same constraints against a value that is already typed and
returns the owning issue list directly. No session object is needed.
