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

/// Stable machine-readable error code. Labels are `E###` strings;
/// see `error.zig` for categories and default messages.
pub const Code = error_mod.Code;
/// Per-code message overrides. A null field uses the code's default message.
pub const Messages = error_mod.Messages;
/// Classified validation failure. `codeFor` maps each error to its `Code`.
pub const ValidationError = error_mod.ValidationError;
/// Single validation issue. Strings are owned by `IssueList` after `add`;
/// the struct itself borrows its string fields.
pub const Issue = issue_mod.Issue;
/// Owning accumulation of issues. Owns arena copies of all issue strings
/// and an `ArrayList` preserving insertion order.
pub const IssueList = issue_mod.List;

/// Compile-time schema kind tag. Used for introspection and recursion detection.
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
    metadata,
};

/// Policy for unrecognized object keys: `reject` records an issue, `strip` ignores them.
pub const UnknownFields = enum { reject, strip };
/// Policy for duplicate object keys: `reject`, or the first or last occurrence wins.
pub const Duplicates = enum { reject, first, last };

/// Optional observation callbacks. `on_issue` runs after each recorded issue;
/// hooks must not fail in a way that aborts validation.
pub const Hooks = struct {
    on_start: ?*const fn (schema_name: []const u8) void = null,
    on_field: ?*const fn (path: []const u8, accepted: bool) void = null,
    on_issue: ?*const fn (issue: Issue) void = null,
    on_finish: ?*const fn (ok: bool, total_issues: usize) void = null,
};

/// Decoding options. `messages` overrides defaults per code; `max_depth` bounds recursion;
/// `hooks` observes progress. No allocation beyond issue recording.
pub const Options = struct {
    unknown_fields: ?UnknownFields = null,
    coerce: bool = false,
    duplicates: Duplicates = .reject,
    messages: Messages = .{},
    max_depth: usize = 128,
    hooks: Hooks = .{},
};

/// Decoding failures: `Reported` means issues were recorded, `OutOfMemory` means allocation failed.
pub const DecodeError = error{ Reported, OutOfMemory };
/// Encoding failures: writer or allocator errors plus `Unsupported` and `TransformFailed`.
pub const EncodeError = std.Io.Writer.Error || std.mem.Allocator.Error || error{ Unsupported, TransformFailed };
/// JSON Schema generation failures: allocator/writer errors plus `Unsupported`.
pub const SchemaError = std.mem.Allocator.Error || std.Io.Writer.Error || error{Unsupported};

/// Typed validation context for `validate` callbacks. Carries the decode `State` and
/// current `path`; `addIssue` copies strings into the issue list arena.
pub const Context = struct {
    state: *State,
    path: []const u8,

    /// Records an issue at the current path. The list owns a copy of the
    /// message and path. A custom validator may record several issues and must
    /// return normally; the caller converts any recorded issue into
    /// `error.Reported` after the callback returns.
    pub fn addIssue(self: *Context, code: Code, message: []const u8) DecodeError!void {
        self.state.issues.add(.{
            .code = code,
            .path = self.path,
            .message = message,
        }) catch return error.OutOfMemory;
        if (self.state.options.hooks.on_issue) |hook| {
            if (self.state.issues.last()) |issue| hook(issue);
        }
    }

    /// Records an issue for `code` using its default message. Allocates copies of
    /// `path`, `expected`, and `received` in the list arena; returns `OutOfMemory`.
    pub fn addCode(self: *Context, code: Code, expected: ?[]const u8, received: ?[]const u8) DecodeError!void {
        self.state.issues.add(.{
            .code = code,
            .path = self.path,
            .message = code.message(),
            .expected = expected,
            .received = received,
        }) catch return error.OutOfMemory;
        if (self.state.options.hooks.on_issue) |hook| {
            if (self.state.issues.last()) |issue| hook(issue);
        }
    }

    /// Records an issue and returns `error.Reported`. Convenience for validators
    /// that must abort after one failure; may return `OutOfMemory` instead.
    pub fn fail(self: *Context, code: Code, message: []const u8) DecodeError {
        self.addIssue(code, message) catch |err| return err;
        return error.Reported;
    }

    /// Returns the arena allocator for validators. Allocations live as long as
    /// `State.arena`; they are not freed individually.
    pub fn allocator(self: *Context) std.mem.Allocator {
        return self.state.arena;
    }
};

