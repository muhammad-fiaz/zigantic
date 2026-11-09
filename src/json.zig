//! JSON decoding and encoding built on `std.json`.
//!
//! Input is parsed by the standard library into a `std.json.Value` tree; schemas
//! then validate and copy that tree into a per-result arena. The JSON tree
//! itself lives in a short-lived arena that is released before `parse` returns,
//! so every decoded string is owned by the result.

const std = @import("std");
const schema = @import("schema.zig");

/// Errors returned by JSON entry points: `InvalidJson` for unparsable input, `OutOfMemory` for allocation failure.
pub const Error = error{ InvalidJson, OutOfMemory };

/// Owning decode result for schema `S`.
/// The result owns its arena and issue list; decoded values stay valid until `deinit`, which must be called exactly once.
pub fn Result(comptime S: type) type {
    return struct {
        const Self = @This();

        arena: *std.heap.ArenaAllocator,
        child_allocator: std.mem.Allocator,
        issues: schema.IssueList,
        value: ?S.Value,

        /// Releases the result arena and issue list and invalidates the result; must be called exactly once.
        pub fn deinit(self: *Self) void {
            const child = self.child_allocator;
            self.issues.deinit();
            self.arena.deinit();
            child.destroy(self.arena);
            self.* = undefined;
        }

        /// Returns true when a decoded value is present.
        pub fn ok(self: *const Self) bool {
            return self.value != null;
        }

        /// Borrowed issues; valid until `deinit`.
        pub fn errors(self: *Self) *schema.IssueList {
            return &self.issues;
        }
    };
}

/// Creates an empty result for schema `S` with a fresh arena and issue list.
/// Caller owns the result and must call `deinit` exactly once. Returns `OutOfMemory` on allocation failure.
pub fn newResult(comptime S: type, allocator: std.mem.Allocator) !Result(S) {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    var issues = try schema.IssueList.init(allocator, .{});
    errdefer issues.deinit();

    return .{
        .arena = arena,
        .child_allocator = allocator,
        .issues = issues,
        .value = null,
    };
}

/// Parses `input` as JSON and decodes it with schema `S`.
/// The returned result owns the arena and issue list; call `deinit` exactly once. Validation failures are reported as issues, not errors.
pub fn parse(comptime S: type, allocator: std.mem.Allocator, input: []const u8, options: schema.Options) Error!Result(S) {
    var result = try newResult(S, allocator);
    errdefer result.deinit();

    var json_arena = std.heap.ArenaAllocator.init(allocator);
    defer json_arena.deinit();

    const parse_options: std.json.ParseOptions = .{
        .duplicate_field_behavior = switch (options.duplicates) {
            // Validate syntax with first-wins so duplicates can be reported at
            // their exact path by the scanner below.
            .reject => .use_first,
            .first => .use_first,
            .last => .use_last,
        },
    };
    var parsed = std.json.parseFromSlice(std.json.Value, json_arena.allocator(), input, parse_options) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.DuplicateField => {
            try result.issues.addCode(.duplicate_field, "$", "unique keys", null);
            if (options.hooks.on_start) |hook| hook(S.schema_name);
            if (options.hooks.on_finish) |hook| hook(false, result.issues.count());
            return result;
        },
        else => return error.InvalidJson,
    };
    defer parsed.deinit();

    if (options.duplicates == .reject) {
        if (try findDuplicate(result.arena.allocator(), input)) |path| {
            try result.issues.addCode(.duplicate_field, path, "unique keys", null);
            if (options.hooks.on_start) |hook| hook(S.schema_name);
            if (options.hooks.on_finish) |hook| hook(false, result.issues.count());
            return result;
        }
    }

    var state = schema.State{
        .arena = result.arena.allocator(),
        .issues = &result.issues,
        .options = options,
    };
    if (options.hooks.on_start) |hook| hook(S.schema_name);
    result.value = S.decode(&state, parsed.value, "$") catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.Reported => null,
    };
    if (options.hooks.on_finish) |hook| hook(result.value != null, result.issues.count());
    return result;
}

