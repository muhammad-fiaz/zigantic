---
title: Benchmarks
description: Run the full zigantic benchmark suite covering JSON, query strings, forms, JSON Schema, typed validation, predicates and date-time parsing.
keywords: zigantic benchmarks, zig json performance, query parsing benchmark, form benchmark, json schema benchmark, validation speed, releasefast, ns per op
---

# Benchmarks

```bash
zig build bench
```

The target builds `bench/benchmark.zig` with `ReleaseFast` and measures eleven
paths:

- **JSON:** model parsing, nested-object parsing, bounded integer parsing and
  model serialization.
- **Query and forms:** query parsing, form parsing and query serialization.
- **Schema and validation:** JSON Schema generation, typed validation and the
  allocation-free `email` predicate.
- **Date and time:** offset date-time parsing.

## Methodology

Each benchmark performs one warmup round at 10% of its measured iteration count,
then seven measured rounds at the full count. A round times every iteration in
one batch; the reported latency is the median per-operation time across the
seven rounds. Throughput is derived from that median as
`1_000_000_000 / median_ns`.

Each iteration releases any owned result: parse results and issue lists are
deinitialized, and string, query and JSON Schema buffers are freed. The email
predicate and date-time parsing are allocation-free. No decoded data
accumulates between iterations. Any invalid fixture or failed validation aborts
the run instead of silently benchmarking an error path.

## Measured results

On Windows 11, Zig 0.17.0, x86_64, with `ReleaseFast` and
`std.heap.smp_allocator`:

```text
zigantic benchmarks
zig 0.17.0 | x86_64-windows | ReleaseFast | smp_allocator
7 measured rounds, 1 warmup round(s); median reported

benchmark                    iterations   median ns/op  min ns/op  max ns/op  ops/sec
json_model_parse                 20000           954        922       1069   1048218
json_nested_parse                20000          1056       1043       1311    946969
integer_parse                   200000           261        250        287   3831417
json_model_stringify             20000           105        101        111   9523809
query_model_parse                20000           785        774        901   1273885
form_model_parse                 20000           681        666        691   1468428
query_model_stringify            20000           270        268        297   3703703
json_schema_generate              5000           549        533        968   1821493
typed_validate                  100000           171        166        202   5847953
email_validator                1000000            41         40         48  24390243
datetime_parse                  500000            23         21         23  43478260
```

These numbers are a snapshot, not a guarantee. Hardware, allocator, build mode
and Zig version all matter, so reproduce them locally before drawing
conclusions. The min and max columns show the spread across measured rounds.

## What dominates the cost

- **JSON model parsing** builds a `std.json` tree, allocates the result arena and
  copies every decoded string. Validation predicates are a small part of the
  total.
- **Nested parsing** adds a second object map, path construction and an
  additional field pass, which is why it is measurably slower than the flat
  model.
- **Integer parsing** is already close to the floor for this API: it still
  creates a result arena and issue list even though the payload is one byte.
- **Serialization** writes directly into an allocating writer without building
  an intermediate JSON tree, making it the cheapest JSON operation.
- **Query and form parsing** borrow key and value text that needs no
  percent-decoding, decode only escaped components into the result arena and
  build a synthetic JSON object before validation.
- **Query serialization** allocates one output buffer and encodes each field in
  order, so it is substantially cheaper than query parsing.
- **JSON Schema generation** serializes the complete document and its
  definitions into an allocating writer on every call.
- **Typed validation** allocates an issue list even when no issues are found,
  because the caller owns and frees the result.
- **The email predicate** is allocation-free; its measurement includes the
  rotating input lookup used to keep the call data-dependent.
- **Date-time parsing** is allocation-free and only performs calendar and
  offset checks.

## Measuring your own workload

Use the same allocator you use in production, and free every result. For a
server, that usually means an arena or a general-purpose allocator rather than
`page_allocator`, which pays a system call per mapping.

Pure predicates in `z.validators` allocate nothing, so they can be benchmarked
without any schema or result setup:

```zig
const start = std.Io.Clock.Timestamp.now(io, .awake);
for (0..iterations) |_| _ = z.validators.isEmail("ada@example.com");
const elapsed = start.durationTo(std.Io.Clock.Timestamp.now(io, .awake));
```

`std.Io.Clock.Timestamp` is the Zig 0.17 replacement for the removed
`std.time.Timer`.

`zig build test-all` runs the tests, every example and this benchmark suite.
