//! # Validation Utilities
//!
//! Validation functions for common patterns.

const std = @import("std");
const utils = @import("utils.zig");

/// Validates email format (basic RFC-compliant check).
/// Returns true if the string is a valid email address.
pub fn isValidEmail(str: []const u8) bool {
    if (str.len == 0 or str.len > 254) return false;
    var at_index: ?usize = null;
    for (str, 0..) |c, i| {
        if (c == '@') {
            if (at_index != null) return false;
            at_index = i;
        } else if (std.ascii.isWhitespace(c)) return false;
    }
    const at = at_index orelse return false;
    if (at == 0 or at >= str.len - 1) return false;
    const domain = str[at + 1 ..];
    var has_dot = false;
    var last_dot: ?usize = null;
    for (domain, 0..) |c, i| {
        if (c == '.') {
            has_dot = true;
            last_dot = i;
        }
    }
    if (!has_dot) return false;
    if (last_dot) |ld| {
        if (ld >= domain.len - 1) return false;
    }
    return true;
}

/// Validates URL format (http:// or https:// only).
pub fn isValidUrl(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (std.ascii.isWhitespace(c)) return false;
    }
    if (std.mem.startsWith(u8, str, "https://")) return str.len > 8;
    if (std.mem.startsWith(u8, str, "http://")) return str.len > 7;
    return false;
}

/// UUID format.
pub fn isUuid(str: []const u8) bool {
    if (str.len != 36) return false;
    for (str, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            if (c != '-') return false;
        } else {
            if (!std.ascii.isHex(c)) return false;
        }
    }
    return true;
}

/// IPv4 address.
pub fn isIpv4(str: []const u8) bool {
    _ = std.Io.net.Ip4Address.parse(str, 0) catch return false;
    return true;
}

/// IPv6 address (basic check).
pub fn isIpv6(str: []const u8) bool {
    _ = std.Io.net.Ip6Address.parse(str, 0) catch return false;
    return true;
}

/// Slug format.
pub fn isSlug(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (!(std.ascii.isLower(c) or std.ascii.isDigit(c) or c == '-')) return false;
    }
    return str[0] != '-' and str[str.len - 1] != '-';
}

/// Hex string.
pub fn isHexString(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (!std.ascii.isHex(c)) return false;
    }
    return true;
}

/// Base64 format.
pub fn isBase64(str: []const u8) bool {
    if (str.len == 0 or str.len % 4 != 0) return false;
    const decoder = std.base64.standard.Decoder;
    const size = decoder.calcSizeForSlice(str) catch return false;
    var buf_on_stack: [1024]u8 = undefined;
    if (size <= buf_on_stack.len) {
        decoder.decode(buf_on_stack[0..size], str) catch return false;
    } else {
        const temp = std.heap.page_allocator.alloc(u8, size) catch return false;
        defer std.heap.page_allocator.free(temp);
        decoder.decode(temp, str) catch return false;
    }
    return true;
}

/// Semantic version.
pub fn isSemver(str: []const u8) bool {
    return utils.parseSemver(str) != null;
}

/// Phone number.
pub fn isPhoneNumber(str: []const u8) bool {
    if (str.len < 7 or str.len > 20) return false;
    var digit_count: usize = 0;
    for (str, 0..) |c, i| {
        if (std.ascii.isDigit(c)) {
            digit_count += 1;
        } else if (c == '+' and i == 0) {} else if (c == '-' or c == ' ' or c == '(' or c == ')') {} else return false;
    }
    return digit_count >= 7 and digit_count <= 15;
}

/// Credit card (Luhn algorithm).
pub fn isValidCreditCard(str: []const u8) bool {
    if (str.len < 13 or str.len > 19) return false;
    var sum: u32 = 0;
    var double = false;
    var i: usize = str.len;
    while (i > 0) {
        i -= 1;
        const c = str[i];
        if (!std.ascii.isDigit(c)) return false;
        var digit: u32 = c - '0';
        if (double) {
            digit *= 2;
            if (digit > 9) digit -= 9;
        }
        sum += digit;
        double = !double;
    }
    return sum % 10 == 0;
}

