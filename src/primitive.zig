//! Boolean, enum, literal and null schemas.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

/// Compile-time configuration for `boolean`.
/// `description` is emitted in JSON Schema output.
pub const BoolConfig = struct {
    /// JSON Schema `description`, emitted when non-empty.
    description: []const u8 = "",
};

/// Returns a boolean schema; `Value` is `bool`.
/// `decode` accepts JSON booleans, and `"true"`/`"false"`/`"1"`/`"0"` strings and `0`/`1` integers when `coerce` is set; `decodeString` accepts the string forms. Mismatches return `error.Reported`; allocation failure returns `error.OutOfMemory`.
/// The schema type exposes `Value`, `kind`, `schema_name`, `is_optional`, `has_default`, `decode`, `decodeString`, `check`, `encode`, and `writeJsonSchema`.
pub fn boolean(comptime config: BoolConfig) type {
    return struct {
        pub const Value = bool;
        pub const schema_description = config.description;
        pub const kind = schema.Kind.boolean;
        pub const schema_name = "boolean";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            return switch (node) {
                .bool => |value| value,
                .string => |text| blk: {
                    if (!state.options.coerce) {
                        return schema.failCode(state, .type_mismatch, path, try schema.quote(state, text), "boolean");
                    }
                    if (std.mem.eql(u8, text, "true") or std.mem.eql(u8, text, "1")) break :blk true;
                    if (std.mem.eql(u8, text, "false") or std.mem.eql(u8, text, "0")) break :blk false;
                    return schema.fail(state, error.CoercionFailed, path, try schema.quote(state, text), "boolean");
                },
                .integer => |value| blk: {
                    if (!state.options.coerce or (value != 0 and value != 1)) {
                        return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "boolean");
                    }
                    break :blk value == 1;
                },
                else => schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "boolean"),
            };
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (std.mem.eql(u8, raw, "true") or std.mem.eql(u8, raw, "1")) return true;
            if (std.mem.eql(u8, raw, "false") or std.mem.eql(u8, raw, "0")) return false;
            return schema.fail(state, error.CoercionFailed, path, try schema.quote(state, raw), "boolean");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            _ = state;
            _ = value;
            _ = path;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try state.json.write(value);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("boolean");
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

fn EnumNames(comptime E: type) type {
    return struct {
        const names = @typeInfo(E).@"enum".field_names;
        const Built = struct {
            bytes: [1024]u8,
            len: usize,
        };
        const built: Built = blk: {
            var buffer: [1024]u8 = undefined;
            @memset(&buffer, 0);
            var len: usize = 0;
            for (names, 0..) |name, index| {
                if (index > 0) {
                    buffer[len] = ',';
                    buffer[len + 1] = ' ';
                    len += 2;
                }
                @memcpy(buffer[len..][0..name.len], name);
                len += name.len;
            }
            break :blk .{ .bytes = buffer, .len = len };
        };
        pub const value: []const u8 = built.bytes[0..built.len];
    };
}

/// Compile-time configuration for `enumType`.
/// `description` is emitted in JSON Schema output.
pub const EnumConfig = struct {
    /// JSON Schema `description`, emitted when non-empty.
    description: []const u8 = "",
};

