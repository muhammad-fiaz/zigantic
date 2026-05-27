//! zigantic - Type-safe data validation and serialization for Zig.

const std = @import("std");

pub const types = @import("types.zig");
pub const validators = @import("validators.zig");
pub const color = @import("color.zig");
pub const errors = @import("errors.zig");
pub const json = @import("json.zig");
pub const version = @import("version.zig");
pub const report = @import("report.zig");
pub const utils = @import("utils.zig");

/// Configuration options for zigantic library.
pub const Config = struct {
    /// Whether to automatically check for library updates.
    auto_update_check: bool = true,
    /// Whether to show update notifications in the log.
    show_update_notifications: bool = true,
    /// Exit the process after validation failures surfaced by the top-level helpers.
    exit_on_validation_error: bool = false,
    /// Exit the process after serialization failures surfaced by the top-level helpers.
    exit_on_serialization_error: bool = false,
    /// Optional callback for formatted validation error output.
    validation_error_callback: ?*const fn ([]const u8) void = null,
    /// Optional formatter that replaces built-in validation messages.
    validation_message_formatter: errors.MessageFormatter = null,
    /// Optional callback for formatted serialization error output.
    serialization_error_callback: ?*const fn ([]const u8) void = null,
    /// Optional formatter that replaces built-in serialization messages.
    serialization_error_formatter: ?*const fn (anyerror) []const u8 = null,
    /// Use ANSI colors when formatting validation errors for callbacks and exit handling.
    use_color_output: bool = true,
    /// Per-validation-error color overrides (null = use built-in colors).
    color_overrides: errors.ColorOverrides = .{},
    /// Maximum number of validation errors to collect per parse (null = unlimited).
    max_errors: ?usize = null,
    /// When true, reject structs with unknown JSON fields (strict deserialization).
    reject_unknown_fields: bool = false,
    /// When true, treat null values as missing (skip null optional fields).
    treat_null_as_missing: bool = false,
    /// When true, allow implicit type coercion (e.g., int to float in JSON).
    allow_coercion: bool = false,
    /// When true, trim whitespace from string values before validation.
    trim_strings: bool = false,
    /// When true, convert string values to lowercase before validation.
    lowercase_strings: bool = false,
    /// When true, collect errors for all fields instead of stopping at first error per field.
    collect_all_errors: bool = true,
    /// When true, include the invalid value in error messages.
    include_value_in_error: bool = true,
    /// Custom field name mapping for JSON deserialization (applies to all structs).
    field_name_map: ?*const fn ([]const u8) []const u8 = null,

    // Lifecycle callbacks
    /// Called before validation begins. Receives the type name as a string.
    before_validation_callback: ?*const fn (type_name: []const u8) void = null,
    /// Called after each field is validated. Receives field name, field type, and success status.
    on_field_validated_callback: ?*const fn (field: []const u8, field_type: []const u8, success: bool) void = null,
    /// Called when a field validation fails. Receives field name and error message.
    on_field_error_callback: ?*const fn (field: []const u8, message: []const u8) void = null,
    /// Called when validation completes. Receives success status and error count.
    on_validation_complete_callback: ?*const fn (success: bool, error_count: usize) void = null,
    /// Called before serialization begins.
    before_serialize_callback: ?*const fn () void = null,
    /// Called after serialization completes. Receives the serialized JSON string.
    after_serialize_callback: ?*const fn (json: []const u8) void = null,
    /// Called when a custom message is resolved for a validation error.
    on_custom_message_resolved: ?*const fn (err: errors.ValidationError, message: []const u8) void = null,
};

var global_config: Config = .{};
var update_thread: ?std.Thread = null;
var update_check_triggered = false;
var update_check_mutex: std.atomic.Mutex = .unlocked;

/// Set the library configuration.
pub fn setConfig(config: Config) void {
    global_config = config;
}

/// Get the current library configuration.
pub fn getConfig() Config {
    return global_config;
}

/// Enable colored validation output.
pub fn enableColor() void {
    global_config.use_color_output = true;
}

/// Disable colored validation output.
pub fn disableColor() void {
    global_config.use_color_output = false;
}

/// Set per-error color overrides. Pass .{} to reset to defaults.
pub fn setColorOverrides(overrides: errors.ColorOverrides) void {
    global_config.color_overrides = overrides;
}

