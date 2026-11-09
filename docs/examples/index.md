---
title: Examples
description: Nine complete, runnable zigantic programs covering validation, model objects, nested schemas, collections, formats, unions, modifiers, errors and query strings.
keywords: zigantic examples, zig validation examples, json schema example, zig query string, zig validation errors
---

# Examples

Every example on this page is a real program in the repository under
`examples/`. Each one compiles against the published package, runs without
arguments and prints the output shown on its page.

Run a single example with:

```bash
zig build run-basic
```

Or run all of them:

```bash
zig build run-all-examples
```

## What each example covers

| Example | What it demonstrates |
| --- | --- |
| [Basic Validation](/examples/basic) | A format check, an integer bound and a charset rule, plus plain and coloured error output. |
| [Model Objects](/examples/model) | `z.object` bound to a declared struct, defaults, enums, arrays, naming, aliases, query parsing and JSON Schema. |
| [Nested Objects](/examples/nested) | Composing object schemas and reading nested error paths. |
| [Collections](/examples/collections) | Arrays with uniqueness and records backed by `std.array_hash_map.String`. |
| [Formats](/examples/formats) | The built-in string formats and the allocation-free `z.validators` predicates. |
| [Unions](/examples/unions) | Untagged unions and discriminated unions with exhaustive `switch`. |
| [Modifiers](/examples/modifiers) | Defaults, optional fields, nullable fields, refinements and typed validation. |
| [Structured Errors](/examples/errors) | Plain rendering, JSON rendering and the `z.validate` issue list. |
| [Query Strings & Forms](/examples/query) | Query and form decoding with coercion, repeated keys and round-trip serialization. |

## Conventions used by every example

- The allocator is always explicit, and is the second argument to a service
  (except `z.checkFirst`, which takes the value second and a scratch buffer
  third).
- Every service takes a trailing options value, even when it is `.{}`.
- A `ParseResult` owns its decoded strings; `defer result.deinit()` releases them.
- Schemas are values of type `type`, so they can be declared as top-level
  constants and reused for JSON, query strings, validation and JSON Schema.

## Related guides

- [Inferred Objects, Tuples & Intersections](/guide/inference) covers
  `z.objectOf`, `z.tuple` and `z.intersection`.
- [JSON, Query & Forms](/guide/json-parsing) documents nested `a[b]` query
  paths and duplicate-key handling.
- [Date & Time](/guide/datetime) covers calendar arithmetic after string
  validation.
- [JSON Schema](/guide/json-schema) explains `$defs`, `$ref` and what can be
  represented.
