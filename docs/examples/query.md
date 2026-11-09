---
title: Query Strings & Forms
description: Decode URL query strings and form bodies with coercion, defaults, repeated keys and round-trip serialization in zigantic.
keywords: zigantic query string, form validation, urlencoded, zig web validation, query parsing
---

# Query Strings & Forms

`parseQuery` and `parseForm` decode percent-encoded text into the same object
model used for JSON, with coercion enabled for numbers, booleans and nulls.
`stringifyQuery` writes the model back as a query string.

## The schema

```zig
const Search = struct {
    query: []const u8,
    page: u16,
    active: bool,
    tags: []const []const u8,
};

const SearchSchema = z.object(Search, .{
    .query = z.string(.{ .min = 1 }),
    .page = z.withDefault(z.integer(u16, .{ .min = 1 }), 1),
    .active = z.boolean(.{}),
    .tags = z.array(z.string(.{ .min = 1 }), .{ .max = 4 }),
}, .{ .naming = .snake_case });
```

## The program

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var result = try z.parseQuery(SearchSchema, allocator, "query=zig+validation&active=true&tags=fast&tags=safe", .{});
    defer result.deinit();
    if (result.value) |search| {
        std.debug.print("{s} page {d} active={any} tags={d}\n", .{
            search.query, search.page, search.active, search.tags.len,
        });

        const text = try z.stringifyQuery(SearchSchema, allocator, search, .{});
        defer allocator.free(text);
        std.debug.print("{s}\n", .{text});
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var form = try z.parseForm(SearchSchema, allocator, "query=login&active=false", .{});
    defer form.deinit();
    std.debug.print("form accepted: {any}\n", .{form.ok()});
}
```

## Output

```text
zig validation page 1 active=true tags=2
query=zig+validation&page=1&active=true&tags=fast&tags=safe
form accepted: false
```

## What to notice

- `+` and `%20` both decode to a space. Percent escapes are decoded before
  validation, so `tags=a%2Cb` is the text `a,b`, not two tags.
- Repeated keys become arrays. A single occurrence of an array field still
  produces a one-element array; a single value never silently becomes a scalar.
- `page` is absent and receives its schema default `1`.
- Coercion is limited to text transport: `"true"` becomes `true`, numeric text
  becomes an integer, and an out-of-range number still fails the integer
  schema.
- `stringifyQuery` uses the object's naming policy, so a `snake_case` schema
  writes `page` rather than `page`/`Page` variants. Values are re-encoded, which
  is why the space in `zig validation` returns as `+`.
- The form fails because `tags` is required by the schema and the body has no
  `tags` value. That is the same `E007` a JSON document would produce, with the
  path `$.tags`.
