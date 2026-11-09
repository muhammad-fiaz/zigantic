//! Pure format predicates.
//!
//! Every function is allocation-free, I/O-free and locale-independent. Formats
//! are validated structurally rather than by prefix or substring guessing.
//! Some formats are intentionally strict subsets of their specifications; the
//! documented subset is enforced exactly.

const std = @import("std");
const datetime = @import("datetime.zig");

const max_email_len = 254;
const max_local_len = 64;
const max_domain_label = 63;

fn isAtext(c: u8) bool {
    if (std.ascii.isAlphanumeric(c)) return true;
    return switch (c) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '/', '=', '?', '^', '_', '`', '{', '|', '}', '~' => true,
        else => false,
    };
}

fn validLocalPart(local: []const u8) bool {
    if (local.len == 0 or local.len > max_local_len) return false;
    if (local[0] == '.' or local[local.len - 1] == '.') return false;
    if (std.mem.find(u8, local, "..") != null) return false;
    if (local[0] == '"' and local[local.len - 1] == '"') {
        if (local.len < 2) return false;
        for (local[1 .. local.len - 1]) |c| {
            if (c == '\\' or c == '"') return false;
            if (c < 0x20 or c > 0x7e) return false;
        }
        return true;
    }
    for (local) |c| {
        if (c == '.') continue;
        if (!isAtext(c)) return false;
    }
    return true;
}

fn validDomain(domain: []const u8) bool {
    if (domain.len == 0 or domain.len > max_email_len) return false;
    var labels: usize = 0;
    var it = std.mem.splitScalar(u8, domain, '.');
    var last: []const u8 = "";
    while (it.next()) |label| {
        if (label.len == 0 or label.len > max_domain_label) return false;
        if (label[0] == '-' or label[label.len - 1] == '-') return false;
        for (label) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '-') return false;
        }
        labels += 1;
        last = label;
    }
    if (labels < 2) return false;
    if (last.len < 2) return false;
    for (last) |c| {
        if (!std.ascii.isAlphabetic(c)) return false;
    }
    return true;
}

/// Pragmatic RFC 5322 subset: one unquoted or quoted local part, a dotted
/// domain with at least one alphabetic top-level label.
pub fn isEmail(text: []const u8) bool {
    if (text.len == 0 or text.len > max_email_len) return false;
    for (text) |c| {
        if (c <= 0x20 or c >= 0x7f) return false;
    }
    const at = std.mem.findScalarLast(u8, text, '@') orelse return false;
    if (std.mem.findScalar(u8, text[0..at], '@') != null) return false;
    return validLocalPart(text[0..at]) and validDomain(text[at + 1 ..]);
}

fn validScheme(scheme: []const u8) bool {
    if (scheme.len == 0) return false;
    if (!std.ascii.isAlphabetic(scheme[0])) return false;
    for (scheme[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '-' and c != '.') return false;
    }
    return true;
}

fn parseUrl(text: []const u8) ?std.Uri {
    if (text.len == 0 or text.len > 2048) return null;
    for (text) |c| {
        if (c <= 0x20 or c == 0x7f) return null;
    }
    const uri = std.Uri.parse(text) catch return null;
    if (uri.scheme.len == 0) return null;
    if (!validScheme(uri.scheme)) return null;
    return uri;
}

fn hasHost(uri: std.Uri) bool {
    const host = switch (uri.host orelse return false) {
        .raw => |value| value,
        .percent_encoded => |value| value,
    };
    return host.len > 0;
}

/// Absolute URL with a valid scheme and a non-empty host.
pub fn isUrl(text: []const u8) bool {
    const uri = parseUrl(text) orelse return false;
    return hasHost(uri);
}

/// Absolute URI with a valid scheme. A host is not required, so `urn:isbn:...`
/// and `mailto:...` are accepted.
pub fn isUri(text: []const u8) bool {
    return parseUrl(text) != null;
}

