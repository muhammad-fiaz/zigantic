//! # Validation Error Types
//!
//! Comprehensive error handling for validation.

const std = @import("std");
const color = @import("color.zig");

pub const Color = color.Color;

/// Presentation details for a validation error type.
///
/// Contains the human-readable message, unique error code, and
/// default terminal color for a specific `ValidationError` variant.
/// Used by `errorPresentation()` to look up display information.
pub const ErrorPresentation = struct {
    /// Human-readable error message (e.g., "value is too short").
    message: []const u8,
    /// Unique error code for programmatic identification (e.g., "E001").
    code: []const u8,
    /// Default ANSI color for terminal output.
    color: Color,
};

/// Function pointer type for custom message formatters.
///
/// When set via `Config.validation_message_formatter`, this function
/// is called for each validation error to produce a custom message.
/// Return the default message from `errorPresentation(err).message`
/// for errors you don't want to customize.
pub const MessageFormatter = ?*const fn (ValidationError) []const u8;

/// Per-error-type custom message configuration.
///
/// Pass a partial struct to `Stringf`, `Intf`, etc. to override
/// default error messages. Null fields use built-in defaults.
///
/// Example:
/// ```zig
/// const Name = Stringf(1, 50, .{
///     .too_short = "name is required",
///     .too_long = "name must be 50 chars or fewer",
/// });
/// ```
pub const ValidationMessageConfig = struct {
    too_short: ?[]const u8 = null,
    too_long: ?[]const u8 = null,
    too_small: ?[]const u8 = null,
    too_large: ?[]const u8 = null,
    invalid_format: ?[]const u8 = null,
    invalid_email: ?[]const u8 = null,
    invalid_url: ?[]const u8 = null,
    invalid_uuid: ?[]const u8 = null,
    invalid_ipv4: ?[]const u8 = null,
    invalid_ipv6: ?[]const u8 = null,
    invalid_phone: ?[]const u8 = null,
    invalid_credit_card: ?[]const u8 = null,
    weak_password: ?[]const u8 = null,
    must_be_even: ?[]const u8 = null,
    must_be_odd: ?[]const u8 = null,
    not_multiple: ?[]const u8 = null,
    must_be_https: ?[]const u8 = null,
    out_of_range: ?[]const u8 = null,
    not_in_step: ?[]const u8 = null,
    pattern_mismatch: ?[]const u8 = null,
    literal_mismatch: ?[]const u8 = null,
    not_in_allowed: ?[]const u8 = null,
    custom_validation_failed: ?[]const u8 = null,
    too_few_items: ?[]const u8 = null,
    too_many_items: ?[]const u8 = null,
    empty_string: ?[]const u8 = null,
    wrong_length: ?[]const u8 = null,
    invalid_number: ?[]const u8 = null,
    type_mismatch: ?[]const u8 = null,
    missing_field: ?[]const u8 = null,
    must_be_lowercase: ?[]const u8 = null,
    must_be_uppercase: ?[]const u8 = null,
    not_positive: ?[]const u8 = null,
    not_negative: ?[]const u8 = null,
    not_zero: ?[]const u8 = null,
};

