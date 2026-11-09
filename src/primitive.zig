//! Boolean, enum, literal and null schemas.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

pub const BoolConfig = struct {
    description: []const u8 = "",
};

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

pub const EnumConfig = struct {
    description: []const u8 = "",
};

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
            try state.json.objectField("const");
            try state.json.write(@as(Value, value));
            try state.json.endObject();
        }
    };
}

pub const NullConfig = struct {
    description: []const u8 = "",
};

pub fn nullValue(comptime config: NullConfig) type {
    return struct {
        pub const Value = void;
        pub const kind = schema.Kind.null_value;
        pub const schema_name = "null";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node == .null) return {};
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