/// Returns a schema for enum `E`; `Value` is `E`. `E` must be an enum type or compilation fails.
/// `decode` accepts a JSON string equal to a field name; `decodeString` accepts a field name as raw text. Unknown names return `error.Reported`; allocation failure returns `error.OutOfMemory`.
/// The schema type exposes `Value`, `kind`, `schema_name`, `is_optional`, `has_default`, `decode`, `decodeString`, `check`, `encode`, and `writeJsonSchema`.
pub fn enumType(comptime E: type, comptime config: EnumConfig) type {
    comptime {
        switch (@typeInfo(E)) {
            .@"enum" => {},
            else => @compileError("enumType requires an enum type, got " ++ @typeName(E)),
        }
    }

    return struct {
        pub const Value = E;
        pub const schema_description = config.description;
        pub const kind = schema.Kind.enum_value;
        pub const schema_name = "enum";
        pub const is_optional = false;
        pub const has_default = false;
        pub const expected = EnumNames(E).value;

        fn match(text: []const u8) ?E {
            inline for (@typeInfo(E).@"enum".field_names) |name| {
                if (std.mem.eql(u8, name, text)) return @field(E, name);
            }
            return null;
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const text = switch (node) {
                .string => |value| value,
                else => return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), expected),
            };
            return match(text) orelse schema.failCode(state, .not_in_enum, path, try schema.quote(state, text), expected);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            return match(raw) orelse schema.failCode(state, .not_in_enum, path, try schema.quote(state, raw), expected);
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            _ = state;
            _ = value;
            _ = path;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try state.json.write(@tagName(value));
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("string");
            try state.json.objectField("enum");
            try state.json.beginArray();
            inline for (@typeInfo(E).@"enum".field_names) |name| {
                try state.json.write(name);
            }
            try state.json.endArray();
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

fn literalIsString(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |info| switch (info.size) {
            .slice => info.child == u8,
            .one => switch (@typeInfo(info.child)) {
                .array => |array| array.child == u8,
                else => false,
            },
            else => false,
        },
        else => false,
    };
}

fn literalExpected(comptime value: anytype) []const u8 {
    const T = @TypeOf(value);
    if (comptime literalIsString(T)) return std.fmt.comptimePrint("\"{s}\"", .{value});
    if (T == bool) return if (value) "true" else "false";
    return std.fmt.comptimePrint("{d}", .{value});
}

/// Returns a schema accepting only the comptime `value`; `Value` is `[]const u8` for strings, `i64` for `comptime_int`, otherwise the type of `value`.
/// `value` must be a string, integer, or boolean or compilation fails. `decode` matches the JSON scalar and `decodeString` matches the raw text form; mismatches return `error.Reported`.
/// The schema type exposes `Value`, `kind`, `schema_name`, `is_optional`, `has_default`, `decode`, `decodeString`, `check`, `encode`, and `writeJsonSchema`.
pub fn literal(comptime value: anytype) type {
    const T = @TypeOf(value);
    comptime {
        const supported = switch (@typeInfo(T)) {
            .int, .comptime_int, .bool => true,
            else => literalIsString(T),
        };
        if (!supported) @compileError("literal supports strings, integers and booleans");
    }

    return struct {
        pub const Value = if (literalIsString(T)) []const u8 else if (T == comptime_int) i64 else T;
        pub const kind = schema.Kind.literal;
        pub const schema_name = "literal";
        pub const is_optional = false;
        pub const has_default = false;
        pub const expected = literalExpected(value);

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (comptime literalIsString(T)) {
                if (node == .string and std.mem.eql(u8, node.string, value)) return value;
                return schema.failCode(state, .invalid_literal, path, try schema.describeScalar(state, node), expected);
            }
            if (T == bool) {
                if (node == .bool and node.bool == value) return value;
                return schema.failCode(state, .invalid_literal, path, try schema.describeScalar(state, node), expected);
            }
            if (node == .integer and node.integer == value) return @intCast(value);
            return schema.failCode(state, .invalid_literal, path, try schema.describeScalar(state, node), expected);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (comptime literalIsString(T)) {
                if (std.mem.eql(u8, raw, value)) return value;
                return schema.failCode(state, .invalid_literal, path, try schema.quote(state, raw), expected);
            }
            if (T == bool) {
                if ((std.mem.eql(u8, raw, "true") and value) or (std.mem.eql(u8, raw, "false") and !value)) return value;
                return schema.failCode(state, .invalid_literal, path, try schema.quote(state, raw), expected);
            }
            const IntT = if (T == comptime_int) i64 else T;
            const parsed = std.fmt.parseInt(IntT, raw, 10) catch {
                return schema.failCode(state, .invalid_literal, path, try schema.quote(state, raw), expected);
            };
            if (parsed == value) return @intCast(parsed);
            return schema.failCode(state, .invalid_literal, path, try schema.quote(state, raw), expected);
        }

        pub fn check(state: *State, candidate: Value, path: []const u8) DecodeError!void {
            if (schema.valuesEqual(Value, candidate, value)) return;
            return schema.failCode(state, .invalid_literal, path, try schema.describeScalar(state, .{ .string = expected }), expected);
        }

        pub fn encode(state: *EncodeState, candidate: Value) EncodeError!void {
            try state.json.write(candidate);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            if (state.target.supportsConst()) {
                try state.json.objectField("const");
                try state.json.write(@as(Value, value));
            } else {
                try state.json.objectField("enum");
                try state.json.beginArray();
                try state.json.write(@as(Value, value));
                try state.json.endArray();
            }
            try state.json.endObject();
        }
    };
}

