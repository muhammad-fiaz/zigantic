//! # Validation Error Types
//!
//! Comprehensive error handling for validation.

const std = @import("std");

pub const ValidationError = error{
    // String errors
    TooShort,
    TooLong,
    MustBeLowercase,
    MustBeUppercase,
    InvalidFormat,
    EmptyString,
    WeakPassword,

    // Number errors
    TooSmall,
    TooLarge,
    InvalidNumber,
    NotPositive,
    NotNegative,
    NotZero,
    DivisionByZero,
    MustBeEven,
    MustBeOdd,
    NotMultiple,
    OutOfRange,
    NotInStep,

    // Type errors
    TypeMismatch,
    InvalidInteger,
    InvalidBoolean,
    InvalidArray,
    InvalidObject,
    InvalidString,

    // Field errors
    MissingField,
    UnknownField,
    DuplicateField,

    // Format errors
    InvalidEmail,
    InvalidUrl,
    InvalidUuid,
    InvalidIpv4,
    InvalidIpv6,
    InvalidPhoneNumber,
    InvalidCreditCard,
    InvalidDate,
    InvalidTime,
    PatternMismatch,
    LiteralMismatch,
    NotInAllowedValues,
    MustBeHttps,
    WrongLength,

    // Collection errors
    TooFewItems,
    TooManyItems,
    DuplicateItem,
    EmptyCollection,

    // Custom/other
    CustomValidationFailed,
    InvalidJson,
    NestedError,
    ValidationFailed,
    ParseError,
};

pub const FieldError = struct {
    field: []const u8,
    message: []const u8,
    error_type: ValidationError,
    value: ?[]const u8 = null,
    code: ?[]const u8 = null,

    pub fn format(self: FieldError, allocator: std.mem.Allocator) ![]const u8 {
        if (self.value) |v| {
            return std.fmt.allocPrint(allocator, "{s}: {s} (got: {s})", .{ self.field, self.message, v });
        }
        return std.fmt.allocPrint(allocator, "{s}: {s}", .{ self.field, self.message });
    }

    pub fn toJson(self: FieldError, allocator: std.mem.Allocator) ![]const u8 {
        if (self.value) |v| {
            return std.fmt.allocPrint(allocator, "{{\"field\":\"{s}\",\"message\":\"{s}\",\"value\":\"{s}\"}}", .{ self.field, self.message, v });
        }
        return std.fmt.allocPrint(allocator, "{{\"field\":\"{s}\",\"message\":\"{s}\"}}", .{ self.field, self.message });
    }
};

