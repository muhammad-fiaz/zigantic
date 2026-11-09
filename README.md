<div align="center">

<img alt="logo" src="https://github.com/user-attachments/assets/937edc35-81a9-4f34-ae80-518298ef0099" />


<a href="https://muhammad-fiaz.github.io/zigantic/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.17.0-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/zigantic"><img src="https://img.shields.io/github/stars/muhammad-fiaz/zigantic" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/zigantic/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/zigantic" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/zigantic/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/zigantic" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/zigantic"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/zigantic" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/zigantic"><img src="https://img.shields.io/github/license/muhammad-fiaz/zigantic" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/zigantic/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/zigantic/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/zigantic/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/zigantic?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-GitHub-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/github.com/muhammad-fiaz/zigantic/"><img alt="Hits" src="https://hits.sh/github.com/muhammad-fiaz/zigantic.svg"/></a>
<p><em>Compile-time schema validation and data parsing for Zig.</em></p>

<b><a href="https://muhammad-fiaz.github.io/zigantic/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/api/reference.html">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/guide/quick-start.html">Quick Start</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/examples/">Examples</a> |
<a href="CONTRIBUTING.md">Contributing</a></b>

</div>

Compile-time schema validation, parsing, transformation and serialization for
Zig 0.17. Schemas are types, so composition and incompatibility are checked by
the compiler. All allocation is explicit: parsed values live in a per-result
arena released by `deinit`, and no hidden allocator is used.

<details>
<summary><strong>Table of Contents</strong> (click to expand)</summary>