/// Per-validation-error color overrides. Each field is optional (null = use default).
pub const ColorOverrides = struct {
    too_short: ?Color = null,
    too_long: ?Color = null,
    too_small: ?Color = null,
    too_large: ?Color = null,
    invalid_format: ?Color = null,
    invalid_email: ?Color = null,
    invalid_url: ?Color = null,
    invalid_uuid: ?Color = null,
    invalid_ipv4: ?Color = null,
    invalid_ipv6: ?Color = null,
    invalid_phone: ?Color = null,
    invalid_credit_card: ?Color = null,
    weak_password: ?Color = null,
    must_be_even: ?Color = null,
    must_be_odd: ?Color = null,
    not_multiple: ?Color = null,
    must_be_https: ?Color = null,
    out_of_range: ?Color = null,
    not_in_step: ?Color = null,
    pattern_mismatch: ?Color = null,
    literal_mismatch: ?Color = null,
    not_in_allowed: ?Color = null,
    custom_validation_failed: ?Color = null,
    too_few_items: ?Color = null,
    too_many_items: ?Color = null,
    empty_string: ?Color = null,
    wrong_length: ?Color = null,
    invalid_number: ?Color = null,
    type_mismatch: ?Color = null,
    missing_field: ?Color = null,
    must_be_lowercase: ?Color = null,
    must_be_uppercase: ?Color = null,
    not_positive: ?Color = null,
    not_negative: ?Color = null,
    not_zero: ?Color = null,
    invalid_json: ?Color = null,
    nested_error: ?Color = null,
    validation_failed: ?Color = null,
    parse_error: ?Color = null,
    invalid_integer: ?Color = null,
    invalid_boolean: ?Color = null,
    invalid_array: ?Color = null,
    invalid_object: ?Color = null,
    invalid_string: ?Color = null,
    unknown_field: ?Color = null,
    duplicate_field: ?Color = null,
    invalid_date: ?Color = null,
    invalid_time: ?Color = null,
    duplicate_item: ?Color = null,
    empty_collection: ?Color = null,
};

fn overrideField(comptime T: type, comptime field: []const u8, overrides: T) ?Color {
    if (!comptime @hasField(T, field)) return null;
    return @field(overrides, field);
}

fn overrideColor(err: ValidationError, overrides: anytype) ?Color {
    const T = @TypeOf(overrides);
    return switch (err) {
        error.TooShort => overrideField(T, "too_short", overrides),
        error.TooLong => overrideField(T, "too_long", overrides),
        error.TooSmall => overrideField(T, "too_small", overrides),
        error.TooLarge => overrideField(T, "too_large", overrides),
        error.InvalidFormat => overrideField(T, "invalid_format", overrides),
        error.InvalidEmail => overrideField(T, "invalid_email", overrides),
        error.InvalidUrl => overrideField(T, "invalid_url", overrides),
        error.InvalidUuid => overrideField(T, "invalid_uuid", overrides),
        error.InvalidIpv4 => overrideField(T, "invalid_ipv4", overrides),
        error.InvalidIpv6 => overrideField(T, "invalid_ipv6", overrides),
        error.InvalidPhoneNumber => overrideField(T, "invalid_phone", overrides),
        error.InvalidCreditCard => overrideField(T, "invalid_credit_card", overrides),
        error.WeakPassword => overrideField(T, "weak_password", overrides),
        error.MustBeEven => overrideField(T, "must_be_even", overrides),
        error.MustBeOdd => overrideField(T, "must_be_odd", overrides),
        error.NotMultiple => overrideField(T, "not_multiple", overrides),
        error.MustBeHttps => overrideField(T, "must_be_https", overrides),
        error.OutOfRange => overrideField(T, "out_of_range", overrides),
        error.NotInStep => overrideField(T, "not_in_step", overrides),
        error.PatternMismatch => overrideField(T, "pattern_mismatch", overrides),
        error.LiteralMismatch => overrideField(T, "literal_mismatch", overrides),
        error.NotInAllowedValues => overrideField(T, "not_in_allowed", overrides),
        error.CustomValidationFailed => overrideField(T, "custom_validation_failed", overrides),
        error.TooFewItems => overrideField(T, "too_few_items", overrides),
        error.TooManyItems => overrideField(T, "too_many_items", overrides),
        error.EmptyString => overrideField(T, "empty_string", overrides),
        error.WrongLength => overrideField(T, "wrong_length", overrides),
        error.InvalidNumber => overrideField(T, "invalid_number", overrides),
        error.TypeMismatch => overrideField(T, "type_mismatch", overrides),
        error.MissingField => overrideField(T, "missing_field", overrides),
        error.MustBeLowercase => overrideField(T, "must_be_lowercase", overrides),
        error.MustBeUppercase => overrideField(T, "must_be_uppercase", overrides),
        error.NotPositive => overrideField(T, "not_positive", overrides),
        error.NotNegative => overrideField(T, "not_negative", overrides),
        error.NotZero => overrideField(T, "not_zero", overrides),
        else => null,
    };
}

