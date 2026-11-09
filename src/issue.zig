//! Structured validation issues and their rendering.
//!
//! An `Issue` is plain data; a `List` accumulates issues while owning copies of
//! every string so callers can free their inputs immediately. Rendering is
//! separate from validation: colour output is opt-in through tint.zig and the
//! plain form never emits escape sequences.

const std = @import("std");
const tint = @import("tint");
const error_mod = @import("error.zig");

pub const Issue = struct {
    code: error_mod.Code,
    path: []const u8,
    message: []const u8,
    expected: ?[]const u8 = null,
    received: ?[]const u8 = null,
};

pub const Capability = tint.ansi.Capability;

pub const Options = struct {
    capacity: usize = 8,
};

pub const RenderOptions = struct {
    capability: Capability = .none,
    show_expected: bool = true,
    show_received: bool = true,
    indent: u8 = 2,
};

const error_color = tint.color.rgb(255, 110, 110);
const path_color = tint.color.rgb(110, 200, 255);
const expected_color = tint.color.rgb(230, 200, 110);
const received_color = tint.color.rgb(200, 200, 200);

fn colored(writer: *std.Io.Writer, capability: Capability, color: tint.color.Color) !void {
    if (capability == .none) return;
    var sequence = tint.ansi.render(color, .foreground, capability);
    try writer.writeAll(sequence.slice());
}

fn resetColor(writer: *std.Io.Writer, capability: Capability) !void {
    if (capability == .none) return;
    try writer.writeAll(tint.ansi.reset.foreground);
}

