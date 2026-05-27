//! Reusable Utilities and Helper Functions
//!
//! Centralizes common logic used throughout the zigantic library.

const std = @import("std");

/// Strips the 'v' or 'V' prefix from a version string.
///
/// Example: "v0.0.3" -> "0.0.3"
pub fn stripVersionPrefix(tag: []const u8) []const u8 {
    if (tag.len == 0) return tag;
    return if (tag[0] == 'v' or tag[0] == 'V') tag[1..] else tag;
}

/// Attempts to parse a semantic version string.
/// Returns null if parsing fails.
pub fn parseSemver(text: []const u8) ?std.SemanticVersion {
    return std.SemanticVersion.parse(text) catch null;
}

test "stripVersionPrefix" {
    try std.testing.expectEqualStrings("0.0.3", stripVersionPrefix("v0.0.3"));
    try std.testing.expectEqualStrings("0.0.3", stripVersionPrefix("V0.0.3"));
    try std.testing.expectEqualStrings("0.0.3", stripVersionPrefix("0.0.3"));
    try std.testing.expectEqualStrings("", stripVersionPrefix(""));
}

test "parseSemver" {
    const v = parseSemver("1.2.3") orelse return error.TestFailed;
    try std.testing.expectEqual(@as(usize, 1), v.major);
    try std.testing.expectEqual(@as(usize, 2), v.minor);
    try std.testing.expectEqual(@as(usize, 3), v.patch);

    try std.testing.expect(parseSemver("invalid") == null);
}

/// Supported naming policies for automatic field serialization/deserialization.
pub const NamingPolicy = enum {
    none,
    snake_case,
    camelCase,
    kebab_case,
    PascalCase,
};

/// Convert a string to snake_case at compile time.
pub fn toSnakeCase(comptime input: []const u8) []const u8 {
    const static_val = comptime blk: {
        var len = 0;
        for (input, 0..) |c, i| {
            if (std.ascii.isUpper(c)) {
                if (i > 0) len += 1;
            }
            len += 1;
        }
        var buf: [256]u8 = undefined;
        var idx = 0;
        for (input, 0..) |c, i| {
            if (std.ascii.isUpper(c)) {
                if (i > 0) {
                    buf[idx] = '_';
                    idx += 1;
                }
                buf[idx] = std.ascii.toLower(c);
            } else {
                buf[idx] = c;
            }
            idx += 1;
        }
        var result_buf: [len]u8 = undefined;
        @memcpy(&result_buf, buf[0..len]);
        const const_buf = result_buf;
        break :blk const_buf;
    };
    return &static_val;
}

/// Convert a string to camelCase at compile time.
pub fn toCamelCase(comptime input: []const u8) []const u8 {
    const static_val = comptime blk: {
        var len = 0;
        var next_upper = false;
        for (input) |c| {
            if (c == '_' or c == '-') {
                next_upper = true;
            } else {
                len += 1;
            }
        }
        var buf: [256]u8 = undefined;
        var idx = 0;
        next_upper = false;
        for (input) |c| {
            if (c == '_' or c == '-') {
                next_upper = true;
            } else {
                if (next_upper) {
                    buf[idx] = if (std.ascii.isLower(c)) std.ascii.toUpper(c) else c;
                    next_upper = false;
                } else {
                    buf[idx] = c;
                }
                idx += 1;
            }
        }
        var result_buf: [len]u8 = undefined;
        @memcpy(&result_buf, buf[0..len]);
        const const_buf = result_buf;
        break :blk const_buf;
    };
    return &static_val;
}

/// Convert a string to kebab-case at compile time.
pub fn toKebabCase(comptime input: []const u8) []const u8 {
    const static_val = comptime blk: {
        var len = 0;
        for (input, 0..) |c, i| {
            if (std.ascii.isUpper(c)) {
                if (i > 0) len += 1;
            }
            len += 1;
        }
        var buf: [256]u8 = undefined;
        var idx = 0;
        for (input, 0..) |c, i| {
            if (std.ascii.isUpper(c)) {
                if (i > 0) {
                    buf[idx] = '-';
                    idx += 1;
                }
                buf[idx] = std.ascii.toLower(c);
            } else {
                buf[idx] = c;
            }
            idx += 1;
        }
        var result_buf: [len]u8 = undefined;
        @memcpy(&result_buf, buf[0..len]);
        const const_buf = result_buf;
        break :blk const_buf;
    };
    return &static_val;
}

/// Convert a string to PascalCase at compile time.
pub fn toPascalCase(comptime input: []const u8) []const u8 {
    const static_val = comptime blk: {
        const camel = toCamelCase(input);
        if (camel.len == 0) {
            const empty_buf: [0]u8 = undefined;
            break :blk empty_buf;
        }
        var buf: [256]u8 = undefined;
        @memcpy(buf[0..camel.len], camel);
        if (std.ascii.isLower(buf[0])) {
            buf[0] = std.ascii.toUpper(buf[0]);
        }
        var result_buf: [camel.len]u8 = undefined;
        @memcpy(&result_buf, buf[0..camel.len]);
        const const_buf = result_buf;
        break :blk const_buf;
    };
    return &static_val;
}

/// Get compile-time field alias or naming convention mapped name for a struct field.
pub fn getFieldAlias(comptime T: type, comptime field_name: []const u8) []const u8 {
    const is_container = comptime switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => true,
        else => false,
    };
    if (comptime is_container) {
        // 1. Check explicit alias declaration
        if (comptime @hasDecl(T, "zigantic_aliases")) {
            const aliases = T.zigantic_aliases;
            if (comptime @hasField(@TypeOf(aliases), field_name)) {
                return @field(aliases, field_name);
            }
        }
        // 2. Check automatic naming policy
        if (comptime @hasDecl(T, "zigantic_naming")) {
            const policy = T.zigantic_naming;
            return comptime switch (policy) {
                .none => field_name,
                .snake_case => toSnakeCase(field_name),
                .camelCase => toCamelCase(field_name),
                .kebab_case => toKebabCase(field_name),
                .PascalCase => toPascalCase(field_name),
            };
        }
    }
    return field_name;
}

test "comptime naming conventions" {
    try std.testing.expectEqualStrings("user_first_name", toSnakeCase("userFirstName"));
    try std.testing.expectEqualStrings("userFirstName", toCamelCase("user_first_name"));
    try std.testing.expectEqualStrings("user-first-name", toKebabCase("userFirstName"));
    try std.testing.expectEqualStrings("UserFirstName", toPascalCase("user_first_name"));
}