fn triggerAutoUpdateCheck(allocator: std.mem.Allocator) void {
    if (@import("builtin").is_test) return;
    while (!update_check_mutex.tryLock()) {
        std.atomic.spinLoopHint();
    }
    defer update_check_mutex.unlock();
    if (update_check_triggered) return;
    update_check_triggered = true;
    if (global_config.auto_update_check and global_config.show_update_notifications) {
        update_thread = report.checkForUpdates(allocator);
    }
}

/// Disable automatic update checking.
pub fn disableUpdateCheck() void {
    setConfig(.{ .auto_update_check = false, .show_update_notifications = false });
}

// String Types
pub const String = types.String;
pub const NonEmptyString = types.NonEmptyString;
pub const Trimmed = types.Trimmed;
pub const Lowercase = types.Lowercase;
pub const Uppercase = types.Uppercase;
pub const Alphanumeric = types.Alphanumeric;
pub const AsciiString = types.AsciiString;
pub const Secret = types.Secret;
pub const StrongPassword = types.StrongPassword;

// Number Types
pub const Int = types.Int;
pub const UInt = types.UInt;
pub const PositiveInt = types.PositiveInt;
pub const NonNegativeInt = types.NonNegativeInt;
pub const NegativeInt = types.NegativeInt;
pub const EvenInt = types.EvenInt;
pub const OddInt = types.OddInt;
pub const MultipleOf = types.MultipleOf;
pub const Float = types.Float;
pub const Percentage = types.Percentage;
pub const Probability = types.Probability;
pub const PositiveFloat = types.PositiveFloat;
pub const NegativeFloat = types.NegativeFloat;
pub const FiniteFloat = types.FiniteFloat;

// Format Types
pub const Email = types.Email;
pub const Url = types.Url;
pub const HttpsUrl = types.HttpsUrl;
pub const Uuid = types.Uuid;
pub const Ipv4 = types.Ipv4;
pub const Ipv6 = types.Ipv6;
pub const Slug = types.Slug;
pub const Semver = types.Semver;
pub const PhoneNumber = types.PhoneNumber;
pub const CreditCard = types.CreditCard;
pub const Regex = types.Regex;
pub const Base64 = types.Base64;
pub const HexString = types.HexString;
pub const HexColor = types.HexColor;
pub const MacAddress = types.MacAddress;
pub const IsoDateTime = types.IsoDateTime;
pub const IsoDate = types.IsoDate;
pub const CountryCode = types.CountryCode;
pub const CurrencyCode = types.CurrencyCode;
pub const Latitude = types.Latitude;
pub const Longitude = types.Longitude;
pub const Port = types.Port;
pub const Iban = types.Iban;
pub const Base58 = types.Base58;
pub const HslColor = types.HslColor;
pub const Duration = types.Duration;
pub const CronExpression = types.CronExpression;
pub const Isbn10 = types.Isbn10;
pub const Isbn13 = types.Isbn13;
pub const AsciiAlphaString = types.AsciiAlphaString;
pub const AsciiPrintableString = types.AsciiPrintableString;
pub const StrongPasswordStrict = types.StrongPasswordStrict;

// Collection Types
pub const List = types.List;
pub const NonEmptyList = types.NonEmptyList;
pub const FixedList = types.FixedList;

// Special Types
pub const Default = types.Default;
pub const DefaultFactory = types.DefaultFactory;
pub const Custom = types.Custom;
pub const Transform = types.Transform;
pub const Coerce = types.Coerce;
pub const Literal = types.Literal;
pub const Partial = types.Partial;
pub const OneOf = types.OneOf;
pub const Range = types.Range;
pub const Nullable = types.Nullable;
pub const Lazy = types.Lazy;

// Custom message variants (accept a messages config struct)
pub const Stringf = types.Stringf;
pub const NonEmptyStringf = types.NonEmptyStringf;
pub const Trimmedf = types.Trimmedf;
pub const Secretf = types.Secretf;
pub const StrongPasswordf = types.StrongPasswordf;
pub const Intf = types.Intf;
pub const UIntf = types.UIntf;
pub const PositiveIntf = types.PositiveIntf;
pub const EvenIntf = types.EvenIntf;
pub const OddIntf = types.OddIntf;
pub const MultipleOff = types.MultipleOff;
pub const Floatf = types.Floatf;
pub const HexStringf = types.HexStringf;
pub const Listf = types.Listf;
pub const FixedListf = types.FixedListf;