pub const ErrorList = struct {
    errors: std.ArrayListUnmanaged(FieldError),
    allocator: std.mem.Allocator,
    max_errors: ?usize = null,

    pub fn init(allocator: std.mem.Allocator) ErrorList {
        return .{ .errors = .{}, .allocator = allocator };
    }

    pub fn initWithMax(allocator: std.mem.Allocator, max: usize) ErrorList {
        return .{ .errors = .{}, .allocator = allocator, .max_errors = max };
    }

    pub fn deinit(self: *ErrorList) void {
        for (self.errors.items) |err| {
            self.allocator.free(err.field);
            self.allocator.free(err.message);
            if (err.value) |v| self.allocator.free(v);
            if (err.code) |c| self.allocator.free(c);
        }
        self.errors.deinit(self.allocator);
    }

    pub fn add(self: *ErrorList, field: []const u8, error_type: ValidationError, message: []const u8, value: ?[]const u8) !void {
        if (self.max_errors) |max| {
            if (self.errors.items.len >= max) return;
        }
        const field_copy = try self.allocator.dupe(u8, field);
        errdefer self.allocator.free(field_copy);
        const message_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(message_copy);
        const value_copy = if (value) |v| try self.allocator.dupe(u8, v) else null;
        try self.errors.append(self.allocator, .{ .field = field_copy, .message = message_copy, .error_type = error_type, .value = value_copy });
    }

    pub fn addWithCode(self: *ErrorList, field: []const u8, error_type: ValidationError, message: []const u8, value: ?[]const u8, code: []const u8) !void {
        if (self.max_errors) |max| {
            if (self.errors.items.len >= max) return;
        }
        const field_copy = try self.allocator.dupe(u8, field);
        errdefer self.allocator.free(field_copy);
        const message_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(message_copy);
        const value_copy = if (value) |v| try self.allocator.dupe(u8, v) else null;
        const code_copy = try self.allocator.dupe(u8, code);
        try self.errors.append(self.allocator, .{ .field = field_copy, .message = message_copy, .error_type = error_type, .value = value_copy, .code = code_copy });
    }

    pub fn addWithPath(self: *ErrorList, parent: []const u8, field: []const u8, error_type: ValidationError, message: []const u8, value: ?[]const u8) !void {
        const full_path = if (parent.len > 0) try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ parent, field }) else try self.allocator.dupe(u8, field);
        errdefer self.allocator.free(full_path);
        const message_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(message_copy);
        const value_copy = if (value) |v| try self.allocator.dupe(u8, v) else null;
        try self.errors.append(self.allocator, .{ .field = full_path, .message = message_copy, .error_type = error_type, .value = value_copy });
    }

    pub fn addIndexed(self: *ErrorList, field: []const u8, index: usize, error_type: ValidationError, message: []const u8, value: ?[]const u8) !void {
        const indexed_path = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ field, index });
        errdefer self.allocator.free(indexed_path);
        const message_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(message_copy);
        const value_copy = if (value) |v| try self.allocator.dupe(u8, v) else null;
        try self.errors.append(self.allocator, .{ .field = indexed_path, .message = message_copy, .error_type = error_type, .value = value_copy });
    }

    pub fn hasErrors(self: ErrorList) bool {
        return self.errors.items.len > 0;
    }
    pub fn count(self: ErrorList) usize {
        return self.errors.items.len;
    }

    pub fn clear(self: *ErrorList) void {
        for (self.errors.items) |err| {
            self.allocator.free(err.field);
            self.allocator.free(err.message);
            if (err.value) |v| self.allocator.free(v);
            if (err.code) |c| self.allocator.free(c);
        }
        self.errors.clearRetainingCapacity();
    }

    pub fn first(self: ErrorList) ?FieldError {
        return if (self.errors.items.len > 0) self.errors.items[0] else null;
    }
    pub fn last(self: ErrorList) ?FieldError {
        return if (self.errors.items.len > 0) self.errors.items[self.errors.items.len - 1] else null;
    }

    pub fn formatAll(self: ErrorList, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);
        for (self.errors.items) |err| {
            try buffer.appendSlice(allocator, err.field);
            try buffer.appendSlice(allocator, ": ");
            try buffer.appendSlice(allocator, err.message);
            if (err.value) |v| {
                try buffer.appendSlice(allocator, " (got: ");
                try buffer.appendSlice(allocator, v);
                try buffer.append(allocator, ')');
            }
            try buffer.append(allocator, '\n');
        }
        return try allocator.dupe(u8, buffer.items);
    }

    pub fn toJsonArray(self: ErrorList, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);
        try buffer.append(allocator, '[');
        for (self.errors.items, 0..) |err, i| {
            const json = try err.toJson(allocator);
            defer allocator.free(json);
            try buffer.appendSlice(allocator, json);
            if (i < self.errors.items.len - 1) try buffer.append(allocator, ',');
        }
        try buffer.append(allocator, ']');
        return try allocator.dupe(u8, buffer.items);
    }

    pub fn containsField(self: ErrorList, field: []const u8) bool {
        for (self.errors.items) |err| {
            if (std.mem.eql(u8, err.field, field)) return true;
        }
        return false;
    }

    pub fn containsErrorType(self: ErrorList, error_type: ValidationError) bool {
        for (self.errors.items) |err| {
            if (err.error_type == error_type) return true;
        }
        return false;
    }

    pub fn getErrorsForField(self: ErrorList, field: []const u8, allocator: std.mem.Allocator) ![]FieldError {
        var result = std.ArrayList(FieldError).init(allocator);
        for (self.errors.items) |err| {
            if (std.mem.eql(u8, err.field, field)) try result.append(err);
        }
        return result.toOwnedSlice();
    }

    pub fn merge(self: *ErrorList, other: ErrorList) !void {
        for (other.errors.items) |err| {
            try self.add(err.field, err.error_type, err.message, err.value);
        }
    }
};

pub fn errorMessage(err: ValidationError) []const u8 {
    return switch (err) {
        error.TooShort => "value is too short",
        error.TooLong => "value is too long",
        error.TooSmall => "value is too small",
        error.TooLarge => "value is too large",
        error.InvalidEmail => "must be a valid email address",
        error.InvalidUrl => "must be a valid URL",
        error.InvalidUuid => "must be a valid UUID",
        error.InvalidIpv4 => "must be a valid IPv4 address",
        error.InvalidIpv6 => "must be a valid IPv6 address",
        error.MissingField => "field is required",
        error.TypeMismatch => "wrong type",
        error.PatternMismatch => "does not match pattern",
        error.TooFewItems => "too few items",
        error.TooManyItems => "too many items",
        error.DuplicateItem => "duplicate item found",
        error.CustomValidationFailed => "validation failed",
        error.MustBeLowercase => "must be lowercase",
        error.MustBeUppercase => "must be uppercase",
        error.LiteralMismatch => "does not match expected value",
        error.NotInAllowedValues => "not in allowed values",
        error.EmptyString => "cannot be empty",
        error.EmptyCollection => "cannot be empty",
        error.InvalidFormat => "invalid format",
        error.WeakPassword => "password is too weak",
        error.MustBeEven => "must be an even number",
        error.MustBeOdd => "must be an odd number",
        error.NotMultiple => "must be a multiple of the divisor",
        error.OutOfRange => "value is out of range",
        error.NotInStep => "value must be in step increments",
        error.MustBeHttps => "must be HTTPS",
        error.WrongLength => "wrong length",
        error.InvalidPhoneNumber => "invalid phone number",
        error.InvalidCreditCard => "invalid credit card number",
        else => "validation error",
    };
}

