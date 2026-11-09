//! Optional, nullable, default, fallback, refinement, transform, lazy and
//! custom schemas.
//!
//! Optional and nullable are distinct: optional accepts absence (handled by the
//! parent object), nullable accepts an explicit JSON null. A missing field is
//! never confused with a null value.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

pub fn optional(comptime S: type) type {
    return struct {
        pub const Value = ?S.Value;
        pub const Inner = S;
        pub const kind = schema.Kind.optional;
        pub const schema_name = "optional";
        pub const is_optional = true;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node == .null) {
                return schema.failCode(state, .type_mismatch, path, "null", "value when the field is present");
            }
            return try S.decode(state, node, path);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (comptime schema.isScalar(S)) {
                return try S.decodeString(state, raw, path);
            }
            return schema.failCode(state, .unsupported, path, null, "query-decodable schema");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            if (value) |present| try S.check(state, present, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            if (value) |present| {
                try S.encode(state, present);
            } else {
                try state.json.write(null);
            }
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try S.writeJsonSchema(state);
        }
    };
}

pub fn nullable(comptime S: type) type {
    return struct {
        pub const Value = ?S.Value;
        pub const Inner = S;
        pub const kind = schema.Kind.nullable;
        pub const schema_name = "nullable";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node == .null) return null;
            return try S.decode(state, node, path);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (std.mem.eql(u8, raw, "null")) return null;
            if (comptime schema.isScalar(S)) {
                return try S.decodeString(state, raw, path);
            }
            return schema.failCode(state, .unsupported, path, null, "query-decodable schema");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            if (value) |present| try S.check(state, present, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            if (value) |present| {
                try S.encode(state, present);
            } else {
                try state.json.write(null);
            }
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("anyOf");
            try state.json.beginArray();
            try S.writeJsonSchema(state);
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("null");
            try state.json.endObject();
            try state.json.endArray();
            try state.json.endObject();
        }
    };
}

pub fn withDefault(comptime S: type, comptime default_value: S.Value) type {
    return struct {
        pub const Value = S.Value;
        pub const Inner = S;
        pub const kind = schema.Kind.default_value;
        pub const schema_name = "default";
        pub const is_optional = false;
        pub const has_default = true;

        pub fn defaultValue() Value {
            return default_value;
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            return try S.decode(state, node, path);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (comptime schema.isScalar(S)) {
                return try S.decodeString(state, raw, path);
            }
            return schema.failCode(state, .unsupported, path, null, "query-decodable schema");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try S.check(state, value, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try S.encode(state, value);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try S.writeJsonSchema(state);
        }
    };
}

pub fn withDefaultFactory(comptime S: type, comptime factory: fn () S.Value) type {
    return struct {
        pub const Value = S.Value;
        pub const Inner = S;
        pub const kind = schema.Kind.default_value;
        pub const schema_name = "default";
        pub const is_optional = false;
        pub const has_default = true;

        pub fn defaultValue() Value {
            return factory();
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            return try S.decode(state, node, path);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (comptime schema.isScalar(S)) {
                return try S.decodeString(state, raw, path);
            }
            return schema.failCode(state, .unsupported, path, null, "query-decodable schema");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try S.check(state, value, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try S.encode(state, value);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try S.writeJsonSchema(state);
        }
    };
}

pub fn fallback(comptime S: type, comptime value: S.Value) type {
    return struct {
        pub const Value = S.Value;
        pub const Inner = S;
        pub const kind = schema.Kind.fallback;
        pub const schema_name = "fallback";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const mark = state.issues.mark();
            if (S.decode(state, node, path)) |decoded| {
                return decoded;
            } else |err| switch (err) {
                error.OutOfMemory => return err,
                error.Reported => {
                    state.issues.rollback(mark);
                    return value;
                },
            }
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (comptime schema.isScalar(S)) {
                const mark = state.issues.mark();
                if (S.decodeString(state, raw, path)) |decoded| {
                    return decoded;
                } else |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => {
                        state.issues.rollback(mark);
                        return value;
                    },
                }
            }
            return schema.failCode(state, .unsupported, path, null, "query-decodable schema");
        }

        pub fn check(state: *State, candidate: Value, path: []const u8) DecodeError!void {
            try S.check(state, candidate, path);
        }

        pub fn encode(state: *EncodeState, candidate: Value) EncodeError!void {
            try S.encode(state, candidate);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try S.writeJsonSchema(state);
        }
    };
}

pub fn RefineConfig(comptime T: type) type {
    return struct {
        check: *const fn (T) bool,
        message: []const u8 = "value failed a refinement check",
    };
}

