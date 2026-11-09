//! Object schemas: declared-model binding and inferred models.
//!
//! `object` binds a schema to an existing Zig struct and verifies every field
//! at compile time. `objectOf` synthesizes a struct type from the schema with
//! Zig 0.17's `@Struct` builtin, so callers never have to declare a parallel
//! model just to parse JSON.

const std = @import("std");
const schema = @import("schema.zig");
const naming = @import("naming.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

/// Configuration for object schemas: naming policy, unknown-field handling,
/// input aliases, partial mode, and optional description for JSON Schema output.
pub const Config = struct {
    naming: naming.Policy = .verbatim,
    unknown_fields: schema.UnknownFields = .reject,
    aliases: []const naming.Alias = &.{},
    partial: bool = false,
    description: []const u8 = "",
};

fn isOptionalType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .optional => true,
        else => false,
    };
}

fn isConstSlice(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |info| info.size == .slice and info.attrs.@"const",
        else => false,
    };
}

fn hasEmptyValue(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "empty") and @TypeOf(T.empty) == T,
        else => false,
    };
}

fn canZero(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .float, .bool, .void, .null, .@"enum", .vector => true,
        .optional => |info| canZero(info.child),
        .array => |info| canZero(info.child),
        .@"struct" => |info| blk: {
            for (info.field_types) |Field| if (!canZero(Field)) break :blk false;
            break :blk true;
        },
        else => false,
    };
}

fn initialValue(comptime T: type) T {
    const info = @typeInfo(T).@"struct";
    // `object` with `.partial` may leave fields without a schema or default
    // absent. Give each field the best defined initializer available instead of
    // requiring the whole model to be trivially zeroable (a record contains
    // pointers, for example).
    var out: T = undefined;
    inline for (info.field_names, 0..) |name, index| {
        const Field = info.field_types[index];
        if (info.field_attrs[index].defaultValue(Field)) |value| {
            @field(out, name) = value;
        } else if (comptime isOptionalType(Field)) {
            @field(out, name) = null;
        } else if (comptime isConstSlice(Field)) {
            @field(out, name) = @as(Field, &.{});
        } else if (comptime hasEmptyValue(Field)) {
            @field(out, name) = Field.empty;
        } else if (comptime canZero(Field)) {
            @field(out, name) = std.mem.zeroes(Field);
        }
    }
    return out;
}

fn requiredKey(comptime name: []const u8, comptime config: Config) []const u8 {
    return naming.keyFor(name, config.naming);
}

fn sentinelName(comptime text: []const u8) [text.len:0]u8 {
    var out: [text.len:0]u8 = undefined;
    @memcpy(out[0..text.len], text);
    out[text.len] = 0;
    return out;
}

fn generatedDefaultPtr(comptime S: type) ?*const anyopaque {
    if (comptime schema.isOptional(S)) {
        const value: S.Value = null;
        return @ptrCast(&value);
    }
    if (comptime schema.hasDefault(S)) {
        const value = S.defaultValue();
        return @ptrCast(&value);
    }
    return null;
}