fn msgField(comptime T: type, comptime field: []const u8, config: T) ?[]const u8 {
    if (comptime @hasField(T, field)) return @field(config, field);
    return null;
}

pub fn messageForConfig(err: ValidationError, config: anytype) ?[]const u8 {
    const T = @TypeOf(config);
    return switch (err) {
        error.TooShort => msgField(T, "too_short", config),
        error.TooLong => msgField(T, "too_long", config),
        error.TooSmall => msgField(T, "too_small", config),
        error.TooLarge => msgField(T, "too_large", config),
        error.InvalidFormat => msgField(T, "invalid_format", config),
        error.InvalidEmail => msgField(T, "invalid_email", config),
        error.InvalidUrl => msgField(T, "invalid_url", config),
        error.InvalidUuid => msgField(T, "invalid_uuid", config),
        error.InvalidIpv4 => msgField(T, "invalid_ipv4", config),
        error.InvalidIpv6 => msgField(T, "invalid_ipv6", config),
        error.InvalidPhoneNumber => msgField(T, "invalid_phone", config),
        error.InvalidCreditCard => msgField(T, "invalid_credit_card", config),
        error.WeakPassword => msgField(T, "weak_password", config),
        error.MustBeEven => msgField(T, "must_be_even", config),
        error.MustBeOdd => msgField(T, "must_be_odd", config),
        error.NotMultiple => msgField(T, "not_multiple", config),
        error.MustBeHttps => msgField(T, "must_be_https", config),
        error.OutOfRange => msgField(T, "out_of_range", config),
        error.NotInStep => msgField(T, "not_in_step", config),
        error.PatternMismatch => msgField(T, "pattern_mismatch", config),
        error.LiteralMismatch => msgField(T, "literal_mismatch", config),
        error.NotInAllowedValues => msgField(T, "not_in_allowed", config),
        error.CustomValidationFailed => msgField(T, "custom_validation_failed", config),
        error.TooFewItems => msgField(T, "too_few_items", config),
        error.TooManyItems => msgField(T, "too_many_items", config),
        error.EmptyString => msgField(T, "empty_string", config),
        error.WrongLength => msgField(T, "wrong_length", config),
        error.InvalidNumber => msgField(T, "invalid_number", config),
        error.TypeMismatch => msgField(T, "type_mismatch", config),
        error.MissingField => msgField(T, "missing_field", config),
        error.MustBeLowercase => msgField(T, "must_be_lowercase", config),
        error.MustBeUppercase => msgField(T, "must_be_uppercase", config),
        error.NotPositive => msgField(T, "not_positive", config),
        error.NotNegative => msgField(T, "not_negative", config),
        error.NotZero => msgField(T, "not_zero", config),
        else => null,
    };
}

fn ansi(value: Color) []const u8 {
    return color.ansi(value);
}