/// Decoding state. `arena` owns all allocations; `issues` accumulates results;
/// `depth` tracks nesting against `options.max_depth`.
pub const State = struct {
    arena: std.mem.Allocator,
    issues: *IssueList,
    options: Options = .{},
    depth: usize = 0,

    /// Enters one nesting level. Returns `error.Reported` (and records an issue)
    /// when `max_depth` is exceeded; otherwise increments `depth`. No allocation.
    pub fn enter(self: *State) DecodeError!void {
        if (self.depth >= self.options.max_depth) {
            return failCode(self, .unsupported, "$", null, "shallower nesting");
        }
        self.depth += 1;
    }

    /// Leaves one nesting level. Decrements `depth` when positive.
    /// Never fails and does not allocate.
    pub fn leave(self: *State) void {
        if (self.depth > 0) self.depth -= 1;
    }
};

/// Encoding options. `emit_null_fields` controls whether null/optional fields
/// emit a JSON `null` instead of being omitted by the parent object.
pub const EncodeOptions = struct {
    emit_null_fields: bool = false,
};

/// JSON Schema draft targeted for `writeJsonSchema`. Selects keyword spelling
/// and the set of supported keywords for generated documents.
pub const JsonSchemaTarget = enum {
    draft_2020_12,
    draft_2019_09,
    draft_07,
    draft_06,
    draft_05,

    /// URI identifying the target draft's meta-schema. Constant, no allocation.
    pub fn schemaUri(self: JsonSchemaTarget) []const u8 {
        return switch (self) {
            .draft_2020_12 => "https://json-schema.org/draft/2020-12/schema",
            .draft_2019_09 => "https://json-schema.org/draft/2019-09/schema",
            .draft_07 => "http://json-schema.org/draft-07/schema#",
            .draft_06 => "http://json-schema.org/draft-06/schema#",
            .draft_05 => "http://json-schema.org/draft-05/schema#",
        };
    }

    /// 2019-09 and 2020-12 use `$defs`; older drafts use `definitions`.
    pub fn usesDollarDefs(self: JsonSchemaTarget) bool {
        return switch (self) {
            .draft_2020_12, .draft_2019_09 => true,
            .draft_07, .draft_06, .draft_05 => false,
        };
    }

    /// Keyword holding generated definitions: `$defs` or `definitions`, depending on the draft. Static string.
    pub fn definitionsKeyword(self: JsonSchemaTarget) []const u8 {
        return if (self.usesDollarDefs()) "$defs" else "definitions";
    }

    /// Prefix for `$ref` values pointing into generated definitions. Static string.
    pub fn refPrefix(self: JsonSchemaTarget) []const u8 {
        return if (self.usesDollarDefs()) "#/$defs/" else "#/definitions/";
    }

    /// 2020-12 uses `prefixItems`; earlier drafts use the tuple form of `items`.
    pub fn usesPrefixItems(self: JsonSchemaTarget) bool {
        return self == .draft_2020_12;
    }

    /// `propertyNames` was introduced in Draft 6.
    pub fn supportsPropertyNames(self: JsonSchemaTarget) bool {
        return self != .draft_05;
    }

    /// Draft 5 expresses exclusive bounds with boolean keywords next to
    /// `minimum` / `maximum`; Draft 6 introduced numeric exclusive bounds.
    pub fn usesBooleanExclusiveBounds(self: JsonSchemaTarget) bool {
        return self == .draft_05;
    }

    /// `const` was introduced in Draft 6; Draft 5 uses a one-element `enum`.
    pub fn supportsConst(self: JsonSchemaTarget) bool {
        return self != .draft_05;
    }

    /// `$id` replaced `id` in Draft 6.
    pub fn idKeyword(self: JsonSchemaTarget) []const u8 {
        return if (self == .draft_05) "id" else "$id";
    }

    /// Whether the target supports the `examples` keyword. Draft 5 predates `examples`. Static check.
    pub fn supportsExamples(self: JsonSchemaTarget) bool {
        return self != .draft_05;
    }

    /// Whether the target supports `readOnly`/`writeOnly` keywords. Drafts 07, 2019-09, and 2020-12 only.
    pub fn supportsReadWriteOnly(self: JsonSchemaTarget) bool {
        return self == .draft_07 or self == .draft_2020_12 or self == .draft_2019_09;
    }
};

/// Options for JSON Schema generation. `target` selects the draft keyword dialect.
pub const JsonSchemaOptions = struct {
    target: JsonSchemaTarget = .draft_2020_12,
};

/// Encoding state. `allocator` is available to transforms/codecs; `json` is the
/// stringify writer; `options` selects emission behavior. No ownership of `json`.
pub const EncodeState = struct {
    allocator: std.mem.Allocator,
    json: *std.json.Stringify,
    options: EncodeOptions = .{},
};

