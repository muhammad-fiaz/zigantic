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

/// Wraps `S` so its field may be absent from the parent object.
/// `Value` is `?S.Value`; absent decodes as null and encodes as JSON null,
/// while a present JSON null is a type mismatch.
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

/// Wraps `S` so its value may be an explicit JSON null. `Value` is `?S.Value`;
/// null decodes to null and encodes to null, while non-null delegates to `S`.
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

/// Wraps `S` so its field may be absent or an explicit JSON null.
/// `Value` is `?S.Value`; nullish accepts both absent and null,
/// unlike `optional` and `nullable` which accept only one.
pub fn nullish(comptime S: type) type {
    return struct {
        pub const Value = ?S.Value;
        pub const Inner = S;
        pub const kind = schema.Kind.optional;
        pub const schema_name = "nullish";
        pub const is_optional = true;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node == .null) return null;
            return try S.decode(state, node, path);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (std.mem.eql(u8, raw, "null")) return null;
            if (comptime schema.isScalar(S)) return try S.decodeString(state, raw, path);
            return schema.failCode(state, .unsupported, path, null, "query-decodable schema");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            if (value) |present| try S.check(state, present, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            if (value) |present| try S.encode(state, present) else try state.json.write(null);
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

/// Annotation carrier for `meta`. `id`, `title`, and `description` map to
/// JSON Schema keywords; examples, deprecated, and read/write-only flag emit conditionally.
pub const Metadata = struct {
    id: ?[]const u8 = null,
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
    examples: []const []const u8 = &.{},
    deprecated: bool = false,
    read_only: bool = false,
    write_only: bool = false,
};

/// Adds JSON Schema metadata while preserving all validation and encoding
/// behaviour of the wrapped schema. Metadata is emitted through `allOf`, so the
/// original constraints remain in force.
pub fn meta(comptime S: type, comptime metadata: Metadata) type {
    return struct {
        pub const Value = S.Value;
        pub const Inner = S;
        pub const kind = schema.Kind.metadata;
        pub const schema_name = "metadata";
        pub const is_optional = schema.isOptional(S);
        pub const has_default = schema.hasDefault(S);

        pub fn defaultValue() Value {
            return S.defaultValue();
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            return try S.decode(state, node, path);
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (comptime schema.isScalar(S)) return try S.decodeString(state, raw, path);
            return schema.failCode(state, .unsupported, path, null, "query-decodable schema");
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try S.check(state, value, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try S.encode(state, value);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("allOf");
            try state.json.beginArray();
            try S.writeJsonSchema(state);
            try state.json.endArray();
            if (metadata.id) |id| {
                try state.json.objectField(state.target.idKeyword());
                try state.json.write(id);
            }
            if (metadata.title) |title| {
                try state.json.objectField("title");
                try state.json.write(title);
            }
            if (metadata.description) |description| {
                try state.json.objectField("description");
                try state.json.write(description);
            }
            if (metadata.examples.len > 0 and state.target.supportsExamples()) {
                try state.json.objectField("examples");
                try state.json.beginArray();
                for (metadata.examples) |example| try state.json.write(example);
                try state.json.endArray();
            }
            if (metadata.deprecated and state.target != .draft_07 and state.target != .draft_06 and state.target != .draft_05) {
                try state.json.objectField("deprecated");
                try state.json.write(true);
            }
            if (state.target.supportsReadWriteOnly()) {
                if (metadata.read_only) {
                    try state.json.objectField("readOnly");
                    try state.json.write(true);
                }
                if (metadata.write_only) {
                    try state.json.objectField("writeOnly");
                    try state.json.write(true);
                }
            }
            try state.json.endObject();
        }
    };
}

fn writeDefaultSchema(state: *SchemaState, comptime S: type, value: S.Value) SchemaError!void {
    try state.json.beginObject();
    try state.json.objectField("allOf");
    try state.json.beginArray();
    try S.writeJsonSchema(state);
    try state.json.endArray();
    try state.json.objectField("default");
    var encode_state = EncodeState{ .allocator = state.arena, .json = state.json };
    S.encode(&encode_state, value) catch return error.Unsupported;
    try state.json.endObject();
}

/// Wraps `S` and supplies `default_value` when a field is absent.
/// `Value` is `S.Value`; the default is returned by `defaultValue` and emitted as the `default` keyword.
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
            try writeDefaultSchema(state, S, default_value);
        }
    };
}

