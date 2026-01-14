//! Basic Example - Direct Validation and JSON Parsing

const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // Disable update check to prevent background thread memory leaks in examples
    z.disableUpdateCheck();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== zigantic Basic Example ===\n\n", .{});

    // Direct validation
    std.debug.print("--- Direct Validation ---\n", .{});
    const name = try z.String(1, 50).init("Alice");
    const age = try z.Int(i32, 18, 120).init(25);
    const email = try z.Email.init("alice@example.com");
    std.debug.print("Name: {s}, Age: {d}, Email: {s}\n", .{ name.get(), age.get(), email.get() });
    std.debug.print("Domain: {s}\n\n", .{email.domain()});

    // JSON parsing
    std.debug.print("--- JSON Parsing ---\n", .{});
    const User = struct {
        name: z.String(1, 50),
        age: z.Int(i32, 18, 120),
        email: z.Email,
        role: z.Default([]const u8, "user"),
    };

    const json =
        \\{"name": "Bob", "age": 30, "email": "bob@example.com"}
    ;

    var result = try z.fromJson(User, json, allocator);
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("User: {s}, {d}, {s}, {s}\n\n", .{
            user.name.get(),
            user.age.get(),
            user.email.get(),
            user.role.get(),
        });
    }

    // Validation errors
    std.debug.print("--- Validation Errors ---\n", .{});
    const bad =
        \\{"name": "", "age": 10, "email": "invalid"}
    ;

    var bad_result = try z.fromJson(User, bad, allocator);
    defer bad_result.deinit();

    if (!bad_result.isValid()) {
        for (bad_result.error_list.errors.items) |err| {
            std.debug.print("  {s}: {s}\n", .{ err.field, err.message });
        }
    }

    std.debug.print("\n=== Done ===\n", .{});
}