/// Returns the presentation details (message, code, color) for a validation error.
///
/// This is the single source of truth for default error messages, codes,
/// and colors. Used by formatting functions and the `messageFor` helper.
pub fn errorPresentation(err: ValidationError) ErrorPresentation {
    return switch (err) {
        error.TooShort => .{ .message = "value is too short", .code = "E001", .color = .red },
        error.TooLong => .{ .message = "value is too long", .code = "E002", .color = .red },
        error.TooSmall => .{ .message = "value is too small", .code = "E003", .color = .yellow },
        error.TooLarge => .{ .message = "value is too large", .code = "E004", .color = .yellow },
        error.NotPositive => .{ .message = "must be positive", .code = "E054", .color = .yellow },
        error.NotNegative => .{ .message = "must be negative", .code = "E055", .color = .yellow },
        error.NotZero => .{ .message = "must not be zero", .code = "E056", .color = .yellow },
        error.DivisionByZero => .{ .message = "division by zero", .code = "E057", .color = .yellow },
        error.MustBeEven => .{ .message = "must be even", .code = "E030", .color = .yellow },
        error.MustBeOdd => .{ .message = "must be odd", .code = "E031", .color = .yellow },
        error.NotMultiple => .{ .message = "must be a multiple of the divisor", .code = "E032", .color = .yellow },
        error.OutOfRange => .{ .message = "value is out of range", .code = "E034", .color = .yellow },
        error.NotInStep => .{ .message = "value must be in step increments", .code = "E035", .color = .yellow },
        error.InvalidNumber => .{ .message = "must be a valid number", .code = "E060", .color = .magenta },
        error.InvalidInteger => .{ .message = "must be a valid integer", .code = "E036", .color = .magenta },
        error.InvalidBoolean => .{ .message = "must be a valid boolean", .code = "E037", .color = .magenta },
        error.InvalidArray => .{ .message = "must be a valid array", .code = "E038", .color = .magenta },
        error.InvalidObject => .{ .message = "must be a valid object", .code = "E039", .color = .magenta },
        error.InvalidString => .{ .message = "must be a valid string", .code = "E040", .color = .magenta },
        error.TypeMismatch => .{ .message = "wrong type", .code = "E021", .color = .magenta },
        error.MissingField => .{ .message = "field is required", .code = "E020", .color = .cyan },
        error.UnknownField => .{ .message = "unknown field", .code = "E041", .color = .cyan },
        error.DuplicateField => .{ .message = "duplicate field", .code = "E042", .color = .cyan },
        error.InvalidEmail => .{ .message = "must be a valid email address", .code = "E010", .color = .blue },
        error.InvalidUrl => .{ .message = "must be a valid URL", .code = "E011", .color = .blue },
        error.InvalidUuid => .{ .message = "must be a valid UUID", .code = "E012", .color = .blue },
        error.InvalidIpv4 => .{ .message = "must be a valid IPv4 address", .code = "E013", .color = .blue },
        error.InvalidIpv6 => .{ .message = "must be a valid IPv6 address", .code = "E014", .color = .blue },
        error.InvalidPhoneNumber => .{ .message = "must be a valid phone number", .code = "E015", .color = .blue },
        error.InvalidCreditCard => .{ .message = "must be a valid credit card number", .code = "E016", .color = .blue },
        error.PatternMismatch => .{ .message = "does not match required pattern", .code = "E022", .color = .blue },
        error.MustBeLowercase => .{ .message = "must be lowercase", .code = "E023", .color = .red },
        error.MustBeUppercase => .{ .message = "must be uppercase", .code = "E024", .color = .red },
        error.WeakPassword => .{ .message = "password is too weak", .code = "E025", .color = .red },
        error.MustBeHttps => .{ .message = "must be HTTPS", .code = "E033", .color = .blue },
        error.InvalidDate => .{ .message = "must be a valid ISO date", .code = "E043", .color = .blue },
        error.InvalidTime => .{ .message = "must be a valid ISO time", .code = "E044", .color = .blue },
        error.LiteralMismatch => .{ .message = "does not match expected literal", .code = "E045", .color = .blue },
        error.NotInAllowedValues => .{ .message = "value is not allowed", .code = "E046", .color = .blue },
        error.WrongLength => .{ .message = "wrong length", .code = "E047", .color = .blue },
        error.TooFewItems => .{ .message = "too few items", .code = "E050", .color = .green },
        error.TooManyItems => .{ .message = "too many items", .code = "E051", .color = .green },
        error.DuplicateItem => .{ .message = "duplicate item found", .code = "E052", .color = .green },
        error.EmptyCollection => .{ .message = "collection cannot be empty", .code = "E053", .color = .green },
        error.CustomValidationFailed => .{ .message = "validation failed", .code = "E099", .color = .bright_red },
        error.InvalidJson => .{ .message = "invalid JSON syntax", .code = "E100", .color = .bright_red },
        error.NestedError => .{ .message = "nested validation error", .code = "E101", .color = .bright_red },
        error.ValidationFailed => .{ .message = "validation failed", .code = "E102", .color = .bright_red },
        error.ParseError => .{ .message = "failed to parse value", .code = "E103", .color = .bright_red },
        error.InvalidFormat => .{ .message = "invalid format", .code = "E058", .color = .blue },
        error.EmptyString => .{ .message = "cannot be empty", .code = "E059", .color = .red },
    };
}

