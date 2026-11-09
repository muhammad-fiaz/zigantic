//! JSON Schema generation for schemas that can describe themselves.

const std = @import("std");
const schema = @import("schema.zig");

/// Generates JSON Schema text for schema `S` using the target draft in `options`.
/// The root schema is emitted under `root`; reused definitions are emitted under `$defs` or `definitions` as selected by the target. Caller owns the returned slice.
pub fn generate(
    comptime S: type,
    allocator: std.mem.Allocator,
    options: schema.JsonSchemaOptions,
) (std.mem.Allocator.Error || std.Io.Writer.Error || error{Unsupported})![]u8 {
    var buffer: std.Io.Writer.Allocating = .init(allocator);
    errdefer buffer.deinit();
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    var json: std.json.Stringify = .{ .writer = &buffer.writer, .options = .{} };
    var definitions = schema.DefinitionRegistry{};
    var state = schema.SchemaState{
        .arena = arena_state.allocator(),
        .json = &json,
        .defs = &definitions,
        .target = options.target,
    };

    try state.json.beginObject();
    try state.json.objectField("$schema");
    try state.json.write(options.target.schemaUri());
    try state.json.objectField("$ref");
    try state.json.write(if (options.target.usesDollarDefs()) "#/$defs/root" else "#/definitions/root");
    try state.json.objectField(options.target.definitionsKeyword());
    try state.json.beginObject();
    try state.json.objectField("root");
    try S.writeJsonSchema(&state);

    var index: usize = 0;
    while (index < definitions.items.items.len) : (index += 1) {
        const definition = definitions.items.items[index];
        try state.json.objectField(definition.key);
        try definition.write(&state);
    }

    try state.json.endObject();
    try state.json.endObject();
    return buffer.toOwnedSlice();
}

test "json schema generation" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const number = @import("number.zig");
    const model = @import("model.zig");
    const primitive = @import("primitive.zig");

    const User = struct {
        name: []const u8,
        age: u8,
        nickname: ?[]const u8 = null,
        active: bool = true,
    };
    const models = @import("modifiers.zig");
    const UserSchema = model.object(User, .{
        .name = string.string(.{ .min = 1 }),
        .age = number.integer(u8, .{ .min = 18 }),
        .nickname = models.optional(string.string(.{})),
        .active = primitive.boolean(.{}),
    }, .{});

    const text = try generate(UserSchema, allocator, .{});
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"type\":\"object\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"required\":[\"name\",\"age\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"active\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"required\":[\"name\",\"age\",\"active\"]") == null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"additionalProperties\":false") != null);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, text, .{});
    defer parsed.deinit();
    const root = parsed.value.object.get("$defs").?.object.get("root").?;
    try std.testing.expect(root.object.get("properties") != null);
}

test "defaults are represented with allOf" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const modifiers = @import("modifiers.zig");

    const Retries = modifiers.withDefault(number.integer(u8, .{}), 3);
    const text = try generate(Retries, allocator, .{});
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"default\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"allOf\"") != null);
}

test "every supported draft has a valid root and definition style" {
    const allocator = std.testing.allocator;
    const string = @import("string.zig");
    const targets = [_]schema.JsonSchemaTarget{ .draft_2020_12, .draft_2019_09, .draft_07, .draft_06, .draft_05 };

    for (targets) |target| {
        const text = try generate(string.string(.{}), allocator, .{ .target = target });
        defer allocator.free(text);
        try std.testing.expect(std.mem.indexOf(u8, text, target.schemaUri()) != null);
        try std.testing.expect(std.mem.indexOf(u8, text, target.definitionsKeyword()) != null);
        try std.testing.expect(std.mem.indexOf(u8, text, target.refPrefix()) != null);
    }
}

test "draft 5 uses legacy literal and exclusive bound forms" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const primitive = @import("primitive.zig");

    const Open = number.integer(i32, .{ .min = 0, .exclusive_min = 2, .exclusive_max = 10 });
    const text = try generate(Open, allocator, .{ .target = .draft_05 });
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"exclusiveMinimum\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"minimum\":2") != null);

    const Kind = primitive.literal("user");
    const literal_text = try generate(Kind, allocator, .{ .target = .draft_05 });
    defer allocator.free(literal_text);
    try std.testing.expect(std.mem.indexOf(u8, literal_text, "\"enum\":[\"user\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, literal_text, "\"const\"") == null);
}

test "recursive schemas use definitions and references" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");
    const model = @import("model.zig");
    const modifiers = @import("modifiers.zig");

    const Node = struct {
        value: i32,
        next: ?*const @This(),
    };
    const Schemas = struct {
        fn node() type {
            return model.object(Node, .{
                .value = number.integer(i32, .{}),
                .next = modifiers.optional(modifiers.lazy(node)),
            }, .{});
        }
    };
    const NodeSchema = Schemas.node();

    const text = try generate(NodeSchema, allocator, .{});
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"$defs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "\"$ref\":\"#/$defs/def_") != null);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value.object.get("$defs").?.object.count() >= 2);
}
