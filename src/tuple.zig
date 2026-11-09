//! Fixed-length heterogeneous tuple schemas.
//!
//! The decoded value is a real Zig tuple synthesized with `@Tuple`, so each
//! position keeps its own static type and every element error carries its index.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

/// Configuration for tuple schemas; holds optional JSON Schema description.
pub const Config = struct {
    description: []const u8 = "",
};

/// Creates a fixed-length tuple schema with Value = @Tuple of element schema Values.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
/// Input must be a JSON array of exact element count; each position decodes via its schema.
/// Length mismatches report immediately; element errors carry their index path.
pub fn tuple(comptime schemas: anytype, comptime config: Config) type {
    const info = @typeInfo(@TypeOf(schemas)).@"struct";
    const count = info.field_names.len;

    const Meta = struct {
        const types = blk: {
            var out: [count]type = undefined;
            for (info.field_names, 0..) |name, index| {
                out[index] = @field(schemas, name).Value;
            }
            break :blk out;
        };
    };

    return struct {
        pub const Value = @Tuple(&Meta.types);
        pub const fields = schemas;
        pub const tuple_config = config;
        pub const kind = schema.Kind.tuple;
        pub const schema_name = "tuple";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node != .array) {
                return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "array tuple");
            }
            try state.enter();
            defer state.leave();

            if (node.array.items.len != count) {
                return schema.failCode(
                    state,
                    .length_mismatch,
                    path,
                    try std.fmt.allocPrint(state.arena, "{d} items", .{node.array.items.len}),
                    std.fmt.comptimePrint("exactly {d} items", .{count}),
                );
            }

            var out: Value = undefined;
            var failed = false;
            inline for (info.field_names, 0..) |name, index| {
                const S = @field(schemas, name);
                const child = try schema.pathIndex(state, path, index);
                if (S.decode(state, node.array.items[index], child)) |decoded| {
                    out[index] = decoded;
                } else |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => {
                        failed = true;
                    },
                }
            }
            if (failed) return error.Reported;
            return out;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            var failed = false;
            inline for (info.field_names, 0..) |name, index| {
                const S = @field(schemas, name);
                const child = try schema.pathIndex(state, path, index);
                S.check(state, value[index], child) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => failed = true,
                };
            }
            if (failed) return error.Reported;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try state.json.beginArray();
            inline for (info.field_names, 0..) |name, index| {
                try @field(schemas, name).encode(state, value[index]);
            }
            try state.json.endArray();
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("array");
            if (state.target.usesPrefixItems()) {
                try state.json.objectField("prefixItems");
                try state.json.beginArray();
                inline for (info.field_names) |name| {
                    try @field(schemas, name).writeJsonSchema(state);
                }
                try state.json.endArray();
                try state.json.objectField("items");
                try state.json.write(false);
            } else {
                try state.json.objectField("items");
                try state.json.beginArray();
                inline for (info.field_names) |name| {
                    try @field(schemas, name).writeJsonSchema(state);
                }
                try state.json.endArray();
                try state.json.objectField("additionalItems");
                try state.json.write(false);
            }
            try state.json.objectField("minItems");
            try state.json.write(count);
            try state.json.objectField("maxItems");
            try state.json.write(count);
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

test "tuple decode, errors and schema" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const number = @import("number.zig");
    const primitive = @import("primitive.zig");

    const Entry = tuple(.{
        string.string(.{ .min = 1 }),
        number.integer(u8, .{ .max = 120 }),
        primitive.boolean(.{}),
    }, .{});

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const node = try std.json.parseFromSlice(std.json.Value, allocator, "[\"Ada\",36,true]", .{});
    defer node.deinit();
    const entry = try Entry.decode(&state, node.value, "entry");
    try std.testing.expectEqualStrings("Ada", entry[0]);
    try std.testing.expectEqual(@as(u8, 36), entry[1]);
    try std.testing.expect(entry[2]);
    try Entry.check(&state, entry, "entry");

    const bad = try std.json.parseFromSlice(std.json.Value, allocator, "[\"Ada\",200,true]", .{});
    defer bad.deinit();
    try std.testing.expectError(error.Reported, Entry.decode(&state, bad.value, "entry"));
    try std.testing.expectEqualStrings("entry[1]", list.last().?.path);

    const wrong_length = try std.json.parseFromSlice(std.json.Value, allocator, "[\"Ada\",36]", .{});
    defer wrong_length.deinit();
    try std.testing.expectError(error.Reported, Entry.decode(&state, wrong_length.value, "entry"));
    try std.testing.expectEqualStrings("E004", list.last().?.code.label());
}