pub fn isHttpsUrl(text: []const u8) bool {
    const uri = parseUrl(text) orelse return false;
    return std.mem.eql(u8, uri.scheme, "https") and hasHost(uri);
}

fn isHexRun(text: []const u8) bool {
    if (text.len == 0) return false;
    for (text) |c| {
        if (!std.ascii.isHex(c)) return false;
    }
    return true;
}

/// RFC 4122 textual form, 8-4-4-4-12 hex digits.
pub fn isUuid(text: []const u8) bool {
    if (text.len != 36) return false;
    const dashes = [_]usize{ 8, 13, 18, 23 };
    for (dashes) |index| {
        if (text[index] != '-') return false;
    }
    var index: usize = 0;
    while (index < text.len) : (index += 1) {
        if (index == 8 or index == 13 or index == 18 or index == 23) continue;
        if (!std.ascii.isHex(text[index])) return false;
    }
    return true;
}

const crockford = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/// ULID: 26 Crockford base32 characters; the first symbol is limited to 0-7.
pub fn isUlid(text: []const u8) bool {
    if (text.len != 26) return false;
    if (text[0] > '7') return false;
    for (text) |c| {
        if (std.mem.findScalar(u8, crockford, std.ascii.toUpper(c)) == null) return false;
    }
    return true;
}

/// Lowercase alphanumeric words separated by single hyphens.
pub fn isSlug(text: []const u8) bool {
    if (text.len == 0 or text.len > 128) return false;
    if (text[0] == '-' or text[text.len - 1] == '-') return false;
    var previous_hyphen = false;
    for (text) |c| {
        if (c == '-') {
            if (previous_hyphen) return false;
            previous_hyphen = true;
            continue;
        }
        if (!std.ascii.isLower(c) and !std.ascii.isDigit(c)) return false;
        previous_hyphen = false;
    }
    return true;
}

/// Semantic Version 2.0.0 through the standard-library parser.
pub fn isSemver(text: []const u8) bool {
    _ = std.SemanticVersion.parse(text) catch return false;
    return true;
}

/// International phone number: optional leading `+`, 7 to 15 digits, with
/// spaces, hyphens, parentheses and dots as separators.
pub fn isPhoneNumber(text: []const u8) bool {
    if (text.len == 0 or text.len > 24) return false;
    var digits: usize = 0;
    var index: usize = 0;
    if (text[0] == '+') index = 1;
    if (index == text.len) return false;
    if (!std.ascii.isDigit(text[index])) return false;
    while (index < text.len) : (index += 1) {
        const c = text[index];
        if (std.ascii.isDigit(c)) {
            digits += 1;
            continue;
        }
        if (c == ' ' or c == '-' or c == '.' or c == '(' or c == ')') continue;
        return false;
    }
    return digits >= 7 and digits <= 15;
}

/// Luhn checksum over an ASCII digit sequence.
pub fn luhn(digits: []const u8) bool {
    if (digits.len == 0) return false;
    var sum: u32 = 0;
    var double = false;
    var index = digits.len;
    while (index > 0) {
        index -= 1;
        if (!std.ascii.isDigit(digits[index])) return false;
        var value: u32 = digits[index] - '0';
        if (double) {
            value *= 2;
            if (value > 9) value -= 9;
        }
        sum += value;
        double = !double;
    }
    return sum % 10 == 0;
}

/// Payment card number: 12 to 19 digits, spaces and hyphens ignored, Luhn valid.
pub fn isCreditCard(text: []const u8) bool {
    var buffer: [19]u8 = undefined;
    var len: usize = 0;
    for (text) |c| {
        if (c == ' ' or c == '-') continue;
        if (!std.ascii.isDigit(c)) return false;
        if (len == buffer.len) return false;
        buffer[len] = c;
        len += 1;
    }
    if (len < 12 or len > 19) return false;
    return luhn(buffer[0..len]);
}