/// Builds an inferred object schema; Value is a synthesized struct of field Values.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
/// Partial mode requires every field optional or defaulted; aliases and naming apply per Config.
/// Duplicate mapped keys fail at compile time; missing required fields report at decode.
pub fn objectOf(comptime schemas: anytype, comptime config: Config) type {
    const schema_info = @typeInfo(@TypeOf(schemas)).@"struct";
    const count = schema_info.field_names.len;

    const Meta = struct {
        const keys = blk: {
            var out: [count][]const u8 = undefined;
            for (schema_info.field_names, 0..) |name, index| {
                out[index] = naming.keyFor(name, config.naming);
            }
            break :blk out;
        };

        const field_names = blk: {
            var out: [count][:0]const u8 = undefined;
            for (keys, 0..) |key, index| {
                out[index] = &sentinelName(key);
            }
            break :blk out;
        };

        const field_types = blk: {
            var out: [count]type = undefined;
            for (schema_info.field_names, 0..) |name, index| {
                out[index] = @field(schemas, name).Value;
            }
            break :blk out;
        };

        const field_attrs = blk: {
            var out: [count]std.lang.Type.Struct.FieldAttributes = undefined;
            for (schema_info.field_names, 0..) |name, index| {
                out[index] = .{ .default_value_ptr = generatedDefaultPtr(@field(schemas, name)) };
            }
            break :blk out;
        };
    };

    comptime {
        for (Meta.keys, 0..) |key, left| {
            for (Meta.keys[0..left]) |previous| {
                if (std.mem.eql(u8, key, previous)) {
                    @compileError("naming policy produces duplicate object key '" ++ key ++ "'");
                }
            }
        }
        if (config.partial) {
            for (schema_info.field_names) |name| {
                const S = @field(schemas, name);
                if (!schema.isOptional(S) and !schema.hasDefault(S)) {
                    @compileError("partial inferred objects require every field to be optional or defaulted; '" ++ name ++ "' is required");
                }
            }
        }
    }

    return struct {
        pub const Value = @Struct(.auto, null, &Meta.field_names, &Meta.field_types, &Meta.field_attrs);
        pub const fields = schemas;
        pub const object_config = config;
        pub const kind = schema.Kind.object;
        pub const schema_name = "object";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node != .object) {
                return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "object");
            }
            try state.enter();
            defer state.leave();

            var out: Value = undefined;
            var seen: [count]bool = undefined;
            for (&seen) |*flag| flag.* = false;
            var failed = false;

            var iterator = node.object.iterator();
            outer_loop: while (iterator.next()) |entry| {
                const key = entry.key_ptr.*;
                inline for (schema_info.field_names, 0..) |name, index| {
                    inline for (comptime naming.inputKeys(name, config.naming, config.aliases)) |candidate| {
                        if (std.mem.eql(u8, candidate, key)) {
                            const S = @field(schemas, name);
                            const child = try schema.pathField(state, path, key);
                            const decoded = S.decode(state, entry.value_ptr.*, child) catch |err| switch (err) {
                                error.OutOfMemory => return err,
                                error.Reported => {
                                    if (state.options.hooks.on_field) |hook| hook(child, false);
                                    failed = true;
                                    continue :outer_loop;
                                },
                            };
                            @field(out, naming.keyFor(name, config.naming)) = decoded;
                            seen[index] = true;
                            if (state.options.hooks.on_field) |hook| hook(child, true);
                            continue :outer_loop;
                        }
                    }
                }
                const policy = state.options.unknown_fields orelse config.unknown_fields;
                if (state.options.hooks.on_field) |hook| hook(key, false);
                if (policy == .reject) {
                    const child = try schema.pathField(state, path, key);
                    try schema.note(state, .unknown_field, child, try schema.quote(state, key), "no additional fields");
                    failed = true;
                }
            }

            inline for (schema_info.field_names, 0..) |name, index| {
                if (!seen[index]) {
                    const S = @field(schemas, name);
                    if (comptime schema.isOptional(S)) {
                        @field(out, naming.keyFor(name, config.naming)) = null;
                    } else if (comptime schema.hasDefault(S)) {
                        @field(out, naming.keyFor(name, config.naming)) = S.defaultValue();
                    } else {
                        const child = try schema.pathField(state, path, requiredKey(name, config));
                        try schema.note(state, .missing_field, child, null, S.schema_name);
                        failed = true;
                    }
                }
            }

            if (failed) return error.Reported;
            return out;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            var failed = false;
            inline for (schema_info.field_names) |name| {
                const S = @field(schemas, name);
                const child = try schema.pathField(state, path, requiredKey(name, config));
                S.check(state, @field(value, naming.keyFor(name, config.naming)), child) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => failed = true,
                };
            }
            if (failed) return error.Reported;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try state.json.beginObject();
            inline for (schema_info.field_names) |name| {
                const S = @field(schemas, name);
                const key = comptime requiredKey(name, config);
                const field_value = @field(value, key);
                if (comptime schema.isOptional(S) or S.kind == schema.Kind.nullable) {
                    if (field_value) |present| {
                        try state.json.objectField(key);
                        try S.encode(state, @as(S.Value, present));
                    } else if (state.options.emit_null_fields) {
                        try state.json.objectField(key);
                        try state.json.write(null);
                    }
                } else {
                    try state.json.objectField(key);
                    try S.encode(state, field_value);
                }
            }
            try state.json.endObject();
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("object");
            try state.json.objectField("properties");
            try state.json.beginObject();
            inline for (schema_info.field_names) |name| {
                const S = @field(schemas, name);
                try state.json.objectField(requiredKey(name, config));
                try S.writeJsonSchema(state);
            }
            try state.json.endObject();

            var required_count: usize = 0;
            inline for (schema_info.field_names) |name| {
                const S = @field(schemas, name);
                if (comptime !schema.isOptional(S) and !schema.hasDefault(S) and !config.partial) required_count += 1;
            }
            if (required_count > 0) {
                try state.json.objectField("required");
                try state.json.beginArray();
                inline for (schema_info.field_names) |name| {
                    const S = @field(schemas, name);
                    if (comptime !schema.isOptional(S) and !schema.hasDefault(S) and !config.partial) {
                        try state.json.write(requiredKey(name, config));
                    }
                }
                try state.json.endArray();
            }

            try state.json.objectField("additionalProperties");
            try state.json.write(config.unknown_fields == .strip);
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