/// Compile-time configuration for `nullValue`.
/// `description` is emitted in JSON Schema output.
pub const NullConfig = struct {
    /// JSON Schema `description`, emitted when non-empty.
    description: []const u8 = "",
};

/// Returns a schema accepting only JSON null; `Value` is `void`.
/// `decode` accepts JSON null and, when `coerce` is set, the string `"null"`; `decodeString` accepts only `"null"`. Other inputs return `error.Reported`.
/// The schema type exposes `Value`, `kind`, `schema_name`, `is_optional`, `has_default`, `decode`, `decodeString`, `check`, `encode`, and `writeJsonSchema`.
pub fn nullValue(comptime config: NullConfig) type {
    return struct {
        pub const Value = void;
        pub const kind = schema.Kind.null_value;
        pub const schema_name = "null";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node == .null) return {};
            if (state.options.coerce) {
                if (node == .string and std.mem.eql(u8, node.string, "null")) return {};
            }
            return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "null");
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (std.mem.eql(u8, raw, "null")) return {};
            return schema.failCode(state, .type_mismatch, path, try schema.quote(state, raw), "null");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            _ = state;
            _ = value;
            _ = path;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            _ = value;
            try state.json.write(null);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("null");
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

/// Textual or array representation used by `bytes` schemas.
/// `base64` and `base64url` use the standard and URL-safe alphabets; `hex` uses hexadecimal text; `array` uses a JSON array of byte values.
pub const ByteEncoding = enum { base64, base64url, hex, array };

/// Compile-time configuration for `bytes`.
/// `encoding` selects the representation; `min`/`max`/`len` bound the decoded byte length; `description` is emitted in JSON Schema output.
pub const BytesConfig = struct {
    /// Representation of the byte sequence.
    encoding: ByteEncoding = .base64,
    /// Minimum decoded byte length; inclusive.
    min: usize = 0,
    /// Maximum decoded byte length; inclusive.
    max: usize = std.math.maxInt(usize),
    /// Exact decoded byte length when non-null.
    len: ?usize = null,
    /// JSON Schema `description`, emitted when non-empty.
    description: []const u8 = "",
};

fn bytesExpected(comptime config: BytesConfig) []const u8 {
    if (config.len) |exact| return std.fmt.comptimePrint("exactly {d} bytes", .{exact});
    if (config.max == std.math.maxInt(usize)) {
        if (config.min == 0) return "any number of bytes";
        return std.fmt.comptimePrint("at least {d} bytes", .{config.min});
    }
    return std.fmt.comptimePrint("{d}..{d} bytes", .{ config.min, config.max });
}

