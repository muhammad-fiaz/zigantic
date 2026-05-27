//! Custom Validation Messages Example

const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    z.disableUpdateCheck();

    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Custom Validation Messages ===\n\n", .{});

    // -- Type-level custom messages --
    std.debug.print("--- Type-Level Custom Messages ---\n", .{});

    const Name = z.Stringf(3, 50, .{
        .too_short = "name must be at least 3 characters long",
    });

    const name_err = Name.init("Jo");
    if (name_err) |_| {} else |err| {
        std.debug.print("Name error: {s}\n", .{z.errorMessage(err)});
        std.debug.print("Custom message: {s}\n\n", .{Name.messageFor(err).?});
    }

    const Age = z.Intf(i32, 18, 120, .{
        .too_small = "you must be at least 18 years old",
        .too_large = "age cannot exceed 120",
    });

    const age_err = Age.init(15);
    if (age_err) |_| {} else |err| {
        std.debug.print("Age error: {s}\n", .{z.errorMessage(err)});
        std.debug.print("Custom message: {s}\n\n", .{Age.messageFor(err).?});
    }

    const Password = z.StrongPasswordf(8, 100, .{
        .weak_password = "password must contain uppercase, lowercase, digit, and special character",
        .too_short = "password must be at least 8 characters",
    });

    const pwd_err = Password.init("weak");
    if (pwd_err) |_| {} else |err| {
        std.debug.print("Password error: {s}\n", .{z.errorMessage(err)});
        std.debug.print("Custom message: {s}\n\n", .{Password.messageFor(err).?});
    }

    // -- JSON parsing with custom messages --
    std.debug.print("--- JSON Parsing with Custom Messages ---\n", .{});

    const User = struct {
        name: z.Stringf(3, 50, .{ .too_short = "name is required and must be at least 3 chars" }),
        age: z.Intf(i32, 18, 120, .{ .too_small = "must be 18 or older to register" }),
        email: z.Email,
    };

    const bad_json =
        \\{"name": "Jo", "age": 15, "email": "invalid"}
    ;

    var result = try z.fromJson(User, bad_json, allocator);
    defer result.deinit();

    std.debug.print("Validation errors:\n", .{});
    for (result.error_list.errors.items) |err| {
        std.debug.print("  {s}: {s}\n", .{ err.field, err.message });
    }

    // -- Global message formatter --
    std.debug.print("\n--- Global Message Formatter ---\n", .{});

    var custom_config = z.getConfig();
    custom_config.validation_message_formatter = struct {
        fn f(err: z.errors.ValidationError) []const u8 {
            return switch (err) {
                error.TooShort => "this field is too short",
                error.TooSmall => "value is below the minimum",
                else => z.errorMessage(err),
            };
        }
    }.f;
    z.setConfig(custom_config);

    var formatted = try z.fromJson(User, bad_json, allocator);
    defer formatted.deinit();

    std.debug.print("Formatted errors (with global formatter):\n", .{});
    for (formatted.error_list.errors.items) |err| {
        std.debug.print("  {s}: {s}\n", .{ err.field, err.message });
    }

    std.debug.print("\n=== Done ===\n", .{});
}