fn FieldsType(comptime names: []const []const u8, comptime types: []const type) type {
    var field_names: [names.len][:0]const u8 = undefined;
    inline for (names, 0..) |name, index| field_names[index] = &sentinelName(name);
    var field_types: [types.len]type = undefined;
    inline for (types, 0..) |FieldType, index| field_types[index] = FieldType;
    var attrs: [names.len]std.lang.Type.Struct.FieldAttributes = undefined;
    inline for (&attrs) |*attr| attr.* = .{};
    return @Struct(.auto, null, &field_names, &field_types, &attrs);
}

fn fieldCount(comptime T: type) comptime_int {
    return @typeInfo(T).@"struct".field_names.len;
}

fn mergedNames(comptime first: type, comptime second: type) [fieldCount(@TypeOf(first.fields)) + fieldCount(@TypeOf(second.fields))][]const u8 {
    const first_info = @typeInfo(@TypeOf(first.fields)).@"struct";
    const second_info = @typeInfo(@TypeOf(second.fields)).@"struct";
    var names: [first_info.field_names.len + second_info.field_names.len][]const u8 = undefined;
    var at: usize = 0;
    for (first_info.field_names) |name| {
        names[at] = name;
        at += 1;
    }
    for (second_info.field_names) |name| {
        for (names[0..at]) |existing| {
            if (std.mem.eql(u8, existing, name)) @compileError("merge contains duplicate field '" ++ name ++ "'");
        }
        names[at] = name;
        at += 1;
    }
    return names;
}

fn mergedTypes(comptime first: type, comptime second: type) [fieldCount(@TypeOf(first.fields)) + fieldCount(@TypeOf(second.fields))]type {
    const names = mergedNames(first, second);
    var types: [names.len]type = undefined;
    inline for (names, 0..) |name, index| {
        if (@hasField(@TypeOf(first.fields), name)) {
            types[index] = @TypeOf(@field(first.fields, name));
        } else {
            types[index] = @TypeOf(@field(second.fields, name));
        }
    }
    return types;
}

/// Merges two inferred-object field sets into a new object schema.
/// Duplicate field names are a compile-time error.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
pub fn merge(comptime first: type, comptime second: type, comptime config: Config) type {
    const names = mergedNames(first, second);
    const types = mergedTypes(first, second);
    const Fields = FieldsType(names[0..], types[0..]);
    var fields: Fields = undefined;
    inline for (@typeInfo(@TypeOf(first.fields)).@"struct".field_names) |name| {
        @field(fields, name) = @field(first.fields, name);
    }
    inline for (@typeInfo(@TypeOf(second.fields)).@"struct".field_names) |name| {
        @field(fields, name) = @field(second.fields, name);
    }
    return objectOf(fields, config);
}

/// Extends an inferred-object field set with additional fields.
/// Duplicate field names are a compile-time error.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
pub fn extend(comptime first: type, comptime second: type, comptime config: Config) type {
    return merge(first, second, config);
}

/// Selects fields from an inferred-object field set into a new object schema.
/// Every selected name must exist; unknown or duplicate names fail at compile time.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
pub fn pick(comptime schemas: type, comptime selected: []const []const u8, comptime config: Config) type {
    for (selected, 0..) |name, index| {
        if (!@hasField(@TypeOf(schemas.fields), name)) @compileError("pick selects unknown field '" ++ name ++ "'");
        for (selected[0..index]) |previous| {
            if (std.mem.eql(u8, previous, name)) @compileError("pick contains duplicate field '" ++ name ++ "'");
        }
    }
    var types: [selected.len]type = undefined;
    inline for (selected, 0..) |name, index| types[index] = @TypeOf(@field(schemas.fields, name));
    const Fields = FieldsType(selected, &types);
    var fields: Fields = undefined;
    inline for (selected) |name| @field(fields, name) = @field(schemas.fields, name);
    return objectOf(fields, config);
}

