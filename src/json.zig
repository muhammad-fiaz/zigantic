//! JSON serialization and deserialization for zigantic.
//!
//! This module provides the core fromJson and toJson functionality,
//! using compile-time introspection to validate and parse JSON into
//! Zig structs with zigantic validation types.

const std = @import("std");
const types = @import("types.zig");
const errors = @import("errors.zig");

/// Result of a JSON parsing operation.
///
/// Contains either the parsed value or a list of validation errors.
pub fn ParseResult(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The parsed and validated value (null if validation failed).
        value: ?T,
        /// List of validation errors (empty if parsing succeeded).
        error_list: errors.ErrorList,
        /// Allocator used for memory management.
        allocator: std.mem.Allocator,
        /// Arena for allocated data within the parsed value.
        arena: std.heap.ArenaAllocator,

        /// Check if parsing was successful.
        pub fn isValid(self: Self) bool {
            return self.value != null and !self.error_list.hasErrors();
        }

        /// Get the value or return an error.
        pub fn unwrap(self: Self) !T {
            if (self.value) |v| {
                return v;
            }
            return error.ValidationFailed;
        }

        /// Free all allocated memory.
        pub fn deinit(self: *Self) void {
            self.error_list.deinit();
            self.arena.deinit();
        }

        /// Get formatted error messages.
        pub fn formatErrors(self: Self) ![]const u8 {
            return self.error_list.formatAll(self.allocator);
        }
    };
}

/// Parse JSON string into a validated struct.
pub fn fromJson(comptime T: type, json_string: []const u8, allocator: std.mem.Allocator) !ParseResult(T) {
    var result = ParseResult(T){
        .value = null,
        .error_list = errors.ErrorList.init(allocator),
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
    };
    errdefer result.deinit();

    const arena_alloc = result.arena.allocator();

    // Parse the JSON
    const parsed = std.json.parseFromSlice(std.json.Value, arena_alloc, json_string, .{}) catch {
        try result.error_list.add("", errors.ValidationError.InvalidJson, "Invalid JSON syntax", null);
        return result;
    };

    // Validate and convert to the target type
    result.value = parseValue(T, parsed.value, arena_alloc, &result.error_list, "") catch |err| {
        if (err == error.OutOfMemory) return err;
        return result;
    };

    return result;
}

/// Parse a JSON value into the target type with validation.
fn parseValue(
    comptime T: type,
    json_value: std.json.Value,
    allocator: std.mem.Allocator,
    error_list: *errors.ErrorList,
    path: []const u8,
) !?T {
    const info = @typeInfo(T);

    // Handle optionals first
    if (info == .optional) {
        if (json_value == .null) {
            return null;
        }
        const inner = try parseValue(info.optional.child, json_value, allocator, error_list, path);
        return inner;
    }

    // Handle arrays/slices (must check before struct since slices can't have decls)
    if (info == .pointer and info.pointer.size == .slice) {
        return parseSlice(T, info.pointer.child, json_value, allocator, error_list, path);
    }

    // Handle primitives (int, float, bool)
    if (info == .int or info == .float or info == .bool) {
        return parsePrimitive(T, json_value, error_list, path);
    }

    // Handle structs - check for zigantic types
    if (info == .@"struct") {
        if (@hasDecl(T, "zigantic_type")) {
            return parseZiganticType(T, json_value, allocator, error_list, path);
        }
        return parseStruct(T, json_value, allocator, error_list, path);
    }

    // Unsupported type
    try addError(error_list, path, errors.ValidationError.TypeMismatch, "unsupported type", null);
    return null;
}

