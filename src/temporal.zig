//! Date, time and date-time schemas.
//!
//! These schemas decode ISO 8601 text into the allocation-free `Date`, `Time`
//! and `DateTime` value types. Parsing and formatting use caller or stack
//! storage; these schemas never allocate.

const std = @import("std");
const schema = @import("schema.zig");
const datetime = @import("datetime.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

/// Configuration for temporal schemas; emits an optional `description` keyword alongside `format`.
pub const Config = struct {
    /// Optional `description` keyword emitted with the JSON Schema output.
    description: []const u8 = "",
};

/// Schema decoding ISO 8601 date text to `Date` (schema name `date`).
/// `decode` reads a JSON string, `decodeString` reads raw text for coercion, `check` validates the calendar date, `encode` writes ISO format, and `writeJsonSchema` emits `format: "date"`. This schema never allocates.
pub fn date(comptime config: Config) type {
    return struct {
        pub const Value = datetime.Date;
        pub const kind = schema.Kind.string;
        pub const schema_name = "date";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const text = switch (node) {
                .string => |value| value,
                else => return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "ISO 8601 date"),
            };
            return datetime.Date.parse(text) catch
                schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "ISO 8601 date");
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            return datetime.Date.parse(raw) catch
                schema.failCode(state, .invalid_format, path, try schema.quote(state, raw), "ISO 8601 date");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            _ = datetime.Date.init(value.year, value.month, value.day) catch
                return schema.failCode(state, .invalid_value, path, null, "valid calendar date");
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            var buffer: [16]u8 = undefined;
            const text = value.format(&buffer) catch return error.Unsupported;
            try state.json.write(text);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("string");
            try state.json.objectField("format");
            try state.json.write("date");
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

/// Schema decoding ISO 8601 time text to `Time` (schema name `time`).
/// `decode` reads a JSON string, `decodeString` reads raw text for coercion, `check` validates field ranges, `encode` writes ISO format, and `writeJsonSchema` emits `format: "time"`. This schema never allocates.
pub fn time(comptime config: Config) type {
    return struct {
        pub const Value = datetime.Time;
        pub const kind = schema.Kind.string;
        pub const schema_name = "time";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const text = switch (node) {
                .string => |value| value,
                else => return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "ISO 8601 time"),
            };
            return datetime.Time.parse(text) catch
                schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "ISO 8601 time");
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            return datetime.Time.parse(raw) catch
                schema.failCode(state, .invalid_format, path, try schema.quote(state, raw), "ISO 8601 time");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            _ = datetime.Time.init(value.hour, value.minute, value.second, value.nanosecond) catch
                return schema.failCode(state, .invalid_value, path, null, "valid time");
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            var buffer: [24]u8 = undefined;
            const text = value.format(&buffer) catch return error.Unsupported;
            try state.json.write(text);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("string");
            try state.json.objectField("format");
            try state.json.write("time");
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

/// Schema decoding ISO 8601 date-time text to `DateTime` (schema name `date-time`).
/// `decode` reads a JSON string, `decodeString` reads raw text for coercion, `check` validates the date, time, and offset, `encode` writes ISO format, and `writeJsonSchema` emits `format: "date-time"`. This schema never allocates; offsets are fixed values.
pub fn dateTime(comptime config: Config) type {
    return struct {
        pub const Value = datetime.DateTime;
        pub const kind = schema.Kind.string;
        pub const schema_name = "date-time";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const text = switch (node) {
                .string => |value| value,
                else => return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "ISO 8601 date-time"),
            };
            return datetime.DateTime.parse(text) catch
                schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "ISO 8601 date-time");
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            return datetime.DateTime.parse(raw) catch
                schema.failCode(state, .invalid_format, path, try schema.quote(state, raw), "ISO 8601 date-time");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            _ = datetime.DateTime.init(value.date, value.time, value.offset_minutes) catch
                return schema.failCode(state, .invalid_value, path, null, "valid date-time");
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            var buffer: [48]u8 = undefined;
            const text = value.format(&buffer) catch return error.Unsupported;
            try state.json.write(text);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("string");
            try state.json.objectField("format");
            try state.json.write("date-time");
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

/// Schema decoding ISO 8601 duration text to `Duration` (schema name `duration`).
/// `decode` reads a JSON string, `decodeString` reads raw text for coercion, `check` accepts any parsed value, `encode` writes ISO format, and `writeJsonSchema` emits `format: "duration"`. This schema never allocates.
pub fn duration(comptime config: Config) type {
    return struct {
        pub const Value = datetime.Duration;
        pub const kind = schema.Kind.string;
        pub const schema_name = "duration";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const text = switch (node) {
                .string => |value| value,
                else => return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "ISO 8601 duration"),
            };
            return datetime.Duration.parse(text) catch
                schema.failCode(state, .invalid_format, path, try schema.quote(state, text), "ISO 8601 duration");
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            return datetime.Duration.parse(raw) catch
                schema.failCode(state, .invalid_format, path, try schema.quote(state, raw), "ISO 8601 duration");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            _ = state;
            _ = value;
            _ = path;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            var buffer: [96]u8 = undefined;
            const text = value.format(&buffer) catch return error.Unsupported;
            try state.json.write(text);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("string");
            try state.json.objectField("format");
            try state.json.write("duration");
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

test "temporal schemas round trip" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const DateSchema = date(.{});
    const value = try DateSchema.decode(&state, .{ .string = "2024-02-29" }, "date");
    try std.testing.expectEqual(@as(u8, 29), value.day);
    try DateSchema.check(&state, value, "date");

    try std.testing.expectError(error.Reported, DateSchema.decode(&state, .{ .string = "2023-02-29" }, "date"));

    const DateTimeSchema = dateTime(.{});
    const dt = try DateTimeSchema.decode(&state, .{ .string = "2024-02-29T12:30:45Z" }, "at");
    try std.testing.expectEqual(@as(i16, 0), dt.offset_minutes);

    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    var json: std.json.Stringify = .{ .writer = &output.writer, .options = .{} };
    var encode_state = EncodeState{ .allocator = allocator, .json = &json };
    try DateSchema.encode(&encode_state, value);
    try std.testing.expectEqualStrings("\"2024-02-29\"", output.written());

    const RangeSchema = duration(.{});
    const span = try RangeSchema.decode(&state, .{ .string = "P2DT3H" }, "span");
    try std.testing.expectEqual(@as(u32, 2), span.days);
    try std.testing.expectEqual(@as(u32, 3), span.hours);
    try RangeSchema.check(&state, span, "span");
    try std.testing.expectError(error.Reported, RangeSchema.decode(&state, .{ .string = "P" }, "span"));
}
