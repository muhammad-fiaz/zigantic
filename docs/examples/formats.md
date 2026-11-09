---
title: Formats
description: Validate emails, HTTPS URLs, UUIDs, IPv4 addresses and ISO 8601 timestamps, and call the allocation-free zigantic format predicates directly.
keywords: zigantic formats, zig email validator, uuid validation, ipv4, iso 8601, credit card luhn
---

# Formats

Every format is a normal string schema with an extra predicate attached, so it
also accepts the `z.string` options such as length and trimming. The same
predicates are exported individually through `z.validators`.

## The schema

```zig
const Contact = struct {
    email: []const u8,
    website: []const u8,
    identifier: []const u8,
    address: []const u8,
    expires: []const u8,
};

const ContactSchema = z.object(Contact, .{
    .email = z.email(.{}),
    .website = z.httpsUrl(.{}),
    .identifier = z.uuid(.{}),
    .address = z.ipv4(.{}),
    .expires = z.isoDateTime(.{}),
}, .{});
```

## The program

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const document =
        \\{"email":"ada@example.com","website":"https://example.com","identifier":"550e8400-e29b-41d4-a716-446655440000","address":"192.168.0.1","expires":"2027-01-01T09:00:00Z"}
    ;

    var result = try z.parse(ContactSchema, allocator, document, .{});
    defer result.deinit();
    std.debug.print("contact valid: {any}\n", .{result.ok()});

    const checks = [_]struct { name: []const u8, ok: bool }{
        .{ .name = "email", .ok = z.validators.isEmail("user+tag@example.co.uk") },
        .{ .name = "ipv6", .ok = z.validators.isIpv6("2001:db8::1") },
        .{ .name = "semver", .ok = z.validators.isSemver("1.2.3-rc.1") },
        .{ .name = "credit card", .ok = z.validators.isCreditCard("4242 4242 4242 4242") },
        .{ .name = "iso duration", .ok = z.validators.isIsoDuration("PT30M") },
    };
    for (checks) |check| {
        std.debug.print("{s}: {any}\n", .{ check.name, check.ok });
    }
}
```

## Output

```text
contact valid: true
email: true
ipv6: true
semver: true
credit card: true
iso duration: true
```

## What to notice

- Formats are validated during decoding as `E006: invalid format`, with the
  format name as the expected value (`email address`, `UUID`, `IPv4 address`,
  `ISO 8601 date-time`).
- `httpsUrl` requires the `https` scheme while `url` accepts any absolute scheme
  with a host.
- `creditCard` ignores spaces and hyphens and verifies the Luhn checksum;
  `isCreditCard` is the underlying predicate.
- `isIsoDateTime` checks the calendar (month lengths, leap years) rather than
  only the shape of the string.
- Predicates take `[]const u8` and allocate nothing, so they are safe to use in
  hot paths, guards and `refine` callbacks.
- Every format constructor takes the full `z.StringConfig`, so
  `z.uuid(.{ .description = "resource id" })` documents the schema without
  changing the check.