// Convenience Functions
pub fn string(comptime min: usize, comptime max: usize) type {
    return String(min, max);
}
pub fn int(comptime T: type, comptime min: comptime_int, comptime max: comptime_int) type {
    return Int(T, min, max);
}
pub fn uint(comptime T: type, comptime min: comptime_int, comptime max: comptime_int) type {
    return UInt(T, min, max);
}
pub fn float(comptime T: type, comptime min: comptime_float, comptime max: comptime_float) type {
    return Float(T, min, max);
}
pub fn list(comptime T: type, comptime min: usize, comptime max: usize) type {
    return List(T, min, max);
}
pub fn default(comptime T: type, comptime val: T) type {
    return Default(T, val);
}
pub fn regex(comptime pattern: []const u8) type {
    return Regex(pattern);
}
pub fn custom(comptime T: type, comptime validator_fn: fn (T) bool) type {
    return Custom(T, validator_fn);
}
pub fn partial(comptime T: type) type {
    return Partial(T);
}
pub fn secret(comptime min: usize, comptime max: usize) type {
    return Secret(min, max);
}
pub fn literal(comptime T: type, comptime val: T) type {
    return Literal(T, val);
}
pub fn trimmed(comptime min: usize, comptime max: usize) type {
    return Trimmed(min, max);
}
pub fn oneOf(comptime T: type, comptime allowed: []const T) type {
    return OneOf(T, allowed);
}
pub fn range(comptime T: type, comptime start: comptime_int, comptime end: comptime_int, comptime step: comptime_int) type {
    return Range(T, start, end, step);
}
pub fn multipleOf(comptime T: type, comptime divisor: comptime_int) type {
    return MultipleOf(T, divisor);
}
pub fn nullable(comptime T: type) type {
    return Nullable(T);
}
pub fn hexString(comptime min: usize, comptime max: usize) type {
    return HexString(min, max);
}
pub fn latitude() type {
    return Latitude;
}
pub fn longitude() type {
    return Longitude;
}
pub fn port() type {
    return Port;
}

// JSON Serialization/Deserialization
pub const ParseResult = json.ParseResult;
pub const ValidationError = errors.ValidationError;
pub const Color = color.Color;
pub const ErrorPresentation = errors.ErrorPresentation;

/// Parses a JSON string into a validated struct.
///
/// Performs compile-time type checking and runtime validation.
/// Returns a `ParseResult` containing either the parsed value
/// or a list of validation errors.
///
/// Triggers lifecycle callbacks: `before_validation_callback`,
/// `on_field_error_callback`, `on_field_validated_callback`,
/// `on_validation_complete_callback`.
pub fn fromJson(comptime T: type, json_string: []const u8, allocator: std.mem.Allocator) !ParseResult(T) {
    triggerAutoUpdateCheck(allocator);
    if (global_config.before_validation_callback) |cb| cb(@typeName(T));
    var result = try json.fromJson(T, json_string, allocator);
    handleValidationResult(T, &result, allocator);
    return result;
}

/// Serializes a value to a compact JSON string.
///
/// Uses compile-time introspection to handle zigantic types,
/// optionals, slices, and nested structs. Triggers
/// `before_serialize_callback` and `after_serialize_callback`.
pub fn toJson(value: anytype, allocator: std.mem.Allocator) ![]const u8 {
    triggerAutoUpdateCheck(allocator);
    if (global_config.before_serialize_callback) |cb| cb();
    const result = json.toJson(value, allocator) catch |err| {
        handleSerializationError(err, "toJson");
        return err;
    };
    if (global_config.after_serialize_callback) |cb| cb(result);
    return result;
}

/// Serializes a value to a pretty-printed JSON string with indentation.
pub fn toJsonPretty(value: anytype, allocator: std.mem.Allocator) ![]const u8 {
    triggerAutoUpdateCheck(allocator);
    if (global_config.before_serialize_callback) |cb| cb();
    const result = json.toJsonPretty(value, allocator) catch |err| {
        handleSerializationError(err, "toJsonPretty");
        return err;
    };
    if (global_config.after_serialize_callback) |cb| cb(result);
    return result;
}

/// Parses a URL query string or form-urlencoded data into a validated struct.
///
/// Supports `key=value` pairs separated by `&`. Values are URL-decoded.
/// Field aliases and naming conventions are respected.
pub fn fromQueryString(comptime T: type, query_string: []const u8, allocator: std.mem.Allocator) !ParseResult(T) {
    triggerAutoUpdateCheck(allocator);
    if (global_config.before_validation_callback) |cb| cb(@typeName(T));
    var result = try json.fromQueryString(T, query_string, allocator);
    handleValidationResult(T, &result, allocator);
    return result;
}

