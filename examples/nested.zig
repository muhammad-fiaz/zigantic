const std = @import("std");
const z = @import("zigantic");

const Address = struct {
    city: []const u8,
    postal_code: []const u8,
};

const AddressSchema = z.object(Address, .{
    .city = z.string(.{ .min = 1, .max = 80 }),
    .postal_code = z.string(.{ .len = 5, .charset = .numeric }),
}, .{});

const User = struct {
    name: []const u8,
    address: Address,
};

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1, .trim = true }),
    .address = AddressSchema,
}, .{});

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const document =
        \\{"name":"Ada","address":{"city":"London","postal_code":"12345"}}
    ;

    var result = try z.parse(UserSchema, allocator, document, .{});
    defer result.deinit();
    if (result.value) |user| {
        std.debug.print("{s} lives in {s} ({s})\n", .{ user.name, user.address.city, user.address.postal_code });
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var broken = try z.parse(UserSchema, allocator,
        \\{"name":"Ada","address":{"city":"London","postal_code":"AB12"}}
    , .{});
    defer broken.deinit();
    if (!broken.ok()) {
        std.debug.print("nested path: {s}\n", .{broken.errors().first().?.path});
    }
}
