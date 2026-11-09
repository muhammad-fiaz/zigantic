//! Tagged union and discriminated-union schemas.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

pub const UnionConfig = struct {
    description: []const u8 = "",
};

fn VariantNames(comptime variants: anytype) type {
    return struct {
        const info = @typeInfo(@TypeOf(variants)).@"struct";
        const Built = struct {
            bytes: [512]u8,
            len: usize,
        };
        const built: Built = blk: {
            var buffer: [512]u8 = undefined;
            @memset(&buffer, 0);
            var len: usize = 0;
            for (info.field_names, 0..) |name, index| {
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

fn unionFieldIndex(comptime U: type, comptime name: []const u8) ?usize {
    const info = @typeInfo(U).@"union";
    for (info.field_names, 0..) |field_name, index| {
        if (std.mem.eql(u8, field_name, name)) return index;
    }
    return null;
}

fn validate(comptime U: type, comptime variants: anytype) void {
    comptime {
        switch (@typeInfo(U)) {
            .@"union" => |info| {
                if (info.tag_type == null) @compileError("union schemas require a tagged union");
            },
            else => @compileError("union schema requires a union type, got " ++ @typeName(U)),
        }
        const info = @typeInfo(@TypeOf(variants)).@"struct";
        for (info.field_names) |name| {
            const index = unionFieldIndex(U, name) orelse
                @compileError("variant '" ++ name ++ "' does not exist on " ++ @typeName(U));
            const S = @field(variants, name);
            const Field = @typeInfo(U).@"union".field_types[index];
            if (S.Value != Field) {
                @compileError("variant '" ++ name ++ "' produces " ++ @typeName(S.Value) ++ " but the union field is " ++ @typeName(Field));
            }
        }
    }
}

/// Tries each variant in declaration order and returns the first that decodes.
pub fn unionOf(comptime U: type, comptime variants: anytype, comptime config: UnionConfig) type {
    validate(U, variants);
    const info = @typeInfo(@TypeOf(variants)).@"struct";

    return struct {
        pub const Value = U;
        pub const schema_description = config.description;
        pub const kind = schema.Kind.union_value;
        pub const schema_name = "union";
        pub const is_optional = false;
        pub const has_default = false;
        pub const expected = VariantNames(variants).value;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const mark = state.issues.mark();
            inline for (info.field_names) |name| {
                const S = @field(variants, name);
                if (S.decode(state, node, path)) |decoded| {
                    return @unionInit(U, name, decoded);
                } else |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => state.issues.rollback(mark),
                }
            }
            return schema.failCode(state, .union_mismatch, path, schema.describeNode(node), expected);
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            switch (value) {
                inline else => |payload, tag| {
                    const S = @field(variants, @tagName(tag));
                    try S.check(state, payload, path);
                },
            }
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            switch (value) {
                inline else => |payload, tag| {
                    const S = @field(variants, @tagName(tag));
                    try S.encode(state, payload);
                },
            }
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("oneOf");
            try state.json.beginArray();
            inline for (info.field_names) |name| {
                const S = @field(variants, name);
                try S.writeJsonSchema(state);
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

pub const DiscriminatedConfig = struct {
    description: []const u8 = "",
};

fn discriminatorNode(node: std.json.Value, comptime key: []const u8) ?std.json.Value {
    if (node != .object) return null;
    var iterator = node.object.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, key)) {
            return entry.value_ptr.*;
        }
    }
    return null;
}

/// Selects a variant through a string discriminator field, then validates the
/// whole object against that variant's schema.
pub fn discriminatedUnion(
    comptime U: type,
    comptime field: []const u8,
    comptime variants: anytype,
    comptime config: DiscriminatedConfig,
) type {
    validate(U, variants);
    const info = @typeInfo(@TypeOf(variants)).@"struct";

    return struct {
        pub const Value = U;
        pub const schema_description = config.description;
        pub const kind = schema.Kind.discriminated_union;
        pub const schema_name = "discriminated union";
        pub const is_optional = false;
        pub const has_default = false;
        pub const discriminator = field;
        pub const expected = VariantNames(variants).value;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node != .object) {
                return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "object");
            }
            const discriminator_node = discriminatorNode(node, field) orelse {
                const key_path = try schema.pathField(state, path, field);
                return schema.failCode(state, .missing_discriminator, key_path, null, field);
            };
            const tag = switch (discriminator_node) {
                .string => |value| value,
                else => return schema.failCode(state, .invalid_discriminator, path, try schema.describeScalar(state, discriminator_node), expected),
            };

            inline for (info.field_names) |name| {
                if (std.mem.eql(u8, name, tag)) {
                    const S = @field(variants, name);
                    const decoded = try S.decode(state, node, path);
                    return @unionInit(U, name, decoded);
                }
            }
            return schema.failCode(state, .invalid_discriminator, path, try schema.quote(state, tag), expected);
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            switch (value) {
                inline else => |payload, tag| {
                    const S = @field(variants, @tagName(tag));
                    try S.check(state, payload, path);
                },
            }
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            switch (value) {
                inline else => |payload, tag| {
                    const S = @field(variants, @tagName(tag));
                    try S.encode(state, payload);
                },
            }
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("oneOf");
            try state.json.beginArray();
            inline for (info.field_names) |name| {
                const S = @field(variants, name);
                try S.writeJsonSchema(state);
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

test "union selects the first matching variant" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const number = @import("number.zig");

    const Scalar = union(enum) { text: []const u8, count: i64 };
    const ScalarSchema = unionOf(Scalar, .{
        .count = number.integer(i64, .{}),
        .text = string.string(.{}),
    }, .{});

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const as_text = try ScalarSchema.decode(&state, .{ .string = "hello" }, "$");
    try std.testing.expectEqualStrings("hello", as_text.text);

    const as_count = try ScalarSchema.decode(&state, .{ .integer = 7 }, "$");
    try std.testing.expectEqual(@as(i64, 7), as_count.count);

    const invalid = try std.json.parseFromSlice(std.json.Value, allocator, "[1,2]", .{});
    defer invalid.deinit();
    try std.testing.expectError(error.Reported, ScalarSchema.decode(&state, invalid.value, "$"));
    try std.testing.expectEqualStrings("E015", list.last().?.code.label());
    try std.testing.expectEqual(@as(usize, 1), list.count());
}

test "discriminated union distinguishes missing and non-string tags" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const model = @import("model.zig");

    const Created = struct { type: []const u8 };
    const Event = union(enum) { created: Created };
    const EventSchema = discriminatedUnion(Event, "type", .{
        .created = model.object(Created, .{
            .type = string.string(.{}),
        }, .{}),
    }, .{});

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const missing = try std.json.parseFromSlice(std.json.Value, allocator, "{}", .{});
    defer missing.deinit();
    try std.testing.expectError(error.Reported, EventSchema.decode(&state, missing.value, "$"));
    try std.testing.expectEqualStrings("E019", list.last().?.code.label());

    const wrong_type = try std.json.parseFromSlice(std.json.Value, allocator, "{\"type\":42}", .{});
    defer wrong_type.deinit();
    try std.testing.expectError(error.Reported, EventSchema.decode(&state, wrong_type.value, "$"));
    try std.testing.expectEqualStrings("E020", list.last().?.code.label());
}
