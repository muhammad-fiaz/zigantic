//! Lifecycle Callbacks Example

const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    z.disableUpdateCheck();

    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Lifecycle Callbacks ===\n\n", .{});

    // -- Validation callbacks --
    std.debug.print("--- Validation Callbacks ---\n", .{});

    var cfg = z.getConfig();
    cfg.before_validation_callback = struct {
        fn call(type_name: []const u8) void {
            std.debug.print("[before_validation] Validating type: {s}\n", .{type_name});
        }
    }.call;
    cfg.on_field_validated_callback = struct {
        fn call(field: []const u8, _: []const u8, success: bool) void {
            std.debug.print("  [field_validated] {s}: {s}\n", .{ field, if (success) "PASS" else "FAIL" });
        }
    }.call;
    cfg.on_field_error_callback = struct {
        fn call(field: []const u8, msg: []const u8) void {
            std.debug.print("  [field_error] {s}: {s}\n", .{ field, msg });
        }
    }.call;
    cfg.on_validation_complete_callback = struct {
        fn call(valid: bool, count: usize) void {
            std.debug.print("  [validation_complete] Valid: {}, Errors: {d}\n\n", .{ valid, count });
        }
    }.call;
    z.setConfig(cfg);

    const User = struct {
        name: z.String(3, 50),
        age: z.Int(i32, 18, 120),
        email: z.Email,
    };

    // Valid data
    std.debug.print("--- Valid Data ---\n", .{});
    const good_json =
        \\{"name": "Alice", "age": 25, "email": "alice@example.com"}
    ;
    var good_result = try z.fromJson(User, good_json, allocator);
    defer good_result.deinit();

    // Invalid data
    std.debug.print("--- Invalid Data ---\n", .{});
    const bad_json =
        \\{"name": "Jo", "age": 15, "email": "invalid"}
    ;
    var bad_result = try z.fromJson(User, bad_json, allocator);
    defer bad_result.deinit();

    // -- Serialization callbacks --
    std.debug.print("\n--- Serialization Callbacks ---\n", .{});

    var ser_cfg = z.getConfig();
    ser_cfg.before_serialize_callback = struct {
        fn call() void {
            std.debug.print("  [before_serialize] Starting serialization\n", .{});
        }
    }.call;
    ser_cfg.after_serialize_callback = struct {
        fn call(result: []const u8) void {
            std.debug.print("  [after_serialize] Result length: {d}\n", .{result.len});
        }
    }.call;
    z.setConfig(ser_cfg);

    const json = try z.toJson(42, allocator);
    defer allocator.free(json);
    std.debug.print("  Serialized value: {s}\n", .{json});

    std.debug.print("\n=== Done ===\n", .{});
}