pub fn refine(comptime S: type, comptime config: RefineConfig(S.Value)) type {
    return struct {
        pub const Value = S.Value;
        pub const Inner = S;
        pub const kind = schema.Kind.refine;
        pub const schema_name = "refinement";
        pub const is_optional = schema.isOptional(S);
        pub const has_default = schema.hasDefault(S);

        pub fn defaultValue() Value {
            return S.defaultValue();
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const value = try S.decode(state, node, path);
            if (!config.check(value)) {
                return schema.failMessage(state, .refinement_failed, path, config.message, null, config.message);
            }
            return value;
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (comptime schema.isScalar(S)) {
                const value = try S.decodeString(state, raw, path);
                if (!config.check(value)) {
                    return schema.failMessage(state, .refinement_failed, path, config.message, null, config.message);
                }
                return value;
            }
            return schema.failCode(state, .unsupported, path, null, "query-decodable schema");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try S.check(state, value, path);
            if (!config.check(value)) {
                return schema.failMessage(state, .refinement_failed, path, config.message, null, config.message);
            }
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try S.encode(state, value);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try S.writeJsonSchema(state);
        }
    };
}

pub fn TransformConfig(comptime In: type, comptime Out: type) type {
    return struct {
        decode: *const fn (std.mem.Allocator, In) anyerror!Out,
        encode: ?*const fn (std.mem.Allocator, Out) anyerror!In = null,
        check: ?*const fn (Out) bool = null,
        message: []const u8 = "value failed a transformation check",
    };
}

/// A typed transformation from the schema's decoded input to a new output.
///
/// `decode` is required. `encode` makes the transformation reversible so the
/// output can be serialized again; `check` validates an existing output. A
/// transformation without `encode` cannot be serialized or re-checked and
/// reports `error.Unsupported` instead of silently dropping data.
pub fn transform(comptime S: type, comptime config: anytype) type {
    const ConfigType = @TypeOf(config);
    const DecodeInfo = @typeInfo(@TypeOf(config.decode)).@"fn";
    const Ret = DecodeInfo.return_type orelse @compileError("transform.decode needs a concrete return type");
    const Outer = switch (@typeInfo(Ret)) {
        .error_union => |info| info.payload,
        else => Ret,
    };

    comptime {
        if (DecodeInfo.param_types.len != 2) @compileError("transform.decode must be fn (allocator, input) error!output");
        if (DecodeInfo.param_types[0] != std.mem.Allocator) @compileError("transform.decode's first parameter must be std.mem.Allocator");
        if (DecodeInfo.param_types[1] != S.Value) @compileError("transform.decode's input must be " ++ @typeName(S.Value));
        if (@typeInfo(Ret) != .error_union) @compileError("transform.decode must return an error union");
    }

    return struct {
        pub const Value = Outer;
        pub const Input = S;
        pub const kind = schema.Kind.transform;
        pub const schema_name = "transform";
        pub const is_optional = false;
        pub const has_default = false;

        const has_encode = @hasField(ConfigType, "encode");
        const has_check = @hasField(ConfigType, "check");
        const failure_message = if (@hasField(ConfigType, "message")) config.message else "value failed a transformation check";

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const input = try S.decode(state, node, path);
            return config.decode(state.arena, input) catch |err| {
                if (err == error.OutOfMemory) return error.OutOfMemory;
                return schema.fail(state, error.TransformFailed, path, null, failure_message);
            };
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            if (comptime has_check) {
                const candidate = config.check;
                const checked = switch (@typeInfo(@TypeOf(candidate))) {
                    .optional => if (candidate) |output_check| blk: {
                        if (!output_check(value)) {
                            return schema.failMessage(state, .transform_failed, path, failure_message, null, failure_message);
                        }
                        break :blk true;
                    } else false,
                    else => blk: {
                        if (!candidate(value)) {
                            return schema.failMessage(state, .transform_failed, path, failure_message, null, failure_message);
                        }
                        break :blk true;
                    },
                };
                if (checked) return;
            }
            if (comptime has_encode) {
                const candidate = config.encode;
                const candidate_is_optional = switch (@typeInfo(@TypeOf(candidate))) {
                    .optional => true,
                    else => false,
                };
                if (comptime candidate_is_optional) {
                    if (candidate) |encode_output| {
                        const original = encode_output(state.arena, value) catch |err| {
                            if (err == error.OutOfMemory) return error.OutOfMemory;
                            return schema.fail(state, error.TransformFailed, path, null, failure_message);
                        };
                        try S.check(state, original, path);
                        return;
                    }
                } else {
                    const original = candidate(state.arena, value) catch |err| {
                        if (err == error.OutOfMemory) return error.OutOfMemory;
                        return schema.fail(state, error.TransformFailed, path, null, failure_message);
                    };
                    try S.check(state, original, path);
                    return;
                }
            }
            return schema.failCode(state, .unsupported, path, null, "transformation with an encode or check function");
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            if (comptime has_encode) {
                const candidate = config.encode;
                switch (@typeInfo(@TypeOf(candidate))) {
                    .optional => if (candidate) |encode_output| {
                        const input = encode_output(state.allocator, value) catch return error.TransformFailed;
                        try S.encode(state, input);
                        return;
                    },
                    else => {
                        const input = candidate(state.allocator, value) catch return error.TransformFailed;
                        try S.encode(state, input);
                        return;
                    },
                }
            }
            return error.Unsupported;
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try S.writeJsonSchema(state);
        }
    };
}

