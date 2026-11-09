//! Validation of already-typed values.
//!
//! `validate` mirrors `parse`: the caller supplies the allocator and receives
//! an owning issue list, which is empty when the value is valid. There is no
//! session object, no init/deinit pair and no retained state between calls.

const std = @import("std");
const schema = @import("schema.zig");

/// Checks `value` against `S` and returns the issues found.
///
/// The returned list owns copies of every path, message and diagnostic, so it
/// stays valid after the temporary path arena is released. The caller frees it
/// with `deinit`, exactly like a parse result.
pub fn validate(
    comptime S: type,
    allocator: std.mem.Allocator,
    value: S.Value,
    options: schema.Options,
) error{OutOfMemory}!schema.IssueList {
    var issues = try schema.IssueList.init(allocator, .{});
    errdefer issues.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var state = schema.State{
        .arena = arena.allocator(),
        .issues = &issues,
        .options = options,
    };
    if (options.hooks.on_start) |hook| hook(S.schema_name);
    S.check(&state, value, "$") catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.Reported => {
            if (options.hooks.on_finish) |hook| hook(false, issues.count());
            return issues;
        },
    };
    if (options.hooks.on_finish) |hook| hook(true, 0);
    return issues;
}

test "validate returns an owning issue list" {
    const allocator = std.testing.allocator;
    const number = @import("number.zig");

    const Age = number.integer(u8, .{ .min = 18 });

    var accepted = try validate(Age, allocator, 30, .{});
    defer accepted.deinit();
    try std.testing.expect(accepted.isEmpty());

    var rejected = try validate(Age, allocator, 10, .{});
    defer rejected.deinit();
    try std.testing.expectEqual(@as(usize, 1), rejected.count());
    try std.testing.expectEqualStrings("$", rejected.first().?.path);
}
