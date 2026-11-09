//! JSON Schema generation for schemas that can describe themselves.

const std = @import("std");
const schema = @import("schema.zig");

pub fn generate(
    comptime S: type,
    allocator: std.mem.Allocator,
    options: schema.EncodeOptions,
) (std.mem.Allocator.Error || std.Io.Writer.Error || error{Unsupported})![]u8 {
    _ = options;
    var buffer: std.Io.Writer.Allocating = .init(allocator);
    errdefer buffer.deinit();
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    var json: std.json.Stringify = .{ .writer = &buffer.writer, .options = .{} };
    var definitions = schema.DefinitionRegistry{};
    var state = schema.SchemaState{ .arena = arena_state.allocator(), .json = &json, .defs = &definitions };

    try state.json.beginObject();
    try state.json.objectField("$schema");
    try state.json.write("https://json-schema.org/draft/2020-12/schema");
    try state.json.objectField("$ref");
    try state.json.write("#/$defs/root");
    try state.json.objectField("$defs");
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