/// Returns a byte-sequence schema; `Value` is `[]const u8`.
/// `decode` accepts base64, base64url, hex, or array-of-bytes input per `encoding`; `decodeString` accepts the text forms. Decoded bytes are allocated in `State.arena`; length configuration is validated at compile time.
/// Encoding uses `EncodeState.allocator` for scratch buffers; the written JSON remains caller-owned. Constraint violations return `error.Reported`; allocation failure returns `error.OutOfMemory`.
/// The schema type exposes `Value`, `kind`, `schema_name`, `is_optional`, `has_default`, `decode`, `decodeString`, `check`, `encode`, and `writeJsonSchema`.
pub fn bytes(comptime config: BytesConfig) type {
    comptime {
        if (config.min > config.max) @compileError("bytes minimum exceeds maximum");
        if (config.len) |exact| {
            if (exact < config.min or exact > config.max) @compileError("bytes exact length must be within minimum and maximum");
        }
    }

    return struct {
        pub const Value = []const u8;
        pub const kind = schema.Kind.array;
        pub const schema_name = "bytes";
        pub const is_optional = false;
        pub const has_default = false;
        pub const expected = bytesExpected(config);

        fn checkLength(state: *State, value: []const u8, path: []const u8) DecodeError!void {
            if (config.len) |exact| {
                if (value.len != exact) return schema.failCode(state, .length_mismatch, path, null, expected);
            }
            if (value.len < config.min) return schema.failCode(state, .too_small, path, null, expected);
            if (value.len > config.max) return schema.failCode(state, .too_large, path, null, expected);
        }

        fn decodeText(state: *State, text: []const u8, path: []const u8) DecodeError!Value {
            const allocator = state.arena;
            const out = switch (config.encoding) {
                .base64 => blk: {
                    const size = std.base64.standard.Decoder.calcSizeForSlice(text) catch
                        return schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "base64 text");
                    const buffer = allocator.alloc(u8, size) catch return error.OutOfMemory;
                    std.base64.standard.Decoder.decode(buffer, text) catch
                        return schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "base64 text");
                    break :blk buffer;
                },
                .base64url => blk: {
                    const size = std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(text) catch
                        return schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "base64url text");
                    const buffer = allocator.alloc(u8, size) catch return error.OutOfMemory;
                    std.base64.url_safe_no_pad.Decoder.decode(buffer, text) catch
                        return schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "base64url text");
                    break :blk buffer;
                },
                .hex => blk: {
                    if (text.len % 2 != 0) return schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "even-length hexadecimal text");
                    const buffer = allocator.alloc(u8, text.len / 2) catch return error.OutOfMemory;
                    _ = std.fmt.hexToBytes(buffer, text) catch
                        return schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "hexadecimal text");
                    break :blk buffer;
                },
                .array => unreachable,
            };
            try checkLength(state, out, path);
            return out;
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (config.encoding == .array) {
                if (node != .array) return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "array of bytes");
                const buffer = state.arena.alloc(u8, node.array.items.len) catch return error.OutOfMemory;
                for (node.array.items, 0..) |item, index| {
                    buffer[index] = switch (item) {
                        .integer => |value| if (value >= 0 and value <= 255) @intCast(value) else return schema.failCode(state, .out_of_range, try schema.pathIndex(state, path, index), null, "0..255"),
                        else => return schema.failCode(state, .type_mismatch, try schema.pathIndex(state, path, index), schema.describeNode(item), "integer byte"),
                    };
                }
                try checkLength(state, buffer, path);
                return buffer;
            }
            const text = switch (node) {
                .string => |value| value,
                else => return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), expected),
            };
            return decodeText(state, text, path);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (config.encoding == .array) return schema.failCode(state, .unsupported, path, null, "text byte representation");
            return decodeText(state, raw, path);
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try checkLength(state, value, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            switch (config.encoding) {
                .array => {
                    try state.json.beginArray();
                    for (value) |byte| try state.json.write(byte);
                    try state.json.endArray();
                },
                .base64 => {
                    const size = std.base64.standard.Encoder.calcSize(value.len);
                    const buffer = state.allocator.alloc(u8, size) catch return error.OutOfMemory;
                    try state.json.write(std.base64.standard.Encoder.encode(buffer, value));
                },
                .base64url => {
                    const size = std.base64.url_safe_no_pad.Encoder.calcSize(value.len);
                    const buffer = state.allocator.alloc(u8, size) catch return error.OutOfMemory;
                    try state.json.write(std.base64.url_safe_no_pad.Encoder.encode(buffer, value));
                },
                .hex => {
                    const size = std.math.mul(usize, value.len, 2) catch return error.OutOfMemory;
                    const buffer = state.allocator.alloc(u8, size) catch return error.OutOfMemory;
                    const alphabet = "0123456789abcdef";
                    for (value, 0..) |byte, index| {
                        buffer[index * 2] = alphabet[byte >> 4];
                        buffer[index * 2 + 1] = alphabet[byte & 0x0f];
                    }
                    try state.json.write(buffer);
                },
            }
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write(if (config.encoding == .array) "array" else "string");
            switch (config.encoding) {
                .array => {
                    try state.json.objectField("items");
                    try state.json.beginObject();
                    try state.json.objectField("type");
                    try state.json.write("integer");
                    try state.json.objectField("minimum");
                    try state.json.write(0);
                    try state.json.objectField("maximum");
                    try state.json.write(255);
                    try state.json.endObject();
                    if (config.len != null or config.min > 0) {
                        try state.json.objectField("minItems");
                        try state.json.write(config.len orelse config.min);
                    }
                    if (config.len) |exact| {
                        try state.json.objectField("maxItems");
                        try state.json.write(exact);
                    } else if (config.max != std.math.maxInt(usize)) {
                        try state.json.objectField("maxItems");
                        try state.json.write(config.max);
                    }
                },
                .base64, .base64url => {
                    try state.json.objectField("contentEncoding");
                    try state.json.write(if (config.encoding == .base64) "base64" else "base64url");
                    try state.json.objectField("contentMediaType");
                    try state.json.write("application/octet-stream");
                },
                .hex => {
                    try state.json.objectField("pattern");
                    try state.json.write("^[0-9a-fA-F]*$");
                },
            }
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

test "bytes schemas round trip supported encodings" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Base64 = bytes(.{ .len = 3 });
    const decoded = try Base64.decode(&state, .{ .string = "AQID" }, "payload");
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, decoded);
    try Base64.check(&state, decoded, "payload");

    const text = try @import("json.zig").stringify(Base64, allocator, decoded, .{});
    defer allocator.free(text);
    try std.testing.expectEqualStrings("\"AQID\"", text);

    const Hex = bytes(.{ .encoding = .hex });
    const hex = try Hex.decode(&state, .{ .string = "010203" }, "payload");
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, hex);
    try std.testing.expectError(error.Reported, Hex.decode(&state, .{ .string = "xyz" }, "payload"));

    const ArrayBytes = bytes(.{ .encoding = .array });
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, "[1,2,255]", .{});
    defer parsed.deinit();
    const array = try ArrayBytes.decode(&state, parsed.value, "payload");
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 255 }, array);

    const invalid = try std.json.parseFromSlice(std.json.Value, allocator, "[256]", .{});
    defer invalid.deinit();
    try std.testing.expectError(error.Reported, ArrayBytes.decode(&state, invalid.value, "payload"));
}