/// Serializes a value to a URL query string (key=value&key2=value2).
///
/// Nested structs are flattened with dot notation. Zigantic wrapper
/// types are unwrapped via `.get()` before serialization.
pub fn toQueryString(value: anytype, allocator: std.mem.Allocator) ![]const u8 {
    triggerAutoUpdateCheck(allocator);
    if (global_config.before_serialize_callback) |cb| cb();
    const result = json.toQueryString(value, allocator) catch |err| {
        handleSerializationError(err, "toQueryString");
        return err;
    };
    if (global_config.after_serialize_callback) |cb| cb(result);
    return result;
}

// Validation Helpers

/// Validates a value against a zigantic type, returning the validated value or an error.
pub fn validate(comptime T: type, value: anytype) errors.ValidationError!T {
    return T.init(value);
}

/// Returns true if the value passes validation for the given type.
pub fn isValid(comptime T: type, value: anytype) bool {
    _ = T.init(value) catch return false;
    return true;
}

/// Returns the human-readable message for a validation error.
pub fn errorMessage(err: errors.ValidationError) []const u8 {
    return errors.errorMessage(err);
}

/// Returns the error code for a validation error (e.g., "E001").
pub fn errorCode(err: errors.ValidationError) []const u8 {
    return errors.errorCode(err);
}

/// Returns the full presentation details (message, code, color) for a validation error.
pub fn errorPresentation(err: errors.ValidationError) errors.ErrorPresentation {
    return errors.errorPresentation(err);
}

/// Returns the default ANSI color for a validation error type.
pub fn errorColor(err: errors.ValidationError) errors.Color {
    return errors.errorColor(err);
}

// Version and Reporting
pub const ISSUES_URL = report.ISSUES_URL;

pub fn getVersion() []const u8 {
    return version.version;
}

pub fn getVersionString() []const u8 {
    return version.getVersionString();
}

pub fn reportInternalError(message: []const u8) void {
    report.reportInternalError(message);
}

pub fn reportInternalErrorWithCode(err: anyerror) void {
    report.reportInternalErrorWithCode(err);
}

fn handleValidationResult(comptime T: type, result: *ParseResult(T), allocator: std.mem.Allocator) void {
    if (global_config.before_validation_callback) |cb| {
        cb(@typeName(T));
    }

    if (result.isValid()) {
        if (global_config.on_validation_complete_callback) |cb| {
            cb(true, 0);
        }
        return;
    }

    if (global_config.on_field_error_callback != null) {
        for (result.error_list.errors.items) |err| {
            if (global_config.on_field_error_callback) |cb| {
                cb(err.field, err.message);
            }
        }
    }

    if (global_config.on_field_validated_callback != null) {
        for (result.error_list.errors.items) |err| {
            if (global_config.on_field_validated_callback) |cb| {
                cb(err.field, @errorName(err.error_type), false);
            }
        }
    }

    const message = if (global_config.use_color_output)
        result.error_list.formatAllColoredWithOverrides(allocator, global_config.validation_message_formatter, global_config.color_overrides) catch return
    else
        result.error_list.formatAllWith(allocator, global_config.validation_message_formatter) catch return;
    defer allocator.free(message);

    if (global_config.validation_error_callback) |callback| {
        callback(message);
    } else if (!@import("builtin").is_test) {
        std.debug.print("{s}\n", .{message});
    }

    if (global_config.on_validation_complete_callback) |cb| {
        cb(false, result.error_list.count());
    }

    if (global_config.exit_on_validation_error) {
        std.process.exit(1);
    }
}

fn handleSerializationError(err: anyerror, operation: []const u8) void {
    var buffer: [256]u8 = undefined;
    const detail = if (global_config.serialization_error_formatter) |formatter| formatter(err) else @errorName(err);
    const message = std.fmt.bufPrint(&buffer, "[{s}] serialization failed: {s}", .{ operation, detail }) catch detail;

    if (global_config.serialization_error_callback) |callback| {
        callback(message);
    } else {
        std.debug.print("{s}\n", .{message});
    }

    if (global_config.exit_on_serialization_error) {
        std.process.exit(1);
    }
}

pub const reportError = reportInternalErrorWithCode;
pub const reportErrorMessage = reportInternalError;

pub fn checkForUpdates(allocator: std.mem.Allocator) ?std.Thread {
    return report.checkForUpdates(allocator);
}

