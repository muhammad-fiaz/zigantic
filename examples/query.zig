const std = @import("std");
const z = @import("zigantic");

const Search = struct {
    query: []const u8,
    page: u16,
    active: bool,
    tags: []const []const u8,
};

const SearchSchema = z.object(Search, .{
    .query = z.string(.{ .min = 1 }),
    .page = z.withDefault(z.integer(u16, .{ .min = 1 }), 1),
    .active = z.boolean(.{}),
    .tags = z.array(z.string(.{ .min = 1 }), .{ .max = 4 }),
}, .{ .naming = .snake_case });

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var result = try z.parseQuery(SearchSchema, allocator, "query=zig+validation&active=true&tags=fast&tags=safe", .{});
    defer result.deinit();
    if (result.value) |search| {
        std.debug.print("{s} page {d} active={any} tags={d}\n", .{
            search.query, search.page, search.active, search.tags.len,
        });

        const text = try z.stringifyQuery(SearchSchema, allocator, search, .{});
        defer allocator.free(text);
        std.debug.print("{s}\n", .{text});
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var form = try z.parseForm(SearchSchema, allocator, "query=login&active=false", .{});
    defer form.deinit();
    std.debug.print("form accepted: {any}\n", .{form.ok()});
}
