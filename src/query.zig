//! Query-string and application/x-www-form-urlencoded handling.
//!
//! Pairs are percent-decoded into a synthetic JSON object of strings and then
//! validated by the object schema with coercion enabled, which keeps defaults,
//! aliases, unknown-field policies and error paths identical to JSON parsing.

const std = @import("std");
const schema = @import("schema.zig");
const json = @import("json.zig");
const naming = @import("naming.zig");

/// Options for query serialization.
pub const StringifyOptions = struct {
    /// When true, null optionals are emitted as `key=null`; otherwise they are omitted.
    emit_nulls: bool = false,
};

fn hexValue(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}

fn decodeComponent(allocator: std.mem.Allocator, text: []const u8) error{ InvalidEncoding, OutOfMemory }![]const u8 {
    var needs_decode = false;
    for (text) |c| {
        if (c == '%' or c == '+') {
            needs_decode = true;
            break;
        }
    }
    if (!needs_decode) return text;
    const out = allocator.alloc(u8, text.len) catch return error.OutOfMemory;
    var len: usize = 0;
    var index: usize = 0;
    while (index < text.len) : (index += 1) {
        const c = text[index];
        if (c == '+') {
            out[len] = ' ';
            len += 1;
            continue;
        }
        if (c == '%') {
            if (index + 2 >= text.len) return error.InvalidEncoding;
            const high = hexValue(text[index + 1]) orelse return error.InvalidEncoding;
            const low = hexValue(text[index + 2]) orelse return error.InvalidEncoding;
            out[len] = high * 16 + low;
            len += 1;
            index += 2;
            continue;
        }
        out[len] = c;
        len += 1;
    }
    return out[0..len];
}

fn isUnreserved(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '-' or c == '.' or c == '_' or c == '~';
}

fn encodeComponent(allocator: std.mem.Allocator, text: []const u8) error{OutOfMemory}![]u8 {
    const hex = "0123456789ABCDEF";
    const capacity = std.math.mul(usize, text.len, 3) catch return error.OutOfMemory;
    const out = allocator.alloc(u8, capacity) catch return error.OutOfMemory;
    var len: usize = 0;
    for (text) |c| {
        if (isUnreserved(c)) {
            out[len] = c;
            len += 1;
        } else if (c == ' ') {
            out[len] = '+';
            len += 1;
        } else {
            out[len] = '%';
            out[len + 1] = hex[c >> 4];
            out[len + 2] = hex[c & 0x0f];
            len += 3;
        }
    }
    return out[0..len];
}

/// Parses a query string into object schema `S` with coercion forced on (`coerce=true`).
/// Input is percent-decoded into a synthetic JSON object decoded in the result arena; result ownership matches JSON parsing. Invalid percent encoding returns `InvalidJson`.
pub fn parse(comptime S: type, allocator: std.mem.Allocator, input: []const u8, options: schema.Options) json.Error!json.Result(S) {
    comptime {
        if (S.kind != .object) @compileError("query parsing requires an object schema");
    }

    var result = json.newResult(S, allocator) catch return error.OutOfMemory;
    errdefer result.deinit();
    const arena = result.arena.allocator();

    var root: std.json.Value = .{ .object = try std.json.ObjectMap.init(arena, &.{}, &.{}) };
    var pairs = std.mem.splitScalar(u8, input, '&');
    while (pairs.next()) |pair| {
        if (pair.len == 0) continue;
        const separator = std.mem.findScalar(u8, pair, '=') orelse pair.len;
        const raw_key = pair[0..separator];
        const raw_value = if (separator < pair.len) pair[separator + 1 ..] else "";
        const key = decodeComponent(arena, raw_key) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.InvalidEncoding => return error.InvalidJson,
        };
        const value = decodeComponent(arena, raw_value) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.InvalidEncoding => return error.InvalidJson,
        };
        try insertQueryEntry(arena, &root, key, value);
    }

    var state = schema.State{
        .arena = arena,
        .issues = &result.issues,
        .options = options,
    };
    state.options.coerce = true;
    if (state.options.hooks.on_start) |hook| hook(S.schema_name);
    result.value = S.decode(&state, root, "$") catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.Reported => null,
    };
    if (state.options.hooks.on_finish) |hook| hook(result.value != null, result.issues.count());
    return result;
}

const QuerySegment = union(enum) {
    key: []const u8,
    index: usize,
};