pub fn lazy(comptime get: fn () type) type {
    return struct {
        pub const Inner = get();
        pub const Value = *const Inner.Value;
        pub const kind = schema.Kind.lazy;
        pub const schema_name = "lazy";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            try state.enter();
            defer state.leave();
            const slot = state.arena.create(Inner.Value) catch return error.OutOfMemory;
            slot.* = try Inner.decode(state, node, path);
            return slot;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try state.enter();
            defer state.leave();
            try Inner.check(state, value.*, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try Inner.encode(state, value.*);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            const key = try state.definitionFor(Inner);
            try state.json.beginObject();
            try state.json.objectField("$ref");
            try state.json.write(std.fmt.allocPrint(state.arena, "#/$defs/{s}", .{key}) catch return error.OutOfMemory);
            try state.json.endObject();
        }
    };
}

pub fn CustomConfig(comptime T: type) type {
    return struct {
        check: *const fn (T) bool,
        message: []const u8 = "value failed a custom check",
    };
}

/// A check-only schema for values that have no JSON representation of their own.
pub fn custom(comptime T: type, comptime config: CustomConfig(T)) type {
    return struct {
        pub const Value = T;
        pub const custom_message = config.message;
        pub const kind = schema.Kind.custom;
        pub const schema_name = "custom";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            _ = node;
            return schema.failCode(state, .unsupported, path, null, "custom schemas validate typed values only");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            if (!config.check(value)) {
                return schema.failMessage(state, .refinement_failed, path, custom_message, null, custom_message);
            }
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            _ = state;
            _ = value;
            return error.Unsupported;
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            _ = state;
            return error.Unsupported;
        }
    };
}

test "optional and nullable are distinct" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const MaybeName = optional(string.string(.{}));
    try std.testing.expectEqualStrings("Ada", (try MaybeName.decode(&state, .{ .string = "Ada" }, "name")).?);
    try std.testing.expectError(error.Reported, MaybeName.decode(&state, .null, "name"));

    const NullableName = nullable(string.string(.{}));
    try std.testing.expect(null == try NullableName.decode(&state, .null, "name"));
    try std.testing.expectEqualStrings("Ada", (try NullableName.decode(&state, .{ .string = "Ada" }, "name")).?);
}

test "defaults and refinements" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Level = withDefault(number.integer(u8, .{}), 3);
    try std.testing.expect(schema.hasDefault(Level));
    try std.testing.expectEqual(@as(u8, 3), Level.defaultValue());

    const Even = refine(number.integer(u8, .{}), .{
        .check = struct {
            fn check(value: u8) bool {
                return value % 2 == 0;
            }
        }.check,
        .message = "must be even",
    });
    try std.testing.expectEqual(@as(u8, 4), try Even.decode(&state, .{ .integer = 4 }, "n"));
    try std.testing.expectError(error.Reported, Even.decode(&state, .{ .integer = 5 }, "n"));
    try std.testing.expectEqualStrings("must be even", list.last().?.message);
}

test "fallback swallows failures" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Port = fallback(number.integer(u16, .{ .max = 1024 }), 8080);
    try std.testing.expectEqual(@as(u16, 8080), try Port.decode(&state, .{ .integer = 9000 }, "port"));
    try std.testing.expectEqual(@as(usize, 0), list.count());
}

test "transform changes the value type" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Doubled = transform(number.integer(i32, .{}), .{
        .decode = struct {
            fn apply(pool: std.mem.Allocator, value: i32) std.mem.Allocator.Error!i32 {
                _ = pool;
                return value * 2;
            }
        }.apply,
        .encode = struct {
            fn apply(pool: std.mem.Allocator, value: i32) std.mem.Allocator.Error!i32 {
                _ = pool;
                return @divExact(value, 2);
            }
        }.apply,
    });
    try std.testing.expectEqual(@as(i32, 42), try Doubled.decode(&state, .{ .integer = 21 }, "n"));
    try Doubled.check(&state, 42, "n");
}

test "custom runs its predicate during typed validation" {
    const allocator = std.testing.allocator;
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const Positive = custom(i32, .{
        .check = struct {
            fn check(value: i32) bool {
                return value > 0;
            }
        }.check,
        .message = "must be positive",
    });

    try Positive.check(&state, 1, "count");
    try std.testing.expectEqual(@as(usize, 0), list.count());
    try std.testing.expectError(error.Reported, Positive.check(&state, -1, "count"));
    try std.testing.expectEqualStrings("E012", list.last().?.code.label());
    try std.testing.expectEqualStrings("must be positive", list.last().?.message);
}
