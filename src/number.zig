//! Integer and floating-point schemas with compile-time bounds.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

pub const IntConfig = struct {
    min: ?comptime_int = null,
    max: ?comptime_int = null,
    even: bool = false,
    multiple_of: ?comptime_int = null,
    description: []const u8 = "",
};

pub const FloatConfig = struct {
    min: ?comptime_float = null,
    max: ?comptime_float = null,
    finite: bool = true,
    description: []const u8 = "",
};

fn intBounds(comptime T: type, comptime config: IntConfig) struct { low: comptime_int, high: comptime_int } {
    return .{
        .low = config.min orelse std.math.minInt(T),
        .high = config.max orelse std.math.maxInt(T),
    };
}

fn intExpected(
    comptime low: comptime_int,
    comptime high: comptime_int,
    comptime even: bool,
    comptime multiple: ?comptime_int,
) []const u8 {
    if (even) {
        if (multiple) |value| return std.fmt.comptimePrint("{d}..{d}, even, multiple of {d}", .{ low, high, value });
        return std.fmt.comptimePrint("{d}..{d}, even", .{ low, high });
    }
    if (multiple) |value| return std.fmt.comptimePrint("{d}..{d}, multiple of {d}", .{ low, high, value });
    return std.fmt.comptimePrint("{d}..{d}", .{ low, high });
}