pub fn errorCode(err: ValidationError) []const u8 {
    return switch (err) {
        error.TooShort => "E001",
        error.TooLong => "E002",
        error.TooSmall => "E003",
        error.TooLarge => "E004",
        error.InvalidEmail => "E010",
        error.InvalidUrl => "E011",
        error.MissingField => "E020",
        error.TypeMismatch => "E021",
        error.CustomValidationFailed => "E099",
        else => "E000",
    };
}

test "ErrorList add single" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("name", error.TooShort, "too short", null);
    try std.testing.expect(errors.hasErrors());
    try std.testing.expectEqual(@as(usize, 1), errors.count());
}

test "ErrorList add multiple" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("name", error.TooShort, "too short", null);
    try errors.add("age", error.TooSmall, "too small", "10");
    try std.testing.expectEqual(@as(usize, 2), errors.count());
}

test "ErrorList with path" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.addWithPath("user", "name", error.TooShort, "too short", null);
    try std.testing.expectEqualStrings("user.name", errors.errors.items[0].field);
}

test "ErrorList indexed" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.addIndexed("items", 2, error.TooShort, "too short", null);
    try std.testing.expectEqualStrings("items[2]", errors.errors.items[0].field);
}

test "ErrorList first and last" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("first", error.TooShort, "first error", null);
    try errors.add("last", error.TooLong, "last error", null);
    try std.testing.expectEqualStrings("first", errors.first().?.field);
    try std.testing.expectEqualStrings("last", errors.last().?.field);
}

test "ErrorList clear" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("name", error.TooShort, "too short", null);
    errors.clear();
    try std.testing.expect(!errors.hasErrors());
}

test "ErrorList containsField" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("name", error.TooShort, "too short", null);
    try std.testing.expect(errors.containsField("name"));
    try std.testing.expect(!errors.containsField("age"));
}

test "ErrorList containsErrorType" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("name", error.TooShort, "too short", null);
    try std.testing.expect(errors.containsErrorType(error.TooShort));
    try std.testing.expect(!errors.containsErrorType(error.TooLong));
}

test "ErrorList formatAll" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("name", error.TooShort, "too short", null);
    const formatted = try errors.formatAll(std.testing.allocator);
    defer std.testing.allocator.free(formatted);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "name: too short") != null);
}

test "ErrorList toJsonArray" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("name", error.TooShort, "too short", null);
    const json = try errors.toJsonArray(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"field\":\"name\"") != null);
}

test "ErrorList initWithMax" {
    var errors = ErrorList.initWithMax(std.testing.allocator, 2);
    defer errors.deinit();
    try errors.add("a", error.TooShort, "a", null);
    try errors.add("b", error.TooShort, "b", null);
    try errors.add("c", error.TooShort, "c", null); // Should be ignored
    try std.testing.expectEqual(@as(usize, 2), errors.count());
}

test "ErrorList addWithCode" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.addWithCode("name", error.TooShort, "too short", null, "E001");
    try std.testing.expectEqualStrings("E001", errors.errors.items[0].code.?);
}

test "FieldError format" {
    const err = FieldError{ .field = "name", .message = "too short", .error_type = error.TooShort, .value = null };
    const formatted = try err.format(std.testing.allocator);
    defer std.testing.allocator.free(formatted);
    try std.testing.expectEqualStrings("name: too short", formatted);
}

test "FieldError toJson" {
    const err = FieldError{ .field = "name", .message = "too short", .error_type = error.TooShort, .value = null };
    const json = try err.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"field\":\"name\"") != null);
}

test "errorMessage" {
    try std.testing.expectEqualStrings("value is too short", errorMessage(error.TooShort));
    try std.testing.expectEqualStrings("password is too weak", errorMessage(error.WeakPassword));
}

test "errorCode" {
    try std.testing.expectEqualStrings("E001", errorCode(error.TooShort));
    try std.testing.expectEqualStrings("E010", errorCode(error.InvalidEmail));
}