fn base64Valid(text: []const u8, comptime url_safe: bool) bool {
    if (text.len == 0) return false;
    var padding: usize = 0;
    for (text, 0..) |c, index| {
        if (c == '=') {
            if (url_safe) return false;
            padding += 1;
            if (index < text.len -| 2) return false;
            continue;
        }
        if (padding > 0) return false;
        if (std.ascii.isAlphanumeric(c)) continue;
        if (url_safe) {
            if (c != '-' and c != '_') return false;
        } else {
            if (c != '+' and c != '/') return false;
        }
    }
    if (url_safe) return text.len % 4 != 1;
    if (text.len % 4 != 0) return false;
    return padding <= 2;
}

pub fn isBase64(text: []const u8) bool {
    return base64Valid(text, false);
}

pub fn isBase64Url(text: []const u8) bool {
    return base64Valid(text, true);
}

pub fn isHex(text: []const u8) bool {
    return isHexRun(text) and text.len % 2 == 0;
}

pub fn isHexColor(text: []const u8) bool {
    if (text.len == 0 or text[0] != '#') return false;
    const body = text[1..];
    if (body.len != 3 and body.len != 6 and body.len != 8) return false;
    return isHexRun(body);
}

/// Six colon- or hyphen-separated octet pairs, consistently separated.
pub fn isMacAddress(text: []const u8) bool {
    if (text.len != 17) return false;
    const separator = text[2];
    if (separator != ':' and separator != '-') return false;
    var group: usize = 0;
    var index: usize = 0;
    while (index < text.len) : (index += 1) {
        if ((index + 1) % 3 == 0) {
            if (text[index] != separator) return false;
            group += 1;
            continue;
        }
        if (!std.ascii.isHex(text[index])) return false;
    }
    return group == 5;
}

/// JWT compact serialization structure: three non-empty base64url segments.
/// Signature verification is intentionally out of scope.
pub fn isJwt(text: []const u8) bool {
    var parts: usize = 0;
    var it = std.mem.splitScalar(u8, text, '.');
    while (it.next()) |part| {
        parts += 1;
        if (part.len == 0) return false;
        if (!base64Valid(part, true)) return false;
    }
    return parts == 3;
}

pub fn isIpv4(text: []const u8) bool {
    if (text.len < 7 or text.len > 15) return false;
    var groups: usize = 0;
    var it = std.mem.splitScalar(u8, text, '.');
    while (it.next()) |part| {
        if (part.len == 0 or part.len > 3) return false;
        if (part.len > 1 and part[0] == '0') return false;
        for (part) |c| {
            if (!std.ascii.isDigit(c)) return false;
        }
        const value = std.fmt.parseInt(u16, part, 10) catch return false;
        if (value > 255) return false;
        groups += 1;
    }
    return groups == 4;
}

fn countGroups(part: []const u8, allow_ipv4_tail: bool, groups: *usize) bool {
    if (part.len == 0) return true;
    var saw_ipv4 = false;
    var segments = std.mem.splitScalar(u8, part, ':');
    while (segments.next()) |segment| {
        if (saw_ipv4 or segment.len == 0) return false;
        if (std.mem.findScalar(u8, segment, '.') != null) {
            if (!allow_ipv4_tail) return false;
            if (!isIpv4(segment)) return false;
            saw_ipv4 = true;
            groups.* += 2;
            continue;
        }
        if (segment.len > 4) return false;
        for (segment) |c| {
            if (!std.ascii.isHex(c)) return false;
        }
        groups.* += 1;
    }
    return true;
}

/// RFC 4291 textual form, including `::` compression and embedded IPv4 tails.
pub fn isIpv6(text: []const u8) bool {
    if (text.len < 2 or text.len > 45) return false;
    var parts: [2][]const u8 = undefined;
    var count: usize = 0;
    var it = std.mem.splitSequence(u8, text, "::");
    while (it.next()) |part| {
        if (count == 2) return false;
        parts[count] = part;
        count += 1;
    }
    if (count == 2) {
        var groups: usize = 0;
        if (!countGroups(parts[0], false, &groups)) return false;
        if (!countGroups(parts[1], true, &groups)) return false;
        return groups < 8;
    }
    var groups: usize = 0;
    if (!countGroups(text, true, &groups)) return false;
    return groups == 8;
}

