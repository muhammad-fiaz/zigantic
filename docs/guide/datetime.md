---
title: Date & Time
description: Parse, format and arithmetic on calendar dates, clock times and offset date-times with allocation-free zigantic types.
keywords: zigantic date, zig time, calendar arithmetic, leap year, add months, iso 8601, fixed utc offset
---

# Date and Time

`z.Date`, `z.Time` and `z.DateTime` are plain values. They allocate nothing and
validate the calendar instead of only checking digit positions.

```zig
const date = try z.Date.parse("2024-02-29");
const next = date.addYears(1);          // 2025-02-28, clamped
const weekday = date.weekday();         // .thursday
const elapsed = date.daysUntil(try z.Date.parse("2024-03-02")); // 2
```

`Date` uses the proleptic Gregorian calendar and counts days from 1970-01-01.
`addMonths` and `addYears` clamp to the last valid day of the target month, so a
leap-day anniversary is well defined.

## Date-time values

```zig
const value = try z.DateTime.parse("2024-02-29T23:30:00+02:00");
const later = value.addSeconds(3600);
// 2024-03-01T00:30:00+02:00

var buffer: [40]u8 = undefined;
const text = try later.format(&buffer);
```

`DateTime` stores a fixed `offset_minutes`. `timestamp` converts to Unix seconds
for that offset, and `fromTimestamp` converts back. Time-zone database
transitions (DST changes) are not modelled; supply the offset the producer used.

## Formatting

`format` writes into a caller-provided slice and returns the written bytes:

```zig
var buffer: [16]u8 = undefined;
const text = try date.format(&buffer);
```

It returns `error.NoSpaceLeft` when the buffer is too small. `Date` writes 10
bytes for years `0000..9999` (11 bytes with a leading `-` for negative years,
more for extreme years), `Time` writes 8 bytes, or 18 with nanoseconds, and
`DateTime` writes the date, a `T`, the time and a `Z` or `±HH:MM` offset. Use
the 48-byte buffer the temporal schemas use internally when the exact width is
not important (for example, a 40-byte buffer in this guide's example for
ordinary years).

## Conversion and comparison

| Call | Result |
| --- | --- |
| `Date.daysSinceEpoch()` | signed days since 1970-01-01 |
| `Date.fromDaysSinceEpoch(days)` | inverse conversion |
| `Date.dayOfYear()` | 1-based day within the year |
| `Date.daysUntil(other)` | signed day difference |
| `Date.compare(other)` | `std.math.Order` |
| `Time.addSeconds(n)` | new time plus day carry |
| `DateTime.timestamp()` | Unix seconds adjusted by the offset |
| `DateTime.dateDifference(other)` | signed day difference |

The free functions `z.datetime.isLeapYear(year)` and
`z.datetime.daysInMonth(year, month)` expose the same calendar rules used by the
ISO date validators.

## Relationship to schemas

String schemas such as `z.isoDate(.{})` and `z.isoDateTime(.{})` validate wire
text without converting it. Decode into a schema first, then parse the validated
string when the application needs arithmetic:

```zig
var result = try z.parse(UserSchema, allocator, document, .{});
defer result.deinit();
if (result.value) |user| {
    const created = try z.DateTime.parse(user.created_at);
    const now: i64 = 1_700_000_000;
    const age = created.dateDifference(z.DateTime.fromTimestamp(now, 0));
}
```
