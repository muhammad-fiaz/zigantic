//! JSON decoding and encoding built on `std.json`.
//!
//! Input is parsed by the standard library into a `std.json.Value` tree; schemas
//! then validate and copy that tree into a per-result arena. The JSON tree
//! itself lives in a short-lived arena that is released before `parse` returns,
//! so every decoded string is owned by the result.

const std = @import("std");
const schema = @import("schema.zig");

pub const Error = error{ InvalidJson, OutOfMemory };

pub fn Result(comptime S: type) type {
    return struct {
        const Self = @This();

        arena: *std.heap.ArenaAllocator,
        child_allocator: std.mem.Allocator,
        issues: schema.IssueList,
        value: ?S.Value,

        pub fn deinit(self: *Self) void {
            const child = self.child_allocator;
            self.issues.deinit();
            self.arena.deinit();
            child.destroy(self.arena);
            self.* = undefined;
        }

        pub fn ok(self: *const Self) bool {
            return self.value != null;
        }

        /// Borrowed issues; valid until `deinit`.
        pub fn errors(self: *Self) *schema.IssueList {
            return &self.issues;
        }
    };
}

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

pub const EncodeOptions = schema.EncodeOptions;

pub fn stringify(
    comptime S: type,
    allocator: std.mem.Allocator,
    value: S.Value,
    options: EncodeOptions,
) (std.mem.Allocator.Error || std.Io.Writer.Error || error{ Unsupported, TransformFailed })![]u8 {
    var buffer: std.Io.Writer.Allocating = .init(allocator);
    errdefer buffer.deinit();
    var json: std.json.Stringify = .{ .writer = &buffer.writer, .options = .{} };
    var state = schema.EncodeState{ .allocator = allocator, .json = &json, .options = options };
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
