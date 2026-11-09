---
title: Introduction
description: zigantic validates JSON, query strings and forms into declared or inferred Zig types with compile-time schemas, explicit allocators and structured errors.
keywords: zigantic, zig validation, zig schema, json validation, allocator explicit, zig 0.17, inferred structs
---

# Introduction

zigantic validates wire data and decodes it into ordinary Zig values. A schema
is a **type**: `z.string(.{})`, `z.integer(u8, .{})` and
`z.object(Model, .{...}, .{})` each return a type with a `Value` declaration and
a common operation set:

- `decode`: a `std.json.Value` tree to `Value`;
- `check`: validate an already-typed `Value`;
- `encode`: write a `Value` through the standard JSON writer;
- `writeJsonSchema`: emit a JSON Schema description;
- `decodeString`: decode one textual component for query and form input, where
  the schema has a text representation.

Composition is resolved by the compiler. Invalid field types, unknown fields,
mismatched union variants and incompatible intersections fail the build. There
is no runtime schema interpreter.

## Zig 0.17 standard-library reuse

The implementation targets Zig 0.17 and reuses the current standard library
instead of maintaining parallel parsers, writers, URI logic or calendar code:

- `std.json` parses input into `std.json.Value` and `std.json.Stringify` writes
  output through `std.Io.Writer`;
- `std.Uri` and `std.SemanticVersion` back URL and semantic-version checks;
- `std.ascii` supplies character classification and case conversion;
- `std.math` supplies integer bounds, finite checks and ordering;
- `std.array_hash_map.String` is the record value type;
- `std.Io.Clock.Timestamp` is used by the benchmark harness.

Zig 0.17 syntax is used throughout, including `@typeInfo(...).@"struct"`,
`@typeName`, `@Struct`, `@Tuple`, `std.Io.Writer` and `std.mem.Allocator`.
Only the Zig 0.17 package in the repository CI is supported.

## Declared and inferred models

A schema can bind to a model you declare:

```zig
const User = struct {
    name: []const u8,
    age: u8,
};

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1 }),
    .age = z.integer(u8, .{ .min = 18 }),
}, .{});
```

Zig 0.17 can also construct types. `z.objectOf` synthesizes a struct with
`@Struct`, `z.tuple` synthesizes a tuple with `@Tuple`, and `z.intersection`
checks several schemas against one value:

```zig
const Profile = z.objectOf(.{
    .name = z.string(.{ .min = 1 }),
    .age = z.integer(u8, .{ .min = 18 }),
}, .{});

const Point = z.tuple(.{
    .x = z.float(f64, .{}),
    .y = z.float(f64, .{}),
}, .{});
```

See [Inferred Objects, Tuples & Intersections](/guide/inference) for the full
rules and examples.

## Complete schema surface

- Objects: `z.object` for declared models and `z.objectOf` for inferred ones,
  with naming policies, aliases, unknown-field policy and defaults; `z.merge`,
  `z.extend`, `z.pick` and `z.omit` compose inferred field sets.
- Collections: `z.array`, `z.fixedArray`, `z.set`, `z.record` and `z.tuple`.
- Products and sums: `z.tuple`, `z.intersection`, `z.unionOf` and
  `z.discriminatedUnion`.
- Primitives: strings and formats, integers, floats, booleans, enums, literals,
  null, `z.bytes` and temporal schemas.
- Modifiers: `optional`, `nullable`, `nullish`, `withDefault`,
  `withDefaultFactory`, `fallback`, `refine`, `meta`, `transform`, `codec`,
  `lazy` and `custom`.
- Wire services: `z.parse`, `z.stringify`, `z.parseQuery`, `z.parseForm`,
  `z.stringifyQuery`, `z.validate`, `z.checkFirst` and `z.jsonSchema`.
- Date and time: `z.Date`, `z.Time` and `z.DateTime` for calendar arithmetic
  after the ISO 8601 string schemas validate the wire text.

## Ownership

Validation predicates allocate nothing. Decoding allocates from a per-result
arena owned by the caller's allocator; `ParseResult.deinit` frees everything.
`z.checkFirst` validates typed values with caller scratch memory and no heap
allocation. `z.stringify` creates one scratch arena for transform encoders and
releases it before returning the caller-owned buffer.

Borrowed input slices stay valid only while the source document lives. Decoded
strings, collections and records are owned by the result arena; issue paths and
messages are owned by the issue list. The library never opens files, reads
environment variables or keeps global configuration. Every service takes a
trailing options value, and every allocation is visible in its signature. See
[Ownership & Allocators](/guide/ownership) for the full allocation matrix and
failure-path rules.

## Composition and wire boundaries

Schemas nest freely inside objects, arrays, records, tuples and unions.
Modifiers distinguish absent keys from explicit `null`, make mappings
reversible with `.encode`, and support recursive models with `z.lazy`.
Recursive JSON Schema output uses `$defs` and `$ref` instead of a permissive
placeholder.

Some values deliberately have no external representation. A `z.custom` value
is check-only: `decode` reports `E021` and `encode` and JSON Schema return
`error.Unsupported`. A `transform` without `.encode` is likewise not
serializable. Query serialization traverses objects, records, tuples, arrays,
intersections, lazy nodes and scalar leaves; unions, transforms without a query
form and custom values return `error.Unsupported` instead of emitting
incomplete text.

## Known limitations

- JSON Schema output targets Draft 2020-12, Draft 2019-09, Draft 7, Draft 6
  and Draft 5. OpenAPI 3.0 output and JSON Schema import are not implemented.
- `multipart/form-data` parsing is not implemented; URL-encoded forms are.
- Pattern validation uses the built-in formats and string predicates. A general
  regular-expression engine is not bundled to keep the package dependency-free.
- Objects reject or strip unknown keys. Preserving unknown keys would need an
  explicit model field and is not automatic.
- Tuples have fixed arity; variadic tuples are not implemented.
- Records use string keys. Maps with arbitrary key types are not implemented.
- String lengths and format checks operate on bytes and ASCII, not grapheme
  clusters or full Unicode normalization.

## What it is not

- Not an ORM or a database layer.
- Not a replacement for `std.json`; it builds on it.
- Not a runtime schema interpreter; schemas and their checks exist at compile
  time, and decoded values are ordinary Zig values.
