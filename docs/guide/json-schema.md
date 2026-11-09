---
title: JSON Schema
description: Generate JSON Schema documents from zigantic schemas, including bounds, formats, required fields and additionalProperties.
keywords: zigantic json schema, schema generation, json schema validation, additionalProperties, required fields
---

# JSON Schema

Any schema that can describe itself implements `writeJsonSchema`. The `z.jsonSchema`
service runs it against an allocated writer and returns owned bytes.

```zig
const text = try z.jsonSchema(UserSchema, allocator, .{});
defer allocator.free(text);
```

The service takes the allocator, then `z.JsonSchemaOptions`. The default target
is Draft 2020-12. Five targets are supported:

```zig
const modern = try z.jsonSchema(UserSchema, allocator, .{});
const draft2019 = try z.jsonSchema(UserSchema, allocator, .{ .target = .draft_2019_09 });
const draft7 = try z.jsonSchema(UserSchema, allocator, .{ .target = .draft_07 });
const draft6 = try z.jsonSchema(UserSchema, allocator, .{ .target = .draft_06 });
const draft5 = try z.jsonSchema(UserSchema, allocator, .{ .target = .draft_05 });
```

| Target | `$schema` | Definitions | Tuples |
| --- | --- | --- | --- |
| `.draft_2020_12` | `https://json-schema.org/draft/2020-12/schema` | `$defs` | `prefixItems` |
| `.draft_2019_09` | `https://json-schema.org/draft/2019-09/schema` | `$defs` | `items` array |
| `.draft_07` | `http://json-schema.org/draft-07/schema#` | `definitions` | `items` array |
| `.draft_06` | `http://json-schema.org/draft-06/schema#` | `definitions` | `items` array |
| `.draft_05` | `http://json-schema.org/draft-05/schema#` | `definitions` | `items` array |

A root `$ref` and a definitions object keep recursive schemas finite. Draft
2020-12 and 2019-09 use `$defs` and `#/$defs/...`; older drafts use
`definitions` and `#/definitions/...`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$ref": "#/$defs/root",
  "$defs": {
    "root": { "type": "object", "properties": {} },
    "def_ab12cd34": { "type": "object", "properties": {} }
  }
}
```

Each recursive type is registered once and receives a stable hash-based key.

## What is emitted

| Schema | JSON Schema |
| --- | --- |
| `z.string(.{...})` | `type: "string"`, `minLength`, `maxLength`, `format`, `description` |
| `z.integer(T, .{...})` | `type: "integer"`, `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `multipleOf`, `description` |
| `z.float(T, .{...})` | `type: "number"`, `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `description` |
| `z.boolean(.{})` | `type: "boolean"` |
| `z.enumType(E, .{})` | `type: "string"` and an `enum` of member names |
| `z.literal(value)` | `const` (Draft 6+) or one-element `enum` (Draft 5) |
| `z.nullValue(.{})` | `type: "null"` |
| `z.array(S, .{...})` | `type: "array"`, `items`, `minItems`, `maxItems`, `uniqueItems` |
| `z.fixedArray(S, N, .{...})` | `type: "array"` with `minItems` and `maxItems` set to `N` |
| `z.set(S, .{...})` | the array form plus `uniqueItems: true` |
| `z.record(S, .{...})` | `type: "object"`, `additionalProperties: S`, `minProperties`, `maxProperties`, `propertyNames` |
| `z.object(T, ..., .{...})` | `type: "object"`, `properties`, `required`, `additionalProperties`, `description` |
| `unionOf` / `discriminatedUnion` | `oneOf` with each variant schema |
| `optional(S)` | the inner schema, because absence is expressed by `required` |
| `nullable(S)` | `anyOf: [S, {"type": "null"}]` |
| `transform` / `codec` | the input schema (`decode` maps it to the output type) |
| `z.meta(S, ...)` | the base schema plus `title`, `description`, `examples` and `$id` |
| `z.withDefault(S, value)` | `allOf: [S]` plus a `default` value |
| `z.date` / `z.time` / `z.dateTime` | `type: "string"` with the corresponding `format` |
| `z.bytes` | a string with the matching encoding format, or `type: "array"` for `.array` |
| `lazy` | `{"$ref": "#/$defs/..."}` plus a `$defs` entry |
| `custom` | unsupported; `z.jsonSchema` returns `error.Unsupported` |
| `fallback` / `refine` | the inner schema |

## Example

```zig
const User = struct {
    name: []const u8,
    email: []const u8,
    age: u8,
    nickname: ?[]const u8 = null,
};

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1, .max = 64, .description = "display name" }),
    .email = z.email(.{}),
    .age = z.integer(u8, .{ .min = 18 }),
    .nickname = z.optional(z.string(.{ .max = 32 })),
}, .{});
```

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$ref": "#/$defs/root",
  "$defs": {
    "root": {
      "type": "object",
      "properties": {
        "name": {"type": "string", "minLength": 1, "maxLength": 64, "description": "display name"},
        "email": {"type": "string", "format": "email"},
        "age": {"type": "integer", "minimum": 18},
        "nickname": {"type": "string", "maxLength": 32}
      },
      "required": ["name", "email", "age"],
      "additionalProperties": false
    }
  }
}
```

`additionalProperties` is `false` for the default `.unknown_fields = .reject`
and `true` for `.strip`. `required` lists only fields that cannot be omitted:
optional fields, schemas with defaults and model fields with struct defaults are
excluded.

## Limits

JSON Schema cannot express every check:

- `.trim`, `.prefix`, `.suffix`, `.contains`, `.case` and `.charset` are
  enforced at decode time but not described.
- `.even` is enforced for integers but is not a JSON Schema keyword.
- Formats without a standard JSON Schema `format` name are emitted without one.
- String prefix, suffix and contains constraints have no standard keyword and
  are omitted.
- Draft 5 has no `propertyNames`, so record key-length limits are enforced at
  decode time but omitted from generated Draft 5 output.
- Draft 5 expresses exclusive bounds with boolean `exclusiveMinimum` and
  `exclusiveMaximum`; when inclusive and exclusive bounds are both present the
  generator emits an `allOf` that preserves both constraints.
- OpenAPI 3.0 output and JSON Schema import are not implemented; use one of the
  five supported JSON Schema drafts and treat import as a manual mapping.
- Refinements and custom checks are omitted.
- Transforms describe their input type, because that is what the wire format
  contains.
- Custom schemas return `error.Unsupported`; they have no JSON representation.

Treat the generated document as documentation and client-side assistance, not
as a complete description of runtime validation.
