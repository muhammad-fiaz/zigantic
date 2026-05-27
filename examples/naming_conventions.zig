const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    z.disableUpdateCheck();

    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("==================================================\n", .{});
    std.debug.print("  zigantic advanced naming conventions & aliases \n", .{});
    std.debug.print("==================================================\n\n", .{});

    // 1. Automatic Naming Policies
    // camelCase struct fields mapped automatically to snake_case in JSON / Query String
    const SnakeUser = struct {
        firstName: []const u8,
        lastName: []const u8,
        emailAddress: z.Email,

        pub const zigantic_naming = z.utils.NamingPolicy.snake_case;
    };

    const json_data =
        \\{
        \\  "first_name": "John",
        \\  "last_name": "Doe",
        \\  "email_address": "john.doe@example.com"
        \\}
    ;

    std.debug.print("Parsing camelCase struct from snake_case JSON...\n", .{});
    std.debug.print("JSON Input:\n{s}\n\n", .{json_data});

    var result_snake = try z.fromJson(SnakeUser, json_data, allocator);
    defer result_snake.deinit();

    if (result_snake.isValid()) {
        const user = result_snake.value.?;
        std.debug.print("Parsed values:\n", .{});
        std.debug.print("  firstName: {s}\n", .{user.firstName});
        std.debug.print("  lastName: {s}\n", .{user.lastName});
        std.debug.print("  emailAddress: {s}\n\n", .{user.emailAddress.get()});

        // Serialize back to JSON - should output snake_case keys!
        const serialized_json = try z.toJsonPretty(user, allocator);
        defer allocator.free(serialized_json);
        std.debug.print("Serialized output (snake_case):\n{s}\n\n", .{serialized_json});
    } else {
        const err_msg = try result_snake.formatErrors();
        defer allocator.free(err_msg);
        std.debug.print("Validation Errors:\n{s}\n", .{err_msg});
    }

    // 2. Explicit Field Aliases & Query parameters
    const AliasedProduct = struct {
        id: i32,
        productName: []const u8,
        priceInUsd: f64,

        pub const zigantic_aliases = .{
            .productName = "name",
            .priceInUsd = "price",
        };
    };

    const query_string = "id=101&name=Mechanical+Keyboard&price=99.99";
    std.debug.print("Parsing aliased struct from URL query string...\n", .{});
    std.debug.print("Query string Input: {s}\n\n", .{query_string});

    var result_query = try z.fromQueryString(AliasedProduct, query_string, allocator);
    defer result_query.deinit();

    if (result_query.isValid()) {
        const product = result_query.value.?;
        std.debug.print("Parsed product:\n", .{});
        std.debug.print("  id: {d}\n", .{product.id});
        std.debug.print("  productName: {s}\n", .{product.productName});
        std.debug.print("  priceInUsd: {d:.2}\n\n", .{product.priceInUsd});

        // Serialize back to URL query string - should use the alias names!
        const serialized_qs = try z.toQueryString(product, allocator);
        defer allocator.free(serialized_qs);
        std.debug.print("Serialized query string (aliased): {s}\n\n", .{serialized_qs});
    }
}