/// Returns the default ANSI color for a validation error type.
pub fn errorColor(err: ValidationError) Color {
    return errorPresentation(err).color;
}

/// Returns the error message for a validation error, using a custom
/// formatter if provided, otherwise the built-in default message.
pub fn messageFor(err: ValidationError, formatter: MessageFormatter) []const u8 {
    return if (formatter) |f| f(err) else errorPresentation(err).message;
}

/// Returns the error message with a three-tier priority:
/// 1. Global formatter (if provided)
/// 2. Type-level custom message (from `ValidationMessageConfig`)
/// 3. Built-in default message
pub fn messageForWithConfig(err: ValidationError, formatter: MessageFormatter, config: anytype) []const u8 {
    if (formatter) |f| return f(err);
    if (messageForConfig(err, config)) |msg| return msg;
    return errorPresentation(err).message;
}

/// Set of all validation error types that can be returned by zigantic types.
///
/// Grouped by category: string, number, type, field, format, collection,
/// and custom/other errors.
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

/// A single validation error attached to a specific struct field.
///
/// Contains the field path, error message, error type, optional
/// invalid value, and optional error code. Provides formatting
/// methods for plain text, colored terminal, and JSON output.
pub const FieldError = struct {
    /// Dot-separated field path (e.g., "address.zip" or "items[2]").
    field: []const u8,
    /// Human-readable error message.
    message: []const u8,
    /// The validation error type that occurred.
    error_type: ValidationError,
    /// The invalid value that caused the error (if available).
    value: ?[]const u8 = null,
    /// Error code for programmatic identification (e.g., "E001").
    code: ?[]const u8 = null,

    /// Formats the error as plain text: "field: message (got: value)".
    pub fn format(self: FieldError, allocator: std.mem.Allocator) ![]const u8 {
        return self.formatWithMessage(allocator, self.message);
    }

    /// Formats the error with a custom message override.
    pub fn formatWithMessage(self: FieldError, allocator: std.mem.Allocator, message: []const u8) ![]const u8 {
        if (self.value) |v| {
            return std.fmt.allocPrint(allocator, "{s}: {s} (got: {s})", .{ self.field, message, v });
        }
        return std.fmt.allocPrint(allocator, "{s}: {s}", .{ self.field, message });
    }

    /// Formats the error with ANSI color codes using the default message.
    pub fn formatColored(self: FieldError, allocator: std.mem.Allocator) ![]const u8 {
        return self.formatColoredWithMessage(allocator, errorPresentation(self.error_type).message);
    }

    /// Formats the error with ANSI colors using a custom message.
    pub fn formatColoredWithMessage(self: FieldError, allocator: std.mem.Allocator, message: []const u8) ![]const u8 {
        return self.formatColoredWithMessageAndOverrides(allocator, message, null);
    }

    /// Formats the error with ANSI colors, custom message, and per-error color overrides.
    ///
    /// Color resolution order:
    /// 1. `overrides` parameter (if non-null and field is set)
    /// 2. Built-in default color from `errorPresentation()`
    pub fn formatColoredWithMessageAndOverrides(self: FieldError, allocator: std.mem.Allocator, message: []const u8, overrides: ?ColorOverrides) ![]const u8 {
        const color_override = if (overrides) |o| overrideColor(self.error_type, o) else null;
        const effective_color = color_override orelse errorPresentation(self.error_type).color;
        const presentation = errorPresentation(self.error_type);
        const field_color = ansi(.bright_cyan);
        const code_color = ansi(.bright_yellow);
        const message_color = ansi(effective_color);
        const value_color = ansi(.white);
        const reset = ansi(.reset);
        if (self.value) |v| {
            return std.fmt.allocPrint(allocator, "{s}{s}{s}: {s}[{s}]{s} {s}{s}{s} {s}(got: {s}){s}", .{
                field_color,
                self.field,
                reset,
                code_color,
                presentation.code,
                reset,
                message_color,
                message,
                reset,
                value_color,
                v,
                reset,
            });
        }
        return std.fmt.allocPrint(allocator, "{s}{s}{s}: {s}[{s}]{s} {s}{s}{s}{s}", .{
            field_color,
            self.field,
            reset,
            code_color,
            presentation.code,
            reset,
            message_color,
            message,
            reset,
            "",
        });
    }

    /// Serializes the error to a JSON object string.
    pub fn toJson(self: FieldError, allocator: std.mem.Allocator) ![]const u8 {
        if (self.value) |v| {
            return std.fmt.allocPrint(allocator, "{{\"field\":\"{s}\",\"message\":\"{s}\",\"value\":\"{s}\"}}", .{ self.field, self.message, v });
        }
        return std.fmt.allocPrint(allocator, "{{\"field\":\"{s}\",\"message\":\"{s}\"}}", .{ self.field, self.message });
    }
};

