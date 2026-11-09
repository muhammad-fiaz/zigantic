const std = @import("std");
const z = @import("zigantic");

const Settings = struct {
    retries: u8,
    label: ?[]const u8,
    timeout: u16,
    ratio: ?f64,
};

const evenTimeout = struct {
    fn check(value: u16) bool {
        return value % 2 == 0;
    }
}.check;

const SettingsSchema = z.object(Settings, .{
    .retries = z.withDefault(z.integer(u8, .{ .max = 10 }), 3),
    .label = z.optional(z.string(.{ .min = 1 })),
    .timeout = z.refine(z.integer(u16, .{ .min = 100 }), .{
        .check = evenTimeout,
        .message = "timeout must be an even number of milliseconds",
    }),
    .ratio = z.nullable(z.probability(f64, .{})),
}, .{});

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var result = try z.parse(SettingsSchema, allocator,
        \\{"timeout":200,"ratio":null}
    , .{});
    defer result.deinit();
    if (result.value) |settings| {
        std.debug.print("retries={d} label={any} timeout={d} ratio={any}\n", .{
            settings.retries, settings.label, settings.timeout, settings.ratio,
        });
    } else {
        const text = try result.errors().render(allocator, .{});
        defer allocator.free(text);
        std.debug.print("{s}", .{text});
    }

    var invalid = try z.parse(SettingsSchema, allocator,
        \\{"timeout":101}
    , .{});
    defer invalid.deinit();
    if (!invalid.ok()) {
        std.debug.print("refinement: {s}\n", .{invalid.errors().first().?.message});
    }

    var issues = try z.validate(SettingsSchema, allocator, .{
        .retries = 5,
        .label = "prod",
        .timeout = 200,
        .ratio = 0.5,
    }, .{});
    defer issues.deinit();
    std.debug.print("typed check: {any}\n", .{issues.isEmpty()});
}
