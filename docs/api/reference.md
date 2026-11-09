---
title: API Reference
description: Complete reference for every zigantic export, constructor, configuration struct, option value, result type and error code.
keywords: zigantic api, zig validation api, schema constructors, configuration options, error codes, json schema api
---

# API Reference

Every public name is available from the package root:

```zig
const z = @import("zigantic");
```

All configuration is passed as a trailing `.{}` value. Constructors are
compile-time functions returning schema **types**; services are runtime
functions taking an allocator before the value and options last.

## Services

| Function | Returns | Notes |
| --- | --- | --- |
| `z.parse(S, allocator, input, .{})` | `ParseResult(S)` | JSON text to a validated value. |
| `z.stringify(S, allocator, value, .{})` | owned `[]u8` | validated value to JSON text. |
| `z.parseQuery(S, allocator, input, .{})` | `ParseResult(S)` | query string for object schemas, including `a[b]` paths. |
| `z.parseForm(S, allocator, input, .{})` | `ParseResult(S)` | `application/x-www-form-urlencoded` body. |
| `z.stringifyQuery(S, allocator, value, .{})` | owned `[]u8` | object schema to a nested query string. |
| `z.jsonSchema(S, allocator, .{})` | owned `[]u8` | JSON Schema document with root `$ref` and `$defs`. |
| `z.validate(S, allocator, value, .{})` | `IssueList` | checks an already-typed value. |

`parse`, `parseQuery` and `parseForm` can return `error.InvalidJson` (malformed
JSON or percent-encoding) and `error.OutOfMemory`. Schema violations are issues
inside the result, not errors. `stringify` can return `error.Unsupported` for
schemas without an encoder, `error.TransformFailed` when a transform's
`.encode` callback fails, and allocator or writer errors. `jsonSchema` can
return `error.Unsupported` for custom schemas, which have no external
representation.

### `ParseResult(S)`

```zig
pub fn Result(comptime S: type) type {
    return struct {
        value: ?S.Value,
        issues: IssueList,

        pub fn deinit(self: *Self) void;
        pub fn ok(self: *const Self) bool;
        pub fn errors(self: *Self) *IssueList;
    };
}
```

- `value` is `null` exactly when validation failed.
- `errors()` returns a borrowed list that is valid until `deinit`.
- `deinit` frees the value arena and the issue list; the result must not be used
  afterwards.

## Schema protocol

A schema is a type with these declarations:

| Member | Type | Meaning |
| --- | --- | --- |
| `Value` | `type` | validated Zig type |
| `kind` | `z.Kind` | schema discriminant |
| `schema_name` | `[]const u8` | name used in missing-field expectations |
| `is_optional` | `bool` | may be absent from an object |
| `has_default` | `bool` | supplies a default when absent |
| `decode(state, node, path)` | `DecodeError!Value` | JSON to value |
| `decodeString(state, raw, path)` | `DecodeError!Value` | text to value for query decoding |
| `check(state, value, path)` | `DecodeError!void` | validate a typed value |
| `encode(state, value)` | `EncodeError!void` | value to JSON |
| `writeJsonSchema(state)` | `SchemaError!void` | describe the schema |

`DecodeError` is `error{ Reported, OutOfMemory }`; `Reported` means at least one
issue was stored. `EncodeError` includes writer, `Unsupported` and
`TransformFailed`. `SchemaError` includes allocator and writer errors plus
`Unsupported`.

Constructors validate their inputs at compile time. Passing a non-integer to
`z.integer`, a schema whose `Value` does not match a model field, or a variant
map that omits a union field is a build error.

## Constructors

### Strings

```zig
z.string(.{})
z.email(.{})
z.url(.{})
z.httpsUrl(.{})
z.uuid(.{})
z.ulid(.{})
z.slug(.{})
z.semver(.{})
z.phoneNumber(.{})
z.creditCard(.{})
z.jwt(.{})
z.base64(.{})
z.base64Url(.{})
z.hex(.{})
z.hexColor(.{})
z.macAddress(.{})
z.ipv4(.{})
z.ipv6(.{})
z.isoDate(.{})
z.isoTime(.{})
z.isoDateTime(.{})
z.isoDuration(.{})
```

