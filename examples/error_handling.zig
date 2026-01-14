//! Error Handling Example - Advanced error management

const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    // Disable update check to prevent background thread memory leaks in examples
    z.disableUpdateCheck();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== zigantic Error Handling ===\n\n", .{});

    // Basic error handling
    std.debug.print("--- Basic Validation Errors ---\n", .{});

    // String too short
    const NameResult = z.String(3, 50).init("Jo");
    if (NameResult) |_| {} else |err| {
        std.debug.print("Name error: {s} (code: {s})\n", .{ z.errorMessage(err), z.errorCode(err) });
    }

    // Number out of range
    const AgeResult = z.Int(i32, 18, 120).init(15);
    if (AgeResult) |_| {} else |err| {
        std.debug.print("Age error: {s}\n", .{z.errorMessage(err)});
    }

    // Invalid email
    const EmailResult = z.Email.init("invalid");
    if (EmailResult) |_| {} else |err| {
        std.debug.print("Email error: {s}\n", .{z.errorMessage(err)});
    }

    // Weak password
    const PwdResult = z.StrongPassword(8, 100).init("password");
    if (PwdResult) |_| {} else |err| {
        std.debug.print("Password error: {s}\n", .{z.errorMessage(err)});
    }

    // Even number required
    const EvenResult = z.EvenInt(i32, 0, 100).init(43);
    if (EvenResult) |_| {} else |err| {
        std.debug.print("Even error: {s}\n", .{z.errorMessage(err)});
    }

    // Multiple of required
    const MultResult = z.MultipleOf(i32, 5).init(23);
    if (MultResult) |_| {} else |err| {
        std.debug.print("Multiple error: {s}\n", .{z.errorMessage(err)});
    }

    // HTTPS required
    const HttpsResult = z.HttpsUrl.init("http://example.com");
    if (HttpsResult) |_| {} else |err| {
        std.debug.print("HTTPS error: {s}\n", .{z.errorMessage(err)});
    }

    // ErrorList usage
    std.debug.print("\n--- ErrorList Usage ---\n", .{});
    var errors = z.errors.ErrorList.init(allocator);
    defer errors.deinit();

    try errors.add("name", z.errors.ValidationError.TooShort, "must be at least 3 characters", "Jo");
    try errors.add("age", z.errors.ValidationError.TooSmall, "must be at least 18", "15");
    try errors.addWithPath("address", "zip", z.errors.ValidationError.InvalidFormat, "invalid zip code", "1234");
    try errors.addIndexed("tags", 2, z.errors.ValidationError.TooLong, "tag too long", null);
    try errors.addWithCode("email", z.errors.ValidationError.InvalidEmail, "invalid email", "bad@", "E010");

    std.debug.print("Total errors: {d}\n", .{errors.count()});
    std.debug.print("Has 'name' error: {}\n", .{errors.containsField("name")});
    std.debug.print("Has TooShort: {}\n", .{errors.containsErrorType(z.errors.ValidationError.TooShort)});

    std.debug.print("\nFormatted errors:\n", .{});
    const formatted = try errors.formatAll(allocator);
    defer allocator.free(formatted);
    std.debug.print("{s}", .{formatted});

    std.debug.print("JSON errors:\n", .{});
    const json = try errors.toJsonArray(allocator);
    defer allocator.free(json);
    std.debug.print("{s}\n", .{json});

    // Limited error list
    std.debug.print("\n--- Limited Error Collection ---\n", .{});
    var limited = z.errors.ErrorList.initWithMax(allocator, 2);
    defer limited.deinit();

    try limited.add("a", z.errors.ValidationError.TooShort, "error 1", null);
    try limited.add("b", z.errors.ValidationError.TooLong, "error 2", null);
    try limited.add("c", z.errors.ValidationError.TooSmall, "error 3 (should be ignored)", null);

    std.debug.print("Max 2 errors collected: {d}\n", .{limited.count()});

    // JSON parsing with errors
    std.debug.print("\n--- JSON Parsing Errors ---\n", .{});
    const User = struct {
        name: z.String(3, 50),
        age: z.Int(i32, 18, 120),
        email: z.Email,
    };

    const bad_json =
        \\{"name": "Jo", "age": 15, "email": "invalid"}
    ;

    var result = try z.fromJson(User, bad_json, allocator);
    defer result.deinit();

    if (!result.isValid()) {
        std.debug.print("Parsing errors ({d}):\n", .{result.error_list.count()});
        for (result.error_list.errors.items) |err| {
            std.debug.print("  [{s}] {s}: {s}\n", .{ z.errorCode(err.error_type), err.field, err.message });
        }
    }

    std.debug.print("\n=== Done ===\n", .{});
}