const DuplicateScanner = struct {
    input: []const u8,
    index: usize = 0,
    allocator: std.mem.Allocator,
    path: std.ArrayList(u8) = .empty,
    keys: std.ArrayList([]const u8) = .empty,

    fn skipSpace(self: *DuplicateScanner) void {
        while (self.index < self.input.len and std.ascii.isWhitespace(self.input[self.index])) self.index += 1;
    }

    fn scanString(self: *DuplicateScanner, keep: bool) !?[]const u8 {
        if (self.index >= self.input.len or self.input[self.index] != '"') return null;
        const start = self.index;
        self.index += 1;
        while (self.index < self.input.len) {
            switch (self.input[self.index]) {
                '"' => {
                    const end = self.index;
                    self.index += 1;
                    if (!keep) return null;
                    const raw = self.input[start + 1 .. end];
                    if (std.mem.indexOfScalar(u8, raw, '\\') == null) return raw;
                    const quoted = self.input[start..self.index];
                    const parsed = std.json.parseFromSlice([]const u8, self.allocator, quoted, .{}) catch return null;
                    return parsed.value;
                },
                '\\' => {
                    self.index += 2;
                    if (self.index > self.input.len) return null;
                },
                else => self.index += 1,
            }
        }
        return null;
    }

    fn scanNumber(self: *DuplicateScanner) void {
        while (self.index < self.input.len) : (self.index += 1) {
            const c = self.input[self.index];
            if (std.ascii.isDigit(c) or c == '-' or c == '+' or c == '.' or c == 'e' or c == 'E') continue;
            break;
        }
    }

    fn scanValue(self: *DuplicateScanner) error{OutOfMemory}!?[]const u8 {
        self.skipSpace();
        if (self.index >= self.input.len) return null;
        return switch (self.input[self.index]) {
            '{' => self.scanObject(),
            '[' => self.scanArray(),
            '"' => blk: {
                _ = try self.scanString(false);
                break :blk null;
            },
            't' => blk: {
                if (!std.mem.startsWith(u8, self.input[self.index..], "true")) return null;
                self.index += 4;
                break :blk null;
            },
            'f' => blk: {
                if (!std.mem.startsWith(u8, self.input[self.index..], "false")) return null;
                self.index += 5;
                break :blk null;
            },
            'n' => blk: {
                if (!std.mem.startsWith(u8, self.input[self.index..], "null")) return null;
                self.index += 4;
                break :blk null;
            },
            else => blk: {
                self.scanNumber();
                break :blk null;
            },
        };
    }

    fn scanArray(self: *DuplicateScanner) error{OutOfMemory}!?[]const u8 {
        self.index += 1;
        self.skipSpace();
        if (self.index < self.input.len and self.input[self.index] == ']') {
            self.index += 1;
            return null;
        }
        var item: usize = 0;
        while (self.index < self.input.len) : (item += 1) {
            const old_len = self.path.items.len;
            const index_text = try std.fmt.allocPrint(self.allocator, "[{d}]", .{item});
            try self.path.appendSlice(self.allocator, index_text);
            if (try self.scanValue()) |duplicate| return duplicate;
            self.path.shrinkRetainingCapacity(old_len);
            self.skipSpace();
            if (self.index >= self.input.len) return null;
            if (self.input[self.index] == ',') {
                self.index += 1;
                continue;
            }
            if (self.input[self.index] == ']') {
                self.index += 1;
                return null;
            }
            return null;
        }
        return null;
    }

    fn scanObject(self: *DuplicateScanner) error{OutOfMemory}!?[]const u8 {
        self.index += 1;
        const frame = self.keys.items.len;
        defer self.keys.shrinkRetainingCapacity(frame);
        self.skipSpace();
        if (self.index < self.input.len and self.input[self.index] == '}') {
            self.index += 1;
            return null;
        }
        while (self.index < self.input.len) {
            self.skipSpace();
            const key = (try self.scanString(true)) orelse return null;
            for (self.keys.items[frame..]) |existing| {
                if (std.mem.eql(u8, existing, key)) {
                    const old_len = self.path.items.len;
                    try self.path.appendSlice(self.allocator, ".");
                    try self.path.appendSlice(self.allocator, key);
                    const duplicate = try self.allocator.dupe(u8, self.path.items);
                    self.path.shrinkRetainingCapacity(old_len);
                    return duplicate;
                }
            }
            try self.keys.append(self.allocator, key);
            self.skipSpace();
            if (self.index >= self.input.len or self.input[self.index] != ':') return null;
            self.index += 1;
            const old_len = self.path.items.len;
            try self.path.appendSlice(self.allocator, ".");
            try self.path.appendSlice(self.allocator, key);
            if (try self.scanValue()) |duplicate| return duplicate;
            self.path.shrinkRetainingCapacity(old_len);
            self.skipSpace();
            if (self.index >= self.input.len) return null;
            if (self.input[self.index] == ',') {
                self.index += 1;
                continue;
            }
            if (self.input[self.index] == '}') {
                self.index += 1;
                return null;
            }
            return null;
        }
        return null;
    }
};

