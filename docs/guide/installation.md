---
title: Installation
description: Install zigantic 0.0.5 with zig fetch from the release tarball or the nightly Git URL, and wire the module into build.zig.
keywords: zigantic install, zig fetch, zig build.zig, zig package, zig 0.17 dependency
---

# Installation

Requires Zig **0.17.0** or newer.

## Release installation (recommended)

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigantic/archive/refs/tags/0.0.5.tar.gz
```

## Nightly installation

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zigantic.git
```

`zig fetch --save` records the dependency in `build.zig.zon`. Add the module to
the artifact that uses it:

```zig
const zigantic = b.dependency("zigantic", .{
    .target = target,
    .optimize = optimize,
}).module("zigantic");

exe.root_module.addImport("zigantic", zigantic);
```

The dependency graph includes `tint` for optional colour rendering; `zig` resolves
it from the package manifest. No system libraries or build-time code generation
are required.

## Local development

```bash
zig build test              # unit and integration tests
zig build run-all-examples  # all examples in examples/
zig build bench             # ReleaseFast benchmark
zig build docs              # native Zig API docs in zig-out/docs/api
```
