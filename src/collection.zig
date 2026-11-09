//! Array and record (string-keyed map) schemas.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

pub const ArrayConfig = struct {
    min: usize = 0,
    max: usize = std.math.maxInt(usize),
    len: ?usize = null,
    unique: bool = false,
    description: []const u8 = "",
};

fn lengthExpected(comptime config: ArrayConfig) []const u8 {
    if (config.len) |exact| return std.fmt.comptimePrint("exactly {d} items", .{exact});
    if (config.max == std.math.maxInt(usize)) {
        if (config.min == 0) return "any number of items";
        return std.fmt.comptimePrint("at least {d} items", .{config.min});
    }
    return std.fmt.comptimePrint("{d}..{d} items", .{ config.min, config.max });
}

pub fn array(comptime S: type, comptime config: ArrayConfig) type {
    return struct {
        pub const Value = []const S.Value;
        pub const Child = S;
        pub const kind = schema.Kind.array;
        pub const schema_name = "array";
        pub const is_optional = false;
        pub const has_default = false;
        pub const expected = lengthExpected(config);

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node != .array) {
                return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), expected);
            }
            try state.enter();
            defer state.leave();

            const items = node.array.items;
            if (config.len) |exact| {
                if (items.len != exact) {
                    return schema.failCode(state, .length_mismatch, path, try std.fmt.allocPrint(state.arena, "{d} items", .{items.len}), expected);
                }
            }
            if (items.len < config.min or items.len > config.max) {
                const code: schema.Code = if (items.len < config.min) .too_small else .too_large;
                return schema.failCode(state, code, path, try std.fmt.allocPrint(state.arena, "{d} items", .{items.len}), expected);
            }

            const out = state.arena.alloc(S.Value, items.len) catch return error.OutOfMemory;
            var failed = false;
            for (items, 0..) |item, index| {
                const child = try schema.pathIndex(state, path, index);
                out[index] = S.decode(state, item, child) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => {
                        failed = true;
                        continue;
                    },
                };
            }
            if (failed) return error.Reported;
            if (config.unique) {
                for (out, 0..) |item, index| {
                    for (out[0..index]) |previous| {
                        if (schema.valuesEqual(S.Value, previous, item)) {
                            const child = try schema.pathIndex(state, path, index);
                            try schema.note(state, .duplicate_field, child, null, "unique items");
                            failed = true;
                            break;
                        }
                    }
                }
                if (failed) return error.Reported;
            }
            return out;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try state.enter();
            defer state.leave();
            if (value.len < config.min or value.len > config.max or (config.len != null and value.len != config.len.?)) {
                return schema.failCode(state, .too_small, path, null, expected);
            }
            var failed = false;
            for (value, 0..) |item, index| {
                const child = try schema.pathIndex(state, path, index);
                S.check(state, item, child) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => failed = true,
                };
            }
            if (failed) return error.Reported;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try state.json.beginArray();
            for (value) |item| {
                try S.encode(state, item);
            }
            try state.json.endArray();
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("array");
            try state.json.objectField("items");
            try S.writeJsonSchema(state);
            if (config.len) |exact| {
                try state.json.objectField("minItems");
                try state.json.write(exact);
                try state.json.objectField("maxItems");
                try state.json.write(exact);
            } else {
                if (config.min > 0) {
                    try state.json.objectField("minItems");
                    try state.json.write(config.min);
                }
                if (config.max != std.math.maxInt(usize)) {
                    try state.json.objectField("maxItems");
                    try state.json.write(config.max);
                }
            }
            if (config.unique) {
                try state.json.objectField("uniqueItems");
                try state.json.write(true);
            }
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

pub const RecordConfig = struct {
    min: usize = 0,
    max: usize = std.math.maxInt(usize),
    key_min: usize = 1,
    key_max: usize = 256,
    description: []const u8 = "",
};

pub fn record(comptime S: type, comptime config: RecordConfig) type {
    return struct {
        pub const Value = std.array_hash_map.String(S.Value);
        pub const Child = S;
        pub const kind = schema.Kind.record;
        pub const schema_name = "record";
        pub const is_optional = false;
        pub const has_default = false;

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node != .object) {
                return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "object");
            }
            try state.enter();
            defer state.leave();

            var out: Value = .empty;
            var failed = false;
            var iterator = node.object.iterator();
            while (iterator.next()) |entry| {
                const key = entry.key_ptr.*;
                if (key.len < config.key_min or key.len > config.key_max) {
                    try schema.note(state, .length_mismatch, path, try schema.quote(state, key), "key length in range");
                    failed = true;
                    continue;
                }
                const owned_key = try schema.dupe(state, key);
                const child = try schema.pathField(state, path, key);
                const decoded = S.decode(state, entry.value_ptr.*, child) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => {
                        failed = true;
                        continue;
                    },
                };
                out.put(state.arena, owned_key, decoded) catch return error.OutOfMemory;
                if (out.count() > config.max) {
                    return schema.failCode(state, .too_large, path, null, "fewer entries");
                }
            }
            if (out.count() < config.min) {
                return schema.failCode(state, .too_small, path, null, "more entries");
            }
            if (failed) return error.Reported;
            return out;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            var failed = false;
            var iterator = value.iterator();
            while (iterator.next()) |entry| {
                const child = try schema.pathField(state, path, entry.key_ptr.*);
                S.check(state, entry.value_ptr.*, child) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => failed = true,
                };
            }
            if (failed) return error.Reported;
        }

        pub fn encode(state: *EncodeState, value: Value) EncodeError!void {
            try state.json.beginObject();
            var iterator = value.iterator();
            while (iterator.next()) |entry| {
                try state.json.objectField(entry.key_ptr.*);
                try S.encode(state, entry.value_ptr.*);
            }
            try state.json.endObject();
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("object");
            try state.json.objectField("additionalProperties");
            try S.writeJsonSchema(state);
            if (config.min > 0) {
                try state.json.objectField("minProperties");
                try state.json.write(config.min);
            }
            if (config.max != std.math.maxInt(usize)) {
                try state.json.objectField("maxProperties");
                try state.json.write(config.max);
            }
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

test "array validation and uniqueness" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const Tags = array(string.string(.{ .min = 2 }), .{ .min = 1, .max = 3, .unique = true });

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const good = try std.json.parseFromSlice(std.json.Value, allocator, "[\"ab\",\"cd\"]", .{});
    defer good.deinit();
    const tags = try Tags.decode(&state, good.value, "tags");
    try std.testing.expectEqual(@as(usize, 2), tags.len);

    const duplicate = try std.json.parseFromSlice(std.json.Value, allocator, "[\"ab\",\"ab\"]", .{});
    defer duplicate.deinit();
    try std.testing.expectError(error.Reported, Tags.decode(&state, duplicate.value, "tags"));
    try std.testing.expectEqualStrings("tags[1]", list.last().?.path);

    const too_many = try std.json.parseFromSlice(std.json.Value, allocator, "[\"ab\",\"cd\",\"ef\",\"gh\"]", .{});
    defer too_many.deinit();
    try std.testing.expectError(error.Reported, Tags.decode(&state, too_many.value, "tags"));
}

test "record decoding" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const Scores = record(number.integer(u16, .{}), .{});
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const node = try std.json.parseFromSlice(std.json.Value, allocator, "{\"ada\":10,\"grace\":12}", .{});
    defer node.deinit();
    const scores = try Scores.decode(&state, node.value, "scores");
    try std.testing.expectEqual(@as(usize, 2), scores.count());
    try std.testing.expectEqual(@as(u16, 12), scores.get("grace").?);
}
