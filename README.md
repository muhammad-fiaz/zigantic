<div align="center">
<img src="docs/public/cover.png" alt="zigantic logo" width="400" />

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
<a href="https://hits.sh/muhammad-fiaz/zigantic/"><img src="https://hits.sh/muhammad-fiaz/zigantic.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>A fast, compile-time schema validation and data parsing library for Zig.</em></p>

<b><a href="https://muhammad-fiaz.github.io/zigantic/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/api/reference.html">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/guide/quick-start.html">Quick Start</a> |
<a href="https://muhammad-fiaz.github.io/zigantic/examples/">Examples</a> |
<a href="CONTRIBUTING.md">Contributing</a></b>

</div>

A fast, compile-time schema validation and data parsing library for Zig, featuring type-safe schema composition, zero-allocation validation, and explicit memory management.

> [!TIP]
> If you build with zigantic, make sure to give it a star ⭐.

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
<summary><strong>Related Zig Projects</strong> (click to expand)</summary>

- For **environment variables and `.env` parsing**, check out [env.zig](https://github.com/muhammad-fiaz/env.zig).
- For **TUI (Terminal User Interface)** support, check out [tui.zig](https://github.com/muhammad-fiaz/tui.zig).
- For **ZON file format** support, check out [zon.zig](https://github.com/muhammad-fiaz/zon.zig).
- For **spinners, loading indicators, and progress bars**, check out [loaders.zig](https://github.com/muhammad-fiaz/loaders.zig).
- For **terminal colors and text styling**, check out [tint.zig](https://github.com/muhammad-fiaz/tint.zig).
- For **Model Context Protocol (MCP)** support, check out [mcp.zig](https://github.com/muhammad-fiaz/mcp.zig).
- For **API framework** support, check out [api.zig](https://github.com/muhammad-fiaz/api.zig).
- For **web framework** support, check out [zix](https://github.com/muhammad-fiaz/zix).
- For **archive handling and compression**, check out [archive.zig](https://github.com/muhammad-fiaz/archive.zig).
- For **compression file formats**, check out [zigx](https://github.com/muhammad-fiaz/zigx).
- For **CUDA** support, check out [cuda.zig](https://github.com/muhammad-fiaz/cuda.zig).
- For **simplified `build.zig` configuration**, check out [buildx.zig](https://github.com/muhammad-fiaz/buildx.zig).
- For **SQLite with a Zig-native implementation**, check out [sqlite.zig](https://github.com/muhammad-fiaz/sqlite.zig).
- For **file downloading**, check out [downloader.zig](https://github.com/muhammad-fiaz/downloader.zig).
- For **update checking and automatic updates**, check out [updater.zig](https://github.com/muhammad-fiaz/updater.zig).
- For **numerical computing**, check out [num.zig](https://github.com/muhammad-fiaz/num.zig).
- For **logging**, check out [logly.zig](https://github.com/muhammad-fiaz/logly.zig).
- For **data validation and serialization**, check out [zigantic](https://github.com/muhammad-fiaz/zigantic).
- For **UUID** support, check out [uuid.zig](https://github.com/muhammad-fiaz/uuid.zig).
- For **key-value database** support, check out [zkv.zig](https://github.com/muhammad-fiaz/zkv.zig).
- For **terminal colors and text styling**, check out [hint.zig](https://github.com/muhammad-fiaz/hint.zig).
- For **Brotli compression**, check out [brotli.zig](https://github.com/muhammad-fiaz/brotli.zig).
- For **Zstandard (Zstd) compression**, check out [zstd.zig](https://github.com/muhammad-fiaz/zstd.zig).
- For **Tree-sitter** integration, check out [tree-sitter.zig](https://github.com/muhammad-fiaz/tree-sitter.zig).
- For **regular expressions**, check out [regex.zig](https://github.com/muhammad-fiaz/regex.zig).

</details>

---

<details>
<summary><strong>Features</strong> (click to expand)</summary>

| Feature | Description |
|---------|-------------|
| **Schemas as types** | Every constructor returns a type exposing `Value`, `kind`, `decode`, `check`, `encode` and `writeJsonSchema`. Composition is resolved at compile time. |
| **Declared models** | `z.object(Model, fields, .{})` binds to a real Zig struct. Unknown fields, type mismatches and uncovered required fields fail the build. |
| **Inferred models** | `z.objectOf(fields, .{})` synthesizes the model with `@Struct`; `z.tuple` uses `@Tuple`; `z.intersection` checks several schemas against one value. |
| **Primitives** | Strings with length, prefix, suffix, contains, trim, case and charset rules; integers with bounds, even and multiple-of checks; floats with bounds and finiteness; booleans, enums, literals and null. |
| **Built-in formats** | Email, URL, HTTPS URL, UUID, ULID, slug, semantic version, phone number, payment card (Luhn), JWT, base64/base64url, hex, hex colour, MAC address, IPv4, IPv6, ISO date, time, date-time and duration. |
| **Objects** | snake_case, camelCase, kebab-case, PascalCase and upper/lower naming policies; field aliases; strict or strip unknown fields; partial models; model defaults. |
| **Collections** | Arrays with minimum, maximum, exact length and uniqueness rules; records backed by `std.array_hash_map.String` with entry and key-length limits. |
| **Unions** | Untagged unions with declaration-order selection, and discriminated unions with literal tags and precise missing/invalid discriminator errors. |
| **Modifiers** | `optional` (absent) and `nullable` (explicit null) kept distinct, compile-time defaults and factories, tolerant fallbacks, refinements, reversible allocation-aware transforms, recursive lazy schemas and typed custom checks. |
| **JSON** | `z.parse` and `z.stringify` build on `std.json`, with duplicate-key policy, unknown-field policy, depth limits and coercion opt-in. |
| **Query strings and forms** | `z.parseQuery`, `z.parseForm` and `z.stringifyQuery` reuse the object schema, enable text coercion, accept nested `a[b]` keys and turn repeated keys into arrays. |
| **JSON Schema** | `z.jsonSchema` emits types, bounds, formats, `required`, `additionalProperties`, and deduplicated `$defs`/`$ref` entries for recursive schemas. |
| **Date and time** | `z.Date`, `z.Time` and `z.DateTime` parse, format and do calendar-correct arithmetic (leap years, month clamping, fixed UTC offsets) without allocating. |
| **Structured errors** | Stable codes and categories, JSONPath-style paths, expected/received text, text or JSON rendering, per-call message overrides and lifecycle hooks. |
| **Typed validation** | `z.validate(S, allocator, value, .{})` checks an already-typed value and returns an owning issue list. No validator session, no `init`/`deinit` pair. |
| **Optional colour** | Error rendering accepts tint capabilities per call: `.none` by default, or `.ansi16`, `.ansi256` and `.trueColor`. Redirected output stays plain. |
| **Predictable ownership** | No hidden allocations during predicate checks; every decoded allocation belongs to the result arena; issues own copies of their strings. |
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
|----------|-----------------|-----------------|--------------|
| **Linux** | Yes | Yes | Yes |
| **Windows** | Yes | Yes | Yes |
| **macOS** | Yes | Yes (Apple Silicon) | Yes |

The library only uses `std`, so any target supported by Zig can host it.
CI cross-compiles and, where the target can run, executes the full test suite.

### Cross-Compilation

```bash
# Build for Linux ARM64 from Windows
zig build -Dtarget=aarch64-linux

# Build for Windows from Linux
zig build -Dtarget=x86_64-windows

# Build for macOS Apple Silicon from Linux
zig build -Dtarget=aarch64-macos

# Run tests under QEMU
zig build test -Dtarget=aarch64-linux-musl -fqemu
```

</details>

---

## Installation

### Method 1: Zig Fetch (Recommended)

**Latest Release (v0.0.4)**

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/0.0.4.tar.gz
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
        .url = "https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/0.0.4.tar.gz",
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

```text
Ada <ada@example.com> in London
{"name":"Ada","email":"ada@example.com","age":36,"address":{"city":"London","postal_code":"12345"}}
```

A failed document produces structured issues instead of an error return:

```text
error[E002]: value is too small
  $.age
    expected: 18..120
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
| `json_model_parse` | JSON | 954 ns/op | **1,048,218 ops/sec** |
| `json_nested_parse` | JSON | 1,056 ns/op | **946,969 ops/sec** |
| `integer_parse` | JSON | 261 ns/op | **3,831,417 ops/sec** |
| `json_model_stringify` | JSON | 105 ns/op | **9,523,809 ops/sec** |
| `query_model_parse` | Query | 785 ns/op | **1,273,885 ops/sec** |
| `form_model_parse` | Forms | 681 ns/op | **1,468,428 ops/sec** |
| `query_model_stringify` | Query | 270 ns/op | **3,703,703 ops/sec** |
| `json_schema_generate` | Schema | 549 ns/op | **1,821,493 ops/sec** |
| `typed_validate` | Validation | 171 ns/op | **5,847,953 ops/sec** |
| `email_validator` | Validation | 41 ns/op | **24,390,243 ops/sec** |
| `datetime_parse` | Date & Time | 23 ns/op | **43,478,260 ops/sec** |

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