/// Removes fields from an inferred-object field set into a new object schema.
/// Unknown names are ignored; remaining field order is preserved.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
pub fn omit(comptime schemas: type, comptime excluded: []const []const u8, comptime config: Config) type {
    const info = @typeInfo(@TypeOf(schemas.fields)).@"struct";
    var count: usize = 0;
    for (info.field_names) |name| {
        var skip = false;
        for (excluded) |item| if (std.mem.eql(u8, name, item)) {
            skip = true;
            break;
        };
        if (!skip) count += 1;
    }
    var names: [count][]const u8 = undefined;
    var types: [count]type = undefined;
    var at: usize = 0;
    for (info.field_names) |name| {
        var skip = false;
        for (excluded) |item| if (std.mem.eql(u8, name, item)) {
            skip = true;
            break;
        };
        if (skip) continue;
        names[at] = name;
        types[at] = @TypeOf(@field(schemas.fields, name));
        at += 1;
    }
    const Fields = FieldsType(names[0..count], types[0..count]);
    var fields: Fields = undefined;
    for (info.field_names) |name| {
        var skip = false;
        for (excluded) |item| if (std.mem.eql(u8, name, item)) {
            skip = true;
            break;
        };
        if (!skip) @field(fields, name) = @field(schemas.fields, name);
    }
    return objectOf(fields, config);
}