/// Scans raw JSON for the first repeated key inside the same object and returns
/// its JSONPath. Malformed input returns null so the standard parser can report
/// the syntax error with its own diagnostics.
fn findDuplicate(allocator: std.mem.Allocator, input: []const u8) error{OutOfMemory}!?[]const u8 {
    var scanner = DuplicateScanner{ .input = input, .allocator = allocator };
    try scanner.path.append(allocator, '$');
    const duplicate = try scanner.scanValue();
    if (duplicate) |path| return path;
    return null;
}

/// Encode options for JSON output. Mirrors `schema.EncodeOptions`; `emit_null_fields` controls `null` emission.
pub const EncodeOptions = schema.EncodeOptions;

/// Encodes `value` as JSON with schema `S` and returns caller-owned text.
/// Encode callbacks receive a scratch arena released before return; the returned slice does not reference it. Caller frees the slice.
pub fn stringify(
    comptime S: type,
    allocator: std.mem.Allocator,
    value: S.Value,
    options: EncodeOptions,
) (std.mem.Allocator.Error || std.Io.Writer.Error || error{ Unsupported, TransformFailed })![]u8 {
    var buffer: std.Io.Writer.Allocating = .init(allocator);
    errdefer buffer.deinit();

    // Encode callbacks receive scratch storage that is valid only for this
    // call. The returned JSON buffer uses the caller's allocator and is
    // independent of this arena.
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();

    var json: std.json.Stringify = .{ .writer = &buffer.writer, .options = .{} };
    var state = schema.EncodeState{ .allocator = scratch.allocator(), .json = &json, .options = options };
    try S.encode(&state, value);
    return buffer.toOwnedSlice();
}

test "json round trip owns its strings" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const number = @import("number.zig");
    const model = @import("model.zig");

    const User = struct {
        name: []const u8,
        age: u8,
    };
    const UserSchema = model.object(User, .{
        .name = string.string(.{ .min = 1 }),
        .age = number.integer(u8, .{}),
    }, .{});

    var result = try parse(UserSchema, allocator, "{\"name\":\"Ada\",\"age\":36}", .{});
    defer result.deinit();
    try std.testing.expect(result.ok());
    try std.testing.expectEqualStrings("Ada", result.value.?.name);

    const text = try stringify(UserSchema, allocator, result.value.?, .{});
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"name\":\"Ada\"") != null);
}

test "invalid json and validation errors" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const Age = number.integer(u8, .{ .min = 18 });

    try std.testing.expectError(error.InvalidJson, parse(Age, allocator, "{", .{}));

    var result = try parse(Age, allocator, "12", .{});
    defer result.deinit();
    try std.testing.expect(!result.ok());
    try std.testing.expectEqual(@as(usize, 1), result.errors().count());
    try std.testing.expectEqualStrings("$", result.errors().first().?.path);
}

test "invalid utf-8 is rejected as invalid json" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const Text = string.string(.{});
    const invalid = [_]u8{ '"', 0xff, 0xfe, '"' };
    try std.testing.expectError(error.InvalidJson, parse(Text, allocator, &invalid, .{}));
}

test "depth limit reports unsupported" {
    const allocator = std.testing.allocator;
    const model = @import("model.zig");
    const string = @import("string.zig");
    const Inner = model.objectOf(.{ .name = string.string(.{}) }, .{});
    const Outer = model.objectOf(.{ .inner = Inner }, .{});

    var result = try parse(Outer, allocator, "{\"inner\":{\"name\":\"Ada\"}}", .{ .max_depth = 1 });
    defer result.deinit();
    try std.testing.expect(!result.ok());
    try std.testing.expectEqualStrings("E021", result.errors().first().?.code.label());
}

test "transform encode scratch allocations are released" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const modifiers = @import("modifiers.zig");

    const Suffixed = modifiers.transform(string.string(.{}), .{
        .decode = struct {
            fn apply(_: std.mem.Allocator, value: []const u8) ![]const u8 {
                return value;
            }
        }.apply,
        .encode = struct {
            fn apply(pool: std.mem.Allocator, value: []const u8) ![]const u8 {
                return std.fmt.allocPrint(pool, "{s}!", .{value});
            }
        }.apply,
    });

    const text = try stringify(Suffixed, allocator, "ok", .{});
    defer allocator.free(text);
    try std.testing.expectEqualStrings("\"ok!\"", text);
}