fn parseTwoDigits(text: []const u8) ?u8 {
    if (text.len != 2) return null;
    if (!std.ascii.isDigit(text[0]) or !std.ascii.isDigit(text[1])) return null;
    return (text[0] - '0') * 10 + (text[1] - '0');
}

/// Calendar date in `YYYY-MM-DD` form.
pub fn isIsoDate(text: []const u8) bool {
    if (text.len != 10) return false;
    if (text[4] != '-' or text[7] != '-') return false;
    const year_text = text[0..4];
    for (year_text) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    const year = std.fmt.parseInt(u32, year_text, 10) catch return false;
    const month = parseTwoDigits(text[5..7]) orelse return false;
    const day = parseTwoDigits(text[8..10]) orelse return false;
    if (month < 1 or month > 12) return false;
    if (day < 1) return false;
    return day <= datetime.daysInMonth(@intCast(year), month);
}

/// Clock time in `HH:MM[:SS[.fraction]][Z|±HH:MM]` form.
pub fn isIsoTime(text: []const u8) bool {
    if (text.len < 5) return false;
    if (text[2] != ':') return false;
    const hour = parseTwoDigits(text[0..2]) orelse return false;
    const minute = parseTwoDigits(text[3..5]) orelse return false;
    if (hour > 23 or minute > 59) return false;
    var index: usize = 5;
    if (index < text.len and text[index] == ':') {
        const second = parseTwoDigits(text[index + 1 .. index + 3]) orelse return false;
        if (second > 60) return false;
        index += 3;
        if (index < text.len and text[index] == '.') {
            index += 1;
            const start = index;
            while (index < text.len and std.ascii.isDigit(text[index])) index += 1;
            if (index == start) return false;
        }
    }
    if (index == text.len) return true;
    if (text[index] == 'Z' or text[index] == 'z') return index + 1 == text.len;
    if (text[index] != '+' and text[index] != '-') return false;
    if (text.len != index + 6) return false;
    if (text[index + 3] != ':') return false;
    const offset_hour = parseTwoDigits(text[index + 1 .. index + 3]) orelse return false;
    const offset_minute = parseTwoDigits(text[index + 4 .. index + 6]) orelse return false;
    return offset_hour <= 23 and offset_minute <= 59;
}

/// Combined ISO date and time separated by `T` or a space.
pub fn isIsoDateTime(text: []const u8) bool {
    if (text.len < 16) return false;
    const separator = std.mem.findScalar(u8, text, 'T') orelse std.mem.findScalar(u8, text, 't') orelse std.mem.findScalar(u8, text, ' ') orelse return false;
    return isIsoDate(text[0..separator]) and isIsoTime(text[separator + 1 ..]);
}

/// ISO 8601 duration: `P` plus one or more numeric components, optionally a
/// leading `-` for negative durations.
pub fn isIsoDuration(text: []const u8) bool {
    if (text.len < 2) return false;
    var index: usize = 0;
    if (text[0] == '-') index = 1;
    if (index >= text.len or (text[index] != 'P' and text[index] != 'p')) return false;
    index += 1;
    if (index == text.len) return false;

    const designators = "YMWDHS";
    var components: usize = 0;
    var saw_time = false;
    while (index < text.len) {
        if (text[index] == 'T' or text[index] == 't') {
            if (saw_time) return false;
            saw_time = true;
            index += 1;
            if (index == text.len) return false;
            continue;
        }
        const start = index;
        while (index < text.len and std.ascii.isDigit(text[index])) index += 1;
        if (index == start) return false;
        if (index == text.len) return false;
        const unit = std.ascii.toUpper(text[index]);
        if (std.mem.findScalar(u8, designators, unit) == null) return false;
        if (saw_time and (unit == 'Y' or unit == 'W' or unit == 'D')) return false;
        if (!saw_time and (unit == 'H' or unit == 'S')) return false;
        components += 1;
        index += 1;
    }
    return components > 0;
}