/// Binds declared model struct T to per-field schemas; Value is T.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
/// Schema fields must exist on T with matching Value type; uncovered T fields require
/// a default, optional type, or partial mode. Decode reports missing/unknown fields.
pub fn object(comptime T: type, comptime schemas: anytype, comptime config: Config) type {
    const model_info = @typeInfo(T).@"struct";
    const schema_info = @typeInfo(@TypeOf(schemas)).@"struct";

    comptime {
        for (schema_info.field_names) |name| {
            const field_index = schema.fieldIndex(T, name) orelse
                @compileError("field '" ++ name ++ "' does not exist on " ++ @typeName(T));
            const S = @field(schemas, name);
            const Field = model_info.field_types[field_index];
            if (!schema.isRecursive(S)) {
                if (S.Value != Field) {
                    @compileError("schema for '" ++ name ++ "' produces " ++ @typeName(S.Value) ++ " but the model field is " ++ @typeName(Field));
                }
            }
        }
        for (model_info.field_names, 0..) |name, index| {
            if (schema.fieldIndex(@TypeOf(schemas), name) != null) continue;
            const Field = model_info.field_types[index];
            const has_default = model_info.field_attrs[index].defaultValue(Field) != null;
            if (!has_default and !isOptionalType(Field) and !config.partial) {
                @compileError("field '" ++ name ++ "' has no schema, no default value and cannot be omitted");
            }
        }
    }

    return struct {
        pub const Value = T;
        pub const model = T;
        pub const fields = schemas;
        pub const object_config = config;
        pub const kind = schema.Kind.object;
        pub const schema_name = "object";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node != .object) {
                return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "object");
            }
            try state.enter();
            defer state.leave();

            var out: T = initialValue(T);
            var seen: [schema_info.field_names.len]bool = undefined;
            for (&seen) |*flag| flag.* = false;
            var failed = false;

            var iterator = node.object.iterator();
            outer_loop: while (iterator.next()) |entry| {
                const key = entry.key_ptr.*;
                var matched = false;
                inline for (schema_info.field_names, 0..) |name, index| {
                    if (!matched) {
                        inline for (comptime naming.inputKeys(name, config.naming, config.aliases)) |candidate| {
                            if (!matched and std.mem.eql(u8, candidate, key)) {
                                matched = true;
                                seen[index] = true;
                                const S = @field(schemas, name);
                                const child = try schema.pathField(state, path, key);
                                const decoded = S.decode(state, entry.value_ptr.*, child) catch |err| switch (err) {
                                    error.OutOfMemory => return err,
                                    error.Reported => {
                                        if (state.options.hooks.on_field) |hook| hook(child, false);
                                        failed = true;
                                        continue :outer_loop;
                                    },
                                };
                                @field(out, name) = decoded;
                                seen[index] = true;
                                if (state.options.hooks.on_field) |hook| hook(child, true);
                                continue :outer_loop;
                            }
                        }
                    }
                }
                if (!matched) {
                    const policy = state.options.unknown_fields orelse config.unknown_fields;
                    if (state.options.hooks.on_field) |hook| hook(key, false);
                    if (policy == .reject) {
                        const child = try schema.pathField(state, path, key);
                        try schema.note(state, .unknown_field, child, try schema.quote(state, key), "no additional fields");
                        failed = true;
                    }
                }
            }

            inline for (schema_info.field_names, 0..) |name, index| {
                if (!seen[index]) {
                    const S = @field(schemas, name);
                    const field_index = comptime schema.fieldIndex(T, name).?;
                    const Field = model_info.field_types[field_index];
                    const has_model_default = model_info.field_attrs[field_index].defaultValue(Field) != null;
                    if (comptime schema.isOptional(S)) {
                        @field(out, name) = null;
                    } else if (comptime schema.hasDefault(S)) {
                        @field(out, name) = S.defaultValue();
                    } else if (comptime isOptionalType(Field) or config.partial or has_model_default) {
                        // initialValue already holds the model default or null
                    } else {
                        const child = try schema.pathField(state, path, requiredKey(name, config));
                        try schema.note(state, .missing_field, child, null, S.schema_name);
                        failed = true;
                    }
                }
            }

            if (failed) return error.Reported;
            return out;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            var failed = false;
            inline for (schema_info.field_names) |name| {
                const S = @field(schemas, name);
                const child = try schema.pathField(state, path, requiredKey(name, config));
                S.check(state, @field(value, name), child) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => failed = true,
                };
            }
            if (failed) return error.Reported;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try state.json.beginObject();
            inline for (schema_info.field_names) |name| {
                const S = @field(schemas, name);
                const key = comptime requiredKey(name, config);
                if (comptime schema.isOptional(S) or S.kind == schema.Kind.nullable) {
                    const optional_value = @field(value, name);
                    if (optional_value) |present| {
                        try state.json.objectField(key);
                        try S.encode(state, @as(S.Value, present));
                    } else if (state.options.emit_null_fields) {
                        try state.json.objectField(key);
                        try state.json.write(null);
                    }
                } else {
                    try state.json.objectField(key);
                    try S.encode(state, @field(value, name));
                }
            }
            try state.json.endObject();
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("object");
            try state.json.objectField("properties");
            try state.json.beginObject();
            inline for (schema_info.field_names) |name| {
                const S = @field(schemas, name);
                try state.json.objectField(requiredKey(name, config));
                try S.writeJsonSchema(state);
            }
            try state.json.endObject();

            var required_count: usize = 0;
            inline for (schema_info.field_names) |name| {
                const S = @field(schemas, name);
                const field_index = comptime schema.fieldIndex(T, name).?;
                const Field = model_info.field_types[field_index];
                const has_model_default = model_info.field_attrs[field_index].defaultValue(Field) != null;
                if (comptime !schema.isOptional(S) and !schema.hasDefault(S) and !isOptionalType(Field) and !config.partial and !has_model_default) {
                    required_count += 1;
                }
            }
            if (required_count > 0) {
                try state.json.objectField("required");
                try state.json.beginArray();
                inline for (schema_info.field_names) |name| {
                    const S = @field(schemas, name);
                    const field_index = comptime schema.fieldIndex(T, name).?;
                    const Field = model_info.field_types[field_index];
                    const has_model_default = model_info.field_attrs[field_index].defaultValue(Field) != null;
                    if (comptime !schema.isOptional(S) and !schema.hasDefault(S) and !isOptionalType(Field) and !config.partial and !has_model_default) {
                        try state.json.write(requiredKey(name, config));
                    }
                }
                try state.json.endArray();
            }

            try state.json.objectField("additionalProperties");
            try state.json.write(additionalAllowed(config.unknown_fields));
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }

        fn additionalAllowed(comptime policy: schema.UnknownFields) bool {
            return policy == .strip;
        }
    };
}

