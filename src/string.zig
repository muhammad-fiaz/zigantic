//! String schemas and the built-in format shortcuts.

const std = @import("std");
const schema = @import("schema.zig");
const validators = @import("validators.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

pub const Case = enum { any, lower, upper };

pub const Charset = enum { any, ascii, printable, alphabetic, alphanumeric, numeric, hex };

pub const Format = enum {
    none,
    email,
    url,
    https_url,
    uuid,
    ulid,
    slug,
    semver,
    phone,
    credit_card,
    jwt,
    base64,
    base64url,
    hex,
    hex_color,
    mac_address,
    ipv4,
    ipv6,
    iso_date,
    iso_time,
    iso_date_time,
    iso_duration,
};

pub const Config = struct {
    min: usize = 0,
    max: usize = std.math.maxInt(usize),
    len: ?usize = null,
    prefix: ?[]const u8 = null,
    suffix: ?[]const u8 = null,
    contains: ?[]const u8 = null,
    trim: bool = false,
    case: Case = .any,
    charset: Charset = .any,
    format: Format = .none,
    description: []const u8 = "",
};

fn charsetValid(comptime charset: Charset, text: []const u8) bool {
    return switch (charset) {
        .any => true,
        .ascii => blk: {
            for (text) |c| {
                if (!std.ascii.isAscii(c)) break :blk false;
            }
            break :blk true;
        },
        .printable => blk: {
            for (text) |c| {
                if (!std.ascii.isPrint(c)) break :blk false;
            }
            break :blk true;
        },
        .alphabetic => blk: {
            for (text) |c| {
                if (!std.ascii.isAlphabetic(c)) break :blk false;
            }
            break :blk true;
        },
        .alphanumeric => blk: {
            for (text) |c| {
                if (!std.ascii.isAlphanumeric(c)) break :blk false;
            }
            break :blk true;
        },
        .numeric => blk: {
            for (text) |c| {
                if (!std.ascii.isDigit(c)) break :blk false;
            }
            break :blk true;
        },
        .hex => blk: {
            for (text) |c| {
                if (!std.ascii.isHex(c)) break :blk false;
            }
            break :blk true;
        },
    };
}

fn caseValid(comptime case: Case, text: []const u8) bool {
    return switch (case) {
        .any => true,
        .lower => blk: {
            for (text) |c| {
                if (std.ascii.isUpper(c)) break :blk false;
            }
            break :blk true;
        },
        .upper => blk: {
            for (text) |c| {
                if (std.ascii.isLower(c)) break :blk false;
            }
            break :blk true;
        },
    };
}

fn formatValid(comptime format: Format, text: []const u8) bool {
    return switch (format) {
        .none => true,
        .email => validators.isEmail(text),
        .url => validators.isUrl(text),
        .https_url => validators.isHttpsUrl(text),
        .uuid => validators.isUuid(text),
        .ulid => validators.isUlid(text),
        .slug => validators.isSlug(text),
        .semver => validators.isSemver(text),
        .phone => validators.isPhoneNumber(text),
        .credit_card => validators.isCreditCard(text),
        .jwt => validators.isJwt(text),
        .base64 => validators.isBase64(text),
        .base64url => validators.isBase64Url(text),
        .hex => validators.isHex(text),
        .hex_color => validators.isHexColor(text),
        .mac_address => validators.isMacAddress(text),
        .ipv4 => validators.isIpv4(text),
        .ipv6 => validators.isIpv6(text),
        .iso_date => validators.isIsoDate(text),
        .iso_time => validators.isIsoTime(text),
        .iso_date_time => validators.isIsoDateTime(text),
        .iso_duration => validators.isIsoDuration(text),
    };
}

fn expectedFormat(comptime format: Format) []const u8 {
    return switch (format) {
        .none => "string",
        .email => "email address",
        .url => "absolute URL",
        .https_url => "HTTPS URL",
        .uuid => "UUID",
        .ulid => "ULID",
        .slug => "kebab-case slug",
        .semver => "semantic version",
        .phone => "phone number",
        .credit_card => "payment card number",
        .jwt => "JSON Web Token",
        .base64 => "base64 text",
        .base64url => "base64url text",
        .hex => "even-length hexadecimal text",
        .hex_color => "hex colour",
        .mac_address => "MAC address",
        .ipv4 => "IPv4 address",
        .ipv6 => "IPv6 address",
        .iso_date => "ISO 8601 date",
        .iso_time => "ISO 8601 time",
        .iso_date_time => "ISO 8601 date-time",
        .iso_duration => "ISO 8601 duration",
    };
}

fn jsonSchemaFormat(comptime format: Format) ?[]const u8 {
    return switch (format) {
        .email => "email",
        .url, .https_url => "uri",
        .uuid => "uuid",
        .ipv4 => "ipv4",
        .ipv6 => "ipv6",
        .iso_date => "date",
        .iso_time => "time",
        .iso_date_time => "date-time",
        .iso_duration => "duration",
        else => null,
    };
}

fn expectedLength(comptime config: Config) []const u8 {
    if (config.len) |exact| return std.fmt.comptimePrint("exactly {d} characters", .{exact});
    if (config.max == std.math.maxInt(usize) and config.min == 0) return "any length";
    if (config.max == std.math.maxInt(usize)) return std.fmt.comptimePrint("at least {d} characters", .{config.min});
    return std.fmt.comptimePrint("{d}..{d} characters", .{ config.min, config.max });
}

fn checkText(comptime config: Config, state: *State, value: []const u8, path: []const u8) DecodeError!void {
    if (value.len < config.min or value.len > config.max or (config.len != null and value.len != config.len.?)) {
        const received = try schema.quote(state, value);
        return schema.failCode(state, if (value.len < config.min) .too_small else if (config.len != null and value.len != config.len.?) .length_mismatch else .too_large, path, received, expectedLength(config));
    }
    if (config.prefix) |prefix| {
        if (!std.mem.startsWith(u8, value, prefix)) {
            return schema.failCode(state, .invalid_value, path, try schema.quote(state, value), std.fmt.comptimePrint("prefix \"{s}\"", .{prefix}));
        }
    }
    if (config.suffix) |suffix| {
        if (!std.mem.endsWith(u8, value, suffix)) {
            return schema.failCode(state, .invalid_value, path, try schema.quote(state, value), std.fmt.comptimePrint("suffix \"{s}\"", .{suffix}));
        }
    }
    if (config.contains) |needle| {
        if (std.mem.find(u8, value, needle) == null) {
            return schema.failCode(state, .invalid_value, path, try schema.quote(state, value), std.fmt.comptimePrint("containing \"{s}\"", .{needle}));
        }
    }
    if (!caseValid(config.case, value)) {
        return schema.failCode(state, .invalid_value, path, try schema.quote(state, value), switch (config.case) {
            .lower => "lowercase text",
            .upper => "uppercase text",
            .any => unreachable,
        });
    }
    if (!charsetValid(config.charset, value)) {
        return schema.failCode(state, .invalid_value, path, try schema.quote(state, value), switch (config.charset) {
            .any => unreachable,
            .ascii => "ASCII text",
            .printable => "printable ASCII text",
            .alphabetic => "alphabetic text",
            .alphanumeric => "alphanumeric text",
            .numeric => "numeric text",
            .hex => "hexadecimal text",
        });
    }
    if (!formatValid(config.format, value)) {
        return schema.failCode(state, .invalid_format, path, try schema.quote(state, value), expectedFormat(config.format));
    }
}

fn withFormat(comptime config: Config, comptime format: Format) Config {
    var result = config;
    result.format = format;
    return result;
}

pub fn string(comptime config: Config) type {
    return struct {
        pub const Value = []const u8;
        pub const kind = schema.Kind.string;
        pub const schema_name = "string";
        pub const is_optional = false;
        pub const has_default = false;

        fn normalize(state: *State, raw: []const u8) DecodeError![]const u8 {
            const text = if (config.trim) std.mem.trim(u8, raw, " \t\r\n") else raw;
            return schema.dupe(state, text);
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const raw = switch (node) {
                .string => |value| value,
                else => {
                    if (!state.options.coerce) {
                        return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), expectedFormat(config.format));
                    }
                    const generated = switch (node) {
                        .integer => |value| try std.fmt.allocPrint(state.arena, "{d}", .{value}),
                        .float => |value| try std.fmt.allocPrint(state.arena, "{d}", .{value}),
                        .bool => |value| @as([]const u8, if (value) "true" else "false"),
                        else => return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), expectedFormat(config.format)),
                    };
                    return decode(state, .{ .string = generated }, path);
                },
            };
            const text = try normalize(state, raw);
            try checkText(config, state, text, path);
            return text;
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            const text = try normalize(state, raw);
            try checkText(config, state, text, path);
            return text;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try checkText(config, state, value, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try state.json.write(value);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("string");
            if (config.len) |exact| {
                try state.json.objectField("minLength");
                try state.json.write(exact);
                try state.json.objectField("maxLength");
                try state.json.write(exact);
            } else {
                if (config.min > 0) {
                    try state.json.objectField("minLength");
                    try state.json.write(config.min);
                }
                if (config.max != std.math.maxInt(usize)) {
                    try state.json.objectField("maxLength");
                    try state.json.write(config.max);
                }
            }
            if (jsonSchemaFormat(config.format)) |format| {
                try state.json.objectField("format");
                try state.json.write(format);
            }
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

pub fn email(comptime config: Config) type {
    return string(withFormat(config, .email));
}

pub fn url(comptime config: Config) type {
    return string(withFormat(config, .url));
}

pub fn httpsUrl(comptime config: Config) type {
    return string(withFormat(config, .https_url));
}

pub fn uuid(comptime config: Config) type {
    return string(withFormat(config, .uuid));
}

pub fn ulid(comptime config: Config) type {
    return string(withFormat(config, .ulid));
}

pub fn slug(comptime config: Config) type {
    return string(withFormat(config, .slug));
}

pub fn semver(comptime config: Config) type {
    return string(withFormat(config, .semver));
}

pub fn phoneNumber(comptime config: Config) type {
    return string(withFormat(config, .phone));
}

pub fn creditCard(comptime config: Config) type {
    return string(withFormat(config, .credit_card));
}

pub fn jwt(comptime config: Config) type {
    return string(withFormat(config, .jwt));
}

pub fn base64(comptime config: Config) type {
    return string(withFormat(config, .base64));
}

pub fn base64Url(comptime config: Config) type {
    return string(withFormat(config, .base64url));
}

pub fn hex(comptime config: Config) type {
    return string(withFormat(config, .hex));
}

pub fn hexColor(comptime config: Config) type {
    return string(withFormat(config, .hex_color));
}

pub fn macAddress(comptime config: Config) type {
    return string(withFormat(config, .mac_address));
}

pub fn ipv4(comptime config: Config) type {
    return string(withFormat(config, .ipv4));
}

pub fn ipv6(comptime config: Config) type {
    return string(withFormat(config, .ipv6));
}

pub fn isoDate(comptime config: Config) type {
    return string(withFormat(config, .iso_date));
}

pub fn isoTime(comptime config: Config) type {
    return string(withFormat(config, .iso_time));
}

pub fn isoDateTime(comptime config: Config) type {
    return string(withFormat(config, .iso_date_time));
}

pub fn isoDuration(comptime config: Config) type {
    return string(withFormat(config, .iso_duration));
}

test "string constraints" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Name = string(.{ .min = 2, .max = 4, .trim = true });
    const name = try Name.decode(&state, .{ .string = "  Ada  " }, "name");
    try std.testing.expectEqualStrings("Ada", name);

    try std.testing.expectError(error.Reported, Name.decode(&state, .{ .string = "A" }, "name"));
    try std.testing.expectEqualStrings("name", list.last().?.path);
    try std.testing.expectEqualStrings("2..4 characters", list.last().?.expected.?);
}

test "format schemas and coercion" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Email = email(.{});
    const address = try Email.decode(&state, .{ .string = "a@example.com" }, "email");
    try std.testing.expectEqualStrings("a@example.com", address);
    try std.testing.expectError(error.Reported, Email.decode(&state, .{ .string = "nope" }, "email"));

    const Text = string(.{});
    try std.testing.expectError(error.Reported, Text.decode(&state, .{ .integer = 7 }, "text"));
    state.options.coerce = true;
    try std.testing.expectEqualStrings("7", try Text.decode(&state, .{ .integer = 7 }, "text"));
}

test "string json schema" {
    const allocator = std.testing.allocator;
    const S = email(.{ .min = 3, .description = "primary address" });
    var buffer: std.Io.Writer.Allocating = .init(allocator);
    defer buffer.deinit();
    var json: std.json.Stringify = .{ .writer = &buffer.writer, .options = .{} };
    var state = schema.SchemaState{ .arena = allocator, .json = &json };
    try S.writeJsonSchema(&state);
    const text = buffer.writer.buffered();
    try std.testing.expect(std.mem.indexOf(u8, text, "\"format\":\"email\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"minLength\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"description\":\"primary address\"") != null);
}