/// Accumulator for collecting multiple validation errors.
///
/// Used during JSON parsing and struct validation to gather all
/// errors before reporting them. Supports optional max-error limits,
/// field lookup, merging, and formatted output.
pub const ErrorList = struct {
    errors: std.ArrayList(FieldError),
    allocator: std.mem.Allocator,
    /// Maximum errors to collect (null = unlimited).
    max_errors: ?usize = null,

    /// Creates a new empty error list.
    pub fn init(allocator: std.mem.Allocator) ErrorList {
        return .{ .errors = .empty, .allocator = allocator };
    }

    /// Creates a new error list with a maximum error count.
    pub fn initWithMax(allocator: std.mem.Allocator, max: usize) ErrorList {
        return .{ .errors = .empty, .allocator = allocator, .max_errors = max };
    }

    /// Frees all allocated error data and the list itself.
    pub fn deinit(self: *ErrorList) void {
        self.freeItems();
        self.errors.deinit(self.allocator);
    }

    fn freeItems(self: *ErrorList) void {
        for (self.errors.items) |err| {
            self.allocator.free(err.field);
            self.allocator.free(err.message);
            if (err.value) |v| self.allocator.free(v);
            if (err.code) |c| self.allocator.free(c);
        }
    }

    fn addResolved(self: *ErrorList, resolved_field: []const u8, error_type: ValidationError, message: []const u8, value: ?[]const u8, code: ?[]const u8) !void {
        if (self.max_errors) |max| {
            if (self.errors.items.len >= max) return;
        }
        const field_copy = try self.allocator.dupe(u8, resolved_field);
        errdefer self.allocator.free(field_copy);
        const message_copy = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(message_copy);
        const value_copy = if (value) |v| try self.allocator.dupe(u8, v) else null;
        const code_copy = if (code) |c| try self.allocator.dupe(u8, c) else null;
        try self.errors.append(self.allocator, .{ .field = field_copy, .message = message_copy, .error_type = error_type, .value = value_copy, .code = code_copy });
    }

    /// Adds an error for a field. Respects `max_errors` limit.
    pub fn add(self: *ErrorList, field: []const u8, error_type: ValidationError, message: []const u8, value: ?[]const u8) !void {
        return self.addResolved(field, error_type, message, value, null);
    }

    /// Adds an error with an explicit error code.
    pub fn addWithCode(self: *ErrorList, field: []const u8, error_type: ValidationError, message: []const u8, value: ?[]const u8, code: []const u8) !void {
        return self.addResolved(field, error_type, message, value, code);
    }

    /// Adds an error with a nested path (e.g., "user.name" for nested structs).
    pub fn addWithPath(self: *ErrorList, parent: []const u8, field: []const u8, error_type: ValidationError, message: []const u8, value: ?[]const u8) !void {
        const full_path = if (parent.len > 0) try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ parent, field }) else try self.allocator.dupe(u8, field);
        defer self.allocator.free(full_path);
        return self.addResolved(full_path, error_type, message, value, null);
    }

    /// Adds an error with an indexed path (e.g., "items[2]" for array elements).
    pub fn addIndexed(self: *ErrorList, field: []const u8, index: usize, error_type: ValidationError, message: []const u8, value: ?[]const u8) !void {
        const indexed_path = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ field, index });
        defer self.allocator.free(indexed_path);
        return self.addResolved(indexed_path, error_type, message, value, null);
    }

    /// Returns true if any errors have been collected.
    pub fn hasErrors(self: ErrorList) bool {
        return self.errors.items.len > 0;
    }

    /// Returns the number of errors collected.
    pub fn count(self: ErrorList) usize {
        return self.errors.items.len;
    }

    /// Clears all errors and frees their allocated memory.
    pub fn clear(self: *ErrorList) void {
        self.freeItems();
        self.errors.clearRetainingCapacity();
    }

    /// Returns the first error, or null if empty.
    pub fn first(self: ErrorList) ?FieldError {
        return if (self.errors.items.len > 0) self.errors.items[0] else null;
    }

    /// Returns the last error, or null if empty.
    pub fn last(self: ErrorList) ?FieldError {
        return if (self.errors.items.len > 0) self.errors.items[self.errors.items.len - 1] else null;
    }

    /// Formats all errors as plain text (one per line).
    pub fn formatAll(self: ErrorList, allocator: std.mem.Allocator) ![]const u8 {
        return self.formatAllWith(allocator, null);
    }

    /// Formats all errors with a custom message formatter.
    pub fn formatAllWith(self: ErrorList, allocator: std.mem.Allocator, formatter: MessageFormatter) ![]const u8 {
        var buffer = std.ArrayList(u8).empty;
        defer buffer.deinit(allocator);
        for (self.errors.items) |err| {
            const msg = if (formatter) |f| messageFor(err.error_type, f) else err.message;
            const line = try err.formatWithMessage(allocator, msg);
            defer allocator.free(line);
            try buffer.appendSlice(allocator, line);
            try buffer.append(allocator, '\n');
        }
        return try allocator.dupe(u8, buffer.items);
    }

    pub fn formatAllColored(self: ErrorList, allocator: std.mem.Allocator) ![]const u8 {
        return self.formatAllColoredWith(allocator, null);
    }

    /// Formats all errors with ANSI colors and a custom message formatter.
    pub fn formatAllColoredWith(self: ErrorList, allocator: std.mem.Allocator, formatter: MessageFormatter) ![]const u8 {
        return self.formatAllColoredWithOverrides(allocator, formatter, null);
    }

    /// Formats all errors with ANSI colors, custom formatter, and per-error color overrides.
    pub fn formatAllColoredWithOverrides(self: ErrorList, allocator: std.mem.Allocator, formatter: MessageFormatter, overrides: ?ColorOverrides) ![]const u8 {
        var buffer = std.ArrayList(u8).empty;
        defer buffer.deinit(allocator);
        for (self.errors.items) |err| {
            const msg = if (formatter) |f| messageFor(err.error_type, f) else err.message;
            const line = try err.formatColoredWithMessageAndOverrides(allocator, msg, overrides);
            defer allocator.free(line);
            try buffer.appendSlice(allocator, line);
            try buffer.append(allocator, '\n');
        }
        return try allocator.dupe(u8, buffer.items);
    }

    /// Serializes all errors as a JSON array string.
    pub fn toJsonArray(self: ErrorList, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).empty;
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

    /// Returns true if any error is attached to the given field path.
    pub fn containsField(self: ErrorList, field: []const u8) bool {
        for (self.errors.items) |err| {
            if (std.mem.eql(u8, err.field, field)) return true;
        }
        return false;
    }

    /// Returns true if any error of the given type has been collected.
    pub fn containsErrorType(self: ErrorList, error_type: ValidationError) bool {
        for (self.errors.items) |err| {
            if (err.error_type == error_type) return true;
        }
        return false;
    }

    /// Returns all errors attached to a specific field path.
    pub fn getErrorsForField(self: ErrorList, field: []const u8, allocator: std.mem.Allocator) ![]FieldError {
        var result = std.ArrayList(FieldError).empty;
        for (self.errors.items) |err| {
            if (std.mem.eql(u8, err.field, field)) try result.append(allocator, err);
        }
        return result.toOwnedSlice(allocator);
    }

    /// Merges another error list into this one.
    pub fn merge(self: *ErrorList, other: ErrorList) !void {
        for (other.errors.items) |err| {
            try self.add(err.field, err.error_type, err.message, err.value);
        }
    }
};

