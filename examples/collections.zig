const std = @import("std");
const z = @import("zigantic");

const Inventory = struct {
    tags: []const []const u8,
    scores: std.array_hash_map.String(u16),
};

const InventorySchema = z.object(Inventory, .{
    .tags = z.array(z.string(.{ .min = 1 }), .{ .max = 8, .unique = true }),
    .scores = z.record(z.integer(u16, .{ .max = 1000 }), .{}),
}, .{});

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const document =
        \\{"tags":["math","logic"],"scores":{"ada":95,"grace":99}}
    ;

    var result = try z.parse(InventorySchema, allocator, document, .{});
    defer result.deinit();

    if (result.value) |inventory| {
        std.debug.print("{d} tags, {d} scores\n", .{ inventory.tags.len, inventory.scores.count() });
        var iterator = inventory.scores.iterator();
        while (iterator.next()) |entry| {
            std.debug.print("  {s}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var duplicate = try z.parse(InventorySchema, allocator,
        \\{"tags":["a","a"],"scores":{}}
    , .{});
    defer duplicate.deinit();
    std.debug.print("duplicate tags accepted: {any}\n", .{duplicate.ok()});

    const Point = z.fixedArray(z.float(f64, .{}), 2, .{});
    var point = try z.parse(Point, allocator, "[1.5,2.5]", .{});
    defer point.deinit();
    if (point.value) |coords| std.debug.print("point: {d},{d}\n", .{ coords[0], coords[1] });

    const Tags = z.set(z.string(.{ .min = 1 }), .{});
    var tags = try z.parse(Tags, allocator, "[\"fast\",\"safe\"]", .{});
    defer tags.deinit();
    std.debug.print("set accepted: {any}\n", .{tags.ok()});
}