/// Wraps `S` and supplies a default by calling `factory` when a field is absent.
/// `Value` is `S.Value`; `defaultValue` invokes the factory on each access,
/// so mutable defaults are refreshed.
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

/// Wraps `S` and returns `value` when decoding fails. `Value` is `S.Value`;
/// on `error.Reported` recorded issues are rolled back, while `OutOfMemory` propagates.
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

/// Configuration for `refine`. `check` must return true for a value to pass;
/// `message` is placed in the refinement failure issue.
pub fn RefineConfig(comptime T: type) type {
    return struct {
        check: *const fn (T) bool,
        message: []const u8 = "value failed a refinement check",
    };
}

/// Wraps `S` and requires `config.check` to hold for the decoded value.
/// `Value` is `S.Value`; failure records a `refinement_failed` issue with `config.message`.
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

/// Configuration for `transform`. `decode` maps `In` to the callback payload (`Out`);
/// optional `encode` and `check` enable reversible encoding and output validation.
pub fn TransformConfig(comptime In: type, comptime Out: type) type {
    return struct {
        decode: *const fn (std.mem.Allocator, In) anyerror!Out,
        encode: ?*const fn (std.mem.Allocator, Out) anyerror!In = null,
        check: ?*const fn (Out) bool = null,
        message: []const u8 = "value failed a transformation check",
    };
}

/// Decodes `S`, then applies `config.decode` to produce `Value`. `Value` is the
/// callback payload type; without `encode` the result cannot be re-encoded
/// and `encode` reports `error.Unsupported`.
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

/// Configuration for `codec`. `decode` maps `In.Value` to `Out.Value`;
/// `encode` maps the reverse direction. Both receive the arena allocator.
pub fn CodecConfig(comptime In: type, comptime Out: type) type {
    return struct {
        decode: *const fn (std.mem.Allocator, In.Value) anyerror!Out.Value,
        encode: *const fn (std.mem.Allocator, Out.Value) anyerror!In.Value,
        message: []const u8 = "value could not be encoded or decoded",
    };
}

/// Validates with `InputSchema`, maps via `config.decode`, then validates with `OutputSchema`.
/// `Value` is `OutputSchema.Value`; encoding reverses the mapping and serializes through `InputSchema`.
pub fn codec(comptime InputSchema: type, comptime OutputSchema: type, comptime config: anytype) type {
    const DecodeInfo = @typeInfo(@TypeOf(config.decode)).@"fn";
    const EncodeInfo = @typeInfo(@TypeOf(config.encode)).@"fn";
    comptime {
        if (DecodeInfo.param_types.len != 2 or DecodeInfo.param_types[0] != std.mem.Allocator or DecodeInfo.param_types[1] != InputSchema.Value) {
            @compileError("codec.decode must be fn (Allocator, Input.Value) error!Output.Value");
        }
        if (EncodeInfo.param_types.len != 2 or EncodeInfo.param_types[0] != std.mem.Allocator or EncodeInfo.param_types[1] != OutputSchema.Value) {
            @compileError("codec.encode must be fn (Allocator, Output.Value) error!Input.Value");
        }
    }

    const failure_message = if (@hasField(@TypeOf(config), "message")) config.message else "value could not be encoded or decoded";

    return struct {
        pub const Value = OutputSchema.Value;
        pub const Input = InputSchema;
        pub const OutputSchemaType = OutputSchema;
        pub const kind = schema.Kind.transform;
        pub const schema_name = "codec";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const input = try InputSchema.decode(state, node, path);
            const output = config.decode(state.arena, input) catch |err| {
                if (err == error.OutOfMemory) return error.OutOfMemory;
                return schema.fail(state, error.TransformFailed, path, null, failure_message);
            };
            try OutputSchema.check(state, output, path);
            return output;
        }

        pub fn decodeString(state: *State, raw: []const u8, path: []const u8) DecodeError!Value {
            if (comptime !schema.isScalar(InputSchema)) return schema.failCode(state, .unsupported, path, null, "query-decodable input schema");
            const input = try InputSchema.decodeString(state, raw, path);
            const output = config.decode(state.arena, input) catch |err| {
                if (err == error.OutOfMemory) return error.OutOfMemory;
                return schema.fail(state, error.TransformFailed, path, null, failure_message);
            };
            try OutputSchema.check(state, output, path);
            return output;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try OutputSchema.check(state, value, path);
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            const input = config.encode(state.allocator, value) catch |err| {
                if (err == error.OutOfMemory) return error.OutOfMemory;
                return error.TransformFailed;
            };
            try InputSchema.encode(state, input);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try InputSchema.writeJsonSchema(state);
        }
    };
}