/// Parse a zigantic validated type from JSON.
fn parseZiganticType(
    comptime T: type,
    json_value: std.json.Value,
    allocator: std.mem.Allocator,
    error_list: *errors.ErrorList,
    path: []const u8,
) !?T {
    const zigantic_type = T.zigantic_type;

    // String types (string, email, url, regex)
    if (zigantic_type == .string or zigantic_type == .email or zigantic_type == .url or zigantic_type == .regex) {
        const str = switch (json_value) {
            .string => |s| s,
            else => {
                try addError(error_list, path, errors.ValidationError.TypeMismatch, "expected string", null);
                return null;
            },
        };

        return T.init(str) catch |err| {
            const msg = getValidationMessage(T, err);
            try addError(error_list, path, err, msg, str);
            return null;
        };
    }

    // Integer types (int, uint)
    if (zigantic_type == .int or zigantic_type == .uint) {
        const val = switch (json_value) {
            .integer => |i| i,
            else => {
                try addError(error_list, path, errors.ValidationError.InvalidInteger, "expected integer", null);
                return null;
            },
        };

        const IntType = T.IntType;
        const casted = std.math.cast(IntType, val) orelse {
            try addError(error_list, path, errors.ValidationError.TooLarge, "integer out of range", null);
            return null;
        };

        return T.init(casted) catch |err| {
            const msg = getValidationMessage(T, err);
            var buf: [32]u8 = undefined;
            const val_str = std.fmt.bufPrint(&buf, "{d}", .{val}) catch "?";
            try addError(error_list, path, err, msg, val_str);
            return null;
        };
    }

    // List type
    if (zigantic_type == .list) {
        const arr = switch (json_value) {
            .array => |a| a,
            else => {
                try addError(error_list, path, errors.ValidationError.InvalidArray, "expected array", null);
                return null;
            },
        };

        const ItemType = T.ItemType;
        var items = try allocator.alloc(ItemType, arr.items.len);
        var valid_count: usize = 0;

        for (arr.items, 0..) |item, i| {
            var item_path_buf: [256]u8 = undefined;
            const item_path = std.fmt.bufPrint(&item_path_buf, "{s}[{d}]", .{ path, i }) catch path;

            if (try parseValue(ItemType, item, allocator, error_list, item_path)) |parsed| {
                items[valid_count] = parsed;
                valid_count += 1;
            }
        }

        if (valid_count != arr.items.len) {
            return null; // Some items failed validation
        }

        return T.init(items[0..valid_count]) catch |err| {
            const msg = getValidationMessage(T, err);
            try addError(error_list, path, err, msg, null);
            return null;
        };
    }

    // Default type
    if (zigantic_type == .default) {
        const ValueType = T.ValueType;
        if (json_value == .null) {
            return T.initDefault();
        }
        const inner = try parseValue(ValueType, json_value, allocator, error_list, path) orelse return null;
        return T.init(inner);
    }

    // Custom type
    if (zigantic_type == .custom) {
        const ValueType = T.ValueType;
        const inner = try parseValue(ValueType, json_value, allocator, error_list, path) orelse return null;
        return T.init(inner) catch |err| {
            const msg = getValidationMessage(T, err);
            try addError(error_list, path, err, msg, null);
            return null;
        };
    }

    // Unsupported zigantic type
    @compileError("Unknown zigantic type");
}

/// Parse a struct from JSON.
fn parseStruct(
    comptime T: type,
    json_value: std.json.Value,
    allocator: std.mem.Allocator,
    error_list: *errors.ErrorList,
    path: []const u8,
) !?T {
    const obj = switch (json_value) {
        .object => |o| o,
        else => {
            try addError(error_list, path, errors.ValidationError.InvalidObject, "expected object", null);
            return null;
        },
    };

    const info = @typeInfo(T).@"struct";
    var result: T = undefined;
    var has_errors = false;

    inline for (info.fields) |field| {
        // Build field path at runtime using a buffer
        var field_path_buf: [512]u8 = undefined;
        const field_path = if (path.len > 0)
            std.fmt.bufPrint(&field_path_buf, "{s}.{s}", .{ path, field.name }) catch field.name
        else
            field.name;

        if (obj.get(field.name)) |field_value| {
            if (try parseValue(field.type, field_value, allocator, error_list, field_path)) |parsed| {
                @field(result, field.name) = parsed;
            } else {
                has_errors = true;
            }
        } else {
            // Field is missing from JSON
            if (handleMissingField(T, field, &result)) |_| {
                // Field was handled (has default or is optional)
            } else |_| {
                // Build error message at runtime
                var msg_buf: [256]u8 = undefined;
                const msg = std.fmt.bufPrint(&msg_buf, "{s} is required", .{field.name}) catch "field is required";
                try addError(error_list, field_path, errors.ValidationError.MissingField, msg, null);
                has_errors = true;
            }
        }
    }

    if (has_errors) {
        return null;
    }

    return result;
}

