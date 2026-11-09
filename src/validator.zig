//! Validation of already-typed values.
//!
//! `validate` mirrors `parse`: the caller supplies the allocator and receives
//! an owning issue list, which is empty when the value is valid. There is no
//! session object, no init/deinit pair and no retained state between calls.

const std = @import("std");
const schema = @import("schema.zig");

/// Validates a typed `value` against `S` and returns an owning issue list.
/// The list copies paths, messages, and diagnostics and must be freed with `deinit`; it is empty when valid. Returns `OutOfMemory` on allocation failure.
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

/// Allocation-free first-error validation using caller-supplied `buffer` as scratch space.
/// Path construction uses `buffer`, so even valid values require a usable buffer; too small a buffer returns `OutOfMemory`. The returned issue borrows `buffer`.
pub fn checkFirst(
    comptime S: type,
    value: S.Value,
    buffer: []u8,
    options: schema.Options,
) error{OutOfMemory}!?schema.Issue {
    var fixed = std.heap.FixedBufferAllocator.init(buffer);
    var issues = schema.IssueList.init(fixed.allocator(), .{ .capacity = 1 }) catch return error.OutOfMemory;

    var state = schema.State{
        .arena = fixed.allocator(),
        .issues = &issues,
        .options = options,
    };
    if (options.hooks.on_start) |hook| hook(S.schema_name);
    S.check(&state, value, "$") catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.Reported => {
            if (options.hooks.on_finish) |hook| hook(false, issues.count());
            return issues.first();
        },
    };
    if (options.hooks.on_finish) |hook| hook(true, 0);
    return null;
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

test "checkFirst uses caller scratch memory" {
    const number = @import("number.zig");
    const Age = number.integer(u8, .{ .min = 18 });
    var buffer: [4096]u8 = undefined;

    try std.testing.expect((try checkFirst(Age, 30, &buffer, .{})) == null);
    const issue = (try checkFirst(Age, 10, &buffer, .{})).?;
    try std.testing.expectEqualStrings("E002", issue.code.label());
    try std.testing.expectEqualStrings("$", issue.path);

    var tiny: [1]u8 = undefined;
    try std.testing.expectError(error.OutOfMemory, checkFirst(Age, 10, &tiny, .{}));
    // Path machinery also uses the buffer, so even a valid value can fail.
    try std.testing.expectError(error.OutOfMemory, checkFirst(Age, 30, &tiny, .{}));
}