test "object decode, defaults and errors" {
    const allocator = std.testing.allocator;
    const User = struct {
        name: []const u8,
        email: []const u8,
        age: u8,
        active: bool = true,
    };

    const UserSchema = object(User, .{
        .name = @import("string.zig").string(.{ .min = 1 }),
        .email = @import("string.zig").email(.{}),
        .age = @import("number.zig").integer(u8, .{ .min = 18 }),
        .active = @import("primitive.zig").boolean(.{}),
    }, .{});

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const node = try std.json.parseFromSlice(std.json.Value, allocator,
        \\{"name":"Ada","email":"ada@example.com","age":36}
    , .{});
    defer node.deinit();

    const user = try UserSchema.decode(&state, node.value, "$");
    try std.testing.expectEqualStrings("Ada", user.name);
    try std.testing.expectEqual(@as(u8, 36), user.age);
    try std.testing.expect(user.active);

    const bad = try std.json.parseFromSlice(std.json.Value, allocator, "{}", .{});
    defer bad.deinit();
    try std.testing.expectError(error.Reported, UserSchema.decode(&state, bad.value, "$"));
}

test "object rejects unknown fields" {
    const allocator = std.testing.allocator;
    const Point = struct { x: i32, y: i32 };
    const PointSchema = object(Point, .{
        .x = @import("number.zig").integer(i32, .{}),
        .y = @import("number.zig").integer(i32, .{}),
    }, .{});

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const node = try std.json.parseFromSlice(std.json.Value, allocator, "{\"x\":1,\"y\":2,\"z\":3}", .{});
    defer node.deinit();
    try std.testing.expectError(error.Reported, PointSchema.decode(&state, node.value, "$"));
    try std.testing.expectEqualStrings("E008", list.last().?.code.label());
    try std.testing.expectEqualStrings("$.z", list.last().?.path);
}

test "inferred object schema" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const number = @import("number.zig");
    const primitive = @import("primitive.zig");
    const modifiers = @import("modifiers.zig");

    const Profile = objectOf(.{
        .user_name = string.string(.{ .min = 1 }),
        .age = number.integer(u8, .{ .min = 18 }),
        .active = modifiers.withDefault(primitive.boolean(.{}), true),
        .nickname = modifiers.optional(string.string(.{})),
    }, .{ .naming = .camel_case });

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const node = try std.json.parseFromSlice(std.json.Value, allocator,
        \\{"userName":"Ada","age":36}
    , .{});
    defer node.deinit();

    const profile = try Profile.decode(&state, node.value, "$");
    try std.testing.expectEqualStrings("Ada", profile.userName);
    try std.testing.expectEqual(@as(u8, 36), profile.age);
    try std.testing.expect(profile.active);
    try std.testing.expect(profile.nickname == null);
    try Profile.check(&state, profile, "$");
}

test "merging and selecting inferred fields" {
    const string = @import("string.zig");
    const number = @import("number.zig");

    const Name = objectOf(.{ .name = string.string(.{}) }, .{});
    const Age = objectOf(.{ .age = number.integer(u8, .{}) }, .{});
    const Both = merge(Name, Age, .{});
    try std.testing.expect(@hasField(Both.Value, "name"));
    try std.testing.expect(@hasField(Both.Value, "age"));

    const OnlyName = pick(Both, &.{"name"}, .{});
    try std.testing.expect(@hasField(OnlyName.Value, "name"));
    try std.testing.expect(!@hasField(OnlyName.Value, "age"));

    const NoName = omit(Both, &.{"name"}, .{});
    try std.testing.expect(!@hasField(NoName.Value, "name"));
    try std.testing.expect(@hasField(NoName.Value, "age"));
}

test "partial declared objects initialize omitted fields" {
    const allocator = std.testing.allocator;
    const Partial = struct {
        name: []const u8,
        age: u8,
    };
    const PartialSchema = object(Partial, .{
        .name = @import("string.zig").string(.{}),
        .age = @import("number.zig").integer(u8, .{}),
    }, .{ .partial = true });

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const node = try std.json.parseFromSlice(std.json.Value, allocator, "{}", .{});
    defer node.deinit();

    const value = try PartialSchema.decode(&state, node.value, "$");
    try std.testing.expectEqual(@as(usize, 0), value.name.len);
    try std.testing.expectEqual(@as(u8, 0), value.age);
    try PartialSchema.check(&state, value, "$");
    try std.testing.expect(list.isEmpty());
}