pub fn checkForUpdatesSync(allocator: std.mem.Allocator) !report.UpdateInfo {
    return report.checkForUpdatesSync(allocator);
}

// Tests
test "String basic" {
    const Name = String(1, 50);
    const name = try Name.init("Alice");
    try std.testing.expectEqualStrings("Alice", name.get());
}

test "Int range" {
    const Age = Int(i32, 18, 120);
    const age = try Age.init(25);
    try std.testing.expectEqual(@as(i32, 25), age.get());
    try std.testing.expectError(errors.ValidationError.TooSmall, Age.init(17));
}

test "Email domain" {
    const email = try Email.init("user@example.com");
    try std.testing.expectEqualStrings("example.com", email.domain());
}

test "Url https" {
    const url = try Url.init("https://example.com");
    try std.testing.expect(url.isHttps());
}

test "Default initDefault" {
    const Role = Default([]const u8, "user");
    const role = Role.initDefault();
    try std.testing.expectEqualStrings("user", role.get());
}

test "Custom validator" {
    const isEven = struct {
        fn f(n: i32) bool {
            return @mod(n, 2) == 0;
        }
    }.f;
    const Even = Custom(i32, isEven);
    const even = try Even.init(42);
    try std.testing.expectEqual(@as(i32, 42), even.get());
}

test "Partial fields" {
    const User = struct { name: []const u8, age: i32 };
    const PartialUser = Partial(User);
    var update: PartialUser = .{};
    update.name = "Alice";
    try std.testing.expect(update.age == null);
}

test "isValid helper" {
    try std.testing.expect(isValid(String(1, 50), "Alice"));
    try std.testing.expect(!isValid(String(1, 50), ""));
}

test "validate helper" {
    const name = try validate(String(1, 50), "Bob");
    try std.testing.expectEqualStrings("Bob", name.get());
}

test "PositiveInt" {
    const P = PositiveInt(i32);
    const p = try P.init(5);
    try std.testing.expect(p.isPositive());
}

test "Secret masking" {
    const Password = Secret(8, 100);
    const pwd = try Password.init("secretpass123");
    try std.testing.expectEqualStrings("********", pwd.masked());
}

test "OneOf" {
    const Status = OneOf(u8, &[_]u8{ 1, 2, 3 });
    _ = try Status.init(2);
    try std.testing.expectError(errors.ValidationError.NotInAllowedValues, Status.init(5));
}

test "Uuid" {
    const uuid = try Uuid.init("550e8400-e29b-41d4-a716-446655440000");
    try std.testing.expectEqual(@as(usize, 36), uuid.get().len);
}

test "Ipv4" {
    const ip = try Ipv4.init("192.168.1.1");
    try std.testing.expectEqualStrings("192.168.1.1", ip.get());
}

test "List" {
    const Tags = List([]const u8, 1, 5);
    const items = [_][]const u8{ "a", "b" };
    const tags = try Tags.init(&items);
    try std.testing.expectEqual(@as(usize, 2), tags.len());
}

test "Trimmed" {
    const Input = Trimmed(1, 50);
    const input = try Input.init("  hello  ");
    try std.testing.expectEqualStrings("hello", input.get());
}

test "EvenInt" {
    const E = EvenInt(i32, 0, 100);
    _ = try E.init(42);
    try std.testing.expectError(errors.ValidationError.MustBeEven, E.init(43));
}

test "MultipleOf" {
    const M = MultipleOf(i32, 5);
    _ = try M.init(25);
    try std.testing.expectError(errors.ValidationError.NotMultiple, M.init(23));
}

test "HttpsUrl" {
    _ = try HttpsUrl.init("https://example.com");
    try std.testing.expectError(errors.ValidationError.MustBeHttps, HttpsUrl.init("http://example.com"));
}

test "Range" {
    const R = Range(i32, 0, 100, 10);
    _ = try R.init(50);
    try std.testing.expectError(errors.ValidationError.NotInStep, R.init(55));
}

test "StrongPassword" {
    const Pwd = StrongPassword(8, 100);
    _ = try Pwd.init("P@ssw0rd!");
    try std.testing.expectError(errors.ValidationError.WeakPassword, Pwd.init("password"));
}

test "Nullable" {
    const N = Nullable(i32);
    const some = N.init(42);
    const none = N.initNull();
    try std.testing.expect(!some.isNull());
    try std.testing.expect(none.isNull());
}

test "errorMessage" {
    try std.testing.expectEqualStrings("value is too short", errorMessage(errors.ValidationError.TooShort));
}

