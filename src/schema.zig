//! Core schema protocol.
//!
//! A schema is a type with a `Value` declaration and four entry points:
//! `decode`, `check`, `encode` and `writeJsonSchema`. Object schemas either bind
//! to a declared Zig model or synthesize one with `@Struct`; tuples synthesize
//! their value with `@Tuple`. Everything here is compile-time metadata plus
//! explicit state; there is no global registry or hidden allocator.

const std = @import("std");
const error_mod = @import("error.zig");
const issue_mod = @import("issue.zig");

pub const Code = error_mod.Code;
pub const Messages = error_mod.Messages;
pub const ValidationError = error_mod.ValidationError;
pub const Issue = issue_mod.Issue;
pub const IssueList = issue_mod.List;

pub const Kind = enum {
    string,
    integer,
    float,
    boolean,
    null_value,
    enum_value,
    literal,
    array,
    record,
    tuple,
    object,
    union_value,
    discriminated_union,
    intersection,
    optional,
    nullable,
    default_value,
    fallback,
    refine,
    transform,
    lazy,
    custom,
};

pub const UnknownFields = enum { reject, strip };
pub const Duplicates = enum { reject, first, last };

pub const Hooks = struct {
    on_start: ?*const fn (schema_name: []const u8) void = null,
    on_field: ?*const fn (path: []const u8, accepted: bool) void = null,
    on_issue: ?*const fn (issue: Issue) void = null,
    on_finish: ?*const fn (ok: bool, total_issues: usize) void = null,
};

pub const Options = struct {
    unknown_fields: ?UnknownFields = null,
    coerce: bool = false,
    duplicates: Duplicates = .reject,
    messages: Messages = .{},
    max_depth: usize = 128,
    hooks: Hooks = .{},
};

pub const DecodeError = error{ Reported, OutOfMemory };
pub const EncodeError = std.Io.Writer.Error || error{ Unsupported, TransformFailed };
pub const SchemaError = std.mem.Allocator.Error || std.Io.Writer.Error || error{Unsupported};

pub const State = struct {
    arena: std.mem.Allocator,
    issues: *IssueList,
    options: Options = .{},
    depth: usize = 0,

    pub fn enter(self: *State) DecodeError!void {
        if (self.depth >= self.options.max_depth) {
            return failCode(self, .unsupported, "$", null, "shallower nesting");
        }
        self.depth += 1;
    }

    pub fn leave(self: *State) void {
        if (self.depth > 0) self.depth -= 1;
    }
};

pub const EncodeOptions = struct {
    emit_null_fields: bool = false,
};

pub const EncodeState = struct {
    allocator: std.mem.Allocator,
    json: *std.json.Stringify,
    options: EncodeOptions = .{},
};

pub const SchemaState = struct {
    arena: std.mem.Allocator,
    json: *std.json.Stringify,
    defs: ?*DefinitionRegistry = null,

    /// Registers a schema type for `$defs` generation and returns its stable
    /// definition key. Types are never generated twice.
    pub fn definitionFor(self: *SchemaState, comptime S: type) SchemaError![]const u8 {
        const registry = self.defs orelse return error.Unsupported;
        const raw_name = @typeName(S);
        const key = try std.fmt.allocPrint(self.arena, "def_{x}", .{std.hash.Wyhash.hash(0, raw_name)});
        for (registry.items.items) |item| {
            if (std.mem.eql(u8, item.key, key)) return item.key;
        }
        try registry.items.append(self.arena, .{ .key = key, .write = struct {
            fn write(state: *SchemaState) SchemaError!void {
                try S.writeJsonSchema(state);
            }
        }.write });
        return key;
    }
};

pub const Definition = struct {
    key: []const u8,
    write: *const fn (*SchemaState) SchemaError!void,
};

pub const DefinitionRegistry = struct {
    items: std.ArrayList(Definition) = .empty,
};

pub fn note(state: *State, code: Code, path: []const u8, received: ?[]const u8, expected: ?[]const u8) DecodeError!void {
    state.issues.add(.{
        .code = code,
        .path = path,
        .message = error_mod.resolveMessage(code, state.options.messages),
        .expected = expected,
        .received = received,
    }) catch return error.OutOfMemory;
    if (state.options.hooks.on_issue) |hook| {
        if (state.issues.last()) |item| hook(item);
    }
}

pub fn failCode(state: *State, code: Code, path: []const u8, received: ?[]const u8, expected: ?[]const u8) DecodeError {
    note(state, code, path, received, expected) catch |err| return err;
    return error.Reported;
}

pub fn failMessage(
    state: *State,
    code: Code,
    path: []const u8,
    message: []const u8,
    received: ?[]const u8,
    expected: ?[]const u8,
) DecodeError {
    state.issues.add(.{ .code = code, .path = path, .message = message, .expected = expected, .received = received }) catch return error.OutOfMemory;
    if (state.options.hooks.on_issue) |hook| {
        if (state.issues.last()) |item| hook(item);
    }
    return error.Reported;
}