/// JSON Schema generation state. `arena` supplies temporary allocations; `defs`
/// tracks emitted definitions when present. Returned keys are arena-owned.
pub const SchemaState = struct {
    arena: std.mem.Allocator,
    json: *std.json.Stringify,
    defs: ?*DefinitionRegistry = null,
    target: JsonSchemaTarget = .draft_2020_12,

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

/// Registered definition entry. `key` is the emitted `$defs` name; `write` emits the schema body.
pub const Definition = struct {
    key: []const u8,
    write: *const fn (*SchemaState) SchemaError!void,
};

/// Ordered registry of generated definitions. `items` preserves emission order for output.
pub const DefinitionRegistry = struct {
    items: std.ArrayList(Definition) = .empty,
};

/// Records an issue using the resolved message for `code`. Copies strings into
/// the list arena, invokes `on_issue`, and returns `OutOfMemory` on failure.
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

/// Records an issue via `note` and returns `error.Reported`. Returns `OutOfMemory` if recording fails.
pub fn failCode(state: *State, code: Code, path: []const u8, received: ?[]const u8, expected: ?[]const u8) DecodeError {
    note(state, code, path, received, expected) catch |err| return err;
    return error.Reported;
}

/// Records an issue with an explicit `message`, then returns `error.Reported`.
/// Copies strings into the list arena and fires `on_issue`; fails with `OutOfMemory`.
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

/// Records an issue for a `ValidationError` using its mapped `Code` and resolved message.
/// Returns `error.Reported` (or `OutOfMemory` when recording fails).
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

/// Builds `parent.key` in `state.arena` (or copies `key` when `parent` is empty).
/// The result is arena-owned and fails with `OutOfMemory`.
pub fn pathField(state: *State, parent: []const u8, key: []const u8) DecodeError![]const u8 {
    if (parent.len == 0) return dupe(state, key);
    return std.fmt.allocPrint(state.arena, "{s}.{s}", .{ parent, key }) catch error.OutOfMemory;
}

/// Builds `parent[index]` in `state.arena` (or `[index]` when `parent` is empty).
/// Allocation stays in the arena and fails with `OutOfMemory`.
pub fn pathIndex(state: *State, parent: []const u8, index: usize) DecodeError![]const u8 {
    if (parent.len == 0) {
        return std.fmt.allocPrint(state.arena, "[{d}]", .{index}) catch error.OutOfMemory;
    }
    return std.fmt.allocPrint(state.arena, "{s}[{d}]", .{ parent, index }) catch error.OutOfMemory;
}

/// Duplicates `bytes` into `state.arena` and returns the copy. Fails with `OutOfMemory`.
pub fn dupe(state: *State, bytes: []const u8) DecodeError![]const u8 {
    return state.arena.dupe(u8, bytes) catch error.OutOfMemory;
}

/// Quoted, length-capped rendering (max 64 chars) for diagnostics.
/// Allocates the formatted string in `state.arena`; fails with `OutOfMemory`.
pub fn quote(state: *State, text: []const u8) DecodeError![]const u8 {
    const limit = 64;
    if (text.len <= limit) {
        return std.fmt.allocPrint(state.arena, "\"{s}\"", .{text}) catch error.OutOfMemory;
    }
    return std.fmt.allocPrint(state.arena, "\"{s}...\"", .{text[0..limit]}) catch error.OutOfMemory;
}

/// JSON type name for `node` (`null`, `boolean`, integer, float, string, array, object).
/// Static string, no allocation.
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

/// Diagnostic rendering of a JSON scalar, or empty string for containers.
/// Scalars needing formatting are allocated in `state.arena`.
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

/// True when `S` carries `is_optional == true`. Compile-time check, no allocation.
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

/// True when `S` carries `has_default == true`. Compile-time check, no allocation.
pub fn hasDefault(comptime S: type) bool {
    return @hasDecl(S, "has_default") and S.has_default;
}

/// Returns `S.defaultValue()` for schemas that provide a default. Fails to compile otherwise.
pub fn defaultValueOf(comptime S: type) S.Value {
    return S.defaultValue();
}

/// True when `S` provides `decodeString` (query-decodable scalar). Compile-time check, no allocation.
pub fn isScalar(comptime S: type) bool {
    return @hasDecl(S, "decodeString");
}

/// Structural equality with string-content comparison for `[]const u8`.
/// Uses `std.meta.eql` otherwise; no allocation.
pub fn valuesEqual(comptime T: type, a: T, b: T) bool {
    return switch (@typeInfo(T)) {
        .pointer => |info| blk: {
            if (info.size == .slice and info.child == u8) break :blk std.mem.eql(u8, a, b);
            break :blk std.meta.eql(a, b);
        },
        else => std.meta.eql(a, b),
    };
}

/// `S.schema_name` when present, otherwise `"value"`. Compile-time string, no allocation.
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
