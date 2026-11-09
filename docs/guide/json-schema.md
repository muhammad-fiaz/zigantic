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

The service takes the allocator, then a trailing options value. The current
release reserves the options value for future generator settings; pass `.{}`.

The document uses a root `$ref` and a `$defs` object so recursive schemas can
refer back to themselves without infinite output:

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
| `z.integer(T, .{...})` | `type: "integer"`, `minimum`, `maximum`, `multipleOf`, `description` |
| `z.float(T, .{...})` | `type: "number"`, `minimum`, `maximum`, `description` |
| `z.boolean(.{})` | `type: "boolean"` |
| `z.enumType(E, .{})` | `type: "string"` and an `enum` of member names |
| `z.literal(value)` | `const` with the literal value |
| `z.nullValue(.{})` | `type: "null"` |
| `z.array(S, .{...})` | `type: "array"`, `items`, `minItems`, `maxItems`, `uniqueItems` |
| `z.record(S, .{...})` | `type: "object"`, `additionalProperties: S`, `minProperties`, `maxProperties` |
| `z.object(T, ..., .{...})` | `type: "object"`, `properties`, `required`, `additionalProperties`, `description` |
| `unionOf` / `discriminatedUnion` | `oneOf` with each variant schema |
| `optional(S)` | the inner schema, because absence is expressed by `required` |
| `nullable(S)` | `anyOf: [S, {"type": "null"}]` |
| `transform` | the input schema (`decode` maps it to the output type) |
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
- Record key length limits (`key_min` / `key_max`) are enforced at decode time
  but are not described.
- Formats without a standard JSON Schema `format` name are emitted without one.
- Refinements and custom checks are omitted.
- Transforms describe their input type, because that is what the wire format
  contains.
- Custom schemas return `error.Unsupported`; they have no JSON representation.

Treat the generated document as documentation and client-side assistance, not
as a complete description of runtime validation.
