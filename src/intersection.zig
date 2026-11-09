//! Intersection schemas: every member must accept the same typed value.
//!
//! Members must produce identical `Value` types at compile time. Decoding uses
//! the first member (so optional/default metadata comes from it) and then
//! checks the decoded value against every other member, which avoids decoding
//! and allocating the same data twice.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

/// Configuration for intersection schemas; holds optional JSON Schema description.
pub const Config = struct {
    description: []const u8 = "",
};

/// Creates an intersection schema requiring every member to accept the same value.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
/// All member Value types must match the first member; at least one member is required.
/// Decode uses the first member then checks the rest; encode uses the first member.
pub fn intersection(comptime schemas: anytype, comptime config: Config) type {
    const info = @typeInfo(@TypeOf(schemas)).@"struct";
    comptime {
        if (info.field_names.len == 0) @compileError("intersection requires at least one schema");
        const First = @field(schemas, info.field_names[0]);
        for (info.field_names[1..]) |name| {
            const S = @field(schemas, name);
            if (S.Value != First.Value) {
                @compileError("intersection member '" ++ name ++ "' produces " ++ @typeName(S.Value) ++ " but the first member produces " ++ @typeName(First.Value));
            }
        }
    }

    const First = @field(schemas, info.field_names[0]);

    return struct {
        pub const Value = First.Value;
        pub const FirstSchema = First;
        pub const fields = schemas;
        pub const intersection_config = config;
        pub const kind = schema.Kind.intersection;
        pub const schema_name = "intersection";
        pub const is_optional = schema.isOptional(First);
        pub const has_default = schema.hasDefault(First);

        pub fn defaultValue() Value {
            return First.defaultValue();
        }

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            const value = try First.decode(state, node, path);
            var failed = false;
            inline for (info.field_names[1..]) |name| {
                const S = @field(schemas, name);
                S.check(state, value, path) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => failed = true,
                };
            }
            if (failed) return error.Reported;
            return value;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            var failed = false;
            inline for (info.field_names) |name| {
                const S = @field(schemas, name);
                S.check(state, value, path) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => failed = true,
                };
            }
            if (failed) return error.Reported;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try First.encode(state, value);
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("allOf");
            try state.json.beginArray();
            inline for (info.field_names) |name| {
                try @field(schemas, name).writeJsonSchema(state);
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

test "intersection validates compatible schemas" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");

    const InRange = number.integer(u16, .{ .min = 10, .max = 100 });
    const Even = @import("modifiers.zig").refine(number.integer(u16, .{}), .{
        .check = struct {
            fn check(value: u16) bool {
                return value % 2 == 0;
            }
        }.check,
        .message = "must be even",
    });
    const Both = intersection(.{ .range = InRange, .even = Even }, .{});

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    try std.testing.expectEqual(@as(u16, 42), try Both.decode(&state, .{ .integer = 42 }, "$"));
    try std.testing.expectError(error.Reported, Both.decode(&state, .{ .integer = 43 }, "$"));
    try std.testing.expectEqualStrings("must be even", list.last().?.message);
    try std.testing.expectError(error.Reported, Both.decode(&state, .{ .integer = 102 }, "$"));
}
