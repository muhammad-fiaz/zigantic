const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const Email = z.email(.{});
    var good = try z.parse(Email, allocator, "\"ada@example.com\"", .{});
    defer good.deinit();
    std.debug.print("email: {s}\n", .{good.value.?});

    const Age = z.integer(u8, .{ .min = 18, .max = 120 });
    var bad = try z.parse(Age, allocator, "12", .{});
    defer bad.deinit();
    if (!bad.ok()) {
        const text = try bad.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    const Code = z.string(.{ .len = 4, .charset = .numeric });
    var result = try z.parse(Code, allocator, "\"12a4\"", .{});
    defer result.deinit();
    if (!result.ok()) {
        const text = try result.errors().render(allocator, .{ .capability = .ansi16 });
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }
}
