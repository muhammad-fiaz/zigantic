const std = @import("std");
const z = @import("zigantic");

const Payload = union(enum) {
    text: []const u8,
    count: i64,
};

const PayloadSchema = z.unionOf(Payload, .{
    .text = z.string(.{ .min = 1 }),
    .count = z.integer(i64, .{}),
}, .{});

const Created = struct {
    type: []const u8,
    id: u64,
};

const Deleted = struct {
    type: []const u8,
    id: u64,
};

const Event = union(enum) {
    created: Created,
    deleted: Deleted,
};

const EventSchema = z.discriminatedUnion(Event, "type", .{
    .created = z.object(Created, .{
        .type = z.literal("created"),
        .id = z.integer(u64, .{}),
    }, .{}),
    .deleted = z.object(Deleted, .{
        .type = z.literal("deleted"),
        .id = z.integer(u64, .{}),
    }, .{}),
}, .{});

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var payload = try z.parse(PayloadSchema, allocator, "\"hello\"", .{});
    defer payload.deinit();
    switch (payload.value.?) {
        .text => |text| std.debug.print("text payload: {s}\n", .{text}),
        .count => |count| std.debug.print("count payload: {d}\n", .{count}),
    }

    var event = try z.parse(EventSchema, allocator,
        \\{"type":"deleted","id":42}
    , .{});
    defer event.deinit();
    switch (event.value.?) {
        .created => |created| std.debug.print("created {d}\n", .{created.id}),
        .deleted => |deleted| std.debug.print("deleted {d}\n", .{deleted.id}),
    }
}