pub fn errorMessage(err: ValidationError) []const u8 {
    return errorPresentation(err).message;
}

pub fn errorCode(err: ValidationError) []const u8 {
    return errorPresentation(err).code;
}

test "Error presentation" {
    const too_short = errorPresentation(error.TooShort);
    try std.testing.expectEqualStrings("value is too short", too_short.message);
    try std.testing.expectEqualStrings("E001", too_short.code);
    try std.testing.expect(too_short.color == .red);

    const invalid_json = errorPresentation(error.InvalidJson);
    try std.testing.expectEqualStrings("invalid JSON syntax", invalid_json.message);
    try std.testing.expectEqualStrings("E100", invalid_json.code);
    try std.testing.expect(invalid_json.color == .bright_red);
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
    try std.testing.expect(std.mem.find(u8, formatted, "name: too short") != null);
}

test "ErrorList toJsonArray" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("name", error.TooShort, "too short", null);
    const json = try errors.toJsonArray(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.find(u8, json, "\"field\":\"name\"") != null);
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
    try std.testing.expect(std.mem.find(u8, json, "\"field\":\"name\"") != null);
}

test "errorMessage" {
    try std.testing.expectEqualStrings("value is too short", errorMessage(error.TooShort));
    try std.testing.expectEqualStrings("password is too weak", errorMessage(error.WeakPassword));
}