test "null coercion is opt-in" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Nothing = nullValue(.{});
    _ = try Nothing.decode(&state, .null, "value");
    try std.testing.expectError(error.Reported, Nothing.decode(&state, .{ .string = "null" }, "value"));

    state.options.coerce = true;
    _ = try Nothing.decode(&state, .{ .string = "null" }, "value");
}

test "boolean coercion is opt-in" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Flag = boolean(.{});
    try std.testing.expect(try Flag.decode(&state, .{ .bool = true }, "flag"));
    try std.testing.expectError(error.Reported, Flag.decode(&state, .{ .string = "true" }, "flag"));
    state.options.coerce = true;
    try std.testing.expect(try Flag.decode(&state, .{ .string = "true" }, "flag"));
    try std.testing.expectError(error.Reported, Flag.decode(&state, .{ .string = "yes" }, "flag"));
}

test "enum and literal schemas" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Colour = enum { red, green, blue };
    const Shade = enumType(Colour, .{});
    try std.testing.expectEqual(Colour.green, try Shade.decode(&state, .{ .string = "green" }, "shade"));
    try std.testing.expectError(error.Reported, Shade.decode(&state, .{ .string = "pink" }, "shade"));

    const Tag = literal("user");
    try std.testing.expectEqualStrings("user", try Tag.decode(&state, .{ .string = "user" }, "tag"));
    try std.testing.expectError(error.Reported, Tag.decode(&state, .{ .string = "admin" }, "tag"));

    const Version = literal(2);
    try std.testing.expectEqual(@as(comptime_int, 2), try Version.decode(&state, .{ .integer = 2 }, "version"));
}

test "null schema" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Nothing = nullValue(.{});
    const nothing = try Nothing.decode(&state, .null, "nothing");
    _ = nothing;
    try std.testing.expectError(error.Reported, Nothing.decode(&state, .{ .bool = false }, "nothing"));
}