/// Hex color code (#RGB, #RRGGBB, RGB, or RRGGBB).
pub fn isHexColor(str: []const u8) bool {
    var hex = str;
    if (hex.len > 0 and hex[0] == '#') hex = hex[1..];
    if (hex.len != 3 and hex.len != 6) return false;
    for (hex) |c| {
        if (!std.ascii.isHex(c)) return false;
    }
    return true;
}

/// MAC address (XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX).
pub fn isMacAddress(str: []const u8) bool {
    if (str.len != 17) return false;
    const separator = str[2];
    if (separator != ':' and separator != '-') return false;
    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        if ((i + 1) % 3 == 0) {
            if (str[i] != separator) return false;
        } else if (!std.ascii.isHex(str[i])) {
            return false;
        }
    }
    return true;
}

/// ISO 8601 date string (YYYY-MM-DD).
pub fn isIsoDate(str: []const u8) bool {
    if (str.len != 10) return false;
    if (str[4] != '-' or str[7] != '-') return false;
    for ([_]usize{ 0, 1, 2, 3, 5, 6, 8, 9 }) |i| {
        if (!std.ascii.isDigit(str[i])) return false;
    }
    return true;
}

/// ISO 8601 datetime string (basic form with optional Z suffix).
pub fn isIsoDateTime(str: []const u8) bool {
    if (str.len < 19) return false;
    if (str[4] != '-' or str[7] != '-') return false;
    if (str[10] != 'T' and str[10] != ' ') return false;
    if (str[13] != ':' or str[16] != ':') return false;
    for ([_]usize{ 0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18 }) |i| {
        if (!std.ascii.isDigit(str[i])) return false;
    }
    return true;
}

/// ISO 3166-1 alpha-2 country code.
pub fn isCountryCode(str: []const u8) bool {
    if (str.len != 2) return false;
    for (str) |c| {
        if (!std.ascii.isAlphabetic(c)) return false;
    }
    return true;
}

/// ISO 4217 currency code.
pub fn isCurrencyCode(str: []const u8) bool {
    if (str.len != 3) return false;
    for (str) |c| {
        if (!std.ascii.isAlphabetic(c)) return false;
    }
    return true;
}

/// Latitude coordinate.
pub fn isLatitude(value: f64) bool {
    return value >= -90.0 and value <= 90.0;
}

/// Longitude coordinate.
pub fn isLongitude(value: f64) bool {
    return value >= -180.0 and value <= 180.0;
}

/// TCP/UDP port number.
pub fn isPort(value: u16) bool {
    return value != 0;
}

/// JSON Web Token format.
pub fn isJwt(str: []const u8) bool {
    var parts: u8 = 0;
    for (str) |c| {
        if (c == '.') parts += 1 else if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') return false;
    }
    return parts == 2;
}

pub fn isAlphanumeric(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isAlphanumeric(c)) return false;
    }
    return true;
}
pub fn isAlpha(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isAlphabetic(c)) return false;
    }
    return true;
}
pub fn isNumeric(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    return true;
}
pub fn isLowercase(str: []const u8) bool {
    for (str) |c| {
        if (std.ascii.isUpper(c)) return false;
    }
    return true;
}
pub fn isUppercase(str: []const u8) bool {
    for (str) |c| {
        if (std.ascii.isLower(c)) return false;
    }
    return true;
}
pub fn isAscii(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isAscii(c)) return false;
    }
    return true;
}
pub fn isPrintable(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isPrint(c)) return false;
    }
    return true;
}
pub fn isEmpty(str: []const u8) bool {
    return str.len == 0;
}
pub fn isBlank(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isWhitespace(c)) return false;
    }
    return true;
}