All of them accept `z.StringConfig`:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `min` | `usize` | `0` | minimum byte length |
| `max` | `usize` | `maxInt(usize)` | maximum byte length |
| `len` | `?usize` | `null` | exact byte length; takes precedence in messages |
| `prefix` | `?[]const u8` | `null` | required prefix |
| `suffix` | `?[]const u8` | `null` | required suffix |
| `contains` | `?[]const u8` | `null` | required substring |
| `trim` | `bool` | `false` | trim ASCII whitespace before checks |
| `case` | `z.StringCase` | `.any` | `.any`, `.lower`, `.upper` |
| `charset` | `z.StringCharset` | `.any` | `.any`, `.ascii`, `.printable`, `.alphabetic`, `.alphanumeric`, `.numeric`, `.hex` |
| `format` | `z.StringFormat` | `.none` | set automatically by format constructors |
| `description` | `[]const u8` | `""` | JSON Schema description |

Length checks run on the trimmed text when `.trim` is set. `.format` is set by
the format constructors and is not usually assigned directly.

### Numbers

```zig
z.integer(T, .{})
z.float(T, .{})
z.positiveInt(T, .{})
z.nonNegativeInt(T, .{})
z.percentage(T, .{})
z.probability(T, .{})
```

`z.IntConfig`:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `min` | `?comptime_int` | `null` | inclusive minimum |
| `max` | `?comptime_int` | `null` | inclusive maximum |
| `even` | `bool` | `false` | require an even value |
| `multiple_of` | `?comptime_int` | `null` | require a multiple |
| `description` | `[]const u8` | `""` | JSON Schema description |

`z.FloatConfig`:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `min` | `?comptime_float` | `null` | inclusive minimum |
| `max` | `?comptime_float` | `null` | inclusive maximum |
| `finite` | `bool` | `true` | reject NaN and infinities |
| `description` | `[]const u8` | `""` | JSON Schema description |

The helpers are constraint presets that still accept the same config:

- `positiveInt` sets `min` to at least `1`.
- `nonNegativeInt` sets `min` to at least `0`.
- `percentage` bounds a float to `0..100`.
- `probability` bounds a float to `0..1`.

### Primitives

```zig
z.boolean(.{})       // z.BoolConfig   { description }
z.enumType(E, .{})   // z.EnumConfig   { description }
z.nullValue(.{})     // z.NullConfig   { description }
z.literal(value)     // string, integer or boolean literal
```

`z.literal` takes the literal itself as its only argument; there is no separate
options value. Its `Value` is `[]const u8` for string literals, `i64` for
comptime integers and `bool` for booleans.

### Objects

```zig
z.object(T, .{
    .field = Schema,
}, .{})

z.objectOf(.{
    .field = Schema,
}, .{})
```

`z.object` binds to a declared Zig type. `z.objectOf` infers the struct with
`@Struct`; its `Value` is the synthesized type. Both accept `z.ObjectConfig`.

`z.ObjectConfig`:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `naming` | `z.Naming` | `.verbatim` | key policy for input, output and schema |
| `unknown_fields` | `z.UnknownFields` | `.reject` | `.reject` or `.strip` |
| `aliases` | `[]const z.Alias` | `&.{}` | extra accepted input keys |
| `partial` | `bool` | `false` | allow any field to be absent |
| `description` | `[]const u8` | `""` | JSON Schema description |

Rules:

- Every schema field must exist on `T`.
- Every field of `T` without a schema must have a default value, be optional, or
  be allowed by `.partial`.
- A missing schema field is filled from, in order: `z.optional` (`null`),
  schema default, model default, `.partial`, otherwise `E007`.

### Collections

```zig
z.array(S, .{})
z.record(S, .{})
```

`z.ArrayConfig`:

| Field | Type | Default |
| --- | --- | --- |
| `min` | `usize` | `0` |
| `max` | `usize` | `maxInt(usize)` |
| `len` | `?usize` | `null` |
| `unique` | `bool` | `false` |
| `description` | `[]const u8` | `""` |

`z.RecordConfig`:

| Field | Type | Default |
| --- | --- | --- |
| `min` | `usize` | `0` |
| `max` | `usize` | `maxInt(usize)` |
| `key_min` | `usize` | `1` |
| `key_max` | `usize` | `256` |
| `description` | `[]const u8` | `""` |

`z.array` produces `[]const S.Value`; `z.record` produces
`std.array_hash_map.String(S.Value)`.

### Tuples and intersections

```zig
z.tuple(.{
    .first = Schema,
    .second = OtherSchema,
}, .{})

z.intersection(.{
    .first = Schema,
    .second = OtherSchema,
}, .{})
```

`z.tuple` synthesizes `@Tuple` from the field schemas. `z.intersection` requires
every member to produce the same `Value`; decoding uses the first member and
checks the result against the others. Both configs contain only `description`.

### Unions

```zig
z.unionOf(U, .{ .variant = Schema }, .{})
z.discriminatedUnion(U, "type", .{ .variant = Schema }, .{})
```

`z.UnionConfig` and `z.DiscriminatedConfig` both contain only `description`.
Variant names must match the union fields and payload types.