test "errorCode" {
    try std.testing.expectEqualStrings("E001", errorCode(error.TooShort));
    try std.testing.expectEqualStrings("E010", errorCode(error.InvalidEmail));
}

test "ErrorList colored formatting" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("name", error.TooShort, "too short", "Jo");
    const colored = try errors.formatAllColored(std.testing.allocator);
    defer std.testing.allocator.free(colored);
    try std.testing.expect(std.mem.find(u8, colored, "\x1b[") != null);
}

test "ErrorList custom message formatting" {
    var errors = ErrorList.init(std.testing.allocator);
    defer errors.deinit();
    try errors.add("email", error.InvalidEmail, "must be a valid email address", "bad@");
    const custom = struct {
        fn f(err: ValidationError) []const u8 {
            return switch (err) {
                error.InvalidEmail => "please provide a valid email",
                else => errorPresentation(err).message,
            };
        }
    }.f;
    const formatted = try errors.formatAllWith(std.testing.allocator, custom);
    defer std.testing.allocator.free(formatted);
    try std.testing.expect(std.mem.find(u8, formatted, "please provide a valid email") != null);
}

test "ValidationMessageConfig - custom messages" {
    const config = ValidationMessageConfig{
        .too_short = "custom too short message",
        .too_large = "custom too large message",
    };
    try std.testing.expectEqualStrings("custom too short message", messageForConfig(error.TooShort, config).?);
    try std.testing.expectEqualStrings("custom too large message", messageForConfig(error.TooLarge, config).?);
    try std.testing.expect(messageForConfig(error.TooLong, config) == null);
}

test "ValidationMessageConfig - messageForWithConfig" {
    const config = ValidationMessageConfig{
        .invalid_email = "please enter a valid email address",
    };
    const custom_formatter = struct {
        fn f(_: ValidationError) []const u8 {
            return "from formatter";
        }
    }.f;
    try std.testing.expectEqualStrings("from formatter", messageForWithConfig(error.InvalidEmail, custom_formatter, config));
    try std.testing.expectEqualStrings("please enter a valid email address", messageForWithConfig(error.InvalidEmail, null, config));
    try std.testing.expectEqualStrings("value is too short", messageForWithConfig(error.TooShort, null, config));
}