/// Handle a missing field in a struct.
fn handleMissingField(comptime T: type, comptime field: std.builtin.Type.StructField, result: *T) !void {
    const FieldType = field.type;
    const field_info = @typeInfo(FieldType);

    // Check if it's an optional type
    if (field_info == .optional) {
        @field(result, field.name) = null;
        return;
    }

    // Check if it's a zigantic Default type (must be a struct first)
    if (field_info == .@"struct") {
        if (@hasDecl(FieldType, "zigantic_type") and FieldType.zigantic_type == .default) {
            @field(result, field.name) = FieldType.initDefault();
            return;
        }
    }

    // Check if struct has a default value
    if (field.default_value_ptr) |ptr| {
        const default: *const FieldType = @ptrCast(@alignCast(ptr));
        @field(result, field.name) = default.*;
        return;
    }

    return error.MissingField;
}

/// Parse a slice from JSON.
fn parseSlice(
    comptime SliceType: type,
    comptime ItemType: type,
    json_value: std.json.Value,
    allocator: std.mem.Allocator,
    error_list: *errors.ErrorList,
    path: []const u8,
) !?SliceType {
    // Special case for []const u8 (strings)
    if (ItemType == u8) {
        const str = switch (json_value) {
            .string => |s| s,
            else => {
                try addError(error_list, path, errors.ValidationError.TypeMismatch, "expected string", null);
                return null;
            },
        };
        return str;
    }

    // Regular array
    const arr = switch (json_value) {
        .array => |a| a,
        else => {
            try addError(error_list, path, errors.ValidationError.InvalidArray, "expected array", null);
            return null;
        },
    };

    var items = try allocator.alloc(ItemType, arr.items.len);
    var valid_count: usize = 0;

    for (arr.items, 0..) |item, i| {
        var item_path_buf: [256]u8 = undefined;
        const item_path = std.fmt.bufPrint(&item_path_buf, "{s}[{d}]", .{ path, i }) catch path;

        if (try parseValue(ItemType, item, allocator, error_list, item_path)) |parsed| {
            items[valid_count] = parsed;
            valid_count += 1;
        }
    }

    if (valid_count != arr.items.len) {
        return null;
    }

    return items[0..valid_count];
}

/// Parse a primitive type from JSON.
fn parsePrimitive(
    comptime T: type,
    json_value: std.json.Value,
    error_list: *errors.ErrorList,
    path: []const u8,
) !?T {
    const info = @typeInfo(T);

    switch (info) {
        .int => {
            const val = switch (json_value) {
                .integer => |i| i,
                else => {
                    try addError(error_list, path, errors.ValidationError.InvalidInteger, "expected integer", null);
                    return null;
                },
            };
            return std.math.cast(T, val) orelse {
                try addError(error_list, path, errors.ValidationError.TooLarge, "integer out of range", null);
                return null;
            };
        },
        .float => {
            const val: T = switch (json_value) {
                .float => |f| @floatCast(f),
                .integer => |i| @floatFromInt(i),
                else => {
                    try addError(error_list, path, errors.ValidationError.InvalidNumber, "expected number", null);
                    return null;
                },
            };
            return val;
        },
        .bool => {
            return switch (json_value) {
                .bool => |b| b,
                else => {
                    try addError(error_list, path, errors.ValidationError.InvalidBoolean, "expected boolean", null);
                    return null;
                },
            };
        },
        else => {
            try addError(error_list, path, errors.ValidationError.TypeMismatch, "unsupported type", null);
            return null;
        },
    }
}