/// Wraps the type returned by `get()` via a deferred thunk for recursive schemas.
/// `Value` is `*const Inner.Value` allocated in the arena; decoding enters a depth-guarded inner decode.
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
            try state.json.write(std.fmt.allocPrint(state.arena, "{s}{s}", .{ state.target.refPrefix(), key }) catch return error.OutOfMemory);
            try state.json.endObject();
        }
    };
}

/// Configuration for `custom`. At least one of `check` (simple predicate)
/// or `validate` (issue-recording validator) must be set; `message` is used for predicate failures.
pub fn CustomConfig(comptime T: type) type {
    return struct {
        check: ?*const fn (T) bool = null,
        validate: ?*const fn (*schema.Context, T) schema.DecodeError!void = null,
        message: []const u8 = "value failed a custom check",
    };
}

/// Check-only schema for values with no JSON representation of their own. `Value` is `T`;
/// supply `check` or `validate`, where `validate` records issues on the context and must return normally.
pub fn custom(comptime T: type, comptime config: CustomConfig(T)) type {
    comptime {
        if (config.check == null and config.validate == null) {
            @compileError("custom requires a check or validate callback");
        }
    }

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
            if (config.validate) |validate_fn| {
                const before = state.issues.count();
                var context = schema.Context{ .state = state, .path = path };
                try validate_fn(&context, value);
                if (state.issues.count() > before) return error.Reported;
                return;
            }
            if (!config.check.?(value)) {
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

test "nullish accepts absence or null and metadata is additive" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const MaybeName = nullish(string.string(.{}));
    try std.testing.expect(null == try MaybeName.decode(&state, .null, "name"));
    try std.testing.expectEqualStrings("Ada", (try MaybeName.decode(&state, .{ .string = "Ada" }, "name")).?);

    const Name = meta(string.string(.{}), .{
        .title = "Display name",
        .examples = &.{ "Ada", "Grace" },
        .read_only = true,
    });
    try std.testing.expectEqualStrings("Ada", try Name.decode(&state, .{ .string = "Ada" }, "name"));
    try Name.check(&state, "Ada", "name");

    const document = try @import("json_schema.zig").generate(Name, allocator, .{});
    defer allocator.free(document);
    try std.testing.expect(std.mem.indexOf(u8, document, "\"title\":\"Display name\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, document, "\"readOnly\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, document, "\"allOf\"") != null);
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

    const Ranged = custom(i32, .{
        .validate = struct {
            fn validate(ctx: *schema.Context, value: i32) schema.DecodeError!void {
                if (value < 0) try ctx.addIssue(.too_small, "must not be negative");
                if (value > 100) try ctx.addIssue(.too_large, "must not exceed 100");
            }
        }.validate,
    });
    try std.testing.expectError(error.Reported, Ranged.check(&state, -1, "count"));
    try std.testing.expectEqualStrings("must not be negative", list.last().?.message);
}