test "errorCode" {
    try std.testing.expectEqualStrings("E001", errorCode(errors.ValidationError.TooShort));
}

test "Query String validation" {
    const allocator = std.testing.allocator;
    const User = struct {
        name: String(1, 50),
        age: Int(i32, 0, 150),
        active: bool,
    };

    const qs = "name=Alice+Johnson&age=25&active=true";
    var result = try fromQueryString(User, qs, allocator);
    defer result.deinit();

    try std.testing.expect(result.isValid());
    const user = result.value.?;
    try std.testing.expectEqualStrings("Alice Johnson", user.name.get());
    try std.testing.expectEqual(@as(i32, 25), user.age.get());
    try std.testing.expectEqual(true, user.active);

    const serialized = try toQueryString(user, allocator);
    defer allocator.free(serialized);
    try std.testing.expectEqualStrings("name=Alice+Johnson&age=25&active=true", serialized);
}

// File-level state for callback tests (Zig 0.16 doesn't allow capturing mutable locals)
var cb_called: bool = false;
var cb_validated_count: usize = 0;
var cb_error_count: usize = 0;
var cb_completed: bool = false;
var cb_serialized: ?[]const u8 = null;

test "before_validation_callback triggered" {
    cb_called = false;
    const cb = struct {
        fn call(_: []const u8) void {
            cb_called = true;
        }
    }.call;
    const prev = global_config.before_validation_callback;
    global_config.before_validation_callback = cb;
    defer global_config.before_validation_callback = prev;

    const User = struct {
        name: String(1, 50),
    };
    const qs = "name=Alice";
    var result = try fromQueryString(User, qs, std.testing.allocator);
    defer result.deinit();
    try std.testing.expect(cb_called);
}

test "on_field_validated callback triggered" {
    cb_validated_count = 0;
    const cb = struct {
        fn call(_: []const u8, _: []const u8, _: bool) void {
            cb_validated_count += 1;
        }
    }.call;
    const prev = global_config.on_field_validated_callback;
    global_config.on_field_validated_callback = cb;
    defer global_config.on_field_validated_callback = prev;

    const User = struct {
        name: String(1, 3),
        age: Int(i32, 0, 150),
    };

    var result = try fromJson(User, "{\"name\":\"Alice\",\"age\":25}", std.testing.allocator);
    defer result.deinit();
    try std.testing.expect(cb_validated_count > 0);
}

test "on_field_error callback triggered" {
    cb_error_count = 0;
    const cb = struct {
        fn call(_: []const u8, _: []const u8) void {
            cb_error_count += 1;
        }
    }.call;
    const prev = global_config.on_field_error_callback;
    global_config.on_field_error_callback = cb;
    defer global_config.on_field_error_callback = prev;

    const User = struct {
        name: String(1, 5),
    };

    var result = try fromJson(User, "{\"name\":\"\"}", std.testing.allocator);
    defer result.deinit();
    try std.testing.expect(cb_error_count > 0);
}

test "on_validation_complete callback triggered" {
    cb_completed = false;
    const cb = struct {
        fn call(_: bool, _: usize) void {
            cb_completed = true;
        }
    }.call;
    const prev = global_config.on_validation_complete_callback;
    global_config.on_validation_complete_callback = cb;
    defer global_config.on_validation_complete_callback = prev;

    const User = struct {
        name: String(1, 50),
    };

    var result = try fromJson(User, "{\"name\":\"Alice\"}", std.testing.allocator);
    defer result.deinit();
    try std.testing.expect(cb_completed);
}

test "before_serialize callback triggered" {
    cb_called = false;
    const cb = struct {
        fn call() void {
            cb_called = true;
        }
    }.call;
    const prev = global_config.before_serialize_callback;
    global_config.before_serialize_callback = cb;
    defer global_config.before_serialize_callback = prev;

    const json_result = try toJson(42, std.testing.allocator);
    defer std.testing.allocator.free(json_result);
    try std.testing.expect(cb_called);
}

test "after_serialize callback triggered" {
    cb_serialized = null;
    const cb = struct {
        fn call(result: []const u8) void {
            cb_serialized = result;
        }
    }.call;
    const prev = global_config.after_serialize_callback;
    global_config.after_serialize_callback = cb;
    defer global_config.after_serialize_callback = prev;

    const json_result = try toJson(42, std.testing.allocator);
    defer std.testing.allocator.free(json_result);
    try std.testing.expect(cb_serialized != null);
}

test {
    std.testing.refAllDecls(@This());
}