pub fn fail(
    state: *State,
    err: ValidationError,
    path: []const u8,
    received: ?[]const u8,
    expected: ?[]const u8,
) DecodeError {
    note(state, error_mod.codeFor(err), path, received, expected) catch |failure| return failure;
    return error.Reported;
}

pub fn pathField(state: *State, parent: []const u8, key: []const u8) DecodeError![]const u8 {
    if (parent.len == 0) return dupe(state, key);
    return std.fmt.allocPrint(state.arena, "{s}.{s}", .{ parent, key }) catch error.OutOfMemory;
}

pub fn pathIndex(state: *State, parent: []const u8, index: usize) DecodeError![]const u8 {
    if (parent.len == 0) {
        return std.fmt.allocPrint(state.arena, "[{d}]", .{index}) catch error.OutOfMemory;
    }
    return std.fmt.allocPrint(state.arena, "{s}[{d}]", .{ parent, index }) catch error.OutOfMemory;
}

pub fn dupe(state: *State, bytes: []const u8) DecodeError![]const u8 {
    return state.arena.dupe(u8, bytes) catch error.OutOfMemory;
}

/// Quoted, length-capped rendering of a string for diagnostics.
pub fn quote(state: *State, text: []const u8) DecodeError![]const u8 {
    const limit = 64;
    if (text.len <= limit) {
        return std.fmt.allocPrint(state.arena, "\"{s}\"", .{text}) catch error.OutOfMemory;
    }
    return std.fmt.allocPrint(state.arena, "\"{s}...\"", .{text[0..limit]}) catch error.OutOfMemory;
}

pub fn describeNode(node: std.json.Value) []const u8 {
    return switch (node) {
        .null => "null",
        .bool => "boolean",
        .integer => "integer",
        .float => "float",
        .number_string => "number",
        .string => "string",
        .array => "array",
        .object => "object",
    };
}

/// Diagnostic rendering of a JSON scalar, or null for containers.
pub fn describeScalar(state: *State, node: std.json.Value) DecodeError![]const u8 {
    return switch (node) {
        .null => "null",
        .bool => |value| if (value) "true" else "false",
        .integer => |value| try std.fmt.allocPrint(state.arena, "{d}", .{value}),
        .float => |value| try std.fmt.allocPrint(state.arena, "{d}", .{value}),
        .number_string => |value| try dupe(state, value),
        .string => |value| try quote(state, value),
        .array, .object => "",
    };
}

pub fn isOptional(comptime S: type) bool {
    return @hasDecl(S, "is_optional") and S.is_optional;
}

/// Whether a schema defers its value type, directly or through an optional or
/// nullable wrapper. Recursive models use this to avoid a compile-time type
/// cycle while still checking every non-recursive field.
pub fn isRecursive(comptime S: type) bool {
    if (!@hasDecl(S, "kind")) return false;
    return switch (S.kind) {
        .lazy => true,
        .optional, .nullable => if (@hasDecl(S, "Inner")) isRecursive(S.Inner) else false,
        else => false,
    };
}

pub fn hasDefault(comptime S: type) bool {
    return @hasDecl(S, "has_default") and S.has_default;
}

pub fn defaultValueOf(comptime S: type) S.Value {
    return S.defaultValue();
}

pub fn isScalar(comptime S: type) bool {
    return @hasDecl(S, "decodeString");
}

pub fn valuesEqual(comptime T: type, a: T, b: T) bool {
    return switch (@typeInfo(T)) {
        .pointer => |info| blk: {
            if (info.size == .slice and info.child == u8) break :blk std.mem.eql(u8, a, b);
            break :blk std.meta.eql(a, b);
        },
        else => std.meta.eql(a, b),
    };
}

pub fn valueName(comptime S: type) []const u8 {
    return if (@hasDecl(S, "schema_name")) S.schema_name else "value";
}

/// Looks up a struct field index by name at compile time, or null.
pub fn fieldIndex(comptime T: type, comptime name: []const u8) ?usize {
    const info = @typeInfo(T).@"struct";
    for (info.field_names, 0..) |field_name, index| {
        if (std.mem.eql(u8, field_name, name)) return index;
    }
    return null;
}

test "path helpers and node descriptions" {
    const allocator = std.testing.allocator;
    var list = try IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list };

    const nested = try pathField(&state, "user", "name");
    try std.testing.expectEqualStrings("user.name", nested);
    const indexed = try pathIndex(&state, nested, 2);
    try std.testing.expectEqualStrings("user.name[2]", indexed);

    try std.testing.expectEqualStrings("object", describeNode(.{ .object = undefined }));
    try std.testing.expectEqualStrings("null", describeNode(.null));
}

test "issue recording honors message overrides" {
    const allocator = std.testing.allocator;
    var list = try IssueList.init(allocator, .{});
    defer list.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var state = State{ .arena = arena.allocator(), .issues = &list, .options = .{ .messages = .{ .too_small = "too small" } } };

    const failure = fail(&state, error.TooSmall, "age", "12", ">= 18");
    try std.testing.expect(failure == error.Reported);
    try std.testing.expectEqualStrings("too small", list.last().?.message);
    try std.testing.expectEqualStrings("E002", list.last().?.code.label());
}
