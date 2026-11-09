//! Key naming policies and field alias mapping.
//!
//! Keys are derived at compile time from Zig field names and stored as
//! compile-time constants, so no allocation or runtime string processing is
//! involved. Aliases let a field accept additional input keys while still
//! emitting a single canonical output key.

const std = @import("std");

pub const Policy = enum {
    verbatim,
    camel_case,
    snake_case,
    kebab_case,
    pascal_case,
    lower_case,
    upper_case,
};

pub const Alias = struct {
    field: []const u8,
    keys: []const []const u8,
};

fn wordBreak(c: u8) bool {
    return c == '_' or c == '-' or c == ' ';
}

fn Text(comptime text: []const u8, comptime policy: Policy) type {
    return struct {
        const Built = struct {
            bytes: [512]u8,
            len: usize,
        };

        const built: Built = blk: {
            var out: [512]u8 = undefined;
            @memset(&out, 0);
            var len: usize = 0;
            switch (policy) {
                .verbatim => {
                    @memcpy(out[0..text.len], text);
                    len = text.len;
                },
                .lower_case, .upper_case => {
                    for (text) |c| {
                        out[len] = if (policy == .lower_case) std.ascii.toLower(c) else std.ascii.toUpper(c);
                        len += 1;
                    }
                },
                .snake_case, .kebab_case => {
                    const separator: u8 = if (policy == .snake_case) '_' else '-';
                    var wrote_separator = true;
                    for (text, 0..) |c, index| {
                        if (wordBreak(c)) {
                            if (!wrote_separator and len > 0) {
                                out[len] = separator;
                                len += 1;
                                wrote_separator = true;
                            }
                            continue;
                        }
                        const starts_word = index > 0 and std.ascii.isUpper(c) and std.ascii.isLower(text[index - 1]);
                        if (starts_word and !wrote_separator) {
                            out[len] = separator;
                            len += 1;
                        }
                        out[len] = std.ascii.toLower(c);
                        len += 1;
                        wrote_separator = false;
                    }
                },
                .camel_case, .pascal_case => {
                    var capitalize_next = policy == .pascal_case;
                    var first = true;
                    for (text) |c| {
                        if (wordBreak(c)) {
                            capitalize_next = true;
                            continue;
                        }
                        var out_char = if (capitalize_next) std.ascii.toUpper(c) else c;
                        if (first and policy == .camel_case) out_char = std.ascii.toLower(c);
                        out[len] = out_char;
                        len += 1;
                        first = false;
                        capitalize_next = false;
                    }
                },
            }
            break :blk .{ .bytes = out, .len = len };
        };

        pub const value: []const u8 = built.bytes[0..built.len];
    };
}

/// Applies `policy` to a field name at compile time.
pub fn apply(comptime text: []const u8, comptime policy: Policy) []const u8 {
    return Text(text, policy).value;
}

/// Canonical output key for `field`.
pub fn keyFor(comptime field: []const u8, comptime policy: Policy) []const u8 {
    return apply(field, policy);
}

fn Keys(
    comptime field: []const u8,
    comptime policy: Policy,
    comptime aliases: []const Alias,
) type {
    return struct {
        const count: usize = blk: {
            var total: usize = 1;
            for (aliases) |alias| {
                if (std.mem.eql(u8, alias.field, field)) total += alias.keys.len;
            }
            break :blk total;
        };

        const Built = struct {
            items: [count][]const u8,
        };

        const built: Built = blk: {
            var items: [count][]const u8 = undefined;
            items[0] = apply(field, policy);
            var at: usize = 1;
            for (aliases) |alias| {
                if (!std.mem.eql(u8, alias.field, field)) continue;
                for (alias.keys) |key| {
                    items[at] = key;
                    at += 1;
                }
            }
            break :blk .{ .items = items };
        };

        pub const value: []const []const u8 = built.items[0..count];
    };
}

/// Accepted input keys for `field`: the canonical key first, then aliases.
pub fn inputKeys(
    comptime field: []const u8,
    comptime policy: Policy,
    comptime aliases: []const Alias,
) []const []const u8 {
    return Keys(field, policy, aliases).value;
}

test "naming policies" {
    try std.testing.expectEqualStrings("user_name", apply("user_name", .snake_case));
    try std.testing.expectEqualStrings("user-name", apply("userName", .kebab_case));
    try std.testing.expectEqualStrings("userName", apply("user_name", .camel_case));
    try std.testing.expectEqualStrings("UserName", apply("user_name", .pascal_case));
    try std.testing.expectEqualStrings("USER_NAME", apply("user_name", .upper_case));
    try std.testing.expectEqualStrings("user_name", apply("user_name", .verbatim));
}

test "alias keys" {
    const aliases = [_]Alias{.{ .field = "name", .keys = &.{ "full_name", "username" } }};
    const keys = inputKeys("name", .snake_case, &aliases);
    try std.testing.expectEqual(@as(usize, 3), keys.len);
    try std.testing.expectEqualStrings("name", keys[0]);
    try std.testing.expectEqualStrings("full_name", keys[1]);
    try std.testing.expectEqualStrings("username", keys[2]);

    const other = inputKeys("age", .snake_case, &aliases);
    try std.testing.expectEqual(@as(usize, 1), other.len);
}