/// Add an error to the error list with proper path handling.
fn addError(
    error_list: *errors.ErrorList,
    path: []const u8,
    err: errors.ValidationError,
    message: []const u8,
    value: ?[]const u8,
) !void {
    const field_name = if (path.len > 0) path else "(root)";
    try error_list.add(field_name, err, message, value);
}

/// Get a validation message for a zigantic type error.
fn getValidationMessage(comptime T: type, err: errors.ValidationError) []const u8 {
    return switch (err) {
        error.TooShort => if (@hasDecl(T, "min"))
            std.fmt.comptimePrint("must be at least {d} characters", .{T.min})
        else
            "too short",
        error.TooLong => if (@hasDecl(T, "max"))
            std.fmt.comptimePrint("must be at most {d} characters", .{T.max})
        else
            "too long",
        error.TooSmall => if (@hasDecl(T, "min"))
            std.fmt.comptimePrint("must be >= {d}", .{T.min})
        else
            "too small",
        error.TooLarge => if (@hasDecl(T, "max"))
            std.fmt.comptimePrint("must be <= {d}", .{T.max})
        else
            "too large",
        error.InvalidEmail => "must be a valid email address",
        error.InvalidUrl => "must be a valid URL",
        error.PatternMismatch => if (@hasDecl(T, "regex_pattern"))
            std.fmt.comptimePrint("must match pattern: {s}", .{T.regex_pattern})
        else
            "does not match required pattern",
        error.TooFewItems => if (@hasDecl(T, "min"))
            std.fmt.comptimePrint("must have at least {d} items", .{T.min})
        else
            "too few items",
        error.TooManyItems => if (@hasDecl(T, "max"))
            std.fmt.comptimePrint("must have at most {d} items", .{T.max})
        else
            "too many items",
        error.CustomValidationFailed => "failed custom validation",
        else => "validation failed",
    };
}

// ============================================================================
// Serialization (toJson)
// ============================================================================

/// Serialize a value to JSON string.
pub fn toJson(value: anytype, allocator: std.mem.Allocator) ![]const u8 {
    return toJsonInternal(value, allocator, false);
}

/// Serialize a value to pretty-printed JSON string.
pub fn toJsonPretty(value: anytype, allocator: std.mem.Allocator) ![]const u8 {
    return toJsonInternal(value, allocator, true);
}

fn toJsonInternal(value: anytype, allocator: std.mem.Allocator, pretty: bool) ![]const u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(allocator);

    try writeJson(@TypeOf(value), value, &buffer, allocator, 0, pretty);

    return buffer.toOwnedSlice(allocator);
}

