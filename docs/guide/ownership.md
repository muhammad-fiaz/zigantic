---
title: Ownership & Allocators
description: Explicit allocation boundaries, borrowed input, owned parse results, diagnostic lifetimes and failure-path cleanup in zigantic.
keywords: zigantic allocator, zigantic ownership, borrowed slices, arena allocation, parse result deinit, checkFirst, memory safety
---

# Ownership & Allocators

Zigantic keeps allocation boundaries visible. Predicate checks take no
allocator, parsing takes one at the result boundary, and caller-buffer
validation can avoid the heap entirely.

## Allocation matrix

| Operation | Allocator | Ownership of result | Lifetime |
| --- | --- | --- | --- |
| `z.validators.*` | none | borrowed `bool` | immediate |
| `schema.check(&state, ...)` | session arena | issues in the session | session |
| `z.checkFirst(S, value, buffer, .{})` | caller buffer | borrowed `?Issue` | buffer |
| `z.validate(S, allocator, value, .{})` | caller allocator | owning `IssueList` | until `deinit` |
| `z.parse`, `z.parseQuery`, `z.parseForm` | caller allocator | owning `ParseResult` | until `deinit` |
| `z.stringify` | caller allocator | owned `[]u8` | until `free` |
| `z.stringifyQuery` | caller allocator | owned `[]u8` | until `free` |
| `z.jsonSchema` | caller allocator | owned `[]u8` | until `free` |
| `z.Date`, `z.Time`, `z.DateTime` parsing | none | value type | immediate |

`schema.check` is the low-level typed check used by `validate`; applications
normally call `z.validate` or `z.checkFirst` instead.

## Borrowed input

`parse` reads the input document while decoding, but decoded strings and
collections are copied into the result arena. A borrowed slice returned by a
predicate or by `checkFirst` must not outlive its source. Query components
without percent escapes can be borrowed during parsing, but the final decoded
value is still arena-owned.

The result arena is not shared between results. Each `ParseResult` owns its
arena, its issue list and every decoded allocation. Call `deinit` exactly once:

```zig
var result = try z.parse(UserSchema, allocator, document, .{});
defer result.deinit();
```

The issue list is part of the result. `result.errors()` returns a borrowed
pointer valid only until `deinit`. Rendering produces a separate owned string.

## Diagnostic lifetimes

`z.validate` returns an owning `IssueList`; its paths, messages, expected and
received strings remain valid until `deinit`. `z.checkFirst` is different: the
returned issue points into the caller's scratch buffer and needs no
deinitialization.

```zig
var scratch: [4096]u8 = undefined;
const issue = try z.checkFirst(UserSchema, user, &scratch, .{});
```

A buffer that is too small returns `error.OutOfMemory`; it never silently drops
the diagnostic.

## Serialization scratch memory

`z.stringify` creates an internal scratch arena for transform and codec
`encode` callbacks. The callbacks may allocate strings there, but the returned
JSON buffer is allocated with the caller's allocator and remains valid after
the scratch arena is destroyed. Free it with the same allocator:

```zig
const text = try z.stringify(UserSchema, allocator, user, .{});
defer allocator.free(text);
```

## Failure paths

Parsing creates the result and issue list first, then uses `errdefer` while
building the value. If JSON parsing, transform encoding or an allocation fails,
partial resources are released before the error returns. The test suite uses
`std.testing.checkAllAllocationFailures` to inject a failure at every
allocation point in a parse.

Transforms receive the result arena on decode. They must return an error rather
than retain a pointer to temporary parser memory. Transform encoders receive
the `stringify` scratch arena. A codec follows the same rule in both
directions.

## Thread safety

Schemas are compile-time types and contain no mutable global state. Separate
results are independent, so separate results may be used from different
threads. A single result, its arena, its issue list and borrowed slices derived
from it are not synchronized and must not be mutated concurrently. Allocator
thread-safety is the allocator's responsibility.

## What the library never does

- It never creates a hidden global allocator.
- It never opens files or reads environment variables.
- It never frees caller-owned input.
- It never returns a slice owned by a temporary parser buffer.
- It never requires an allocator for a pure predicate check.
