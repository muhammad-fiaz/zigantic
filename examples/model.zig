const std = @import("std");
const z = @import("zigantic");

const Role = enum { user, admin };

const User = struct {
    name: []const u8,
    email: []const u8,
    age: u8,
    role: Role = .user,
    tags: []const []const u8 = &.{},
};

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1, .max = 64, .trim = true }),
    .email = z.email(.{}),
    .age = z.integer(u8, .{ .min = 18 }),
    .role = z.enumType(Role, .{}),
    .tags = z.array(z.string(.{ .min = 1 }), .{ .max = 8 }),
}, .{ .naming = .snake_case, .aliases = &.{
    .{ .field = "name", .keys = &.{"full_name"} },
} });

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const document =
        \\{"name":"Ada","email":"ada@example.com","age":36,"role":"admin","tags":["math","logic"]}
    ;

    var result = try z.parse(UserSchema, allocator, document, .{});
    defer result.deinit();
    if (result.value) |user| {
        std.debug.print("{s} <{s}> age {d}, {s}, {d} tags\n", .{
            user.name, user.email, user.age, @tagName(user.role), user.tags.len,
        });

        const again = try z.stringify(UserSchema, allocator, user, .{});
        defer allocator.free(again);
        std.debug.print("{s}\n", .{again});
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var query = try z.parseQuery(UserSchema, allocator, "full_name=Grace&email=grace%40example.com&age=45", .{});
    defer query.deinit();
    if (query.value) |user| {
        std.debug.print("query: {s} ({s}), role {s}\n", .{ user.name, user.email, @tagName(user.role) });
    }

    const schema_json = try z.jsonSchema(UserSchema, allocator, .{});
    defer allocator.free(schema_json);
    std.debug.print("schema bytes: {d}\n", .{schema_json.len});
}