pub fn integer(comptime T: type, comptime config: IntConfig) type {
    comptime {
        switch (@typeInfo(T)) {
            .int => {},
            else => @compileError("integer requires an integer type, got " ++ @typeName(T)),
        }
        const bounds = intBounds(T, config);
        if (bounds.low < std.math.minInt(T) or bounds.low > std.math.maxInt(T)) {
            @compileError("integer minimum does not fit " ++ @typeName(T));
        }
        if (bounds.high < std.math.minInt(T) or bounds.high > std.math.maxInt(T)) {
            @compileError("integer maximum does not fit " ++ @typeName(T));
        }
        if (bounds.low > bounds.high) @compileError("integer minimum exceeds maximum");
        if (config.multiple_of) |value| {
            if (value <= 0) @compileError("multiple_of must be positive");
        }
    }

    const bounds = intBounds(T, config);

    return struct {
        pub const Value = T;
        pub const kind = schema.Kind.integer;
        pub const schema_name = "integer";
        pub const is_optional = false;
        pub const has_default = false;
        pub const expected = intExpected(bounds.low, bounds.high, config.even, config.multiple_of);

        fn checkRange(state: *State, value: T, path: []const u8) DecodeError!T {
            const low: T = bounds.low;
            const high: T = bounds.high;
            const received = std.fmt.allocPrint(state.arena, "{d}", .{value}) catch return error.OutOfMemory;
            if (value < low) return schema.failCode(state, .too_small, path, received, expected);
            if (value > high) return schema.failCode(state, .too_large, path, received, expected);
            if (config.even and @rem(value, 2) != 0) {
                return schema.failCode(state, .invalid_value, path, received, "even integer");
            }
            if (config.multiple_of) |value_multiple| {
                const divisor: T = value_multiple;
                if (@rem(value, divisor) != 0) return schema.failCode(state, .invalid_value, path, received, "multiple of the configured divisor");
            }
            return value;
        }

        fn cast(state: *State, value: anytype, path: []const u8) DecodeError!T {
            const converted = std.math.cast(T, value) orelse {
                const received = std.fmt.allocPrint(state.arena, "{d}", .{value}) catch return error.OutOfMemory;
                return schema.failCode(state, .out_of_range, path, received, expected);
            };
            return checkRange(state, converted, path);
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            switch (node) {
                .integer => |value| return cast(state, value, path),
                .float => |value| {
                    if (!std.math.isFinite(value)) {
                        return schema.fail(state, error.NotFinite, path, null, expected);
                    }
                    const truncated = @trunc(value);
                    if (truncated != value) {
                        return schema.fail(state, error.NotInteger, path, try schema.describeScalar(state, node), expected);
                    }
                    if (value < @as(f64, @floatFromInt(bounds.low)) or value > @as(f64, @floatFromInt(bounds.high))) {
                        return schema.failCode(state, .out_of_range, path, try schema.describeScalar(state, node), expected);
                    }
                    return cast(state, @as(i64, @intFromFloat(truncated)), path);
                },
                .number_string => |text| {
                    const parsed = std.fmt.parseInt(T, text, 10) catch {
                        return schema.failCode(state, .out_of_range, path, try schema.quote(state, text), expected);
                    };
                    return checkRange(state, parsed, path);
                },
                .string => |text| {
                    if (!state.options.coerce) {
                        return schema.failCode(state, .type_mismatch, path, try schema.quote(state, text), expected);
                    }
                    const parsed = std.fmt.parseInt(T, text, 10) catch {
                        return schema.fail(state, error.CoercionFailed, path, try schema.quote(state, text), expected);
                    };
                    return checkRange(state, parsed, path);
                },
                else => return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), expected),
            }
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            const parsed = std.fmt.parseInt(T, raw, 10) catch {
                return schema.fail(state, error.CoercionFailed, path, try schema.quote(state, raw), expected);
            };
            return checkRange(state, parsed, path);
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            _ = try checkRange(state, value, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try state.json.write(value);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("integer");
            if (config.min) |value| {
                try state.json.objectField("minimum");
                try state.json.write(value);
            }
            if (config.max) |value| {
                try state.json.objectField("maximum");
                try state.json.write(value);
            }
            if (config.multiple_of) |value| {
                try state.json.objectField("multipleOf");
                try state.json.write(value);
            }
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

fn floatExpected(comptime config: FloatConfig) []const u8 {
    const low = config.min;
    const high = config.max;
    if (config.finite) {
        if (low != null and high != null) return std.fmt.comptimePrint("finite number, {d}..{d}", .{ low.?, high.? });
        if (low) |value| return std.fmt.comptimePrint("finite number, >= {d}", .{value});
        if (high) |value| return std.fmt.comptimePrint("finite number, <= {d}", .{value});
        return "finite number";
    }
    if (low != null and high != null) return std.fmt.comptimePrint("{d}..{d}", .{ low.?, high.? });
    if (low) |value| return std.fmt.comptimePrint(">= {d}", .{value});
    if (high) |value| return std.fmt.comptimePrint("<= {d}", .{value});
    return "number";
}

pub fn float(comptime T: type, comptime config: FloatConfig) type {
    comptime {
        switch (@typeInfo(T)) {
            .float => {},
            else => @compileError("float requires a floating-point type, got " ++ @typeName(T)),
        }
        if (config.min != null and config.max != null and config.min.? > config.max.?) {
            @compileError("float minimum exceeds maximum");
        }
    }

    return struct {
        pub const Value = T;
        pub const kind = schema.Kind.float;
        pub const schema_name = "float";
        pub const is_optional = false;
        pub const has_default = false;
        pub const expected = floatExpected(config);

        fn checkRange(state: *State, value: T, path: []const u8) DecodeError!T {
            const received = std.fmt.allocPrint(state.arena, "{d}", .{value}) catch return error.OutOfMemory;
            if (config.finite and !std.math.isFinite(value)) {
                return schema.fail(state, error.NotFinite, path, received, expected);
            }
            if (config.min) |low| {
                if (value < low) return schema.failCode(state, .too_small, path, received, expected);
            }
            if (config.max) |high| {
                if (value > high) return schema.failCode(state, .too_large, path, received, expected);
            }
            return value;
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const value: T = switch (node) {
                .integer => |raw| @floatFromInt(raw),
                .float => |raw| @floatCast(raw),
                .number_string => |text| std.fmt.parseFloat(T, text) catch {
                    return schema.fail(state, error.CoercionFailed, path, try schema.quote(state, text), expected);
                },
                .string => |text| blk: {
                    if (!state.options.coerce) {
                        return schema.failCode(state, .type_mismatch, path, try schema.quote(state, text), expected);
                    }
                    break :blk std.fmt.parseFloat(T, text) catch {
                        return schema.fail(state, error.CoercionFailed, path, try schema.quote(state, text), expected);
                    };
                },
                else => return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), expected),
            };
            return checkRange(state, value, path);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            const parsed = std.fmt.parseFloat(T, raw) catch {
                return schema.fail(state, error.CoercionFailed, path, try schema.quote(state, raw), expected);
            };
            return checkRange(state, parsed, path);
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            _ = try checkRange(state, value, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            if (!std.math.isFinite(value)) return error.Unsupported;
            try state.json.write(value);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("number");
            if (config.min) |value| {
                try state.json.objectField("minimum");
                try state.json.write(value);
            }
            if (config.max) |value| {
                try state.json.objectField("maximum");
                try state.json.write(value);
            }
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

pub fn positiveInt(comptime T: type, comptime config: IntConfig) type {
    const min = if (config.min) |value| @max(value, 1) else 1;
    return integer(T, .{
        .min = min,
        .max = config.max,
        .even = config.even,
        .multiple_of = config.multiple_of,
        .description = config.description,
    });
}

pub fn nonNegativeInt(comptime T: type, comptime config: IntConfig) type {
    const min = if (config.min) |value| @max(value, 0) else 0;
    return integer(T, .{
        .min = min,
        .max = config.max,
        .even = config.even,
        .multiple_of = config.multiple_of,
        .description = config.description,
    });
}

pub fn percentage(comptime T: type, comptime config: FloatConfig) type {
    const min = if (config.min) |value| @max(value, 0) else 0;
    const max = if (config.max) |value| @min(value, 100) else 100;
    return float(T, .{
        .min = min,
        .max = max,
        .finite = config.finite,
        .description = config.description,
    });
}

pub fn probability(comptime T: type, comptime config: FloatConfig) type {
    const min = if (config.min) |value| @max(value, 0) else 0;
    const max = if (config.max) |value| @min(value, 1) else 1;
    return float(T, .{
        .min = min,
        .max = max,
        .finite = config.finite,
        .description = config.description,
    });
}

test "integer bounds and coercion" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Age = integer(u8, .{ .min = 18, .max = 120 });
    try std.testing.expectEqual(@as(u8, 30), try Age.decode(&state, .{ .integer = 30 }, "age"));
    try std.testing.expectError(error.Reported, Age.decode(&state, .{ .integer = 12 }, "age"));
    try std.testing.expectEqualStrings("18..120", list.last().?.expected.?);
    try std.testing.expectError(error.Reported, Age.decode(&state, .{ .integer = 300 }, "age"));

    const Even = integer(i32, .{ .even = true, .multiple_of = 5 });
    try std.testing.expectEqual(@as(i32, 20), try Even.decode(&state, .{ .float = 20.0 }, "value"));
    try std.testing.expectError(error.Reported, Even.decode(&state, .{ .float = 21.0 }, "value"));
}

test "float validation" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Ratio = probability(f64, .{});
    try std.testing.expectEqual(@as(f64, 0.5), try Ratio.decode(&state, .{ .float = 0.5 }, "ratio"));
    try std.testing.expectError(error.Reported, Ratio.decode(&state, .{ .float = 1.5 }, "ratio"));
    try std.testing.expectError(error.Reported, Ratio.decode(&state, .{ .number_string = "1e999" }, "ratio"));
}
