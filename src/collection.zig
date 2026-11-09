//! Array and record (string-keyed map) schemas.

const std = @import("std");
const schema = @import("schema.zig");

const State = schema.State;
const DecodeError = schema.DecodeError;
const EncodeError = schema.EncodeError;
const SchemaError = schema.SchemaError;
const EncodeState = schema.EncodeState;
const SchemaState = schema.SchemaState;

/// Bounds for array schemas: minimum, maximum, exact length, uniqueness, and description.
/// Exact length must fall within [min, max] when set; min must not exceed max.
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

/// Creates an array schema with Value = []const S.Value allocated in State.arena.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
/// Length must satisfy min, max, and len; unique enforces distinct items via deep equality.
/// Decode/check report length, uniqueness, and element issues; encode writes a JSON array.
pub fn array(comptime S: type, comptime config: ArrayConfig) type {
    comptime {
        if (config.min > config.max) @compileError("array minimum exceeds maximum");
        if (config.len) |exact| {
            if (exact < config.min or exact > config.max) @compileError("array exact length must be within minimum and maximum");
        }
    }

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

            const received = try std.fmt.allocPrint(state.arena, "{d} items", .{value.len});
            if (config.len) |exact| {
                if (value.len != exact) return schema.failCode(state, .length_mismatch, path, received, expected);
            }
            if (value.len < config.min) return schema.failCode(state, .too_small, path, received, expected);
            if (value.len > config.max) return schema.failCode(state, .too_large, path, received, expected);

            var failed = false;
            for (value, 0..) |item, index| {
                const child = try schema.pathIndex(state, path, index);
                S.check(state, item, child) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => failed = true,
                };
            }
            if (config.unique) {
                for (value, 0..) |item, index| {
                    for (value[0..index]) |previous| {
                        if (schema.valuesEqual(S.Value, previous, item)) {
                            const child = try schema.pathIndex(state, path, index);
                            try schema.note(state, .duplicate_field, child, null, "unique items");
                            failed = true;
                            break;
                        }
                    }
                }
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

/// Configuration for fixed arrays; only description is supported.
/// Length is fixed by the N parameter to fixedArray.
pub const FixedConfig = struct {
    description: []const u8 = "",
};

/// Creates a fixed-length array schema with Value = [N]S.Value.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
/// Input length must equal N; elements decode via S and may allocate in State.arena.
/// Decode/check report length mismatches; encode writes the N elements in order.
pub fn fixedArray(comptime S: type, comptime N: usize, comptime config: FixedConfig) type {
    return struct {
        pub const Value = [N]S.Value;
        pub const Child = S;
        pub const kind = schema.Kind.array;
        pub const schema_name = "fixed array";
        pub const is_optional = false;
        pub const has_default = false;
        pub const expected = std.fmt.comptimePrint("exactly {d} items", .{N});

        pub fn decode(state: *State, node: std.json.Value, path: []const u8) DecodeError!Value {
            if (node != .array) return schema.failCode(state, .type_mismatch, path, schema.describeNode(node), "array");
            try state.enter();
            defer state.leave();
            if (node.array.items.len != N) {
                return schema.failCode(state, .length_mismatch, path, try std.fmt.allocPrint(state.arena, "{d} items", .{node.array.items.len}), expected);
            }

            var out: Value = undefined;
            var failed = false;
            inline for (0..N) |index| {
                const child = try schema.pathIndex(state, path, index);
                out[index] = S.decode(state, node.array.items[index], child) catch |err| switch (err) {
                    error.OutOfMemory => return err,
                    error.Reported => blk: {
                        failed = true;
                        break :blk undefined;
                    },
                };
            }
            if (failed) return error.Reported;
            return out;
        }

        pub fn check(state: *State, value: Value, path: []const u8) DecodeError!void {
            try state.enter();
            defer state.leave();
            var failed = false;
            inline for (0..N) |index| {
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
            inline for (0..N) |index| try S.encode(state, value[index]);
            try state.json.endArray();
        }

        pub fn writeJsonSchema(state: *SchemaState) SchemaError!void {
            try state.json.beginObject();
            try state.json.objectField("type");
            try state.json.write("array");
            try state.json.objectField("items");
            try S.writeJsonSchema(state);
            try state.json.objectField("minItems");
            try state.json.write(N);
            try state.json.objectField("maxItems");
            try state.json.write(N);
            if (config.description.len > 0) {
                try state.json.objectField("description");
                try state.json.write(config.description);
            }
            try state.json.endObject();
        }
    };
}

/// Creates an ordered-set schema with Value = []const S.Value, arena-allocated.
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
/// Duplicates are rejected by deep equality; length bounds apply as for array.
/// Membership checking is linear to avoid requiring a hash for S.Value.
pub fn set(comptime S: type, comptime config: ArrayConfig) type {
    return array(S, .{
        .min = config.min,
        .max = config.max,
        .len = config.len,
        .unique = true,
        .description = config.description,
    });
}

/// Bounds for record schemas: entry count limits, key length limits, and description.
/// min must not exceed max; key_min must not exceed key_max.
pub const RecordConfig = struct {
    min: usize = 0,
    max: usize = std.math.maxInt(usize),
    key_min: usize = 1,
    key_max: usize = 256,
    description: []const u8 = "",
};

/// Creates a record schema with Value = std.array_hash_map.String(S.Value).
/// Returned schema provides Value, kind, decode, check, encode, and writeJsonSchema.
/// Keys and values are arena-owned on decode; iteration preserves insertion order.
/// Entry count and key length are constrained by config; violations report via issues.
pub fn record(comptime S: type, comptime config: RecordConfig) type {
    comptime {
        if (config.min > config.max) @compileError("record minimum exceeds maximum");
        if (config.key_min > config.key_max) @compileError("record key minimum exceeds maximum");
    }

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
            if (value.count() < config.min) {
                try schema.note(state, .too_small, path, null, "more entries");
                failed = true;
            }
            if (value.count() > config.max) {
                try schema.note(state, .too_large, path, null, "fewer entries");
                failed = true;
            }
            var iterator = value.iterator();
            while (iterator.next()) |entry| {
                const key = entry.key_ptr.*;
                if (key.len < config.key_min or key.len > config.key_max) {
                    try schema.note(state, .length_mismatch, path, try schema.quote(state, key), "key length in range");
                    failed = true;
                }
                const child = try schema.pathField(state, path, key);
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
            if (state.target.supportsPropertyNames()) {
                try state.json.objectField("propertyNames");
                try state.json.beginObject();
                try state.json.objectField("type");
                try state.json.write("string");
                if (config.key_min > 0) {
                    try state.json.objectField("minLength");
                    try state.json.write(config.key_min);
                }
                if (config.key_max != std.math.maxInt(usize)) {
                    try state.json.objectField("maxLength");
                    try state.json.write(config.key_max);
                }
                try state.json.endObject();
            }
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

test "array check enforces length and uniqueness" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const Tags = array(string.string(.{}), .{ .min = 1, .max = 2, .len = 2, .unique = true });
    const Bounded = array(string.string(.{}), .{ .min = 1, .max = 2 });

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const valid = [_][]const u8{ "ab", "cd" };
    try Tags.check(&state, &valid, "tags");
    try std.testing.expect(list.isEmpty());

    const duplicate = [_][]const u8{ "ab", "ab" };
    try std.testing.expectError(error.Reported, Tags.check(&state, &duplicate, "tags"));
    try std.testing.expectEqualStrings("E009", list.last().?.code.label());
    try std.testing.expectEqualStrings("tags[1]", list.last().?.path);

    const too_many = [_][]const u8{ "ab", "cd", "ef" };
    try std.testing.expectError(error.Reported, Tags.check(&state, &too_many, "tags"));
    try std.testing.expectEqualStrings("E004", list.last().?.code.label());
    try std.testing.expectError(error.Reported, Bounded.check(&state, &too_many, "tags"));
    try std.testing.expectEqualStrings("E003", list.last().?.code.label());

    const too_short = [_][]const u8{"ab"};
    try std.testing.expectError(error.Reported, Tags.check(&state, &too_short, "tags"));
    try std.testing.expectEqualStrings("E004", list.last().?.code.label());
}

test "record check enforces entry and key limits" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const Scores = record(number.integer(u16, .{}), .{
        .min = 1,
        .max = 2,
        .key_min = 3,
        .key_max = 5,
    });

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    var valid: Scores.Value = .empty;
    defer valid.deinit(allocator);
    try valid.put(allocator, "ada", 10);
    try valid.put(allocator, "grace", 12);
    try Scores.check(&state, valid, "scores");
    try std.testing.expect(list.isEmpty());

    var bad_key: Scores.Value = .empty;
    defer bad_key.deinit(allocator);
    try bad_key.put(allocator, "ab", 10);
    try std.testing.expectError(error.Reported, Scores.check(&state, bad_key, "scores"));
    try std.testing.expectEqualStrings("E004", list.last().?.code.label());

    var too_many: Scores.Value = .empty;
    defer too_many.deinit(allocator);
    try too_many.put(allocator, "ada", 10);
    try too_many.put(allocator, "grace", 12);
    try too_many.put(allocator, "linus", 14);
    try std.testing.expectError(error.Reported, Scores.check(&state, too_many, "scores"));
    try std.testing.expectEqualStrings("E003", list.last().?.code.label());

    var too_few: Scores.Value = .empty;
    defer too_few.deinit(allocator);
    try std.testing.expectError(error.Reported, Scores.check(&state, too_few, "scores"));
    try std.testing.expectEqualStrings("E002", list.last().?.code.label());
}

test "fixed arrays and ordered sets" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const string = @import("string.zig");
    const Pair = fixedArray(number.integer(u8, .{}), 2, .{});
    const Tags = set(string.string(.{}), .{ .min = 1, .max = 3 });

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const pair_node = try std.json.parseFromSlice(std.json.Value, allocator, "[1,2]", .{});
    defer pair_node.deinit();
    const pair = try Pair.decode(&state, pair_node.value, "pair");
    try std.testing.expectEqual(@as(u8, 2), pair[1]);
    try Pair.check(&state, pair, "pair");

    const short_node = try std.json.parseFromSlice(std.json.Value, allocator, "[1,2,3]", .{});
    defer short_node.deinit();
    try std.testing.expectError(error.Reported, Pair.decode(&state, short_node.value, "pair"));

    const tags_node = try std.json.parseFromSlice(std.json.Value, allocator, "[\"a\",\"b\"]", .{});
    defer tags_node.deinit();
    const tags = try Tags.decode(&state, tags_node.value, "tags");
    try std.testing.expectEqual(@as(usize, 2), tags.len);

    const duplicate_node = try std.json.parseFromSlice(std.json.Value, allocator, "[\"a\",\"a\"]", .{});
    defer duplicate_node.deinit();
    try std.testing.expectError(error.Reported, Tags.decode(&state, duplicate_node.value, "tags"));
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

test "uniqueness follows IEEE float equality and deep equality" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const string = @import("string.zig");

    const FloatSet = set(number.float(f64, .{ .finite = false }), .{ .min = 2, .max = 2 });
    const zeroes = [_]f64{ -0.0, 0.0 };
    const nans = [_]f64{ std.math.nan(f64), std.math.nan(f64) };
    const nested_hits = [_][]const []const u8{ &.{"a"}, &.{"a"} };
    const Nested = array(array(string.string(.{}), .{ .len = 1 }), .{ .unique = true });

    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    try std.testing.expectError(error.Reported, FloatSet.check(&state, &zeroes, "items"));
    try std.testing.expectEqualStrings("E009", list.last().?.code.label());
    try std.testing.expectEqualStrings("items[1]", list.last().?.path);

    const before = list.count();
    try FloatSet.check(&state, &nans, "items");
    try std.testing.expectEqual(before, list.count());

    try std.testing.expectError(error.Reported, Nested.check(&state, &nested_hits, "items"));
    try std.testing.expectEqualStrings("E009", list.last().?.code.label());
}

test "record iteration preserves insertion order" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const Scores = record(number.integer(u16, .{}), .{});
    var list = try schema.IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const node = try std.json.parseFromSlice(std.json.Value, allocator, "{\"zeta\":1,\"alpha\":2,\"mid\":3}", .{});
    defer node.deinit();
    const scores = try Scores.decode(&state, node.value, "scores");
    var keys: [3][]const u8 = undefined;
    var index: usize = 0;
    var it = scores.iterator();
    while (it.next()) |entry| {
        keys[index] = entry.key_ptr.*;
        index += 1;
    }
    try std.testing.expectEqualStrings("zeta", keys[0]);
    try std.testing.expectEqualStrings("alpha", keys[1]);
    try std.testing.expectEqualStrings("mid", keys[2]);
}