fn allDigits(text: []const u8) bool {
    if (text.len == 0) return false;
    for (text) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

fn parseQueryKey(allocator: std.mem.Allocator, key: []const u8) error{OutOfMemory}![]QuerySegment {
    var trimmed = key;
    while (std.mem.endsWith(u8, trimmed, "[]")) trimmed = trimmed[0 .. trimmed.len - 2];

    var segments: std.ArrayList(QuerySegment) = .empty;
    var start: usize = 0;
    var index: usize = 0;
    while (index < trimmed.len) : (index += 1) {
        if (trimmed[index] == '[') {
            if (index > start) try segments.append(allocator, .{ .key = trimmed[start..index] });
            const close = std.mem.indexOfScalarPos(u8, trimmed, index + 1, ']') orelse break;
            const inner = trimmed[index + 1 .. close];
            if (inner.len > 0) {
                if (allDigits(inner)) {
                    try segments.append(allocator, .{ .index = std.fmt.parseInt(usize, inner, 10) catch 0 });
                } else {
                    try segments.append(allocator, .{ .key = inner });
                }
            }
            index = close;
            start = close + 1;
            if (start < trimmed.len and trimmed[start] == '.') start += 1;
            index = start;
            if (index >= trimmed.len) break;
            index -= 1;
        } else if (trimmed[index] == '.') {
            if (index > start) try segments.append(allocator, .{ .key = trimmed[start..index] });
            start = index + 1;
        }
    }
    if (start <= trimmed.len and start < trimmed.len) {
        try segments.append(allocator, .{ .key = trimmed[start..] });
    }
    if (segments.items.len == 0) try segments.append(allocator, .{ .key = trimmed });
    return segments.toOwnedSlice(allocator);
}

fn mergeQueryLeaf(allocator: std.mem.Allocator, existing: *std.json.Value, value: std.json.Value) error{OutOfMemory}!void {
    if (existing.* == .array) {
        existing.array.append(value) catch return error.OutOfMemory;
        return;
    }
    var list = std.json.Array.init(allocator);
    list.append(existing.*) catch return error.OutOfMemory;
    list.append(value) catch return error.OutOfMemory;
    existing.* = .{ .array = list };
}

fn insertQueryAt(allocator: std.mem.Allocator, node: *std.json.Value, segments: []const QuerySegment, value: std.json.Value) error{OutOfMemory}!void {
    if (segments.len == 0) {
        try mergeQueryLeaf(allocator, node, value);
        return;
    }
    switch (segments[0]) {
        .key => |key| {
            if (node.* != .object) node.* = .{ .object = try std.json.ObjectMap.init(allocator, &.{}, &.{}) };
            if (segments.len == 1) {
                const entry = try node.object.getOrPut(allocator, key);
                if (entry.found_existing) {
                    try mergeQueryLeaf(allocator, entry.value_ptr, value);
                } else {
                    entry.value_ptr.* = value;
                }
                return;
            }
            const entry = try node.object.getOrPut(allocator, key);
            if (!entry.found_existing) entry.value_ptr.* = .{ .object = try std.json.ObjectMap.init(allocator, &.{}, &.{}) };
            try insertQueryAt(allocator, entry.value_ptr, segments[1..], value);
        },
        .index => |position| {
            if (node.* != .array) node.* = .{ .array = std.json.Array.init(allocator) };
            while (node.array.items.len <= position) node.array.append(.null) catch return error.OutOfMemory;
            try insertQueryAt(allocator, &node.array.items[position], segments[1..], value);
        },
    }
}

fn insertQueryEntry(allocator: std.mem.Allocator, root: *std.json.Value, key: []const u8, value: []const u8) error{OutOfMemory}!void {
    const segments = try parseQueryKey(allocator, key);
    try insertQueryAt(allocator, root, segments, .{ .string = value });
}

/// Alias for `parse`; `application/x-www-form-urlencoded` bodies use the same encoding and coercion.
pub fn parseForm(comptime S: type, allocator: std.mem.Allocator, input: []const u8, options: schema.Options) json.Error!json.Result(S) {
    return parse(S, allocator, input, options);
}

/// Serializes an object schema value as an `application/x-www-form-urlencoded` string.
/// Keys and values are percent-encoded; nested objects, tuples, arrays, and records use bracket notation. Caller owns the returned slice.
pub fn stringify(
    comptime S: type,
    allocator: std.mem.Allocator,
    value: S.Value,
    options: StringifyOptions,
) (std.mem.Allocator.Error || std.Io.Writer.Error || error{Unsupported})![]u8 {
    comptime {
        if (S.kind != .object) @compileError("query serialization requires an object schema");
    }

    var buffer: std.Io.Writer.Allocating = .init(allocator);
    errdefer buffer.deinit();
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var first = true;
    inline for (@typeInfo(@TypeOf(S.fields)).@"struct".field_names) |name| {
        const F = @field(S.fields, name);
        const key = comptime naming.keyFor(name, S.object_config.naming);
        try appendValue(F, arena, &buffer.writer, &first, key, @field(value, name), options.emit_nulls);
    }
    return buffer.toOwnedSlice();
}

fn writePair(writer: *std.Io.Writer, first: *bool, key: []const u8, value: []const u8) !void {
    if (!first.*) try writer.writeByte('&');
    first.* = false;
    try writer.writeAll(key);
    try writer.writeByte('=');
    try writer.writeAll(value);
}

fn appendNull(allocator: std.mem.Allocator, writer: *std.Io.Writer, first: *bool, key: []const u8) !void {
    const encoded_key = try encodeComponent(allocator, key);
    try writePair(writer, first, encoded_key, "null");
}

fn appendText(allocator: std.mem.Allocator, writer: *std.Io.Writer, first: *bool, key: []const u8, text: []const u8) !void {
    const encoded_key = try encodeComponent(allocator, key);
    try writePair(writer, first, encoded_key, text);
}

fn appendValue(
    comptime F: type,
    allocator: std.mem.Allocator,
    writer: *std.Io.Writer,
    first: *bool,
    key: []const u8,
    value: anytype,
    emit_nulls: bool,
) (std.mem.Allocator.Error || std.Io.Writer.Error || error{Unsupported})!void {
    switch (F.kind) {
        .optional, .nullable => {
            if (value) |present| {
                try appendValue(F.Inner, allocator, writer, first, key, present, emit_nulls);
            } else if (emit_nulls) {
                try appendNull(allocator, writer, first, key);
            }
        },
        .default_value, .refine, .fallback, .metadata => {
            try appendValue(F.Inner, allocator, writer, first, key, value, emit_nulls);
        },
        .string => {
            const encoded = try encodeComponent(allocator, value);
            try appendText(allocator, writer, first, key, encoded);
        },
        .integer, .float => {
            const text = try std.fmt.allocPrint(allocator, "{d}", .{value});
            try appendText(allocator, writer, first, key, text);
        },
        .boolean => try appendText(allocator, writer, first, key, if (value) "true" else "false"),
        .enum_value => try appendText(allocator, writer, first, key, @tagName(value)),
        .literal => {
            if (comptime @TypeOf(value) == []const u8) {
                const encoded = try encodeComponent(allocator, value);
                try appendText(allocator, writer, first, key, encoded);
            } else if (comptime @TypeOf(value) == bool) {
                try appendText(allocator, writer, first, key, if (value) "true" else "false");
            } else {
                const text = try std.fmt.allocPrint(allocator, "{d}", .{value});
                try appendText(allocator, writer, first, key, text);
            }
        },
        .array => {
            for (value) |item| {
                try appendValue(F.Child, allocator, writer, first, key, item, emit_nulls);
            }
        },
        .tuple => {
            inline for (@typeInfo(F.Value).tuple.field_types, 0..) |_, index| {
                const child_key = try std.fmt.allocPrint(allocator, "{s}[{d}]", .{ key, index });
                try appendValue(@typeInfo(@TypeOf(F.fields)).@"struct".field_types[index], allocator, writer, first, child_key, value[index], emit_nulls);
            }
        },
        .object => {
            inline for (@typeInfo(@TypeOf(F.fields)).@"struct".field_names) |name| {
                const child_key = try std.fmt.allocPrint(allocator, "{s}[{s}]", .{ key, comptime naming.keyFor(name, F.object_config.naming) });
                try appendValue(@field(F.fields, name), allocator, writer, first, child_key, @field(value, name), emit_nulls);
            }
        },
        .record => {
            var iterator = value.iterator();
            while (iterator.next()) |entry| {
                const child_key = try std.fmt.allocPrint(allocator, "{s}[{s}]", .{ key, entry.key_ptr.* });
                try appendValue(F.Child, allocator, writer, first, child_key, entry.value_ptr.*, emit_nulls);
            }
        },
        .lazy => try appendValue(F.Inner, allocator, writer, first, key, value.*, emit_nulls),
        .intersection => try appendValue(F.FirstSchema, allocator, writer, first, key, value, emit_nulls),
        else => return error.Unsupported,
    }
}

test "nested query strings round trip" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const model = @import("model.zig");

    const Address = model.objectOf(.{ .city = string.string(.{}) }, .{});
    const User = model.objectOf(.{
        .name = string.string(.{}),
        .address = Address,
        .tags = @import("collection.zig").array(string.string(.{}), .{}),
    }, .{});

    var result = try parse(User, allocator, "name=Ada&address[city]=Paris&tags=fast&tags=safe", .{});
    defer result.deinit();
    try std.testing.expect(result.ok());
    try std.testing.expectEqualStrings("Paris", result.value.?.address.city);
    try std.testing.expectEqual(@as(usize, 2), result.value.?.tags.len);

    const text = try stringify(User, allocator, result.value.?, .{});
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "address%5Bcity%5D=Paris") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "tags=fast&tags=safe") != null);
}

test "query serialization follows lazy and intersection schemas" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const model = @import("model.zig");
    const modifiers = @import("modifiers.zig");
    const intersection = @import("intersection.zig");

    const Text = intersection.intersection(.{
        .first = string.string(.{}),
        .second = string.string(.{ .min = 1 }),
    }, .{});
    const Form = model.objectOf(.{ .name = Text }, .{});

    var result = try parse(Form, allocator, "name=Ada", .{});
    defer result.deinit();
    try std.testing.expect(result.ok());

    const text = try stringify(Form, allocator, result.value.?, .{});
    defer allocator.free(text);
    try std.testing.expectEqualStrings("name=Ada", text);

    const LazyForm = model.objectOf(.{ .name = modifiers.lazy(queryTextSchema) }, .{});
    var name: []const u8 = "Ada";
    const value: LazyForm.Value = .{ .name = &name };
    const lazy_text = try stringify(LazyForm, allocator, value, .{});
    defer allocator.free(lazy_text);
    try std.testing.expectEqualStrings("name=Ada", lazy_text);
}

fn queryTextSchema() type {
    return @import("string.zig").string(.{});
}