pub const List = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Issue),
    arena: *std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator, options: Options) !List {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        return .{
            .allocator = allocator,
            .entries = try std.ArrayList(Issue).initCapacity(allocator, options.capacity),
            .arena = arena,
        };
    }

    pub fn deinit(self: *List) void {
        self.entries.deinit(self.allocator);
        self.arena.deinit();
        self.allocator.destroy(self.arena);
        self.* = undefined;
    }

    /// Drops every issue and reclaims the arena, retaining capacity.
    pub fn clear(self: *List) void {
        self.entries.clearRetainingCapacity();
        _ = self.arena.reset(.retain_capacity);
    }

    pub fn count(self: *const List) usize {
        return self.entries.items.len;
    }

    pub fn isEmpty(self: *const List) bool {
        return self.entries.items.len == 0;
    }

    pub fn at(self: *const List, index: usize) Issue {
        return self.entries.items[index];
    }

    pub fn first(self: *const List) ?Issue {
        if (self.entries.items.len == 0) return null;
        return self.entries.items[0];
    }

    pub fn last(self: *const List) ?Issue {
        if (self.entries.items.len == 0) return null;
        return self.entries.items[self.entries.items.len - 1];
    }

    /// Number of recorded issues; pass to `rollback` to discard later ones.
    pub fn mark(self: *const List) usize {
        return self.entries.items.len;
    }

    /// Discards issues recorded after `mark`. Strings stay in the arena until
    /// the next `clear` or `deinit`.
    pub fn rollback(self: *List, point: usize) void {
        if (point >= self.entries.items.len) return;
        self.entries.shrinkRetainingCapacity(point);
    }

    fn copy(self: *List, bytes: []const u8) ![]const u8 {
        return self.arena.allocator().dupe(u8, bytes);
    }

    pub fn add(self: *List, issue: Issue) !void {
        try self.entries.append(self.allocator, .{
            .code = issue.code,
            .path = try self.copy(issue.path),
            .message = try self.copy(issue.message),
            .expected = if (issue.expected) |text| try self.copy(text) else null,
            .received = if (issue.received) |text| try self.copy(text) else null,
        });
    }

    pub fn addCode(
        self: *List,
        code: error_mod.Code,
        path: []const u8,
        expected: ?[]const u8,
        received: ?[]const u8,
    ) !void {
        try self.add(.{ .code = code, .path = path, .message = code.message(), .expected = expected, .received = received });
    }

    pub fn addError(
        self: *List,
        err: error_mod.ValidationError,
        path: []const u8,
        expected: ?[]const u8,
        received: ?[]const u8,
    ) !void {
        try self.addCode(error_mod.codeFor(err), path, expected, received);
    }

    pub fn write(self: *const List, writer: *std.Io.Writer, options: RenderOptions) !void {
        for (self.entries.items, 0..) |issue, index| {
            if (index > 0) try writer.writeByte('\n');
            try colored(writer, options.capability, error_color);
            try writer.writeAll("error[");
            try writer.writeAll(issue.code.label());
            try writer.writeAll("]");
            try resetColor(writer, options.capability);
            try writer.writeAll(": ");
            try writer.writeAll(issue.message);
            try writer.writeByte('\n');

            if (issue.path.len > 0) {
                for (0..options.indent) |_| try writer.writeByte(' ');
                try colored(writer, options.capability, path_color);
                try writer.writeAll(issue.path);
                try resetColor(writer, options.capability);
                try writer.writeByte('\n');
            }

            if (options.show_expected) {
                if (issue.expected) |expected| {
                    for (0..options.indent * 2) |_| try writer.writeByte(' ');
                    try colored(writer, options.capability, expected_color);
                    try writer.writeAll("expected: ");
                    try resetColor(writer, options.capability);
                    try writer.writeAll(expected);
                    try writer.writeByte('\n');
                }
            }

            if (options.show_received) {
                if (issue.received) |received| {
                    for (0..options.indent * 2) |_| try writer.writeByte(' ');
                    try colored(writer, options.capability, received_color);
                    try writer.writeAll("received: ");
                    try resetColor(writer, options.capability);
                    try writer.writeAll(received);
                    try writer.writeByte('\n');
                }
            }
        }
    }

    pub fn render(self: *const List, allocator: std.mem.Allocator, options: RenderOptions) ![]u8 {
        var buffer: std.Io.Writer.Allocating = .init(allocator);
        errdefer buffer.deinit();
        try self.write(&buffer.writer, options);
        return buffer.toOwnedSlice();
    }

    pub fn writeJson(self: *const List, writer: *std.Io.Writer) !void {
        var json: std.json.Stringify = .{ .writer = writer, .options = .{} };
        try json.beginArray();
        for (self.entries.items) |issue| {
            try json.beginObject();
            try json.objectField("code");
            try json.write(issue.code.label());
            try json.objectField("path");
            try json.write(issue.path);
            try json.objectField("message");
            try json.write(issue.message);
            if (issue.expected) |expected| {
                try json.objectField("expected");
                try json.write(expected);
            }
            if (issue.received) |received| {
                try json.objectField("received");
                try json.write(received);
            }
            try json.endObject();
        }
        try json.endArray();
    }

    pub fn toJson(self: *const List, allocator: std.mem.Allocator) ![]u8 {
        var buffer: std.Io.Writer.Allocating = .init(allocator);
        errdefer buffer.deinit();
        try self.writeJson(&buffer.writer);
        return buffer.toOwnedSlice();
    }
};

test "issue list renders plain text and json" {
    const allocator = std.testing.allocator;
    var list = try List.init(allocator, .{});
    defer list.deinit();

    try list.addError(error.TooSmall, "user.age", ">= 18", "12");
    try list.addCode(.invalid_format, "user.email", "email address", "\"nope\"");

    try std.testing.expectEqual(@as(usize, 2), list.count());
    try std.testing.expectEqualStrings("E002", list.first().?.code.label());

    const text = try list.render(allocator, .{});
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "error[E002]: value is too small") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "user.age") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "expected: >= 18") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\x1b[") == null);

    const json_text = try list.toJson(allocator);
    defer allocator.free(json_text);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_text, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 2), parsed.value.array.items.len);

    list.rollback(1);
    try std.testing.expectEqual(@as(usize, 1), list.count());
    list.clear();
    try std.testing.expect(list.isEmpty());
}

test "colored rendering emits tint sequences" {
    const allocator = std.testing.allocator;
    var list = try List.init(allocator, .{});
    defer list.deinit();
    try list.addCode(.type_mismatch, "$", "integer", "\"text\"");

    const text = try list.render(allocator, .{ .capability = .ansi16 });
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "\x1b[") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "error[E001]") != null);
}
