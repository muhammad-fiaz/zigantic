//! # Validation Utilities
//!
//! Validation functions for common patterns.

const std = @import("std");


/// Email format.
pub fn isValidEmail(str: []const u8) bool {
    if (str.len == 0 or str.len > 254) return false;
    var at_index: ?usize = null;
    for (str, 0..) |c, i| {
        if (c == '@') {
            if (at_index != null) return false;
            at_index = i;
        } else if (c == ' ' or c == '\t' or c == '\n' or c == '\r') return false;
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

/// URL format (http/https).
pub fn isValidUrl(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (c == ' ' or c == '\t' or c == '\n' or c == '\r') return false;
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
    var parts: u8 = 0;
    var current: u16 = 0;
    var digits: u8 = 0;
    for (str) |c| {
        if (c == '.') {
            if (digits == 0 or current > 255) return false;
            parts += 1;
            current = 0;
            digits = 0;
        } else if (c >= '0' and c <= '9') {
            current = current * 10 + (c - '0');
            digits += 1;
            if (digits > 3) return false;
        } else return false;
    }
    return parts == 3 and digits > 0 and current <= 255;
}

/// IPv6 address (basic check).
pub fn isIpv6(str: []const u8) bool {
    if (str.len < 2 or str.len > 45) return false;
    var colons: u8 = 0;
    var consecutive_colons: u8 = 0;
    var prev_was_colon = false;
    for (str) |c| {
        if (c == ':') {
            colons += 1;
            if (prev_was_colon) consecutive_colons += 1;
            prev_was_colon = true;
        } else if (std.ascii.isHex(c)) {
            prev_was_colon = false;
        } else return false;
    }
    return colons >= 2 and colons <= 7 and consecutive_colons <= 1;
}

/// Slug format.
pub fn isSlug(str: []const u8) bool {
    if (str.len == 0) return false;
    for (str) |c| {
        if (!((c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '-')) return false;
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
    for (str, 0..) |c, i| {
        if (c == '=') {
            if (i < str.len - 2) return false;
        } else if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '/') return false;
    }
    return true;
}

/// Semantic version.
pub fn isSemver(str: []const u8) bool {
    var dots: u8 = 0;
    var last_was_dot = true;
    for (str) |c| {
        if (c == '.') {
            if (last_was_dot) return false;
            dots += 1;
            last_was_dot = true;
        } else if (c >= '0' and c <= '9') {
            last_was_dot = false;
        } else if (c == '-' or c == '+') {
            if (dots < 2) return false;
            break;
        } else return false;
    }
    return dots >= 2 and !last_was_dot;
}

/// Phone number.
pub fn isPhoneNumber(str: []const u8) bool {
    if (str.len < 7 or str.len > 20) return false;
    var digit_count: usize = 0;
    for (str, 0..) |c, i| {
        if (c >= '0' and c <= '9') {
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
        if (c < '0' or c > '9') return false;
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
        if (c >= 'A' and c <= 'Z') return false;
    }
    return true;
}
pub fn isUppercase(str: []const u8) bool {
    for (str) |c| {
        if (c >= 'a' and c <= 'z') return false;
    }
    return true;
}
pub fn isAscii(str: []const u8) bool {
    for (str) |c| {
        if (c > 127) return false;
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
        if (c != ' ' and c != '\t' and c != '\n' and c != '\r') return false;
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
    if (std.mem.eql(u8, class, "0-9")) return c >= '0' and c <= '9';
    if (std.mem.eql(u8, class, "a-z")) return c >= 'a' and c <= 'z';
    if (std.mem.eql(u8, class, "A-Z")) return c >= 'A' and c <= 'Z';
    if (std.mem.eql(u8, class, "a-zA-Z")) return std.ascii.isAlphabetic(c);
    if (std.mem.eql(u8, class, "0-9a-zA-Z")) return std.ascii.isAlphanumeric(c);
    for (class) |pc| {
        if (pc == c) return true;
    }
    return false;
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