/// Contains only allowed characters.
pub fn containsOnly(str: []const u8, allowed: []const u8) bool {
    for (str) |c| {
        var found = false;
        for (allowed) |a| {
            if (c == a) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

/// Starts with prefix.
pub fn startsWith(str: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, str, prefix);
}

/// Ends with suffix.
pub fn endsWith(str: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, str, suffix);
}

pub fn matchesPattern(comptime pattern: []const u8, str: []const u8) bool {
    var pat_idx: usize = 0;
    var str_idx: usize = 0;
    while (pat_idx < pattern.len) {
        if (str_idx >= str.len) return false;
        const c = str[str_idx];
        if (pattern[pat_idx] == '[') {
            var class_end: usize = pat_idx + 1;
            while (class_end < pattern.len and pattern[class_end] != ']') class_end += 1;
            if (class_end >= pattern.len) return false;
            if (matchesClass(pattern[pat_idx + 1 .. class_end], c)) {
                str_idx += 1;
                pat_idx = class_end + 1;
            } else return false;
        } else if (pattern[pat_idx] == '.') {
            str_idx += 1;
            pat_idx += 1;
        } else {
            if (c == pattern[pat_idx]) {
                str_idx += 1;
                pat_idx += 1;
            } else return false;
        }
    }
    return str_idx == str.len;
}

fn matchesClass(class: []const u8, c: u8) bool {
    if (std.mem.eql(u8, class, "0-9")) return std.ascii.isDigit(c);
    if (std.mem.eql(u8, class, "a-z")) return std.ascii.isLower(c);
    if (std.mem.eql(u8, class, "A-Z")) return std.ascii.isUpper(c);
    if (std.mem.eql(u8, class, "a-zA-Z")) return std.ascii.isAlphabetic(c);
    if (std.mem.eql(u8, class, "0-9a-zA-Z")) return std.ascii.isAlphanumeric(c);
    for (class) |pc| {
        if (pc == c) return true;
    }
    return false;
}

/// Validates IBAN (International Bank Account Number) format.
/// Checks length, country prefix, and basic format. Does NOT perform
/// the full MOD-97 checksum (that requires knowing the country spec).
pub fn isIban(str: []const u8) bool {
    if (str.len < 15 or str.len > 34) return false;
    for (str, 0..) |c, i| {
        if (i < 2) {
            if (!std.ascii.isAlphabetic(c)) return false;
        } else if (c == ' ') {
            continue;
        } else {
            if (!std.ascii.isAlphanumeric(c)) return false;
        }
    }
    return true;
}

/// Validates Base58 encoded string (Bitcoin/crypto addresses).
/// Excludes 0, O, I, l to avoid ambiguous characters.
pub fn isBase58(str: []const u8) bool {
    if (str.len == 0) return false;
    const alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    for (str) |c| {
        var found = false;
        for (alphabet) |a| {
            if (c == a) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

/// Validates HSL color string (e.g., "hsl(120, 100%, 50%)" or "hsl(120 100% 50%)").
pub fn isHslColor(str: []const u8) bool {
    if (str.len < 10) return false;
    if (!std.mem.startsWith(u8, str, "hsl(")) return false;
    if (str[str.len - 1] != ')') return false;
    const inner = str[4 .. str.len - 1];
    var parens: u32 = 0;
    var commas: u32 = 0;
    var has_percent = false;
    for (inner) |c| {
        if (c == ',') commas += 1;
        if (c == '%') has_percent = true;
        if (c == '(') parens += 1;
        if (c == ')') {
            if (parens == 0) return false;
            parens -= 1;
        }
    }
    return (commas == 2 or (commas == 0 and std.mem.count(u8, inner, " ") >= 2)) and has_percent;
}

/// Validates ISO 8601 duration string (e.g., "P1Y2M3DT4H5M6S", "P30D", "PT12H").
pub fn isIsoDuration(str: []const u8) bool {
    if (str.len < 2) return false;
    if (str[0] != 'P') return false;
    var i: usize = 1;
    var has_value = false;
    while (i < str.len) {
        const c = str[i];
        if (c == 'T') {
            i += 1;
            continue;
        }
        if (std.ascii.isDigit(c)) {
            has_value = true;
            while (i < str.len and std.ascii.isDigit(str[i])) i += 1;
            if (i < str.len) {
                const unit = str[i];
                if (unit != 'Y' and unit != 'M' and unit != 'W' and unit != 'D' and
                    unit != 'H' and unit != 'M' and unit != 'S')
                    return false;
                i += 1;
            }
        } else {
            return false;
        }
    }
    return has_value;
}

/// Validates cron expression (5 or 6 fields).
/// Fields: minute(0-59) hour(0-23) day(1-31) month(1-12) weekday(0-7).
pub fn isCronExpression(str: []const u8) bool {
    var fields: u32 = 0;
    var in_field = false;
    for (str) |c| {
        if (std.ascii.isWhitespace(c)) {
            if (in_field) fields += 1;
            in_field = false;
        } else {
            in_field = true;
        }
    }
    if (in_field) fields += 1;
    return fields == 5 or fields == 6;
}

/// Validates strong password (min 8 chars, upper+lower+digit+special).
pub fn isStrongPassword(str: []const u8) bool {
    if (str.len < 8) return false;
    var has_upper = false;
    var has_lower = false;
    var has_digit = false;
    var has_special = false;
    for (str) |c| {
        if (std.ascii.isUpper(c)) has_upper = true;
        if (std.ascii.isLower(c)) has_lower = true;
        if (std.ascii.isDigit(c)) has_digit = true;
        if (!std.ascii.isAlphanumeric(c)) has_special = true;
    }
    return has_upper and has_lower and has_digit and has_special;
}

/// Validates that string contains only ASCII printable characters.
pub fn isAsciiPrintable(str: []const u8) bool {
    for (str) |c| {
        if (!std.ascii.isPrint(c)) return false;
    }
    return true;
}

/// Validates ISBN-10 format (digits + optional X at end, with hyphens/spaces).
pub fn isIsbn10(str: []const u8) bool {
    var digits: [10]u8 = undefined;
    var idx: usize = 0;
    for (str) |c| {
        if (c == '-' or c == ' ') continue;
        if (idx >= 10) return false;
        if (std.ascii.isDigit(c)) {
            digits[idx] = c - '0';
        } else if (c == 'X' and idx == 9) {
            digits[idx] = 10;
        } else {
            return false;
        }
        idx += 1;
    }
    if (idx != 10) return false;
    var sum: u32 = 0;
    for (digits, 0..) |d, i| {
        sum += @as(u32, d) * @as(u32, @intCast(10 - i));
    }
    return sum % 11 == 0;
}

/// Validates ISBN-13 format (13 digits, with hyphens/spaces).
pub fn isIsbn13(str: []const u8) bool {
    var digits: [13]u8 = undefined;
    var idx: usize = 0;
    for (str) |c| {
        if (c == '-' or c == ' ') continue;
        if (idx >= 13) return false;
        if (!std.ascii.isDigit(c)) return false;
        digits[idx] = c - '0';
        idx += 1;
    }
    if (idx != 13) return false;
    var sum: u32 = 0;
    for (digits, 0..) |d, i| {
        const weight: u32 = if (i % 2 == 0) 1 else 3;
        sum += @as(u32, d) * weight;
    }
    return sum % 10 == 0;
}

/// Validates ASCII-only alphabetic string (no digits, no special chars).
pub fn isAsciiAlpha(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (!std.ascii.isAlphabetic(c)) return false;
    }
    return true;
}

test "isValidEmail - valid" {
    try std.testing.expect(isValidEmail("user@example.com"));
    try std.testing.expect(isValidEmail("user.name@example.com"));
    try std.testing.expect(isValidEmail("user+tag@example.co.uk"));
}

test "isValidEmail - invalid" {
    try std.testing.expect(!isValidEmail(""));
    try std.testing.expect(!isValidEmail("userexample.com"));
    try std.testing.expect(!isValidEmail("@example.com"));
    try std.testing.expect(!isValidEmail("user@"));
    try std.testing.expect(!isValidEmail("user@example"));
}

test "isValidUrl - valid" {
    try std.testing.expect(isValidUrl("http://example.com"));
    try std.testing.expect(isValidUrl("https://example.com"));
    try std.testing.expect(isValidUrl("https://example.com/path?q=1"));
}

test "isValidUrl - invalid" {
    try std.testing.expect(!isValidUrl(""));
    try std.testing.expect(!isValidUrl("example.com"));
    try std.testing.expect(!isValidUrl("ftp://example.com"));
    try std.testing.expect(!isValidUrl("http://"));
}

test "isUuid - valid" {
    try std.testing.expect(isUuid("550e8400-e29b-41d4-a716-446655440000"));
    try std.testing.expect(isUuid("123e4567-e89b-12d3-a456-426614174000"));
}

test "isUuid - invalid" {
    try std.testing.expect(!isUuid(""));
    try std.testing.expect(!isUuid("550e8400e29b41d4a716446655440000"));
    try std.testing.expect(!isUuid("invalid-uuid"));
}

test "isIpv4 - valid" {
    try std.testing.expect(isIpv4("192.168.1.1"));
    try std.testing.expect(isIpv4("0.0.0.0"));
    try std.testing.expect(isIpv4("255.255.255.255"));
}

test "isIpv4 - invalid" {
    try std.testing.expect(!isIpv4("256.1.1.1"));
    try std.testing.expect(!isIpv4("192.168.1"));
    try std.testing.expect(!isIpv4("192.168.1.1.1"));
}

test "isSlug - valid" {
    try std.testing.expect(isSlug("hello-world"));
    try std.testing.expect(isSlug("abc123"));
    try std.testing.expect(isSlug("a"));
}

test "isSlug - invalid" {
    try std.testing.expect(!isSlug("-hello"));
    try std.testing.expect(!isSlug("hello-"));
    try std.testing.expect(!isSlug("Hello"));
}

test "isHexString" {
    try std.testing.expect(isHexString("0123456789abcdef"));
    try std.testing.expect(isHexString("ABCDEF"));
    try std.testing.expect(!isHexString("xyz"));
}

test "isHexColor" {
    try std.testing.expect(isHexColor("#ff5733"));
    try std.testing.expect(isHexColor("ff5733"));
    try std.testing.expect(isHexColor("#f53"));
    try std.testing.expect(!isHexColor("#ff57"));
}

test "isMacAddress" {
    try std.testing.expect(isMacAddress("00:1A:2B:3C:4D:5E"));
    try std.testing.expect(isMacAddress("00-1A-2B-3C-4D-5E"));
    try std.testing.expect(!isMacAddress("001A:2B:3C:4D:5E"));
}

test "isIsoDate and isIsoDateTime" {
    try std.testing.expect(isIsoDate("2024-01-15"));
    try std.testing.expect(!isIsoDate("2024-1-15"));
    try std.testing.expect(isIsoDateTime("2024-01-15T10:30:00Z"));
    try std.testing.expect(isIsoDateTime("2024-01-15 10:30:00"));
    try std.testing.expect(!isIsoDateTime("2024-01-15"));
}

test "isCountryCode and isCurrencyCode" {
    try std.testing.expect(isCountryCode("US"));
    try std.testing.expect(!isCountryCode("USA"));
    try std.testing.expect(isCurrencyCode("USD"));
    try std.testing.expect(!isCurrencyCode("US"));
}

test "isLatitude isLongitude isPort" {
    try std.testing.expect(isLatitude(45.0));
    try std.testing.expect(!isLatitude(120.0));
    try std.testing.expect(isLongitude(-75.0));
    try std.testing.expect(!isLongitude(200.0));
    try std.testing.expect(isPort(443));
    try std.testing.expect(!isPort(0));
}

test "isSemver" {
    try std.testing.expect(isSemver("1.2.3"));
    try std.testing.expect(isSemver("0.0.1"));
    try std.testing.expect(isSemver("1.0.0-alpha"));
    try std.testing.expect(!isSemver("1.2"));
}

test "isPhoneNumber" {
    try std.testing.expect(isPhoneNumber("+1234567890"));
    try std.testing.expect(isPhoneNumber("123-456-7890"));
    try std.testing.expect(!isPhoneNumber("123"));
}

test "isJwt" {
    try std.testing.expect(isJwt("header.payload.signature"));
    try std.testing.expect(!isJwt("invalid"));
}

test "isAlphanumeric" {
    try std.testing.expect(isAlphanumeric("abc123"));
    try std.testing.expect(!isAlphanumeric("abc-123"));
}

test "isAlpha" {
    try std.testing.expect(isAlpha("hello"));
    try std.testing.expect(!isAlpha("hello123"));
}

test "isNumeric" {
    try std.testing.expect(isNumeric("12345"));
    try std.testing.expect(!isNumeric("123.45"));
}

test "isLowercase" {
    try std.testing.expect(isLowercase("hello"));
    try std.testing.expect(!isLowercase("Hello"));
}

test "isUppercase" {
    try std.testing.expect(isUppercase("HELLO"));
    try std.testing.expect(!isUppercase("Hello"));
}

test "isBlank" {
    try std.testing.expect(isBlank("   "));
    try std.testing.expect(isBlank("\t\n"));
    try std.testing.expect(!isBlank("a"));
}

test "containsOnly" {
    try std.testing.expect(containsOnly("aab", "ab"));
    try std.testing.expect(!containsOnly("abc", "ab"));
}

test "matchesPattern" {
    try std.testing.expect(matchesPattern("[0-9][0-9][0-9]", "123"));
    try std.testing.expect(matchesPattern("[a-z][0-9]", "a1"));
    try std.testing.expect(!matchesPattern("[0-9][0-9][0-9]", "12"));
    try std.testing.expect(!matchesPattern("[0-9][0-9][0-9]", "abc"));
}

test "matchesPattern - phone" {
    const pattern = "[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]";
    try std.testing.expect(matchesPattern(pattern, "123-4567"));
    try std.testing.expect(!matchesPattern(pattern, "1234567"));
}

test "isIban" {
    try std.testing.expect(isIban("DE89370400440532013000"));
    try std.testing.expect(isIban("GB29NWBK60161331926819"));
    try std.testing.expect(!isIban("DE89"));
    try std.testing.expect(!isIban(""));
}

test "isBase58" {
    try std.testing.expect(isBase58("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"));
    try std.testing.expect(isBase58("3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy"));
    try std.testing.expect(!isBase58("0OIl"));
    try std.testing.expect(!isBase58(""));
}

test "isHslColor" {
    try std.testing.expect(isHslColor("hsl(120, 100%, 50%)"));
    try std.testing.expect(isHslColor("hsl(0, 0%, 100%)"));
    try std.testing.expect(!isHslColor("rgb(255, 0, 0)"));
    try std.testing.expect(!isHslColor("hsl(120)"));
}

test "isIsoDuration" {
    try std.testing.expect(isIsoDuration("P1Y2M3DT4H5M6S"));
    try std.testing.expect(isIsoDuration("P30D"));
    try std.testing.expect(isIsoDuration("PT12H30M"));
    try std.testing.expect(!isIsoDuration("1Y2M"));
    try std.testing.expect(!isIsoDuration("P"));
}

test "isCronExpression" {
    try std.testing.expect(isCronExpression("0 12 * * *"));
    try std.testing.expect(isCronExpression("30 4 1,15 * *"));
    try std.testing.expect(isCronExpression("0 0 * * 0"));
    try std.testing.expect(!isCronExpression("0 12 *"));
}

test "isStrongPassword" {
    try std.testing.expect(isStrongPassword("P@ssw0rd!"));
    try std.testing.expect(isStrongPassword("MyStr0ng!Pass"));
    try std.testing.expect(!isStrongPassword("password"));
    try std.testing.expect(!isStrongPassword("12345678"));
    try std.testing.expect(!isStrongPassword("short"));
}

test "isAsciiPrintable" {
    try std.testing.expect(isAsciiPrintable("Hello, World!"));
    try std.testing.expect(isAsciiPrintable("Test 123 !@#"));
    try std.testing.expect(!isAsciiPrintable("Hello\x00"));
    try std.testing.expect(!isAsciiPrintable("tab\there"));
}

test "isIsbn10" {
    try std.testing.expect(isIsbn10("0-306-40615-2"));
    try std.testing.expect(isIsbn10("007462542X"));
    try std.testing.expect(!isIsbn10("0-306-40615-0"));
    try std.testing.expect(!isIsbn10("1234567890"));
}

test "isIsbn13" {
    try std.testing.expect(isIsbn13("978-0-306-40615-7"));
    try std.testing.expect(isIsbn13("9780074625422"));
    try std.testing.expect(!isIsbn13("978-0-306-40615-0"));
}

test "isAsciiAlpha" {
    try std.testing.expect(isAsciiAlpha("Hello"));
    try std.testing.expect(isAsciiAlpha("ABCdef"));
    try std.testing.expect(!isAsciiAlpha("Hello123"));
    try std.testing.expect(!isAsciiAlpha(""));
}