### Modifiers

| Constructor | `Value` | Notes |
| --- | --- | --- |
| `z.optional(S)` | `?S.Value` | absent key; rejects explicit `null` |
| `z.nullable(S)` | `?S.Value` | accepts explicit `null` |
| `z.withDefault(S, value)` | `S.Value` | compile-time default |
| `z.withDefaultFactory(S, factory)` | `S.Value` | `fn () S.Value` |
| `z.fallback(S, value)` | `S.Value` | value used when decoding fails |
| `z.refine(S, .{ .check, .message })` | `S.Value` | `fn (S.Value) bool` |
| `z.transform(S, .{ .decode, .encode, .check })` | decode payload | reversible typed conversion |
| `z.lazy(get)` | `*const Inner.Value` | `fn () type` |
| `z.custom(T, .{ .check, .message })` | `T` | typed checks only; a failed check is `E012` |

`z.RefineConfig(T)`:

| Field | Type | Default |
| --- | --- | --- |
| `check` | `*const fn (T) bool` | required |
| `message` | `[]const u8` | `"value failed a refinement check"` |

`z.CustomConfig(T)`:

| Field | Type | Default |
| --- | --- | --- |
| `check` | `*const fn (T) bool` | required |
| `message` | `[]const u8` | `"value failed a custom check"` |

`z.TransformConfig(In, Out)`:

| Field | Type | Default |
| --- | --- | --- |
| `decode` | `*const fn (Allocator, In.Value) anyerror!Out` | required |
| `encode` | `?*const fn (Allocator, Out) anyerror!In.Value` | `null` |
| `check` | `?*const fn (Out) bool` | `null` |
| `message` | `[]const u8` | `"value failed a transformation check"` |

Supplying `encode` makes `z.stringify` possible. Without `encode`, `encode`
returns `error.Unsupported`. Without either `encode` or `check`, `check` also
returns `error.Unsupported`.

## Date and time

`z.Date`, `z.Time` and `z.DateTime` provide allocation-free civil arithmetic:

| Type | Members |
| --- | --- |
| `Date` | `init`, `parse`, `format`, `daysSinceEpoch`, `fromDaysSinceEpoch`, `weekday`, `dayOfYear`, `addDays`, `addMonths`, `addYears`, `daysUntil`, `compare`, `eql` |
| `Time` | `init`, `parse`, `format`, `seconds`, `addSeconds`, `compare` |
| `DateTime` | `init`, `parse`, `format`, `timestamp`, `fromTimestamp`, `addSeconds`, `addDays`, `dateDifference`, `compare` |

`DateTime` keeps a fixed `offset_minutes`; arithmetic is exact for that offset.
Time-zone database transitions are not modelled. The `z.datetime` module also
exports `isLeapYear` and `daysInMonth`.

## Options

`z.Options` is shared by `parse`, `parseQuery`, `parseForm` and `validate`:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `unknown_fields` | `?z.UnknownFields` | `null` | per-call override of the object policy |
| `coerce` | `bool` | `false` | accept strings for numbers and booleans in JSON |
| `duplicates` | `z.Duplicates` | `.reject` | `.reject`, `.first` or `.last` for repeated JSON keys |
| `messages` | `z.Messages` | all `null` | per-code message overrides |
| `max_depth` | `usize` | `128` | nesting limit for objects, arrays and lazy nodes |
| `hooks` | `z.Hooks` | all `null` | lifecycle callbacks |

`z.EncodeOptions` (used by `stringify`; accepted but currently unused by `jsonSchema`):

| Field | Type | Default |
| --- | --- | --- |
| `emit_null_fields` | `bool` | `false` |

`z.QueryStringifyOptions` (used by `stringifyQuery`):

| Field | Type | Default |
| --- | --- | --- |
| `emit_nulls` | `bool` | `false` |

`z.RenderOptions` (used by `IssueList.render` / `write`):

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `capability` | `z.Capability` | `.none` | tint colour capability |
| `show_expected` | `bool` | `true` | print the expected line |
| `show_received` | `bool` | `true` | print the received line |
| `indent` | `u8` | `2` | spaces before details |

`z.IssueList.init` takes its own `Options` with `capacity` (`usize`, default
`8`), the initial issue capacity.

### Hooks

```zig
pub const Hooks = struct {
    on_start: ?*const fn (schema_name: []const u8) void = null,
    on_field: ?*const fn (path: []const u8, accepted: bool) void = null,
    on_issue: ?*const fn (issue: Issue) void = null,
    on_finish: ?*const fn (ok: bool, total_issues: usize) void = null,
};
```