fn parseWithAllocationFailures(allocator: std.mem.Allocator) !void {
    const string = @import("string.zig");
    const Model = struct { name: []const u8 };
    const ModelSchema = @import("model.zig").object(Model, .{
        .name = string.string(.{ .min = 1 }),
    }, .{});

    var result = try parse(ModelSchema, allocator, "{\"name\":\"Ada\"}", .{});
    defer result.deinit();
    try std.testing.expect(result.ok());
    try std.testing.expectEqualStrings("Ada", result.value.?.name);
}

test "parse cleans up at every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parseWithAllocationFailures, .{});
}

test "bidirectional codecs validate both sides" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const number = @import("number.zig");
    const modifiers = @import("modifiers.zig");

    const Count = modifiers.codec(string.string(.{}), number.integer(u32, .{ .max = 100 }), .{
        .decode = struct {
            fn apply(_: std.mem.Allocator, text: []const u8) !u32 {
                return std.fmt.parseInt(u32, text, 10);
            }
        }.apply,
        .encode = struct {
            fn apply(pool: std.mem.Allocator, value: u32) ![]const u8 {
                return std.fmt.allocPrint(pool, "{d}", .{value});
            }
        }.apply,
    });

    var parsed = try parse(Count, allocator, "\"42\"", .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u32, 42), parsed.value.?);

    const text = try stringify(Count, allocator, parsed.value.?, .{});
    defer allocator.free(text);
    try std.testing.expectEqualStrings("\"42\"", text);

    var too_large = try parse(Count, allocator, "\"101\"", .{});
    defer too_large.deinit();
    try std.testing.expect(!too_large.ok());
}

test "nested codecs, bytes and temporal schemas compose" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const number = @import("number.zig");
    const primitive = @import("primitive.zig");
    const temporal = @import("temporal.zig");
    const modifiers = @import("modifiers.zig");
    const model = @import("model.zig");

    const Count = modifiers.codec(string.string(.{}), number.integer(u32, .{ .max = 100 }), .{
        .decode = struct {
            fn apply(_: std.mem.Allocator, text: []const u8) !u32 {
                return std.fmt.parseInt(u32, text, 10);
            }
        }.apply,
        .encode = struct {
            fn apply(pool: std.mem.Allocator, value: u32) ![]const u8 {
                return std.fmt.allocPrint(pool, "{d}", .{value});
            }
        }.apply,
    });

    const Payload = struct {
        label: []const u8,
        count: u32,
        day: @import("datetime.zig").Date,
        digest: []const u8,
    };
    const PayloadSchema = model.object(Payload, .{
        .label = modifiers.meta(string.string(.{ .min = 1 }), .{ .title = "Label" }),
        .count = Count,
        .day = temporal.date(.{}),
        .digest = primitive.bytes(.{ .encoding = .hex, .len = 4 }),
    }, .{});

    var result = try parse(PayloadSchema, allocator,
        \\{"label":"item","count":"7","day":"2024-02-29","digest":"deadbeef"}
    , .{});
    defer result.deinit();
    try std.testing.expect(result.ok());
    try std.testing.expectEqual(@as(u32, 7), result.value.?.count);
    try std.testing.expectEqual(@as(u8, 29), result.value.?.day.day);
    try std.testing.expectEqualSlices(u8, &.{ 0xde, 0xad, 0xbe, 0xef }, result.value.?.digest);

    const text = try stringify(PayloadSchema, allocator, result.value.?, .{});
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"count\":\"7\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"deadbeef\"") != null);
}

test "duplicate keys report their nested path" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const model = @import("model.zig");

    const Inner = model.objectOf(.{ .x = number.integer(u8, .{}) }, .{});
    const Outer = model.objectOf(.{ .inner = Inner }, .{});

    var result = try parse(Outer, allocator, "{\"inner\":{\"x\":1,\"x\":2}}", .{ .duplicates = .reject });
    defer result.deinit();
    try std.testing.expect(!result.ok());
    try std.testing.expectEqualStrings("E009", result.errors().first().?.code.label());
    try std.testing.expectEqualStrings("$.inner.x", result.errors().first().?.path);

    var accepted = try parse(Outer, allocator, "{\"inner\":{\"x\":1,\"x\":2}}", .{ .duplicates = .last });
    defer accepted.deinit();
    try std.testing.expect(accepted.ok());
    try std.testing.expectEqual(@as(u8, 2), accepted.value.?.inner.x);
}
