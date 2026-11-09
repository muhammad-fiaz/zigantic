---
title: Model Objects
description: Bind an object schema to a declared Zig struct with defaults, enums, arrays, snake_case naming, aliases, query parsing and JSON Schema generation.
keywords: zigantic object schema, zig struct validation, snake_case, field alias, json schema generation
---

# Model Objects

Object schemas bind to a model you declare. The compiler compares the field map
with the struct: a field with no schema needs a default, an unknown field name
fails the build, and a schema whose `Value` does not match the field type fails
the build as well.

## The model and schema

```zig
const Role = enum { user, admin };

const User = struct {
    name: []const u8,
    email: []const u8,
    age: u8,
    role: Role = .user,
    tags: []const []const u8 = &.{},
};

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1, .max = 64, .trim = true }),
    .email = z.email(.{}),
    .age = z.integer(u8, .{ .min = 18 }),
    .role = z.enumType(Role, .{}),
    .tags = z.array(z.string(.{ .min = 1 }), .{ .max = 8 }),
}, .{ .naming = .snake_case, .aliases = &.{
    .{ .field = "name", .keys = &.{"full_name"} },
} });
```

The schema covers every field, including `role` and `tags`, which also have
model defaults. A field may be omitted when the schema makes it optional, when
the schema supplies a default, when the model supplies a default, or when the
object config sets `.partial = true`. All other fields are required. In this
model, `role` and `tags` fall back to their struct defaults.

## The program

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const document =
        \\{"name":"Ada","email":"ada@example.com","age":36,"role":"admin","tags":["math","logic"]}
    ;

    var result = try z.parse(UserSchema, allocator, document, .{});
    defer result.deinit();
    if (result.value) |user| {
        std.debug.print("{s} <{s}> age {d}, {s}, {d} tags\n", .{
            user.name, user.email, user.age, @tagName(user.role), user.tags.len,
        });

        const again = try z.stringify(UserSchema, allocator, user, .{});
        defer allocator.free(again);
        std.debug.print("{s}\n", .{again});
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var query = try z.parseQuery(UserSchema, allocator, "full_name=Grace&email=grace%40example.com&age=45", .{});
    defer query.deinit();
    if (query.value) |user| {
        std.debug.print("query: {s} ({s}), role {s}\n", .{ user.name, user.email, @tagName(user.role) });
    }

    const schema_json = try z.jsonSchema(UserSchema, allocator, .{});
    defer allocator.free(schema_json);
    std.debug.print("schema bytes: {d}\n", .{schema_json.len});
}
```

## Output

```text
Ada <ada@example.com> age 36, admin, 2 tags
{"name":"Ada","email":"ada@example.com","age":36,"role":"admin","tags":["math","logic"]}
query: Grace (grace@example.com), role user
schema bytes: 454
```

## What to notice

- `.naming = .snake_case` maps `postalCode`-style Zig fields to `postal_code`
  keys. Input and output both use the configured policy, so `stringify`
  round-trips the document unchanged.
- The alias `full_name` is accepted only for reading. Output always uses the
  canonical key, so a client can send a legacy name while the response is
  consistent.
- `parseQuery` uses the same schema, naming and aliases as `parse`; only the
  transport differs. Text values are coerced, so `age=45` becomes `u8` 45.
- `jsonSchema` describes required fields, bounds, formats and
  `additionalProperties`. It returns owned bytes like `stringify`.
- The query omits `role` and `tags`; the model defaults apply because the struct
  declares them. If a field had no schema default, no model default and was not
  optional, the query would report `E007: required field is missing`.
