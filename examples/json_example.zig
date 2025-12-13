//! JSON Example - Serialization and Deserialization

const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== zigantic JSON Example ===\n\n", .{});

    // Define a validated struct
    const User = struct {
        id: u32,
        name: z.String(1, 100),
        age: z.Int(i32, 0, 150),
        email: z.Email,
        active: bool,
        role: z.Default([]const u8, "user"),
    };

    // Parse JSON
    std.debug.print("--- Parsing Valid JSON ---\n", .{});
    const valid_json =
        \\{"id": 1, "name": "Alice", "age": 28, "email": "alice@example.com", "active": true}
    ;

    var result = try z.fromJson(User, valid_json, allocator);
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("ID: {d}\n", .{user.id});
        std.debug.print("Name: {s}\n", .{user.name.get()});
        std.debug.print("Age: {d}\n", .{user.age.get()});
        std.debug.print("Email: {s}\n", .{user.email.get()});
        std.debug.print("Active: {}\n", .{user.active});
        std.debug.print("Role: {s} (default)\n", .{user.role.get()});
    }

    // Parse with errors
    std.debug.print("\n--- Parsing Invalid JSON ---\n", .{});
    const invalid_json =
        \\{"id": 1, "name": "", "age": -5, "email": "not-email", "active": true}
    ;

    var bad_result = try z.fromJson(User, invalid_json, allocator);
    defer bad_result.deinit();

    if (!bad_result.isValid()) {
        std.debug.print("Validation errors ({d}):\n", .{bad_result.error_list.count()});
        for (bad_result.error_list.errors.items) |err| {
            std.debug.print("  {s}: {s}\n", .{ err.field, err.message });
        }
    }

    // Serialize to JSON
    std.debug.print("\n--- Serialization ---\n", .{});
    const Config = struct {
        host: []const u8,
        port: u16,
        debug: bool,
        tags: []const []const u8,
    };

    const config = Config{
        .host = "localhost",
        .port = 8080,
        .debug = true,
        .tags = &[_][]const u8{ "api", "v1" },
    };

    const compact = try z.toJson(config, allocator);
    defer allocator.free(compact);
    std.debug.print("Compact: {s}\n", .{compact});

    const pretty = try z.toJsonPretty(config, allocator);
    defer allocator.free(pretty);
    std.debug.print("Pretty:\n{s}\n", .{pretty});

    // Nested struct
    std.debug.print("\n--- Nested Structs ---\n", .{});
    const Address = struct {
        street: []const u8,
        city: []const u8,
        zip: z.String(5, 10),
    };

    const Person = struct {
        name: z.String(1, 50),
        address: Address,
    };

    const nested_json =
        \\{"name": "Bob", "address": {"street": "123 Main St", "city": "NYC", "zip": "10001"}}
    ;

    var nested_result = try z.fromJson(Person, nested_json, allocator);
    defer nested_result.deinit();

    if (nested_result.value) |person| {
        std.debug.print("Person: {s}\n", .{person.name.get()});
        std.debug.print("Address: {s}, {s} {s}\n", .{
            person.address.street,
            person.address.city,
            person.address.zip.get(),
        });
    }

    std.debug.print("\n=== Done ===\n", .{});
}
