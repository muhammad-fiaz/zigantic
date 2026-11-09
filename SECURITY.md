# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| >= 0.0.4 | :white_check_mark: |
| < 0.0.4  | :x: |

## Reporting a Vulnerability

Do **not** open a public issue for a security vulnerability.

Report privately through
[GitHub Security Advisories](https://github.com/muhammad-fiaz/zigantic/security/advisories/new).
Include:

- the affected version and Zig version;
- a minimal reproducer or schema and input;
- the observed impact (crash, leak, incorrect acceptance, denial of service);
- any suggested fix.

You will receive an acknowledgement, an assessment, and progress updates. Credit
is given with your permission after a fix is released.

## Scope

In scope:

- the library in `src/`;
- the examples in `examples/` and the benchmark in `bench/`;
- build scripts and package metadata.

Out of scope:

- third-party dependencies, including `tint` and the Zig standard library;
- applications built with zigantic;
- the VitePress documentation site.

## Security Properties

zigantic is an input-validation library. It does not perform authentication,
authorization, encryption, or network I/O.

- **Explicit allocation.** Every allocation comes from an allocator supplied by
  the caller. Parsed values live in the result arena and are released by
  `deinit`; there is no global allocator, hidden arena, or background task.
- **Bounded recursion.** `Options.max_depth` limits object, array and lazy
  recursion during decoding, so hostile nesting is reported instead of
  exhausting the stack.
- **Duplicate keys.** `Options.duplicates = .reject` scans the complete document
  before decoding and reports `E009` at the exact nested path. `.first` and
  `.last` are explicit opt-ins.
- **No permissive fallbacks.** A schema that cannot encode or describe itself
  returns `error.Unsupported`; it never silently serializes incomplete data.
- **Input is copied.** Decoded strings and records are copied into the result
  arena. The input buffer does not outlive the call and may be reused
  immediately.
- **Format checks are structural.** Email, URL, UUID, IP, JWT, card and
  date/time predicates are allocation-free and do not trust prefixes or
  substrings alone.

## Operational Guidance

1. Treat validation as one layer. Enforce transport limits, authentication,
   authorization, and rate limits in the application.
2. Do not use a permissive `unknown_fields = .strip` policy to hide schema
   drift; log rejected fields instead.
3. Keep `.duplicates = .reject` unless the upstream producer is trusted to send
   unique keys.
4. Do not put secrets in schemas, error messages, or JSON Schema descriptions;
   generated schemas are intended to be public documentation.
5. Free every `ParseResult` and every `IssueList` with `deinit`. Reusing a
   result after `deinit` is undefined behaviour.
6. Validate dates and times before converting them to timestamps; the library
   rejects invalid calendar dates but does not model time-zone database rules.

## Dependency and Build Integrity

CI builds and tests the package on Linux, Windows, and macOS with Zig 0.17.0,
including cross-compiled targets. The repository contains no generated code,
install scripts, or network calls at build time. `zig build docs`, `zig build
bench`, and `zig build run-all-examples` run locally and require no credentials.

Thank you for helping keep zigantic and its users safe.
