const std = @import("std");
const z = @import("zigantic");

const Order = struct {
    id: []const u8,
    quantity: u16,
    email: []const u8,
};

const OrderSchema = z.object(Order, .{
    .id = z.uuid(.{}),
    .quantity = z.integer(u16, .{ .min = 1, .max = 100 }),
    .email = z.email(.{}),
}, .{});

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const document =
        \\{"id":"not-a-uuid","quantity":0,"email":"missing-at-sign"}
    ;

    var result = try z.parse(OrderSchema, allocator, document, .{});
    defer result.deinit();

    const text = try result.errors().render(allocator, .{});
    defer allocator.free(text);
    std.debug.print("{s}", .{text});

    const json_text = try result.errors().toJson(allocator);
    defer allocator.free(json_text);
    std.debug.print("{s}\n", .{json_text});

    const Age = z.integer(u8, .{ .min = 18 });
    var accepted = try z.validate(Age, allocator, 30, .{});
    defer accepted.deinit();
    var rejected = try z.validate(Age, allocator, 12, .{});
    defer rejected.deinit();
    std.debug.print("typed check: {any} then {any}, {d} issue(s)\n", .{ accepted.isEmpty(), rejected.isEmpty(), rejected.count() });
}