test "email validation" {
    try std.testing.expect(isEmail("user.name+tag@example.co.uk"));
    try std.testing.expect(isEmail("\"quoted\"@example.com"));
    try std.testing.expect(!isEmail("user@localhost"));
    try std.testing.expect(!isEmail("user..name@example.com"));
    try std.testing.expect(!isEmail("user@-example.com"));
    try std.testing.expect(!isEmail("@example.com"));
    try std.testing.expect(!isEmail("us er@example.com"));
}

test "url validation" {
    try std.testing.expect(isUrl("https://example.com/path?q=1#frag"));
    try std.testing.expect(isUrl("http://localhost:8080"));
    try std.testing.expect(!isUrl("example.com"));
    try std.testing.expect(!isUrl("https://"));
    try std.testing.expect(!isUrl("1http://example.com"));
    try std.testing.expect(isHttpsUrl("https://example.com"));
    try std.testing.expect(!isHttpsUrl("http://example.com"));
    try std.testing.expect(isUri("urn:isbn:0451450523"));
    try std.testing.expect(isUri("mailto:ada@example.com"));
    try std.testing.expect(!isUri("relative/path"));
}

test "identifiers" {
    try std.testing.expect(isUuid("550e8400-e29b-41d4-a716-446655440000"));
    try std.testing.expect(!isUuid("550e8400e29b41d4a716446655440000"));
    try std.testing.expect(isUlid("01ARZ3NDEKTSV4RRFFQ69G5FAV"));
    try std.testing.expect(!isUlid("81ARZ3NDEKTSV4RRFFQ69G5FAV"));
    try std.testing.expect(isSlug("my-cool-slug-2"));
    try std.testing.expect(!isSlug("-leading"));
    try std.testing.expect(!isSlug("double--hyphen"));
    try std.testing.expect(isSemver("1.2.3-rc.1+build"));
    try std.testing.expect(!isSemver("1.2"));
}

test "network formats" {
    try std.testing.expect(isIpv4("192.168.0.1"));
    try std.testing.expect(!isIpv4("256.1.1.1"));
    try std.testing.expect(!isIpv4("192.168.00.1"));
    try std.testing.expect(isIpv6("2001:db8::1"));
    try std.testing.expect(isIpv6("::1"));
    try std.testing.expect(isIpv6("::ffff:192.168.0.1"));
    try std.testing.expect(!isIpv6("2001:db8:::1"));
    try std.testing.expect(!isIpv6("1:2:3"));
    try std.testing.expect(isMacAddress("00:1A:2B:3C:4D:5E"));
    try std.testing.expect(!isMacAddress("00:1A:2B:3C:4D"));
}

test "dates and durations" {
    try std.testing.expect(isIsoDate("2024-02-29"));
    try std.testing.expect(!isIsoDate("2023-02-29"));
    try std.testing.expect(isIsoTime("23:59:59.500Z"));
    try std.testing.expect(isIsoTime("12:30+02:00"));
    try std.testing.expect(!isIsoTime("24:00"));
    try std.testing.expect(isIsoDateTime("2024-02-29T12:30:00Z"));
    try std.testing.expect(isIsoDuration("P3Y6M4DT12H30M5S"));
    try std.testing.expect(!isIsoDuration("P"));
}

test "payments and encodings" {
    try std.testing.expect(isCreditCard("4242 4242 4242 4242"));
    try std.testing.expect(!isCreditCard("4242 4242 4242 4241"));
    try std.testing.expect(isBase64("SGVsbG8="));
    try std.testing.expect(!isBase64("SGVsbG8"));
    try std.testing.expect(isBase64Url("SGVsbG8"));
    try std.testing.expect(isHexColor("#ff00aa"));
    try std.testing.expect(!isHexColor("#ff00a"));
    try std.testing.expect(isJwt("aGVhZGVy.cGF5bG9hZA.c2ln"));
}
