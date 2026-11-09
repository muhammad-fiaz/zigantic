---
title: Validation Types
description: "Every zigantic primitive: string constraints and built-in formats, integer and float bounds, booleans, enums, literals and null."
keywords: zigantic validation types, zig string validation, email format, uuid, ipv4, integer bounds, float bounds, enum schema
---

# Validation Types

This page lists every built-in schema, the options it accepts and the failures
it can produce.

## Strings

`z.string(.{})` is a `[]const u8`. Every format constructor accepts the same
`z.StringConfig`, so a format composes with length and character rules.

| Option | Type | Default | Failure |
| --- | --- | --- | --- |
| `min` | `usize` | `0` | `E002` |
| `max` | `usize` | `maxInt(usize)` | `E003` |
| `len` | `?usize` | `null` | `E004` |
| `prefix` | `?[]const u8` | `null` | `E005` |
| `suffix` | `?[]const u8` | `null` | `E005` |
| `contains` | `?[]const u8` | `null` | `E005` |
| `trim` | `bool` | `false` | none; normalises first |
| `case` | `z.StringCase` | `.any` | `E005` |
| `charset` | `z.StringCharset` | `.any` | `E005` |
| `description` | `[]const u8` | `""` | none; JSON Schema only |

`z.StringCase`: `.any`, `.lower`, `.upper`.

`z.StringCharset`: `.any`, `.ascii`, `.printable`, `.alphabetic`,
`.alphanumeric`, `.numeric`, `.hex`.

```zig
const Handle = z.string(.{
    .min = 3,
    .max = 32,
    .prefix = "@",
    .charset = .alphanumeric,
    .trim = true,
});
```

`trim` removes ASCII whitespace before the length, prefix, suffix, contains,
case, charset and format checks, and the returned slice excludes it.

## Built-in formats

| Constructor | Accepted form | Expected text |
| --- | --- | --- |
| `email` | RFC 5322 subset with dotted domain and alphabetic TLD | `email address` |
| `url` | absolute URL with scheme and host | `absolute URL` |
| `httpsUrl` | absolute URL with the `https` scheme | `HTTPS URL` |
| `uuid` | 8-4-4-4-12 hexadecimal | `UUID` |
| `ulid` | 26 Crockford base32 characters, first `0-7` | `ULID` |
| `slug` | lowercase words separated by single hyphens | `kebab-case slug` |
| `semver` | Semantic Version 2.0.0 | `semantic version` |
| `phoneNumber` | optional `+`, 7-15 digits, separators allowed | `phone number` |
| `creditCard` | 12-19 digits with Luhn checksum | `payment card number` |
| `jwt` | three non-empty base64url segments | `JSON Web Token` |
| `base64` / `base64Url` | strict alphabet and padding | `base64 text` / `base64url text` |
| `hex` | even-length hexadecimal | `even-length hexadecimal text` |
| `hexColor` | `#RGB`, `#RRGGBB`, `#RRGGBBAA` | `hex colour` |
| `macAddress` | six octet pairs with a consistent separator | `MAC address` |
| `ipv4` / `ipv6` | RFC 4291 text form, including `::` and IPv4 tails | `IPv4 address` / `IPv6 address` |
| `isoDate` | `YYYY-MM-DD` with calendar checks | `ISO 8601 date` |
| `isoTime` | `HH:MM[:SS[.fff]][Z|±HH:MM]` | `ISO 8601 time` |
| `isoDateTime` | date, `T` or space, time | `ISO 8601 date-time` |
| `isoDuration` | `P...` with date/time components | `ISO 8601 duration` |

Format failures are `E006`. They are checked after length, prefix/suffix,
contains, case and charset, so the most specific rule wins in order.

`creditCard` accepts spaces and hyphens as separators. `ipv6` accepts IPv4-mapped
and IPv4-compatible tails. `isoDate` rejects `2025-02-29` and accepts
`2024-02-29`.

## Date and time values

The ISO string schemas validate wire text. When an application needs calendar
arithmetic, parse the validated text into `z.Date`, `z.Time` or `z.DateTime`:

```zig
const date = try z.Date.parse("2024-02-29");
const next = date.addYears(1);      // 2025-02-28
const weekday = date.weekday();     // .thursday

const value = try z.DateTime.parse("2024-02-29T23:30:00+02:00");
const later = value.addSeconds(3600);
```

These types are allocation-free, reject invalid calendar dates, clamp month
arithmetic to the target month's last day, and preserve a fixed UTC offset.
`z.datetime.isLeapYear` and `z.datetime.daysInMonth` expose the same rules. See
[Date & Time](/guide/datetime) for formatting, timestamps and comparison.

## Predicates

The same checks are exported without a schema:

```zig
z.validators.isEmail("a@example.com");
z.validators.isIpv6("2001:db8::1");
z.validators.isCreditCard("4242 4242 4242 4242");
z.validators.luhn("4242424242424242");
z.validators.isIsoDuration("PT30M");
```

All predicates take `[]const u8`, allocate nothing and return `bool`. They are
safe in hot paths and in `refine` callbacks.

## Integers

`z.integer(T, .{})` produces any signed or unsigned integer type `T`.

| Option | Type | Default | Failure |
| --- | --- | --- | --- |
| `min` | `?comptime_int` | `null` | `E002` |
| `max` | `?comptime_int` | `null` | `E003` |
| `even` | `bool` | `false` | `E005` |
| `multiple_of` | `?comptime_int` | `null` | `E005` |
| `description` | `[]const u8` | `""` | none |

Bounds must fit `T`; a bound outside the type's range is a compile error. A
value outside `T` is `E016`, a fractional JSON number is `E018`, and a
non-numeric JSON value is `E001`.

```zig
z.integer(i32, .{ .min = -10, .max = 10, .multiple_of = 2 });
z.integer(u8, .{ .even = true });
```

## Floats

`z.float(T, .{})` produces `f16`, `f32`, `f64`, `f80` or `f128`.

| Option | Type | Default | Failure |
| --- | --- | --- | --- |
| `min` | `?comptime_float` | `null` | `E002` |
| `max` | `?comptime_float` | `null` | `E003` |
| `finite` | `bool` | `true` | `E017` |
| `description` | `[]const u8` | `""` | none |

`NaN` and infinities are rejected unless `.finite = false`. Encoding a
non-finite value returns `error.Unsupported`.

## Numeric presets

```zig
z.positiveInt(u16, .{});
z.nonNegativeInt(i64, .{});
z.percentage(f32, .{});
z.probability(f64, .{});
```

Each preset accepts the normal integer or float config, so metadata and extra
constraints compose:

```zig
const Ratio = z.probability(f64, .{ .description = "success ratio" });
```

`positiveInt` keeps `min` at least `1`, `nonNegativeInt` keeps it at least `0`,
`percentage` bounds to `0..100` and `probability` bounds to `0..1`.

## Booleans, enums, literals and null

```zig
z.boolean(.{ .description = "feature flag" });
z.enumType(Role, .{});          // Role is a Zig enum
z.literal("created");           // exact string
z.literal(200);                 // exact integer
z.literal(true);                // exact boolean
z.nullValue(.{});               // void, matches JSON null
```

- `z.boolean` accepts JSON booleans; with `.coerce = true` it also accepts the
  strings `"true"`, `"false"`, `"1"`, `"0"` and the integers `1` and `0`.
- `z.enumType` matches enum member names exactly and reports `E010`.
- `z.literal` reports `E011` with the literal as the expected value.
- `z.nullValue` produces `void` and reports `E001` for any non-null value.