- [Why Use zigantic?](#why-use-zigantic)
- [Prerequisites](#prerequisites)
- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Performance](#performance)
- [Contributing](#contributing)
- [License](#license)

</details>

---

<details>
<summary><strong>Features</strong> (click to expand)</summary>

| Feature | Description |
|---------|-------------|
| **Schemas as types** | Every constructor returns a type exposing `Value`, `kind`, `decode`, `check`, `encode` and `writeJsonSchema`. Composition is resolved at compile time. |
| **Declared models** | `z.object(Model, fields, .{})` binds to a real Zig struct. Unknown fields, type mismatches and uncovered required fields fail the build. |
| **Inferred models** | `z.objectOf(fields, .{})` synthesizes the model with `@Struct`; `z.tuple` uses `@Tuple`; `z.intersection` checks several schemas against one value. |
| **Primitives** | Strings with length, prefix, suffix, contains, trim, case and charset rules; integers and floats with inclusive/exclusive bounds, multiple-of, finiteness and numeric presets; booleans, enums, literals, null, temporal schemas and binary data. |
| **Built-in formats** | Email, URL, HTTPS URL, UUID, ULID, slug, semantic version, phone number, payment card (Luhn), JWT, base64/base64url, hex, hex colour, MAC address, IPv4, IPv6, ISO date, time, date-time and duration. |
| **Objects** | snake_case, camelCase, kebab-case, PascalCase and upper/lower naming policies; field aliases; strict or strip unknown fields; partial models; model defaults. |
| **Collections** | Arrays with minimum, maximum, exact length and uniqueness rules; fixed-length arrays; ordered unique sets; tuples; records backed by `std.array_hash_map.String` with entry and key-length limits. |
| **Unions** | Untagged unions with declaration-order selection, and discriminated unions with literal tags and precise missing/invalid discriminator errors. |
| **Modifiers** | `optional` (absent), `nullable` (explicit null) and `nullish` kept distinct; defaults, factories, fallbacks, refinements, reversible transforms and bidirectional codecs, metadata, recursive lazy schemas and typed custom checks with multiple issues. |
| **JSON** | `z.parse` and `z.stringify` build on `std.json`, with duplicate-key policy, unknown-field policy, depth limits and coercion opt-in. |
| **Query strings and forms** | `z.parseQuery`, `z.parseForm` and `z.stringifyQuery` reuse the object schema, enable text coercion, accept nested `a[b]` keys and turn repeated keys into arrays. |
| **JSON Schema** | `z.jsonSchema` emits types, bounds, formats, `required`, `additionalProperties`, metadata, and deduplicated definitions/references for recursive schemas, targeting Draft 2020-12, 2019-09, 7, 6 or 5. |
| **Date and time** | `z.Date`, `z.Time` and `z.DateTime` parse, format and do calendar-correct arithmetic (leap years, month clamping, fixed UTC offsets) without allocating. |
| **Structured errors** | Stable codes and categories, JSONPath-style paths, expected/received text, text or JSON rendering, per-call message overrides and lifecycle hooks. |
| **Typed validation** | `z.validate(S, allocator, value, .{})` returns an owning issue list; `z.checkFirst(S, value, buffer, .{})` reports the first issue using caller scratch memory without heap allocation. |
| **Optional colour** | Error rendering accepts tint capabilities per call: `.none` by default, or `.ansi16`, `.ansi256` and `.trueColor`. Redirected output stays plain. |
| **Predictable ownership** | No hidden allocations during predicate checks; every decoded allocation belongs to the result arena; issues own copies of their strings; stringify uses a scratch arena for transform encoders. |
| **Cross-platform** | Pure Zig with no system libraries. Builds and tests on Linux, Windows and macOS, including cross-compiled targets. |

</details>

---

<details>
<summary><strong>Prerequisites and Supported Platforms</strong> (click to expand)</summary>

<br>

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Zig** | **0.17.0** (required) | Download from [ziglang.org](https://ziglang.org/download/) |
| **Operating System** | Windows 10+, Linux, macOS | No system libraries required |

> [!IMPORTANT]
> **Zig 0.17.0 is required.** zigantic relies on the 0.17 standard library,
> including `std.Io`, and will not build with older compilers.

---

## Supported Platforms

| Platform | x86_64 (64-bit) | aarch64 (ARM64) | x86 (32-bit) |
|----------|:---------------:|:---------------:|:------------:|
| **Linux** | Yes | Yes | Yes |
| **Windows** | Yes | Yes | Yes |
| **macOS** | Yes | Yes (Apple Silicon) | Yes |

The core library depends only on the Zig standard library. All formats are
textual, so behavior is identical on little- and big-endian targets, and no
64-bit size assumption is made.

### Cross-Compilation

```bash
# Build and run tests for Linux ARM64 (QEMU required)
zig build test -Dtarget=aarch64-linux-musl -fqemu

# Build for Windows 32-bit from Linux
zig build test -Dtarget=x86-windows

# Build tests for macOS Apple Silicon from Linux
zig build test -Dtarget=aarch64-macos -fqemu
```

</details>

---

## Installation

### Method 1: Zig Fetch (Recommended)

**Latest Release (v0.0.5)**

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/0.0.5.tar.gz
```

> [!NOTE]
> **zigantic** requires Zig **0.17.0+**.
>
> For documentation matching older releases, check out that release's tag and
> run `zig build docs` to generate native HTML documentation into
> `zig-out/docs/api`.

<details>
<summary><strong>Method 2: Latest Beta / Development Build</strong> (click to expand)</summary>

Use this for the latest development build from the GitHub `main` branch:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zigantic.git
```

</details>

---

<details>
<summary><strong>Method 3: Manual `build.zig.zon` Configuration</strong> (click to expand)</summary>

```zig
.dependencies = .{
    .zigantic = .{
        .url = "https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/0.0.5.tar.gz",
        .hash = "...", // Run `zig fetch --save <url>` to generate the hash.
    },
},
```

</details>

---

<details>
<summary><strong>Method 4: Local Source Checkout</strong> (click to expand)</summary>

```bash
git clone https://github.com/muhammad-fiaz/zigantic.git
cd zigantic
zig build test
zig build run-all-examples
```

To use a local checkout from another project:

```zig
.dependencies = .{
    .zigantic = .{
        .path = "../zigantic",
    },
},
```

</details>

### Wire into `build.zig`

```zig
const zigantic_dep = b.dependency("zigantic", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zigantic", zigantic_dep.module("zigantic"));
```

## Quick Start

```zig
const std = @import("std");
const z = @import("zigantic");

const Address = struct {
    city: []const u8,
    postal_code: []const u8,
};

const AddressSchema = z.object(Address, .{
    .city = z.string(.{ .min = 1, .max = 80 }),
    .postal_code = z.string(.{ .len = 5, .charset = .numeric }),
}, .{});

const User = struct {
    name: []const u8,
    email: []const u8,
    age: u8,
    address: Address,
};

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1, .trim = true }),
    .email = z.email(.{}),
    .age = z.integer(u8, .{ .min = 18 }),
    .address = AddressSchema,
}, .{});

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const document =
        \\{"name":"Ada","email":"ada@example.com","age":36,"address":{"city":"London","postal_code":"12345"}}
    ;

    var result = try z.parse(UserSchema, allocator, document, .{});
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("{s} <{s}> in {s}\n", .{ user.name, user.email, user.address.city });

        const text = try z.stringify(UserSchema, allocator, user, .{});
        defer allocator.free(text);
        std.debug.print("{s}\n", .{text});
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }
}
```

Output:

```bash
Ada <ada@example.com> in London
{"name":"Ada","email":"ada@example.com","age":36,"address":{"city":"London","postal_code":"12345"}}
```

A failed document produces structured issues instead of an error return:

```bash
error[E002]: value is too small
  $.age
    expected: 18..255
    received: 12
```

Query strings use the same schema:

```zig
var query = try z.parseQuery(UserSchema, allocator, "name=Grace&email=grace%40example.com&age=45", .{});
defer query.deinit();
```

## Performance

Run the benchmarks with:

```bash
zig build bench
```

---

<details>
<summary><strong>Benchmarks</strong> (click to expand)</summary>

Benchmark target: `x86_64-windows`, `ReleaseFast`, `std.heap.smp_allocator`.
Measurements recorded on November 9, 2026 with Zig 0.17.0.

Each benchmark uses one warmup round and seven measured rounds; the table
reports the median latency and throughput derived from it.

| Benchmark | Area | Median Latency | Throughput |
| :--- | :--- | ---: | ---: |
| `json_model_parse` | JSON | 905 ns/op | **1,104,972 ops/sec** |
| `json_nested_parse` | JSON | 1,028 ns/op | **972,762 ops/sec** |
| `integer_parse` | JSON | 254 ns/op | **3,937,007 ops/sec** |
| `json_model_stringify` | JSON | 106 ns/op | **9,433,962 ops/sec** |
| `query_model_parse` | Query | 766 ns/op | **1,305,483 ops/sec** |
| `form_model_parse` | Forms | 673 ns/op | **1,485,884 ops/sec** |
| `query_model_stringify` | Query | 244 ns/op | **4,098,360 ops/sec** |
| `json_schema_generate` | Schema | 542 ns/op | **1,845,018 ops/sec** |
| `typed_validate` | Validation | 160 ns/op | **6,250,000 ops/sec** |
| `email_validator` | Validation | 36 ns/op | **27,777,777 ops/sec** |
| `datetime_parse` | Date & Time | 23 ns/op | **43,478,260 ops/sec** |
| `record_parse` | Collections | 915 ns/op | **1,092,896 ops/sec** |
| `set_parse` | Collections | 683 ns/op | **1,464,128 ops/sec** |
| `tuple_parse` | Collections | 631 ns/op | **1,584,786 ops/sec** |
| `union_parse` | Unions | 673 ns/op | **1,485,884 ops/sec** |
| `recursive_parse` | Recursive | 1,006 ns/op | **994,035 ops/sec** |
| `duration_parse` | Date & Time | 18 ns/op | **55,555,555 ops/sec** |

Operations that return owned data create and free their result, so those numbers
include arena allocation, copying and cleanup. The predicate and date-time
benchmarks are allocation-free. No decoded data accumulates. Hardware,
allocator, build mode and Zig version all affect the result; reproduce locally
before drawing conclusions.

For methodology and analysis, see the
[benchmark guide](https://muhammad-fiaz.github.io/zigantic/guide/benchmarks.html).

**Note:** These are recorded measurements for the specified platform and build
mode, not universal performance guarantees.

</details>

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality at the bottom of the relevant source file
4. Ensure formatting and tests pass:

   ```bash
   zig fmt --check src/ examples/ bench/
   zig build test
   zig build run-all-examples
   ```

5. Submit a pull request

The documentation site lives in `docs/`. Build it locally with:

```bash
cd docs
bun install
bun run build
```

## License

MIT License — see [LICENSE](LICENSE) for details.