fn writeJson(
    comptime T: type,
    value: T,
    buffer: *std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,
    depth: usize,
    pretty: bool,
) !void {
    const info = @typeInfo(T);

    // Handle optionals first
    if (info == .optional) {
        if (value) |v| {
            try writeJson(info.optional.child, v, buffer, allocator, depth, pretty);
        } else {
            try buffer.appendSlice(allocator, "null");
        }
        return;
    }

    // Handle slices (must check before struct since slices can't have decls)
    if (info == .pointer and info.pointer.size == .slice) {
        // String slice
        if (info.pointer.child == u8) {
            try writeJsonString(value, buffer, allocator);
            return;
        }

        // Array slice
        try buffer.append(allocator, '[');
        for (value, 0..) |item, i| {
            if (i > 0) {
                try buffer.append(allocator, ',');
                if (pretty) try buffer.append(allocator, ' ');
            }
            try writeJson(@TypeOf(item), item, buffer, allocator, depth + 1, pretty);
        }
        try buffer.append(allocator, ']');
        return;
    }

    // Handle primitives
    switch (info) {
        .int => {
            var int_buf: [32]u8 = undefined;
            const int_str = std.fmt.bufPrint(&int_buf, "{d}", .{value}) catch return error.OutOfMemory;
            try buffer.appendSlice(allocator, int_str);
            return;
        },
        .float => {
            var float_buf: [64]u8 = undefined;
            const float_str = std.fmt.bufPrint(&float_buf, "{d}", .{value}) catch return error.OutOfMemory;
            try buffer.appendSlice(allocator, float_str);
            return;
        },
        .bool => {
            try buffer.appendSlice(allocator, if (value) "true" else "false");
            return;
        },
        else => {},
    }

    // Handle structs - check for zigantic types first
    if (info == .@"struct") {
        if (@hasDecl(T, "zigantic_type")) {
            const inner = value.get();
            try writeJson(@TypeOf(inner), inner, buffer, allocator, depth, pretty);
            return;
        }

        // Regular struct
        try buffer.append(allocator, '{');
        if (pretty) try buffer.append(allocator, '\n');

        const fields = info.@"struct".fields;
        var first = true;

        inline for (fields) |field| {
            if (!first) {
                try buffer.append(allocator, ',');
                if (pretty) try buffer.append(allocator, '\n');
            }
            first = false;

            if (pretty) {
                try buffer.appendNTimes(allocator, ' ', (depth + 1) * 2);
            }

            try writeJsonString(field.name, buffer, allocator);
            try buffer.append(allocator, ':');
            if (pretty) try buffer.append(allocator, ' ');

            try writeJson(field.type, @field(value, field.name), buffer, allocator, depth + 1, pretty);
        }

        if (pretty) {
            try buffer.append(allocator, '\n');
            try buffer.appendNTimes(allocator, ' ', depth * 2);
        }
        try buffer.append(allocator, '}');
        return;
    }

    // Fallback - write null for unknown types
    try buffer.appendSlice(allocator, "null");
}

fn writeJsonString(str: []const u8, buffer: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) !void {
    try buffer.append(allocator, '"');

    for (str) |c| {
        switch (c) {
            '"' => try buffer.appendSlice(allocator, "\\\""),
            '\\' => try buffer.appendSlice(allocator, "\\\\"),
            '\n' => try buffer.appendSlice(allocator, "\\n"),
            '\r' => try buffer.appendSlice(allocator, "\\r"),
            '\t' => try buffer.appendSlice(allocator, "\\t"),
            else => {
                if (c < 0x20) {
                    try buffer.appendSlice(allocator, "\\u00");
                    const hex = "0123456789abcdef";
                    try buffer.append(allocator, hex[c >> 4]);
                    try buffer.append(allocator, hex[c & 0xf]);
                } else {
                    try buffer.append(allocator, c);
                }
            },
        }
    }

    try buffer.append(allocator, '"');
}

// ============================================================================
// Tests
// ============================================================================

test "fromJson - simple struct" {
    const allocator = std.testing.allocator;

    const User = struct {
        name: []const u8,
        age: i32,
        active: bool,
    };

    const json_str =
        \\{"name": "Alice", "age": 30, "active": true}
    ;

    var result = try fromJson(User, json_str, allocator);
    defer result.deinit();

    try std.testing.expect(result.isValid());
    const user = result.value.?;
    try std.testing.expectEqualStrings("Alice", user.name);
    try std.testing.expectEqual(@as(i32, 30), user.age);
    try std.testing.expect(user.active);
}

test "fromJson - with validation types" {
    const allocator = std.testing.allocator;
    const z = @import("zigantic.zig");

    const User = struct {
        name: z.String(1, 50),
        age: z.Int(i32, 18, 120),
    };

    const json_str =
        \\{"name": "Bob", "age": 25}
    ;

    var result = try fromJson(User, json_str, allocator);
    defer result.deinit();

    try std.testing.expect(result.isValid());
    const user = result.value.?;
    try std.testing.expectEqualStrings("Bob", user.name.get());
    try std.testing.expectEqual(@as(i32, 25), user.age.get());
}

