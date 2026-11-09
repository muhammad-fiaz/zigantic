//! Integer and floating-point schemas with compile-time bounds.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

/// Compile-time configuration for `integer` and integer helpers.
/// `min`/`max` are inclusive bounds; `exclusive_min`/`exclusive_max` are exclusive bounds; `even` requires an even value; `multiple_of` must be positive; `description` is emitted in JSON Schema output.
pub const IntConfig = struct {
    /// Inclusive minimum; null defaults to the type minimum.
    min: ?comptime_int = null,
    /// Inclusive maximum; null defaults to the type maximum.
    max: ?comptime_int = null,
    /// Exclusive minimum; null skips the check.
    exclusive_min: ?comptime_int = null,
    /// Exclusive maximum; null skips the check.
    exclusive_max: ?comptime_int = null,
    /// When true, rejects odd integers.
    even: bool = false,
    /// Required divisor; must be positive when non-null.
    multiple_of: ?comptime_int = null,
    /// JSON Schema `description`, emitted when non-empty.
    description: []const u8 = "",
};

/// Compile-time configuration for `float` and float helpers.
/// `min`/`max` are inclusive bounds; `exclusive_min`/`exclusive_max` are exclusive bounds; `finite` rejects NaN and infinities; `description` is emitted in JSON Schema output.
pub const FloatConfig = struct {
    /// Inclusive minimum; null skips the check.
    min: ?comptime_float = null,
    /// Inclusive maximum; null skips the check.
    max: ?comptime_float = null,
    /// Exclusive minimum; null skips the check.
    exclusive_min: ?comptime_float = null,
    /// Exclusive maximum; null skips the check.
    exclusive_max: ?comptime_float = null,
    /// When true, rejects NaN and positive or negative infinity.
    finite: bool = true,
    /// JSON Schema `description`, emitted when non-empty.
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

/// Returns an integer schema for `T`; `Value` is `T`.
/// `decode` accepts JSON integers, integral floats, `number_string` values, and strings when `coerce` is set; `decodeString` parses decimal text. Constraint violations return `error.Reported`; allocation failure returns `error.OutOfMemory`.
/// Bounds and `multiple_of` are validated at compile time and must fit `T`; `T` must be an integer type.
/// The schema type exposes `Value`, `kind`, `schema_name`, `is_optional`, `has_default`, `decode`, `decodeString`, `check`, `encode`, and `writeJsonSchema`.
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
        if (config.exclusive_min) |value| {
            if (value < bounds.low or value > bounds.high) @compileError("integer exclusive minimum is outside the allowed range");
        }
        if (config.exclusive_max) |value| {
            if (value < bounds.low or value > bounds.high) @compileError("integer exclusive maximum is outside the allowed range");
        }
        if (config.exclusive_min != null and config.exclusive_max != null and config.exclusive_min.? >= config.exclusive_max.?) {
            @compileError("integer exclusive minimum must be less than exclusive maximum");
        }
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
            if (config.exclusive_min) |exclusive| {
                if (value <= exclusive) return schema.failCode(state, .too_small, path, received, expected);
            }
            if (config.exclusive_max) |exclusive| {
                if (value >= exclusive) return schema.failCode(state, .too_large, path, received, expected);
            }
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
                    const low_f: f64 = @floatFromInt(bounds.low);
                    const high_f: f64 = @floatFromInt(bounds.high);
                    if (value < low_f or value > high_f) {
                        return schema.failCode(state, .out_of_range, path, try schema.describeScalar(state, node), expected);
                    }
                    // The value is within the float-rounded bounds of `T`, so
                    // converting through 128-bit intermediates never panics.
                    // Values that rounded to the boundary of `T` surface as
                    // `out_of_range` through `cast` instead of panicking.
                    if (truncated >= 0) {
                        if (truncated < @as(f64, @floatFromInt(std.math.maxInt(i128)))) {
                            return cast(state, @as(i128, @intFromFloat(truncated)), path);
                        }
                        if (truncated < @as(f64, @floatFromInt(std.math.maxInt(u128)))) {
                            return cast(state, @as(u128, @intFromFloat(truncated)), path);
                        }
                        return schema.failCode(state, .out_of_range, path, try schema.describeScalar(state, node), expected);
                    }
                    return cast(state, @as(i128, @intFromFloat(truncated)), path);
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
            if (state.target.usesBooleanExclusiveBounds()) {
                if ((config.min != null and config.exclusive_min != null) or (config.max != null and config.exclusive_max != null)) {
                    try state.json.objectField("allOf");
                    try state.json.beginArray();
                    if (config.min) |value| {
                        try state.json.beginObject();
                        try state.json.objectField("minimum");
                        try state.json.write(value);
                        try state.json.endObject();
                    }
                    if (config.exclusive_min) |value| {
                        try state.json.beginObject();
                        try state.json.objectField("minimum");
                        try state.json.write(value);
                        try state.json.objectField("exclusiveMinimum");
                        try state.json.write(true);
                        try state.json.endObject();
                    }
                    if (config.max) |value| {
                        try state.json.beginObject();
                        try state.json.objectField("maximum");
                        try state.json.write(value);
                        try state.json.endObject();
                    }
                    if (config.exclusive_max) |value| {
                        try state.json.beginObject();
                        try state.json.objectField("maximum");
                        try state.json.write(value);
                        try state.json.objectField("exclusiveMaximum");
                        try state.json.write(true);
                        try state.json.endObject();
                    }
                    try state.json.endArray();
                } else {
                    if (config.exclusive_min) |value| {
                        try state.json.objectField("minimum");
                        try state.json.write(value);
                        try state.json.objectField("exclusiveMinimum");
                        try state.json.write(true);
                    } else if (config.min) |value| {
                        try state.json.objectField("minimum");
                        try state.json.write(value);
                    }
                    if (config.exclusive_max) |value| {
                        try state.json.objectField("maximum");
                        try state.json.write(value);
                        try state.json.objectField("exclusiveMaximum");
                        try state.json.write(true);
                    } else if (config.max) |value| {
                        try state.json.objectField("maximum");
                        try state.json.write(value);
                    }
                }
            } else {
                if (config.min) |value| {
                    try state.json.objectField("minimum");
                    try state.json.write(value);
                }
                if (config.max) |value| {
                    try state.json.objectField("maximum");
                    try state.json.write(value);
                }
                if (config.exclusive_min) |value| {
                    try state.json.objectField("exclusiveMinimum");
                    try state.json.write(value);
                }
                if (config.exclusive_max) |value| {
                    try state.json.objectField("exclusiveMaximum");
                    try state.json.write(value);
                }
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

/// Returns a floating-point schema for `T`; `Value` is `T`.
/// `decode` accepts JSON integers, floats, and `number_string` values, and strings when `coerce` is set; `decodeString` parses float text. Constraint violations return `error.Reported`; allocation failure returns `error.OutOfMemory`.
/// Range configuration is validated at compile time; `T` must be a floating-point type.
/// The schema type exposes `Value`, `kind`, `schema_name`, `is_optional`, `has_default`, `decode`, `decodeString`, `check`, `encode`, and `writeJsonSchema`.
pub fn float(comptime T: type, comptime config: FloatConfig) type {
    comptime {
        switch (@typeInfo(T)) {
            .float => {},
            else => @compileError("float requires a floating-point type, got " ++ @typeName(T)),
        }
        if (config.min != null and config.max != null and config.min.? > config.max.?) {
            @compileError("float minimum exceeds maximum");
        }
        if (config.exclusive_min != null and config.exclusive_max != null and config.exclusive_min.? >= config.exclusive_max.?) {
            @compileError("float exclusive minimum must be less than exclusive maximum");
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
            if (config.exclusive_min) |exclusive| {
                if (value <= exclusive) return schema.failCode(state, .too_small, path, received, expected);
            }
            if (config.exclusive_max) |exclusive| {
                if (value >= exclusive) return schema.failCode(state, .too_large, path, received, expected);
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
            if (state.target.usesBooleanExclusiveBounds()) {
                if ((config.min != null and config.exclusive_min != null) or (config.max != null and config.exclusive_max != null)) {
                    try state.json.objectField("allOf");
                    try state.json.beginArray();
                    if (config.min) |value| {
                        try state.json.beginObject();
                        try state.json.objectField("minimum");
                        try state.json.write(value);
                        try state.json.endObject();
                    }
                    if (config.exclusive_min) |value| {
                        try state.json.beginObject();
                        try state.json.objectField("minimum");
                        try state.json.write(value);
                        try state.json.objectField("exclusiveMinimum");
                        try state.json.write(true);
                        try state.json.endObject();
                    }
                    if (config.max) |value| {
                        try state.json.beginObject();
                        try state.json.objectField("maximum");
                        try state.json.write(value);
                        try state.json.endObject();
                    }
                    if (config.exclusive_max) |value| {
                        try state.json.beginObject();
                        try state.json.objectField("maximum");
                        try state.json.write(value);
                        try state.json.objectField("exclusiveMaximum");
                        try state.json.write(true);
                        try state.json.endObject();
                    }
                    try state.json.endArray();
                } else {
                    if (config.exclusive_min) |value| {
                        try state.json.objectField("minimum");
                        try state.json.write(value);
                        try state.json.objectField("exclusiveMinimum");
                        try state.json.write(true);
                    } else if (config.min) |value| {
                        try state.json.objectField("minimum");
                        try state.json.write(value);
                    }
                    if (config.exclusive_max) |value| {
                        try state.json.objectField("maximum");
                        try state.json.write(value);
                        try state.json.objectField("exclusiveMaximum");
                        try state.json.write(true);
                    } else if (config.max) |value| {
                        try state.json.objectField("maximum");
                        try state.json.write(value);
                    }
                }
            } else {
                if (config.min) |value| {
                    try state.json.objectField("minimum");
                    try state.json.write(value);
                }
                if (config.max) |value| {
                    try state.json.objectField("maximum");
                    try state.json.write(value);
                }
                if (config.exclusive_min) |value| {
                    try state.json.objectField("exclusiveMinimum");
                    try state.json.write(value);
                }
                if (config.exclusive_max) |value| {
                    try state.json.objectField("exclusiveMaximum");
                    try state.json.write(value);
                }
            }
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

/// Integer schema with the lower bound raised to 1 when needed.
/// Shorthand for `integer` with `min` at least 1 and `exclusive_min` cleared; see `integer` for the schema protocol.
pub fn positiveInt(comptime T: type, comptime config: IntConfig) type {
    const min = if (config.min) |value| @max(value, 1) else 1;
    return integer(T, .{
        .min = min,
        .max = config.max,
        .exclusive_min = null,
        .exclusive_max = config.exclusive_max,
        .even = config.even,
        .multiple_of = config.multiple_of,
        .description = config.description,
    });
}

/// Integer schema with the upper bound lowered to -1 when needed.
/// Shorthand for `integer` with `max` at most -1 and `exclusive_max` cleared; see `integer` for the schema protocol.
pub fn negativeInt(comptime T: type, comptime config: IntConfig) type {
    const max = if (config.max) |value| @min(value, -1) else -1;
    return integer(T, .{
        .min = config.min,
        .max = max,
        .exclusive_min = config.exclusive_min,
        .exclusive_max = null,
        .even = config.even,
        .multiple_of = config.multiple_of,
        .description = config.description,
    });
}

/// Integer schema with the lower bound raised to 0 when needed.
/// Shorthand for `integer` with `min` at least 0 and `exclusive_min` cleared; see `integer` for the schema protocol.
pub fn nonNegativeInt(comptime T: type, comptime config: IntConfig) type {
    const min = if (config.min) |value| @max(value, 0) else 0;
    return integer(T, .{
        .min = min,
        .max = config.max,
        .exclusive_min = null,
        .exclusive_max = config.exclusive_max,
        .even = config.even,
        .multiple_of = config.multiple_of,
        .description = config.description,
    });
}

/// Integer schema with the upper bound lowered to 0 when needed.
/// Shorthand for `integer` with `max` at most 0 and `exclusive_max` cleared; see `integer` for the schema protocol.
pub fn nonPositiveInt(comptime T: type, comptime config: IntConfig) type {
    const max = if (config.max) |value| @min(value, 0) else 0;
    return integer(T, .{
        .min = config.min,
        .max = max,
        .exclusive_min = config.exclusive_min,
        .exclusive_max = null,
        .even = config.even,
        .multiple_of = config.multiple_of,
        .description = config.description,
    });
}

/// Restricts an integer to JavaScript's safe integer range, intersected with
/// the type's own bounds.
/// Shorthand for `integer` with `min`/`max` intersected with ±9_007_199_254_740_991; see `integer` for the schema protocol.
pub fn safeInt(comptime T: type, comptime config: IntConfig) type {
    const safe = 9_007_199_254_740_991;
    const low = @max(std.math.minInt(T), -safe);
    const high = @min(std.math.maxInt(T), safe);
    return integer(T, .{
        .min = if (config.min) |value| @max(value, low) else low,
        .max = if (config.max) |value| @min(value, high) else high,
        .exclusive_min = config.exclusive_min,
        .exclusive_max = config.exclusive_max,
        .even = config.even,
        .multiple_of = config.multiple_of,
        .description = config.description,
    });
}

/// Integer schema requiring an unsigned integer type `T`.
/// Shorthand for `integer` with the same configuration; non-unsigned types fail compilation. See `integer` for the schema protocol.
pub fn unsignedInt(comptime T: type, comptime config: IntConfig) type {
    comptime {
        switch (@typeInfo(T)) {
            .int => |info| if (info.signedness != .unsigned) @compileError("unsignedInt requires an unsigned integer type"),
            else => @compileError("unsignedInt requires an unsigned integer type"),
        }
    }
    return integer(T, config);
}

/// Floating-point schema bounded to 0..100, intersected with the configured bounds.
/// Shorthand for `float` with `min`/`max` narrowed to 0 and 100; see `float` for the schema protocol.
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

/// Floating-point schema bounded to 0..1, intersected with the configured bounds.
/// Shorthand for `float` with `min`/`max` narrowed to 0 and 1; see `float` for the schema protocol.
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

test "exclusive bounds and numeric helpers" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Open = integer(i32, .{ .exclusive_min = 0, .exclusive_max = 10 });
    try std.testing.expectEqual(@as(i32, 1), try Open.decode(&state, .{ .integer = 1 }, "n"));
    try std.testing.expectError(error.Reported, Open.decode(&state, .{ .integer = 0 }, "n"));
    try std.testing.expectError(error.Reported, Open.decode(&state, .{ .integer = 10 }, "n"));

    const Positive = positiveInt(i32, .{});
    try std.testing.expectError(error.Reported, Positive.decode(&state, .{ .integer = 0 }, "n"));
    try std.testing.expectEqual(@as(i32, 1), try Positive.decode(&state, .{ .integer = 1 }, "n"));

    const Negative = negativeInt(i32, .{});
    try std.testing.expectEqual(@as(i32, -1), try Negative.decode(&state, .{ .integer = -1 }, "n"));
    try std.testing.expectError(error.Reported, Negative.decode(&state, .{ .integer = 0 }, "n"));

    const Safe = safeInt(i64, .{});
    try std.testing.expectError(error.Reported, Safe.decode(&state, .{ .integer = 9_007_199_254_740_992 }, "n"));
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

test "float inputs near wide integer boundaries report out of range" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    // 2^64 rounds from the decimal below; the float path must report
    // `out_of_range` instead of panicking in `@intFromFloat`.
    const MaxU64 = integer(u64, .{});
    try std.testing.expectError(error.Reported, MaxU64.decode(&state, .{ .float = 1.8446744073709552e19 }, "n"));
    try std.testing.expectEqualStrings("E016", list.last().?.code.label());

    const MaxI64 = integer(i64, .{});
    try std.testing.expectError(error.Reported, MaxI64.decode(&state, .{ .float = 9.223372036854776e18 }, "n"));
    try std.testing.expectEqualStrings("E016", list.last().?.code.label());

    const Wide = integer(i128, .{});
    try std.testing.expectEqual(@as(i128, 42), try Wide.decode(&state, .{ .float = 42.0 }, "n"));
    try std.testing.expectError(error.Reported, Wide.decode(&state, .{ .float = 1.7014118346046923e38 }, "n"));
}
