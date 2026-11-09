---
title: Naming & Aliases
description: Map Zig field names to JSON keys with compile-time naming policies and accept legacy keys with per-field aliases in zigantic.
keywords: zigantic naming, camelCase json, snake_case, kebab-case, field aliases, json key mapping
---

# Naming & Aliases

Zig fields are usually `camelCase`; JSON APIs often use `snake_case`. Object
schemas translate names at compile time, so no allocation or per-key lookup is
needed at runtime.

## Naming policies

```zig
const UserSchema = z.object(User, .{
    .firstName = z.string(.{}),
    .postalCode = z.string(.{}),
}, .{ .naming = .snake_case });
```

The policy applies to input keys, output keys and generated JSON Schema.

| Policy | `firstName` becomes |
| --- | --- |
| `.verbatim` (default) | `firstName` |
| `.camel_case` | `firstName` |
| `.snake_case` | `first_name` |
| `.kebab_case` | `first-name` |
| `.pascal_case` | `FirstName` |
| `.lower_case` | `firstname` |
| `.upper_case` | `FIRSTNAME` |

Policies are applied by `z.naming.apply(text, policy)` at compile time; the same
function is exported if you need to derive a key yourself.

## Aliases

An alias lets a field accept additional input keys without changing its output
key:

```zig
const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1 }),
    .email = z.email(.{}),
}, .{
    .naming = .snake_case,
    .aliases = &.{
        .{ .field = "name", .keys = &.{ "full_name", "display_name" } },
        .{ .field = "email", .keys = &.{"email_address"} },
    },
});
```

- `.field` must name a field that has a schema; unknown names fail the build.
- Aliases are read-only. Encoding always writes the canonical key for the
  configured policy.
- When a document contains the canonical key and one or more aliases, every
  matching key is decoded in document order and the last one wins. Send exactly
  one key per field to keep the result predictable.
- Aliases also work for query strings and form bodies, which makes them useful
  for accepting legacy parameter names.

## Duplicate keys

JSON objects can repeat a key. `Options.duplicates` controls what happens:

```zig
var result = try z.parse(UserSchema, allocator, document, .{
    .duplicates = .reject, // default: report E009
    // .first: keep the first occurrence
    // .last:  keep the last occurrence
});
```

With `.reject` the parse result contains a single `E009` issue at the exact
nested path where the key repeats (for example `$.address.city`) and no value.
The `.first` and `.last` policies keep the selected occurrence and continue
validation normally. Query strings are unaffected: repeated keys are the
encoding for arrays.

## Required keys in errors

When a field is missing, the reported path uses the canonical key produced by
the naming policy. A client that sent an alias still gets an error path that
matches the schema's output, not the alias it happened to omit:

```text
error[E007]: required field is missing
  $.name
    expected: string
```