Hooks are plain function pointers supplied per call. They run on the calling
thread and must not retain borrowed slices after returning.

## Issues

```zig
pub const Issue = struct {
    code: z.Code,
    path: []const u8,
    message: []const u8,
    expected: ?[]const u8,
    received: ?[]const u8,
};
```

`z.IssueList` methods:

| Method | Result |
| --- | --- |
| `init(allocator, .{})` | owning empty list |
| `deinit()` | frees the list and its arena |
| `clear()` | removes issues, keeps capacity |
| `count()` / `isEmpty()` | size queries |
| `at(index)` | `Issue` by index |
| `first()` / `last()` | `?Issue` |
| `mark()` / `rollback(point)` | transactional suffix removal |
| `add(issue)` / `addCode(...)` / `addError(...)` | append |
| `write(writer, .{})` / `render(allocator, .{})` | annotated text |
| `writeJson(writer)` / `toJson(allocator)` | JSON array |

`at`, `first` and `last` return borrowed `Issue` values whose strings are owned
by the list.

## Error codes

| Code | Name | Category | Default message |
| --- | --- | --- | --- |
| `E001` | `type_mismatch` | type | invalid type |
| `E002` | `too_small` | length | value is too small |
| `E003` | `too_large` | length | value is too large |
| `E004` | `length_mismatch` | length | invalid length |
| `E005` | `invalid_value` | structure | invalid value |
| `E006` | `invalid_format` | format | invalid format |
| `E007` | `missing_field` | structure | required field is missing |
| `E008` | `unknown_field` | structure | unknown field is not allowed |
| `E009` | `duplicate_field` | structure | duplicate field |
| `E010` | `not_in_enum` | structure | value is not an allowed enum member |
| `E011` | `invalid_literal` | structure | value does not match the required literal |
| `E012` | `refinement_failed` | refinement | value failed a refinement check |
| `E013` | `transform_failed` | coercion | value could not be transformed |
| `E014` | `coercion_failed` | coercion | value could not be coerced |
| `E015` | `union_mismatch` | structure | value does not match any union variant |
| `E016` | `out_of_range` | length | value is outside the allowed range |
| `E017` | `not_finite` | range | value must be finite |
| `E018` | `not_integer` | type | value must be an integer |
| `E019` | `missing_discriminator` | structure | discriminator field is missing |
| `E020` | `invalid_discriminator` | structure | discriminator selects an unknown variant |
| `E021` | `unsupported` | unsupported | operation is not supported by this schema |

`z.Code` exposes `label()`, `category()` and `message()`. `z.Messages` has one
optional field per code, named after the code, for per-call overrides.

## Naming

`z.Naming` (alias of `Policy`) values: `.verbatim`, `.camel_case`,
`.snake_case`, `.kebab_case`, `.pascal_case`, `.lower_case`, `.upper_case`.

`z.Alias`:

```zig
pub const Alias = struct {
    field: []const u8,
    keys: []const []const u8,
};
```

Aliases add accepted input keys. Encoding always uses the canonical key.

## Validators

`z.validators` exposes pure, allocation-free predicates taking `[]const u8`:

```zig
isEmail, isUrl, isHttpsUrl, isUuid, isUlid, isSlug, isSemver,
isPhoneNumber, luhn, isCreditCard, isBase64, isBase64Url, isHex,
isHexColor, isMacAddress, isJwt, isIpv4, isIpv6, isIsoDate,
isIsoTime, isIsoDateTime, isIsoDuration
```

`luhn` takes a string of digits and verifies the checksum; `isCreditCard`
normalises separators and then calls it.

## Other exports

| Export | Meaning |
| --- | --- |
| `z.version` | package version string |
| `z.ValidationError` | `error{...}` enum of validation failures |
| `z.Category` | issue category enum |
| `z.Kind` | schema discriminant enum |
| `z.State` | decode state passed to schemas |
| `z.UnknownFields` | `.reject` / `.strip` |
| `z.Duplicates` | `.reject` / `.first` / `.last` |
| `z.ObjectConfig`, `z.ArrayConfig`, `z.RecordConfig` | object and collection configuration |
| `z.TupleConfig`, `z.IntersectionConfig` | tuple and intersection configuration |
| `z.RefineConfig`, `z.TransformConfig`, `z.CustomConfig` | modifier configuration |
| `z.Capability` | tint colour capability |
| `z.Date`, `z.Time`, `z.DateTime`, `z.Weekday` | civil date/time arithmetic |
| `z.datetime` | `isLeapYear`, `daysInMonth` and the date/time types |

## Native documentation

```bash
zig build docs
```

Writes the Zig-generated reference for every public declaration to
`zig-out/docs/api`.
