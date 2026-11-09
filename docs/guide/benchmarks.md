---
title: Benchmarks
description: Run the full zigantic benchmark suite covering JSON, query strings, forms, JSON Schema, typed validation, predicates and date-time parsing.
keywords: zigantic benchmarks, zig json performance, query parsing benchmark, form benchmark, json schema benchmark, validation speed, releasefast, ns per op
---

# Benchmarks

```bash
zig build bench
```

The target builds `bench/benchmark.zig` with `ReleaseFast` and measures
seventeen paths:

- **JSON:** model parsing, nested-object parsing, bounded integer parsing and
  model serialization.
- **Collections and composition:** record, set, tuple, union and recursive
  schema parsing.
- **Query and forms:** query parsing, form parsing and query serialization.
- **Schema and validation:** JSON Schema generation, typed validation and the
  allocation-free `email` predicate.
- **Date and time:** offset date-time and duration parsing.

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
json_model_parse                 20000           905        883        925   1104972
json_nested_parse                20000          1028       1002       1047    972762
integer_parse                   200000           254        247        264   3937007
json_model_stringify             20000           106        102        113   9433962
query_model_parse                20000           766        750        810   1305483
form_model_parse                 20000           673        664        676   1485884
query_model_stringify            20000           244        242        253   4098360
json_schema_generate              5000           542        534        574   1845018
typed_validate                  100000           160        159        164   6250000
email_validator                1000000            36         35         37  27777777
datetime_parse                  500000            23         23         25  43478260
record_parse                     20000           915        910        928   1092896
set_parse                        20000           683        670        714   1464128
tuple_parse                      20000           631        626        641   1584786
union_parse                      20000           673        669        686   1485884
recursive_parse                  10000          1006        977       1039    994035
duration_parse                  500000            18         17         18  55555555

json_model_parse allocation profile: 9 allocations, 6922 bytes, 4 deallocations
```

These numbers are a snapshot, not a guarantee. Hardware, allocator, build mode
and Zig version all matter, so reproduce them locally before drawing
conclusions. The min and max columns show the spread across measured rounds.
The benchmark harness also reports a one-shot allocation profile for the user
model parse; on the same machine it recorded 9 allocations totaling 6922 bytes.

## What dominates the cost

- **JSON model parsing** builds a `std.json` tree, allocates the result arena and
  copies every decoded string. Validation predicates are a small part of the
  total.
- **Nested parsing** adds a second object map, path construction and an
  additional field pass, which is why it is measurably slower than the flat
  model.
- **Records** add map growth and ordered key extraction on top of the same
  per-field checks as flat objects.
- **Sets** pay for the schema decode plus an O(n²) uniqueness comparison across
  already-decoded strings.
- **Tuples** decode position by position with no key lookup, making them
  cheaper than records.
- **Unions** select variants by tag comparison before validation, so a
  discriminated union costs little more than a single object decode.
- **Recursive schemas** decode through `lazy` slots, so each level pays for an
  arena allocation for the node value.
- **Duration parsing** is allocation-free like date-time parsing and only
  scans the component text.
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