test "fromJson - validation error" {
    const allocator = std.testing.allocator;
    const z = @import("zigantic.zig");

    const User = struct {
        age: z.Int(i32, 18, 120),
    };

    const json_str =
        \\{"age": 12}
    ;

    var result = try fromJson(User, json_str, allocator);
    defer result.deinit();

    try std.testing.expect(!result.isValid());
    try std.testing.expect(result.error_list.hasErrors());
}

test "fromJson - optional fields" {
    const allocator = std.testing.allocator;

    const User = struct {
        name: []const u8,
        nickname: ?[]const u8,
    };

    const json_str =
        \\{"name": "Charlie"}
    ;

    var result = try fromJson(User, json_str, allocator);
    defer result.deinit();

    try std.testing.expect(result.isValid());
    const user = result.value.?;
    try std.testing.expectEqualStrings("Charlie", user.name);
    try std.testing.expect(user.nickname == null);
}

test "fromJson - nested struct" {
    const allocator = std.testing.allocator;

    const Address = struct {
        street: []const u8,
        city: []const u8,
    };

    const User = struct {
        name: []const u8,
        address: Address,
    };

    const json_str =
        \\{"name": "Diana", "address": {"street": "123 Main St", "city": "NYC"}}
    ;

    var result = try fromJson(User, json_str, allocator);
    defer result.deinit();

    try std.testing.expect(result.isValid());
    const user = result.value.?;
    try std.testing.expectEqualStrings("Diana", user.name);
    try std.testing.expectEqualStrings("123 Main St", user.address.street);
    try std.testing.expectEqualStrings("NYC", user.address.city);
}

test "fromJson - default values" {
    const allocator = std.testing.allocator;
    const z = @import("zigantic.zig");

    const User = struct {
        name: []const u8,
        role: z.Default([]const u8, "user"),
    };

    const json_str =
        \\{"name": "Eve"}
    ;

    var result = try fromJson(User, json_str, allocator);
    defer result.deinit();

    try std.testing.expect(result.isValid());
    const user = result.value.?;
    try std.testing.expectEqualStrings("Eve", user.name);
    try std.testing.expectEqualStrings("user", user.role.get());
}

test "toJson - simple struct" {
    const allocator = std.testing.allocator;

    const User = struct {
        name: []const u8,
        age: i32,
        active: bool,
    };

    const user = User{
        .name = "Frank",
        .age = 35,
        .active = false,
    };

    const json_str = try toJson(user, allocator);
    defer allocator.free(json_str);

    // Verify it's valid JSON
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Frank", parsed.value.object.get("name").?.string);
    try std.testing.expectEqual(@as(i64, 35), parsed.value.object.get("age").?.integer);
    try std.testing.expect(!parsed.value.object.get("active").?.bool);
}

test "toJson - with zigantic types" {
    const allocator = std.testing.allocator;
    const z = @import("zigantic.zig");

    const User = struct {
        name: z.String(1, 50),
        age: z.Int(i32, 18, 120),
    };

    const user = User{
        .name = try z.String(1, 50).init("Grace"),
        .age = try z.Int(i32, 18, 120).init(28),
    };

    const json_str = try toJson(user, allocator);
    defer allocator.free(json_str);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Grace", parsed.value.object.get("name").?.string);
    try std.testing.expectEqual(@as(i64, 28), parsed.value.object.get("age").?.integer);
}

test "toJsonPretty" {
    const allocator = std.testing.allocator;

    const User = struct {
        name: []const u8,
        age: i32,
    };

    const user = User{
        .name = "Henry",
        .age = 40,
    };

    const json_str = try toJsonPretty(user, allocator);
    defer allocator.free(json_str);

    // Verify it contains newlines (pretty printed)
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\n") != null);
}
