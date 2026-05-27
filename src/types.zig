//! # Advanced Validation Types
//!
//! Compile-time validated wrapper types with advanced features.

const std = @import("std");
const validators = @import("validators.zig");
const errors = @import("errors.zig");

/// String with length constraints and helper methods.
///
/// Validates that the input string length is between `min_len` and `max_len`.
/// Returns `TooShort` or `TooLong` on validation failure.
///
/// Example:
/// ```zig
/// const Name = String(1, 50);
/// const name = try Name.init("Alice"); // OK
/// const err = Name.init("");           // Error.TooShort
/// ```
pub fn String(comptime min_len: usize, comptime max_len: usize) type {
    return Stringf(min_len, max_len, .{});
}

/// String with length constraints and custom validation messages.
///
/// Same as `String` but accepts a `messages` struct to override
/// default error messages for `TooShort` and `TooLong` errors.
///
/// Example:
/// ```zig
/// const Name = Stringf(3, 50, .{
///     .too_short = "name must be at least 3 characters",
///     .too_long = "name must be 50 characters or fewer",
/// });
/// ```
pub fn Stringf(comptime min_len: usize, comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .string;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn len(self: Self) usize {
            return self.value.len;
        }
        pub fn isEmpty(self: Self) bool {
            return self.value.len == 0;
        }
        pub fn startsWith(self: Self, prefix: []const u8) bool {
            return std.mem.startsWith(u8, self.value, prefix);
        }
        pub fn endsWith(self: Self, suffix: []const u8) bool {
            return std.mem.endsWith(u8, self.value, suffix);
        }
        pub fn contains(self: Self, needle: []const u8) bool {
            return std.mem.find(u8, self.value, needle) != null;
        }
        pub fn charAt(self: Self, index: usize) ?u8 {
            return if (index < self.value.len) self.value[index] else null;
        }
        pub fn slice(self: Self, start: usize, end: usize) []const u8 {
            const s = @min(start, self.value.len);
            const e = @min(end, self.value.len);
            return self.value[s..e];
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Non-empty string. Shorthand for `String(1, max_len)`.
pub fn NonEmptyString(comptime max_len: usize) type {
    return NonEmptyStringf(max_len, .{});
}

/// Non-empty string with custom messages. Shorthand for `Stringf(1, max_len, messages)`.
pub fn NonEmptyStringf(comptime max_len: usize, comptime messages: anytype) type {
    return Stringf(1, max_len, messages);
}

/// Trimmed string with auto-whitespace removal.
///
/// Strips leading/trailing whitespace before validating length.
/// Provides `getOriginal()` and `wasTrimmed()` to inspect the original input.
pub fn Trimmed(comptime min_len: usize, comptime max_len: usize) type {
    return Trimmedf(min_len, max_len, .{});
}

pub fn Trimmedf(comptime min_len: usize, comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        original: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .trimmed;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            const trimmed = std.mem.trim(u8, str, " \t\n\r");
            if (trimmed.len < min_len) return errors.ValidationError.TooShort;
            if (trimmed.len > max_len) return errors.ValidationError.TooLong;
            return Self{ .value = trimmed, .original = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn getOriginal(self: Self) []const u8 {
            return self.original;
        }
        pub fn wasTrimmed(self: Self) bool {
            return self.value.len != self.original.len;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Lowercase string.
pub fn Lowercase(comptime max_len: usize) type {
    return Lowercasef(max_len, .{});
}

pub fn Lowercasef(comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const max = max_len;
        pub const zigantic_type = .lowercase;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len > max_len) return errors.ValidationError.TooLong;
            for (str) |c| {
                if (std.ascii.isUpper(c)) return errors.ValidationError.MustBeLowercase;
            }
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Uppercase string.
pub fn Uppercase(comptime max_len: usize) type {
    return Uppercasef(max_len, .{});
}

pub fn Uppercasef(comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const max = max_len;
        pub const zigantic_type = .uppercase;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len > max_len) return errors.ValidationError.TooLong;
            for (str) |c| {
                if (std.ascii.isLower(c)) return errors.ValidationError.MustBeUppercase;
            }
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Alphanumeric string.
pub fn Alphanumeric(comptime min_len: usize, comptime max_len: usize) type {
    return Alphanumericf(min_len, max_len, .{});
}

pub fn Alphanumericf(comptime min_len: usize, comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .alphanumeric;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            for (str) |c| {
                if (!std.ascii.isAlphanumeric(c)) return errors.ValidationError.InvalidFormat;
            }
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// ASCII-only string.
pub fn AsciiString(comptime min_len: usize, comptime max_len: usize) type {
    return AsciiStringf(min_len, max_len, .{});
}

pub fn AsciiStringf(comptime min_len: usize, comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .ascii;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            for (str) |c| {
                if (!std.ascii.isAscii(c)) return errors.ValidationError.InvalidFormat;
            }
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Secret/password string with strength checking.
pub fn Secret(comptime min_len: usize, comptime max_len: usize) type {
    return Secretf(min_len, max_len, .{});
}

pub fn Secretf(comptime min_len: usize, comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .secret;
        pub const is_secret = true;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn masked(_: Self) []const u8 {
            return "********";
        }
        pub fn hasUppercase(self: Self) bool {
            for (self.value) |c| {
                if (std.ascii.isUpper(c)) return true;
            }
            return false;
        }
        pub fn hasLowercase(self: Self) bool {
            for (self.value) |c| {
                if (std.ascii.isLower(c)) return true;
            }
            return false;
        }
        pub fn hasDigit(self: Self) bool {
            for (self.value) |c| {
                if (std.ascii.isDigit(c)) return true;
            }
            return false;
        }
        pub fn hasSpecial(self: Self) bool {
            for (self.value) |c| {
                if (!std.ascii.isAlphanumeric(c)) return true;
            }
            return false;
        }
        pub fn strength(self: Self) u8 {
            var score: u8 = 0;
            if (self.value.len >= 8) score += 1;
            if (self.value.len >= 12) score += 1;
            if (self.hasUppercase()) score += 1;
            if (self.hasLowercase()) score += 1;
            if (self.hasDigit()) score += 1;
            if (self.hasSpecial()) score += 1;
            return score;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Strong password with requirements.
pub fn StrongPassword(comptime min_len: usize, comptime max_len: usize) type {
    return StrongPasswordf(min_len, max_len, .{});
}

pub fn StrongPasswordf(comptime min_len: usize, comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .strong_password;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            var has_upper = false;
            var has_lower = false;
            var has_digit = false;
            var has_special = false;
            for (str) |c| {
                if (std.ascii.isUpper(c)) has_upper = true else if (std.ascii.isLower(c)) has_lower = true else if (std.ascii.isDigit(c)) has_digit = true else has_special = true;
            }
            if (!has_upper or !has_lower or !has_digit or !has_special) return errors.ValidationError.WeakPassword;
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn masked(_: Self) []const u8 {
            return "********";
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Signed integer with range constraints and utility methods.
///
/// Validates that the value is within `[min_val, max_val]`.
/// Provides `isPositive()`, `isEven()`, `abs()`, `clamp()`, etc.
///
/// Example:
/// ```zig
/// const Age = Int(i32, 0, 150);
/// const age = try Age.init(25);
/// ```
pub fn Int(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int) type {
    return Intf(T, min_val, max_val, .{});
}

/// Signed integer with range constraints and custom validation messages.
pub fn Intf(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const IntType = T;
        pub const zigantic_type = .int;
        pub const custom_messages = messages;

        pub fn init(val: T) errors.ValidationError!Self {
            if (val < min_val) return errors.ValidationError.TooSmall;
            if (val > max_val) return errors.ValidationError.TooLarge;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn isPositive(self: Self) bool {
            return self.value > 0;
        }
        pub fn isNegative(self: Self) bool {
            return self.value < 0;
        }
        pub fn isZero(self: Self) bool {
            return self.value == 0;
        }
        pub fn isEven(self: Self) bool {
            return @mod(self.value, 2) == 0;
        }
        pub fn isOdd(self: Self) bool {
            return @mod(self.value, 2) != 0;
        }
        pub fn abs(self: Self) T {
            return if (self.value < 0) -self.value else self.value;
        }
        pub fn clamp(self: Self, lo: T, hi: T) T {
            return @max(lo, @min(hi, self.value));
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Unsigned integer with range.
pub fn UInt(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int) type {
    return UIntf(T, min_val, max_val, .{});
}

pub fn UIntf(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const IntType = T;
        pub const zigantic_type = .uint;
        pub const custom_messages = messages;

        pub fn init(val: T) errors.ValidationError!Self {
            if (val < min_val) return errors.ValidationError.TooSmall;
            if (val > max_val) return errors.ValidationError.TooLarge;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn isZero(self: Self) bool {
            return self.value == 0;
        }
        pub fn isEven(self: Self) bool {
            return @mod(self.value, 2) == 0;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

pub fn PositiveInt(comptime T: type) type {
    return PositiveIntf(T, .{});
}

pub fn PositiveIntf(comptime T: type, comptime messages: anytype) type {
    return Intf(T, 1, std.math.maxInt(T), messages);
}

pub fn NonNegativeInt(comptime T: type) type {
    return NonNegativeIntf(T, .{});
}

pub fn NonNegativeIntf(comptime T: type, comptime messages: anytype) type {
    return Intf(T, 0, std.math.maxInt(T), messages);
}

pub fn NegativeInt(comptime T: type) type {
    return NegativeIntf(T, .{});
}

pub fn NegativeIntf(comptime T: type, comptime messages: anytype) type {
    return Intf(T, std.math.minInt(T), -1, messages);
}

/// Even number only.
pub fn EvenInt(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int) type {
    return EvenIntf(T, min_val, max_val, .{});
}

pub fn EvenIntf(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const zigantic_type = .even;
        pub const custom_messages = messages;

        pub fn init(val: T) errors.ValidationError!Self {
            if (val < min_val) return errors.ValidationError.TooSmall;
            if (val > max_val) return errors.ValidationError.TooLarge;
            if (@mod(val, 2) != 0) return errors.ValidationError.MustBeEven;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Odd number only.
pub fn OddInt(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int) type {
    return OddIntf(T, min_val, max_val, .{});
}

pub fn OddIntf(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const zigantic_type = .odd;
        pub const custom_messages = messages;

        pub fn init(val: T) errors.ValidationError!Self {
            if (val < min_val) return errors.ValidationError.TooSmall;
            if (val > max_val) return errors.ValidationError.TooLarge;
            if (@mod(val, 2) == 0) return errors.ValidationError.MustBeOdd;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Multiple of N.
pub fn MultipleOf(comptime T: type, comptime divisor: comptime_int) type {
    return MultipleOff(T, divisor, .{});
}

pub fn MultipleOff(comptime T: type, comptime divisor: comptime_int, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: T,
        pub const multiple = divisor;
        pub const zigantic_type = .multiple;
        pub const custom_messages = messages;

        pub fn init(val: T) errors.ValidationError!Self {
            if (@mod(val, divisor) != 0) return errors.ValidationError.NotMultiple;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Float with range and utilities.
pub fn Float(comptime T: type, comptime min_val: comptime_float, comptime max_val: comptime_float) type {
    return Floatf(T, min_val, max_val, .{});
}

pub fn Floatf(comptime T: type, comptime min_val: comptime_float, comptime max_val: comptime_float, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const FloatType = T;
        pub const zigantic_type = .float;
        pub const custom_messages = messages;

        pub fn init(val: T) errors.ValidationError!Self {
            if (std.math.isNan(val)) return errors.ValidationError.InvalidNumber;
            if (std.math.isInf(val)) return errors.ValidationError.InvalidNumber;
            if (val < min_val) return errors.ValidationError.TooSmall;
            if (val > max_val) return errors.ValidationError.TooLarge;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn isPositive(self: Self) bool {
            return self.value > 0;
        }
        pub fn isNegative(self: Self) bool {
            return self.value < 0;
        }
        pub fn isZero(self: Self) bool {
            return self.value == 0;
        }
        pub fn floor(self: Self) T {
            return @floor(self.value);
        }
        pub fn ceil(self: Self) T {
            return @ceil(self.value);
        }
        pub fn round(self: Self) T {
            return @round(self.value);
        }
        pub fn trunc(self: Self) T {
            return @trunc(self.value);
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

pub fn Percentage(comptime T: type) type {
    return Percentagef(T, .{});
}

pub fn Percentagef(comptime T: type, comptime messages: anytype) type {
    return Floatf(T, 0.0, 100.0, messages);
}

pub fn Probability(comptime T: type) type {
    return Probabilityf(T, .{});
}

pub fn Probabilityf(comptime T: type, comptime messages: anytype) type {
    return Floatf(T, 0.0, 1.0, messages);
}

pub fn PositiveFloat(comptime T: type) type {
    return PositiveFloatf(T, .{});
}

pub fn PositiveFloatf(comptime T: type, comptime messages: anytype) type {
    return Floatf(T, 0.0, std.math.floatMax(T), messages);
}

pub fn NegativeFloat(comptime T: type) type {
    return NegativeFloatf(T, .{});
}

pub fn NegativeFloatf(comptime T: type, comptime messages: anytype) type {
    return Floatf(T, -std.math.floatMax(T), 0.0, messages);
}

/// Finite float (no NaN or Inf).
pub fn FiniteFloat(comptime T: type) type {
    return FiniteFloatf(T, .{});
}

pub fn FiniteFloatf(comptime T: type, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: T,
        pub const FloatType = T;
        pub const zigantic_type = .finite_float;
        pub const custom_messages = messages;

        pub fn init(val: T) errors.ValidationError!Self {
            if (std.math.isNan(val) or std.math.isInf(val)) return errors.ValidationError.InvalidNumber;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Email address with format validation and utilities.
///
/// Validates email format (basic RFC-compliant check).
/// Provides `domain()`, `localPart()`, and `isBusinessEmail()`.
pub const Email = struct {
    value: []const u8,
    pub const zigantic_type = .email;

    pub fn init(str: []const u8) errors.ValidationError!Email {
        if (!validators.isValidEmail(str)) return errors.ValidationError.InvalidEmail;
        return Email{ .value = str };
    }
    pub fn get(self: Email) []const u8 {
        return self.value;
    }
    pub fn domain(self: Email) []const u8 {
        for (self.value, 0..) |c, i| {
            if (c == '@') return self.value[i + 1 ..];
        }
        return "";
    }
    pub fn localPart(self: Email) []const u8 {
        for (self.value, 0..) |c, i| {
            if (c == '@') return self.value[0..i];
        }
        return self.value;
    }
    pub fn isBusinessEmail(self: Email) bool {
        const d = self.domain();
        const free_domains = [_][]const u8{ "gmail.com", "yahoo.com", "hotmail.com", "outlook.com" };
        for (free_domains) |fd| {
            if (std.mem.eql(u8, d, fd)) return false;
        }
        return true;
    }
    /// Returns true if the local part contains a '+' tag (e.g., "user+tag@example.com").
    pub fn hasTag(self: Email) bool {
        const local = self.localPart();
        for (local) |c| {
            if (c == '+') return true;
        }
        return false;
    }
    /// Returns the tag portion after '+' in the local part, or null.
    pub fn tag(self: Email) ?[]const u8 {
        const local = self.localPart();
        for (local, 0..) |c, i| {
            if (c == '+') return local[i + 1 ..];
        }
        return null;
    }
    /// Returns true if the domain is a common free email provider.
    pub fn isFreeEmail(self: Email) bool {
        return !self.isBusinessEmail();
    }
    /// Returns the TLD (top-level domain) of the email.
    pub fn tld(self: Email) []const u8 {
        const d = self.domain();
        var last_dot: ?usize = null;
        for (d, 0..) |c, i| {
            if (c == '.') last_dot = i;
        }
        if (last_dot) |ld| return d[ld + 1 ..];
        return "";
    }
};

/// URL with utilities.
pub const Url = struct {
    value: []const u8,
    pub const zigantic_type = .url;

    pub fn init(str: []const u8) errors.ValidationError!Url {
        if (!validators.isValidUrl(str)) return errors.ValidationError.InvalidUrl;
        return Url{ .value = str };
    }
    pub fn get(self: Url) []const u8 {
        return self.value;
    }
    pub fn isHttps(self: Url) bool {
        return std.mem.startsWith(u8, self.value, "https://");
    }
    pub fn protocol(self: Url) []const u8 {
        if (std.mem.startsWith(u8, self.value, "https://")) return "https";
        if (std.mem.startsWith(u8, self.value, "http://")) return "http";
        return "";
    }
    pub fn host(self: Url) []const u8 {
        var start: usize = 0;
        if (std.mem.startsWith(u8, self.value, "https://")) {
            start = 8;
        } else if (std.mem.startsWith(u8, self.value, "http://")) {
            start = 7;
        }
        const rest = self.value[start..];
        for (rest, 0..) |c, i| {
            if (c == '/' or c == ':' or c == '?') return rest[0..i];
        }
        return rest;
    }
    /// Returns the path portion of the URL (after host, before query).
    pub fn path(self: Url) []const u8 {
        var start: usize = 0;
        if (std.mem.startsWith(u8, self.value, "https://")) {
            start = 8;
        } else if (std.mem.startsWith(u8, self.value, "http://")) {
            start = 7;
        }
        const rest = self.value[start..];
        const host_end = for (rest, 0..) |c, i| {
            if (c == '/' or c == '?' or c == '#') break i;
        } else rest.len;
        const path_start = host_end;
        const path_end = for (rest[path_start..], 0..) |c, i| {
            if (c == '?' or c == '#') break path_start + i;
        } else rest.len;
        return rest[path_start..path_end];
    }
    /// Returns the query string (after '?', before '#'), or null if none.
    pub fn query(self: Url) ?[]const u8 {
        for (self.value, 0..) |c, i| {
            if (c == '?') {
                const q = self.value[i + 1 ..];
                for (q, 0..) |qc, qi| {
                    if (qc == '#') return q[0..qi];
                }
                return q;
            }
        }
        return null;
    }
    /// Returns the fragment (after '#'), or null if none.
    pub fn fragment(self: Url) ?[]const u8 {
        for (self.value, 0..) |c, i| {
            if (c == '#') return self.value[i + 1 ..];
        }
        return null;
    }
    /// Returns the port number from the URL, or null if not specified.
    pub fn port(self: Url) ?u16 {
        // Look for port in the raw URL after the host portion
        var start: usize = 0;
        if (std.mem.startsWith(u8, self.value, "https://")) {
            start = 8;
        } else if (std.mem.startsWith(u8, self.value, "http://")) {
            start = 7;
        }
        const rest = self.value[start..];
        for (rest, 0..) |c, i| {
            if (c == ':') {
                // Found a colon - check if followed by digits before any /, ?, #
                var end = i + 1;
                while (end < rest.len and rest[end] >= '0' and rest[end] <= '9') end += 1;
                if (end > i + 1) {
                    return std.fmt.parseInt(u16, rest[i + 1 .. end], 10) catch null;
                }
            }
            if (c == '/' or c == '?') break;
        }
        return null;
    }
    /// Returns true if the URL has a query string.
    pub fn hasQuery(self: Url) bool {
        return self.query() != null;
    }
    /// Returns true if the URL has a fragment.
    pub fn hasFragment(self: Url) bool {
        return self.fragment() != null;
    }
    /// Returns the filename from the URL path (last segment after '/').
    pub fn filename(self: Url) []const u8 {
        const p = self.path();
        var last_slash: ?usize = null;
        for (p, 0..) |c, i| {
            if (c == '/') last_slash = i;
        }
        if (last_slash) |ls| return p[ls + 1 ..];
        return p;
    }
};

/// Https-only URL.
pub const HttpsUrl = struct {
    value: []const u8,
    pub const zigantic_type = .https_url;

    pub fn init(str: []const u8) errors.ValidationError!HttpsUrl {
        if (!std.mem.startsWith(u8, str, "https://")) return errors.ValidationError.MustBeHttps;
        if (!validators.isValidUrl(str)) return errors.ValidationError.InvalidUrl;
        return HttpsUrl{ .value = str };
    }
    pub fn get(self: HttpsUrl) []const u8 {
        return self.value;
    }
};

pub const Uuid = struct {
    value: []const u8,
    pub const zigantic_type = .uuid;

    pub fn init(str: []const u8) errors.ValidationError!Uuid {
        if (!validators.isUuid(str)) return errors.ValidationError.InvalidUuid;
        return Uuid{ .value = str };
    }
    pub fn get(self: Uuid) []const u8 {
        return self.value;
    }
    pub fn version(self: Uuid) ?u8 {
        return if (self.value.len >= 15) self.value[14] - '0' else null;
    }
};

pub const Ipv4 = struct {
    value: []const u8,
    pub const zigantic_type = .ipv4;

    pub fn init(str: []const u8) errors.ValidationError!Ipv4 {
        if (!validators.isIpv4(str)) return errors.ValidationError.InvalidIpv4;
        return Ipv4{ .value = str };
    }
    pub fn get(self: Ipv4) []const u8 {
        return self.value;
    }
    pub fn isPrivate(self: Ipv4) bool {
        return std.mem.startsWith(u8, self.value, "10.") or
            std.mem.startsWith(u8, self.value, "192.168.") or
            std.mem.startsWith(u8, self.value, "172.16.") or
            std.mem.startsWith(u8, self.value, "172.17.") or
            std.mem.startsWith(u8, self.value, "172.18.") or
            std.mem.startsWith(u8, self.value, "172.19.") or
            std.mem.startsWith(u8, self.value, "172.20.") or
            std.mem.startsWith(u8, self.value, "172.21.") or
            std.mem.startsWith(u8, self.value, "172.22.") or
            std.mem.startsWith(u8, self.value, "172.23.") or
            std.mem.startsWith(u8, self.value, "172.24.") or
            std.mem.startsWith(u8, self.value, "172.25.") or
            std.mem.startsWith(u8, self.value, "172.26.") or
            std.mem.startsWith(u8, self.value, "172.27.") or
            std.mem.startsWith(u8, self.value, "172.28.") or
            std.mem.startsWith(u8, self.value, "172.29.") or
            std.mem.startsWith(u8, self.value, "172.30.") or
            std.mem.startsWith(u8, self.value, "172.31.");
    }
    pub fn isLoopback(self: Ipv4) bool {
        return std.mem.startsWith(u8, self.value, "127.");
    }
};

pub const Ipv6 = struct {
    value: []const u8,
    pub const zigantic_type = .ipv6;

    pub fn init(str: []const u8) errors.ValidationError!Ipv6 {
        if (!validators.isIpv6(str)) return errors.ValidationError.InvalidIpv6;
        return Ipv6{ .value = str };
    }
    pub fn get(self: Ipv6) []const u8 {
        return self.value;
    }
    pub fn isLoopback(self: Ipv6) bool {
        return std.mem.eql(u8, self.value, "::1");
    }
};

pub const Slug = struct {
    value: []const u8,
    pub const zigantic_type = .slug;

    pub fn init(str: []const u8) errors.ValidationError!Slug {
        if (!validators.isSlug(str)) return errors.ValidationError.InvalidFormat;
        return Slug{ .value = str };
    }
    pub fn get(self: Slug) []const u8 {
        return self.value;
    }
};

pub const Semver = struct {
    value: []const u8,
    pub const zigantic_type = .semver;

    pub fn init(str: []const u8) errors.ValidationError!Semver {
        if (!validators.isSemver(str)) return errors.ValidationError.InvalidFormat;
        return Semver{ .value = str };
    }
    pub fn get(self: Semver) []const u8 {
        return self.value;
    }
};

pub const PhoneNumber = struct {
    value: []const u8,
    pub const zigantic_type = .phone;

    pub fn init(str: []const u8) errors.ValidationError!PhoneNumber {
        if (!validators.isPhoneNumber(str)) return errors.ValidationError.InvalidPhoneNumber;
        return PhoneNumber{ .value = str };
    }
    pub fn get(self: PhoneNumber) []const u8 {
        return self.value;
    }
    pub fn hasCountryCode(self: PhoneNumber) bool {
        return self.value.len > 0 and self.value[0] == '+';
    }
};

pub const CreditCard = struct {
    value: []const u8,
    pub const zigantic_type = .credit_card;
    pub const is_secret = true;

    pub fn init(str: []const u8) errors.ValidationError!CreditCard {
        if (!validators.isValidCreditCard(str)) return errors.ValidationError.InvalidCreditCard;
        return CreditCard{ .value = str };
    }
    pub fn get(self: CreditCard) []const u8 {
        return self.value;
    }
    pub fn masked(self: CreditCard) []const u8 {
        return if (self.value.len >= 4) self.value[self.value.len - 4 ..] else self.value;
    }
    pub fn cardType(self: CreditCard) []const u8 {
        if (self.value.len == 0) return "unknown";
        if (self.value[0] == '4') return "visa";
        if (self.value[0] == '5') return "mastercard";
        if (self.value[0] == '3') return "amex";
        return "unknown";
    }
};

pub fn Regex(comptime pattern: []const u8) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const regex_pattern = pattern;
        pub const zigantic_type = .regex;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (!validators.matchesPattern(pattern, str)) return errors.ValidationError.PatternMismatch;
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
    };
}

/// Base64 encoded string.
pub const Base64 = struct {
    value: []const u8,
    pub const zigantic_type = .base64;

    pub fn init(str: []const u8) errors.ValidationError!Base64 {
        if (str.len == 0) return errors.ValidationError.TooShort;
        // Basic base64 character validation
        for (str) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '/' and c != '=') {
                return errors.ValidationError.InvalidFormat;
            }
        }
        return Base64{ .value = str };
    }
    pub fn get(self: Base64) []const u8 {
        return self.value;
    }
    pub fn estimatedDecodedLen(self: Base64) usize {
        // Base64: 4 chars = 3 bytes, account for padding
        const padding = blk: {
            var count: usize = 0;
            if (self.value.len > 0 and self.value[self.value.len - 1] == '=') count += 1;
            if (self.value.len > 1 and self.value[self.value.len - 2] == '=') count += 1;
            break :blk count;
        };
        return (self.value.len / 4) * 3 - padding;
    }
};

/// Hexadecimal string.
pub fn HexString(comptime min_len: usize, comptime max_len: usize) type {
    return HexStringf(min_len, max_len, .{});
}

pub fn HexStringf(comptime min_len: usize, comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .hex_string;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            for (str) |c| {
                if (!std.ascii.isHex(c)) return errors.ValidationError.InvalidFormat;
            }
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn isLowercase(self: Self) bool {
            for (self.value) |c| {
                if (c >= 'A' and c <= 'F') return false;
            }
            return true;
        }
        pub fn isUppercase(self: Self) bool {
            for (self.value) |c| {
                if (c >= 'a' and c <= 'f') return false;
            }
            return true;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Hex color code (e.g., #FF5733 or FF5733).
pub fn HexColor() type {
    return HexColorf(.{});
}

pub fn HexColorf(comptime messages: anytype) type {
    return struct {
        value: []const u8,
        pub const zigantic_type = .hex_color;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!@This() {
            if (!validators.isHexColor(str)) return errors.ValidationError.InvalidFormat;
            return @This(){ .value = str };
        }
        pub fn get(self: @This()) []const u8 {
            return self.value;
        }
        pub fn getHex(self: @This()) []const u8 {
            if (self.value.len > 0 and self.value[0] == '#') return self.value[1..];
            return self.value;
        }
        pub fn hasHash(self: @This()) bool {
            return self.value.len > 0 and self.value[0] == '#';
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// MAC address (e.g., 00:1A:2B:3C:4D:5E).
pub fn MacAddress() type {
    return MacAddressf(.{});
}

pub fn MacAddressf(comptime messages: anytype) type {
    return struct {
        value: []const u8,
        pub const zigantic_type = .mac_address;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!@This() {
            if (!validators.isMacAddress(str)) return errors.ValidationError.InvalidFormat;
            return @This(){ .value = str };
        }
        pub fn get(self: @This()) []const u8 {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// ISO 8601 DateTime string (e.g., 2024-01-15T10:30:00Z).
pub fn IsoDateTime() type {
    return IsoDateTimef(.{});
}

pub fn IsoDateTimef(comptime messages: anytype) type {
    return struct {
        value: []const u8,
        pub const zigantic_type = .iso_datetime;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!@This() {
            if (!validators.isIsoDateTime(str)) return errors.ValidationError.InvalidFormat;
            return @This(){ .value = str };
        }
        pub fn get(self: @This()) []const u8 {
            return self.value;
        }
        pub fn getDatePart(self: @This()) []const u8 {
            return if (self.value.len >= 10) self.value[0..10] else "";
        }
        pub fn getTimePart(self: @This()) []const u8 {
            if (self.value.len >= 19) {
                return self.value[11..19];
            }
            return "";
        }
        pub fn hasTimezone(self: @This()) bool {
            return self.value.len > 19 and (self.value[19] == 'Z' or self.value[19] == '+' or self.value[19] == '-');
        }
        pub fn isUtc(self: @This()) bool {
            return self.value.len > 19 and self.value[19] == 'Z';
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// ISO 8601 Date string (e.g., 2024-01-15).
pub fn IsoDate() type {
    return IsoDatef(.{});
}

pub fn IsoDatef(comptime messages: anytype) type {
    return struct {
        value: []const u8,
        pub const zigantic_type = .iso_date;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!@This() {
            if (!validators.isIsoDate(str)) return errors.ValidationError.InvalidFormat;
            return @This(){ .value = str };
        }
        pub fn get(self: @This()) []const u8 {
            return self.value;
        }
        pub fn getYear(self: @This()) ?u16 {
            const digits = self.value[0..4];
            return std.fmt.parseInt(u16, digits, 10) catch null;
        }
        pub fn getMonth(self: @This()) ?u8 {
            const digits = self.value[5..7];
            return std.fmt.parseInt(u8, digits, 10) catch null;
        }
        pub fn getDay(self: @This()) ?u8 {
            const digits = self.value[8..10];
            return std.fmt.parseInt(u8, digits, 10) catch null;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// ISO 3166-1 alpha-2 country code (e.g., US, GB, DE).
pub fn CountryCode() type {
    return CountryCodef(.{});
}

pub fn CountryCodef(comptime messages: anytype) type {
    return struct {
        value: []const u8,
        pub const zigantic_type = .country_code;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!@This() {
            if (!validators.isCountryCode(str)) return errors.ValidationError.InvalidFormat;
            return @This(){ .value = str };
        }
        pub fn get(self: @This()) []const u8 {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// ISO 4217 currency code (e.g., USD, EUR, GBP).
pub fn CurrencyCode() type {
    return CurrencyCodef(.{});
}

pub fn CurrencyCodef(comptime messages: anytype) type {
    return struct {
        value: []const u8,
        pub const zigantic_type = .currency_code;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!@This() {
            if (!validators.isCurrencyCode(str)) return errors.ValidationError.InvalidFormat;
            return @This(){ .value = str };
        }
        pub fn get(self: @This()) []const u8 {
            return self.value;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Latitude coordinate (-90 to 90).
pub fn Latitude() type {
    return Latitudef(.{});
}

pub fn Latitudef(comptime messages: anytype) type {
    return struct {
        value: f64,
        pub const zigantic_type = .latitude;
        pub const custom_messages = messages;

        pub fn init(val: f64) errors.ValidationError!@This() {
            if (!validators.isLatitude(val)) return errors.ValidationError.OutOfRange;
            return @This(){ .value = val };
        }
        pub fn get(self: @This()) f64 {
            return self.value;
        }
        pub fn isNorthern(self: @This()) bool {
            return self.value >= 0;
        }
        pub fn isSouthern(self: @This()) bool {
            return self.value < 0;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Longitude coordinate (-180 to 180).
pub fn Longitude() type {
    return Longitudef(.{});
}

pub fn Longitudef(comptime messages: anytype) type {
    return struct {
        value: f64,
        pub const zigantic_type = .longitude;
        pub const custom_messages = messages;

        pub fn init(val: f64) errors.ValidationError!@This() {
            if (!validators.isLongitude(val)) return errors.ValidationError.OutOfRange;
            return @This(){ .value = val };
        }
        pub fn get(self: @This()) f64 {
            return self.value;
        }
        pub fn isEastern(self: @This()) bool {
            return self.value >= 0;
        }
        pub fn isWestern(self: @This()) bool {
            return self.value < 0;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// Port number (1-65535).
pub fn Port() type {
    return Portf(.{});
}

pub fn Portf(comptime messages: anytype) type {
    return struct {
        value: u16,
        pub const zigantic_type = .port;
        pub const custom_messages = messages;

        pub fn init(val: u16) errors.ValidationError!@This() {
            if (!validators.isPort(val)) return errors.ValidationError.TooSmall;
            return @This(){ .value = val };
        }
        pub fn get(self: @This()) u16 {
            return self.value;
        }
        pub fn isPrivileged(self: @This()) bool {
            return self.value < 1024;
        }
        pub fn isRegistered(self: @This()) bool {
            return self.value >= 1024 and self.value <= 49151;
        }
        pub fn isDynamic(self: @This()) bool {
            return self.value > 49151;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// IBAN (International Bank Account Number) with format validation.
pub const Iban = struct {
    value: []const u8,
    pub const zigantic_type = .iban;

    pub fn init(str: []const u8) errors.ValidationError!Iban {
        if (!validators.isIban(str)) return errors.ValidationError.InvalidFormat;
        return Iban{ .value = str };
    }
    pub fn get(self: Iban) []const u8 {
        return self.value;
    }
    /// Returns the 2-letter country code prefix (e.g., "DE", "GB").
    pub fn countryCode(self: Iban) []const u8 {
        return if (self.value.len >= 2) self.value[0..2] else "";
    }
    /// Returns the length without spaces.
    pub fn normalizedLength(self: Iban) usize {
        var count: usize = 0;
        for (self.value) |c| {
            if (c != ' ') count += 1;
        }
        return count;
    }
};

/// Base58 encoded string (cryptocurrency addresses, Bitcoin, etc.).
pub const Base58 = struct {
    value: []const u8,
    pub const zigantic_type = .base58;

    pub fn init(str: []const u8) errors.ValidationError!Base58 {
        if (!validators.isBase58(str)) return errors.ValidationError.InvalidFormat;
        return Base58{ .value = str };
    }
    pub fn get(self: Base58) []const u8 {
        return self.value;
    }
    pub fn len(self: Base58) usize {
        return self.value.len;
    }
};

/// HSL color string (e.g., "hsl(120, 100%, 50%)").
pub const HslColor = struct {
    value: []const u8,
    pub const zigantic_type = .hsl_color;

    pub fn init(str: []const u8) errors.ValidationError!HslColor {
        if (!validators.isHslColor(str)) return errors.ValidationError.InvalidFormat;
        return HslColor{ .value = str };
    }
    pub fn get(self: HslColor) []const u8 {
        return self.value;
    }
};

/// ISO 8601 duration string (e.g., "P1Y2M3DT4H5M6S", "P30D").
pub const Duration = struct {
    value: []const u8,
    pub const zigantic_type = .duration;

    pub fn init(str: []const u8) errors.ValidationError!Duration {
        if (!validators.isIsoDuration(str)) return errors.ValidationError.InvalidFormat;
        return Duration{ .value = str };
    }
    pub fn get(self: Duration) []const u8 {
        return self.value;
    }
    /// Returns true if this duration includes a time component (T prefix in time part).
    pub fn hasTime(self: Duration) bool {
        return std.mem.indexOf(u8, self.value, "T") != null;
    }
};

/// Cron expression (5 or 6 fields: minute hour day month weekday [year]).
pub const CronExpression = struct {
    value: []const u8,
    pub const zigantic_type = .cron;

    pub fn init(str: []const u8) errors.ValidationError!CronExpression {
        if (!validators.isCronExpression(str)) return errors.ValidationError.InvalidFormat;
        return CronExpression{ .value = str };
    }
    pub fn get(self: CronExpression) []const u8 {
        return self.value;
    }
    /// Returns the number of fields (5 or 6).
    pub fn fieldCount(self: CronExpression) u32 {
        var count: u32 = 0;
        var in_field = false;
        for (self.value) |c| {
            if (std.ascii.isWhitespace(c)) {
                if (in_field) count += 1;
                in_field = false;
            } else {
                in_field = true;
            }
        }
        if (in_field) count += 1;
        return count;
    }
};

/// ISBN-10 with checksum validation.
pub const Isbn10 = struct {
    value: []const u8,
    pub const zigantic_type = .isbn10;

    pub fn init(str: []const u8) errors.ValidationError!Isbn10 {
        if (!validators.isIsbn10(str)) return errors.ValidationError.InvalidFormat;
        return Isbn10{ .value = str };
    }
    pub fn get(self: Isbn10) []const u8 {
        return self.value;
    }
};

/// ISBN-13 with checksum validation.
pub const Isbn13 = struct {
    value: []const u8,
    pub const zigantic_type = .isbn13;

    pub fn init(str: []const u8) errors.ValidationError!Isbn13 {
        if (!validators.isIsbn13(str)) return errors.ValidationError.InvalidFormat;
        return Isbn13{ .value = str };
    }
    pub fn get(self: Isbn13) []const u8 {
        return self.value;
    }
};

/// ASCII alphabetic string (A-Z, a-z only, no digits or special characters).
pub fn AsciiAlphaString(comptime min_len: usize, comptime max_len: usize) type {
    return AsciiAlphaStringf(min_len, max_len, .{});
}

pub fn AsciiAlphaStringf(comptime min_len: usize, comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .ascii_alpha;
        pub const custom_messages = messages;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            if (!validators.isAsciiAlpha(str)) return errors.ValidationError.InvalidFormat;
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn len(self: Self) usize {
            return self.value.len;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

/// ASCII printable string (0x20-0x7E only).
pub fn AsciiPrintableString(comptime min_len: usize, comptime max_len: usize) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .ascii_printable;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            if (!validators.isAsciiPrintable(str)) return errors.ValidationError.InvalidFormat;
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
        pub fn len(self: Self) usize {
            return self.value.len;
        }
    };
}

/// Strong password with built-in requirements (min 8, upper+lower+digit+special).
pub const StrongPasswordStrict = struct {
    value: []const u8,
    pub const zigantic_type = .strong_password;

    pub fn init(str: []const u8) errors.ValidationError!StrongPasswordStrict {
        if (!validators.isStrongPassword(str)) return errors.ValidationError.WeakPassword;
        return StrongPasswordStrict{ .value = str };
    }
    pub fn get(self: StrongPasswordStrict) []const u8 {
        return self.value;
    }
    pub fn masked(_: StrongPasswordStrict) []const u8 {
        return "********";
    }
    pub fn len(self: StrongPasswordStrict) usize {
        return self.value.len;
    }
};

/// Dynamic-length list with min/max item count constraints.
///
/// Validates that the slice length is within `[min_len, max_len]`.
/// Provides `len()`, `first()`, `last()`, `at()` for safe access.
pub fn List(comptime T: type, comptime min_len: usize, comptime max_len: usize) type {
    return Listf(T, min_len, max_len, .{});
}

/// Dynamic-length list with custom validation messages.
pub fn Listf(comptime T: type, comptime min_len: usize, comptime max_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        items: []const T,
        pub const min = min_len;
        pub const max = max_len;
        pub const ItemType = T;
        pub const zigantic_type = .list;
        pub const custom_messages = messages;

        pub fn init(items: []const T) errors.ValidationError!Self {
            if (items.len < min_len) return errors.ValidationError.TooFewItems;
            if (items.len > max_len) return errors.ValidationError.TooManyItems;
            return Self{ .items = items };
        }
        pub fn get(self: Self) []const T {
            return self.items;
        }
        pub fn len(self: Self) usize {
            return self.items.len;
        }
        pub fn isEmpty(self: Self) bool {
            return self.items.len == 0;
        }
        pub fn first(self: Self) ?T {
            return if (self.items.len > 0) self.items[0] else null;
        }
        pub fn last(self: Self) ?T {
            return if (self.items.len > 0) self.items[self.items.len - 1] else null;
        }
        pub fn at(self: Self, index: usize) ?T {
            return if (index < self.items.len) self.items[index] else null;
        }
        /// Returns true if the list contains the given item (requires T == u8 or == []const u8).
        pub fn contains(self: Self, item: T) bool {
            const info = @typeInfo(T);
            for (self.items) |i| {
                if (info == .pointer and info.pointer.size == .slice and info.pointer.child == u8) {
                    if (std.mem.eql(u8, i, item)) return true;
                } else {
                    if (i == item) return true;
                }
            }
            return false;
        }
        /// Returns a slice of items from start to end (exclusive).
        pub fn slice(self: Self, start: usize, end: usize) []const T {
            const s = @min(start, self.items.len);
            const e = @min(end, self.items.len);
            return self.items[s..e];
        }
        /// Returns the sum of all items (requires T to be numeric).
        pub fn sum(self: Self) T {
            var total: T = 0;
            for (self.items) |item| {
                total += item;
            }
            return total;
        }
        /// Returns true if all items satisfy the given predicate function.
        pub fn all(self: Self, predicate: fn (T) bool) bool {
            for (self.items) |item| {
                if (!predicate(item)) return false;
            }
            return true;
        }
        /// Returns true if any item satisfies the given predicate function.
        pub fn any(self: Self, predicate: fn (T) bool) bool {
            for (self.items) |item| {
                if (predicate(item)) return true;
            }
            return false;
        }
        /// Returns the index of the first item matching the predicate, or null.
        pub fn findIndex(self: Self, predicate: fn (T) bool) ?usize {
            for (self.items, 0..) |item, i| {
                if (predicate(item)) return i;
            }
            return null;
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

pub fn NonEmptyList(comptime T: type, comptime max_len: usize) type {
    return NonEmptyListf(T, max_len, .{});
}

pub fn NonEmptyListf(comptime T: type, comptime max_len: usize, comptime messages: anytype) type {
    return Listf(T, 1, max_len, messages);
}

/// Fixed-size tuple/array.
pub fn FixedList(comptime T: type, comptime exact_len: usize) type {
    return FixedListf(T, exact_len, .{});
}

pub fn FixedListf(comptime T: type, comptime exact_len: usize, comptime messages: anytype) type {
    return struct {
        const Self = @This();
        items: []const T,
        pub const length = exact_len;
        pub const ItemType = T;
        pub const zigantic_type = .fixed_list;
        pub const custom_messages = messages;

        pub fn init(items: []const T) errors.ValidationError!Self {
            if (items.len != exact_len) return errors.ValidationError.WrongLength;
            return Self{ .items = items };
        }
        pub fn get(self: Self) []const T {
            return self.items;
        }
        pub fn at(self: Self, comptime index: usize) T {
            return self.items[index];
        }
        pub fn messageFor(err: errors.ValidationError) ?[]const u8 {
            return errors.messageForConfig(err, messages);
        }
    };
}

pub fn Default(comptime T: type, comptime default_value: T) type {
    return struct {
        const Self = @This();
        value: T,
        pub const default = default_value;
        pub const ValueType = T;
        pub const zigantic_type = .default;

        pub fn init(val: T) Self {
            return Self{ .value = val };
        }
        pub fn initDefault() Self {
            return Self{ .value = default_value };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn isDefault(self: Self) bool {
            const info = @typeInfo(T);
            if (info == .pointer and info.pointer.size == .slice) {
                return std.mem.eql(info.pointer.child, self.value, default_value);
            } else {
                return self.value == default_value;
            }
        }
        pub fn getOrDefault(opt: ?Self) T {
            return if (opt) |v| v.value else default_value;
        }
    };
}

/// Default value generated by a factory function when missing.
pub fn DefaultFactory(comptime T: type, comptime factory_fn: fn () T) type {
    return struct {
        const Self = @This();
        value: T,
        pub const ValueType = T;
        pub const zigantic_type = .default_factory;

        pub fn init(val: T) Self {
            return Self{ .value = val };
        }
        pub fn initDefault() Self {
            return Self{ .value = factory_fn() };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn getOrDefault(opt: ?Self) T {
            return if (opt) |v| v.value else factory_fn();
        }
    };
}

pub fn Custom(comptime T: type, comptime validator_fn: fn (T) bool) type {
    return struct {
        const Self = @This();
        value: T,
        pub const ValueType = T;
        pub const validate = validator_fn;
        pub const zigantic_type = .custom;

        pub fn init(val: T) errors.ValidationError!Self {
            if (!validator_fn(val)) return errors.ValidationError.CustomValidationFailed;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

/// Custom with transformation.
pub fn Transform(comptime T: type, comptime transform_fn: fn (T) T) type {
    return struct {
        const Self = @This();
        value: T,
        original: T,
        pub const ValueType = T;
        pub const zigantic_type = .transform;

        pub fn init(val: T) Self {
            return Self{ .value = transform_fn(val), .original = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn getOriginal(self: Self) T {
            return self.original;
        }
    };
}

/// Coerce from one type to another.
pub fn Coerce(comptime From: type, comptime To: type) type {
    return struct {
        const Self = @This();
        value: To,
        pub const FromType = From;
        pub const ToType = To;
        pub const zigantic_type = .coerce;

        pub fn init(val: From) errors.ValidationError!Self {
            const info = @typeInfo(From);
            if (info == .int or info == .comptime_int) {
                return Self{ .value = @intCast(val) };
            } else if (info == .float or info == .comptime_float) {
                return Self{ .value = @floatCast(val) };
            }
            return errors.ValidationError.TypeMismatch;
        }
        pub fn get(self: Self) To {
            return self.value;
        }
    };
}

pub fn Literal(comptime T: type, comptime expected: T) type {
    return struct {
        const Self = @This();
        value: T,
        pub const expected_value = expected;
        pub const ValueType = T;
        pub const zigantic_type = .literal;

        pub fn init(val: T) errors.ValidationError!Self {
            if (val != expected) return errors.ValidationError.LiteralMismatch;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

pub fn Partial(comptime T: type) type {
    const info = @typeInfo(T);
    if (info != .@"struct") @compileError("Partial: T must be a struct");

    const fields = info.@"struct".fields;
    comptime var field_names: [fields.len][]const u8 = undefined;
    comptime var field_types: [fields.len]type = undefined;
    comptime var field_attrs: [fields.len]std.builtin.Type.StructField.Attributes = undefined;

    inline for (fields, 0..) |field, i| {
        const OptionalType = ?field.type;
        field_names[i] = field.name;
        field_types[i] = OptionalType;
        field_attrs[i] = .{
            .@"comptime" = false,
            .@"align" = @alignOf(OptionalType),
            .default_value_ptr = @ptrCast(&@as(OptionalType, null)),
        };
    }

    return @Struct(
        .auto,
        null,
        &field_names,
        &field_types,
        &field_attrs,
    );
}

pub fn OneOf(comptime T: type, comptime allowed: []const T) type {
    return struct {
        const Self = @This();
        value: T,
        pub const allowed_values = allowed;
        pub const ValueType = T;
        pub const zigantic_type = .oneof;

        pub fn init(val: T) errors.ValidationError!Self {
            for (allowed) |a| {
                if (a == val) return Self{ .value = val };
            }
            return errors.ValidationError.NotInAllowedValues;
        }
        pub fn get(self: Self) T {
            return self.value;
        }
        pub fn isFirst(self: Self) bool {
            return allowed.len > 0 and self.value == allowed[0];
        }
        pub fn isLast(self: Self) bool {
            return allowed.len > 0 and self.value == allowed[allowed.len - 1];
        }
    };
}

/// Range-constrained with step.
pub fn Range(comptime T: type, comptime start: comptime_int, comptime end: comptime_int, comptime step: comptime_int) type {
    return struct {
        const Self = @This();
        value: T,
        pub const range_start = start;
        pub const range_end = end;
        pub const range_step = step;
        pub const zigantic_type = .range;

        pub fn init(val: T) errors.ValidationError!Self {
            if (val < start or val > end) return errors.ValidationError.OutOfRange;
            if (@mod(val - start, step) != 0) return errors.ValidationError.NotInStep;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

/// Nullable wrapper with explicit null handling.
pub fn Nullable(comptime T: type) type {
    return struct {
        const Self = @This();
        value: ?T,
        pub const InnerType = T;
        pub const zigantic_type = .nullable;

        pub fn init(val: ?T) Self {
            return Self{ .value = val };
        }
        pub fn initNull() Self {
            return Self{ .value = null };
        }
        pub fn get(self: Self) ?T {
            return self.value;
        }
        pub fn isNull(self: Self) bool {
            return self.value == null;
        }
        pub fn unwrap(self: Self) !T {
            return self.value orelse error.NullValue;
        }
        pub fn unwrapOr(self: Self, default: T) T {
            return self.value orelse default;
        }
    };
}

/// Lazy evaluation wrapper.
pub fn Lazy(comptime T: type) type {
    return struct {
        const Self = @This();
        generator: *const fn () T,
        cached: ?T = null,
        pub const ValueType = T;
        pub const zigantic_type = .lazy;

        pub fn init(gen: *const fn () T) Self {
            return Self{ .generator = gen };
        }
        pub fn get(self: *Self) T {
            if (self.cached) |v| return v;
            self.cached = self.generator();
            return self.cached.?;
        }
        pub fn isComputed(self: Self) bool {
            return self.cached != null;
        }
        pub fn reset(self: *Self) void {
            self.cached = null;
        }
    };
}

test "String basic" {
    const Name = String(1, 50);
    const name = try Name.init("Alice");
    try std.testing.expectEqualStrings("Alice", name.get());
    try std.testing.expect(name.startsWith("Ali"));
    try std.testing.expect(name.charAt(0).? == 'A');
}

test "String slice" {
    const S = String(1, 50);
    const s = try S.init("hello world");
    try std.testing.expectEqualStrings("hello", s.slice(0, 5));
}

test "Secret strength" {
    const Password = Secret(8, 100);
    const weak = try Password.init("password");
    const strong = try Password.init("P@ssw0rd123!");
    try std.testing.expect(weak.strength() < strong.strength());
}

test "StrongPassword" {
    const Pwd = StrongPassword(8, 100);
    _ = try Pwd.init("P@ssw0rd!");
    try std.testing.expectError(errors.ValidationError.WeakPassword, Pwd.init("password"));
}

test "Int utilities" {
    const N = Int(i32, -100, 100);
    const n = try N.init(42);
    try std.testing.expect(n.isEven());
    try std.testing.expect(!n.isOdd());
    try std.testing.expectEqual(@as(i32, 42), n.clamp(0, 50));
}

test "EvenInt" {
    const E = EvenInt(i32, 0, 100);
    _ = try E.init(42);
    try std.testing.expectError(errors.ValidationError.MustBeEven, E.init(43));
}

test "OddInt" {
    const O = OddInt(i32, 0, 100);
    _ = try O.init(43);
    try std.testing.expectError(errors.ValidationError.MustBeOdd, O.init(42));
}

test "MultipleOf" {
    const M = MultipleOf(i32, 5);
    _ = try M.init(25);
    try std.testing.expectError(errors.ValidationError.NotMultiple, M.init(23));
}

test "Float utilities" {
    const F = Float(f64, -100.0, 100.0);
    const f = try F.init(3.7);
    try std.testing.expect(f.floor() == 3.0);
    try std.testing.expect(f.ceil() == 4.0);
}

test "FiniteFloat" {
    const F = FiniteFloat(f64);
    _ = try F.init(3.14);
    try std.testing.expectError(errors.ValidationError.InvalidNumber, F.init(std.math.nan(f64)));
}

test "Email business check" {
    const personal = try Email.init("user@gmail.com");
    const business = try Email.init("user@company.com");
    try std.testing.expect(!personal.isBusinessEmail());
    try std.testing.expect(business.isBusinessEmail());
}

test "Url host" {
    const url = try Url.init("https://example.com/path");
    try std.testing.expectEqualStrings("example.com", url.host());
}

test "HttpsUrl" {
    _ = try HttpsUrl.init("https://example.com");
    try std.testing.expectError(errors.ValidationError.MustBeHttps, HttpsUrl.init("http://example.com"));
}

test "Ipv4 private" {
    const private = try Ipv4.init("192.168.1.1");
    const public = try Ipv4.init("8.8.8.8");
    try std.testing.expect(private.isPrivate());
    try std.testing.expect(!public.isPrivate());
}

test "PhoneNumber country code" {
    const with = try PhoneNumber.init("+1234567890");
    const without = try PhoneNumber.init("1234567890");
    try std.testing.expect(with.hasCountryCode());
    try std.testing.expect(!without.hasCountryCode());
}

test "CreditCard type" {
    const visa = try CreditCard.init("4111111111111111");
    try std.testing.expectEqualStrings("visa", visa.cardType());
}

test "List at" {
    const L = List(u32, 1, 10);
    const items = [_]u32{ 1, 2, 3 };
    const l = try L.init(&items);
    try std.testing.expectEqual(@as(u32, 2), l.at(1).?);
    try std.testing.expect(l.at(10) == null);
}

test "FixedList" {
    const F = FixedList(u32, 3);
    const items = [_]u32{ 1, 2, 3 };
    const f = try F.init(&items);
    try std.testing.expectEqual(@as(u32, 2), f.at(1));
}

test "Default getOrDefault" {
    const D = Default(i32, 42);
    try std.testing.expectEqual(@as(i32, 42), D.getOrDefault(null));
    try std.testing.expectEqual(@as(i32, 10), D.getOrDefault(D.init(10)));
}

test "OneOf position" {
    const Status = OneOf(u8, &[_]u8{ 1, 2, 3 });
    const first = try Status.init(1);
    const last = try Status.init(3);
    try std.testing.expect(first.isFirst());
    try std.testing.expect(last.isLast());
}

test "Range" {
    const R = Range(i32, 0, 100, 10);
    _ = try R.init(50);
    try std.testing.expectError(errors.ValidationError.OutOfRange, R.init(150));
    try std.testing.expectError(errors.ValidationError.NotInStep, R.init(55));
}

test "Nullable" {
    const N = Nullable(i32);
    const some = N.init(42);
    const none = N.initNull();
    try std.testing.expect(!some.isNull());
    try std.testing.expect(none.isNull());
    try std.testing.expectEqual(@as(i32, 42), some.unwrapOr(0));
    try std.testing.expectEqual(@as(i32, 0), none.unwrapOr(0));
}

test "Trimmed wasTrimmed" {
    const T = Trimmed(1, 50);
    const t = try T.init("  hello  ");
    try std.testing.expect(t.wasTrimmed());
}

test "AsciiString" {
    const A = AsciiString(1, 50);
    _ = try A.init("hello");
}

test "Partial" {
    const User = struct { name: []const u8, age: i32 };
    const PartialUser = Partial(User);
    var p: PartialUser = .{};
    p.name = "Alice";
    try std.testing.expect(p.age == null);
}

test "Uuid version" {
    const uuid = try Uuid.init("550e8400-e29b-41d4-a716-446655440000");
    try std.testing.expectEqual(@as(?u8, 4), uuid.version());
}

test "Semver" {
    const s = try Semver.init("1.2.3");
    try std.testing.expectEqualStrings("1.2.3", s.get());
}

test "Ipv6 loopback" {
    const ip = try Ipv6.init("::1");
    try std.testing.expect(ip.isLoopback());
}

test "Ipv4 loopback" {
    const ip = try Ipv4.init("127.0.0.1");
    try std.testing.expect(ip.isLoopback());
}

test "String with custom messages" {
    const CustomName = Stringf(1, 50, .{ .too_short = "name is required" });
    const name = try CustomName.init("Alice");
    try std.testing.expectEqualStrings("Alice", name.get());
    const err = CustomName.init("");
    try std.testing.expect(err == error.TooShort);
    try std.testing.expectEqualStrings("name is required", CustomName.messageFor(error.TooShort).?);
}

test "Int with custom messages" {
    const CustomAge = Intf(i32, 18, 120, .{ .too_small = "must be 18 or older" });
    const age = try CustomAge.init(25);
    try std.testing.expectEqual(@as(i32, 25), age.get());
    try std.testing.expectEqualStrings("must be 18 or older", CustomAge.messageFor(error.TooSmall).?);
}

test "List with custom messages" {
    const CustomList = Listf(u32, 2, 5, .{ .too_few_items = "need at least 2 items" });
    const items = [_]u32{ 1, 2, 3 };
    const list = try CustomList.init(&items);
    try std.testing.expectEqual(@as(usize, 3), list.len());
    try std.testing.expectEqualStrings("need at least 2 items", CustomList.messageFor(error.TooFewItems).?);
}

test "Secret with custom messages" {
    const CustomPwd = Secretf(8, 100, .{ .too_short = "password must be at least 8 chars" });
    try std.testing.expectEqualStrings("password must be at least 8 chars", CustomPwd.messageFor(error.TooShort).?);
}

test "StrongPassword with custom messages" {
    const CustomPwd = StrongPasswordf(8, 100, .{ .weak_password = "password needs upper, lower, digit, and special" });
    try std.testing.expectEqualStrings("password needs upper, lower, digit, and special", CustomPwd.messageFor(error.WeakPassword).?);
}

test "Float with custom messages" {
    const CustomF = Floatf(f64, -100.0, 100.0, .{ .too_small = "value too low" });
    try std.testing.expectEqualStrings("value too low", CustomF.messageFor(error.TooSmall).?);
}

test "MultipleOf with custom messages" {
    const CustomM = MultipleOff(i32, 5, .{ .not_multiple = "must be divisible by 5" });
    try std.testing.expectEqualStrings("must be divisible by 5", CustomM.messageFor(error.NotMultiple).?);
}

test "EvenInt with custom messages" {
    const CustomE = EvenIntf(i32, 0, 100, .{ .must_be_even = "only even numbers allowed" });
    try std.testing.expectEqualStrings("only even numbers allowed", CustomE.messageFor(error.MustBeEven).?);
}

test "OddInt with custom messages" {
    const CustomO = OddIntf(i32, 0, 100, .{ .must_be_odd = "only odd numbers allowed" });
    try std.testing.expectEqualStrings("only odd numbers allowed", CustomO.messageFor(error.MustBeOdd).?);
}

test "HexString with custom messages" {
    const CustomH = HexStringf(3, 6, .{ .invalid_format = "must be valid hex" });
    try std.testing.expectEqualStrings("must be valid hex", CustomH.messageFor(error.InvalidFormat).?);
}

test "Trimmed with custom messages" {
    const CustomT = Trimmedf(1, 50, .{ .too_short = "must not be empty" });
    try std.testing.expectEqualStrings("must not be empty", CustomT.messageFor(error.TooShort).?);
}

test "NonEmptyString with custom messages" {
    const CustomN = NonEmptyStringf(50, .{ .too_short = "cannot be empty" });
    try std.testing.expectEqualStrings("cannot be empty", CustomN.messageFor(error.TooShort).?);
}

test "UInt with custom messages" {
    const CustomU = UIntf(u32, 1, 100, .{ .too_small = "must be at least 1" });
    try std.testing.expectEqualStrings("must be at least 1", CustomU.messageFor(error.TooSmall).?);
}

test "PositiveInt with custom messages" {
    const CustomP = PositiveIntf(i32, .{ .too_small = "must be positive" });
    try std.testing.expectEqualStrings("must be positive", CustomP.messageFor(error.TooSmall).?);
}

test "FixedList with custom messages" {
    const CustomF = FixedListf(u32, 3, .{ .wrong_length = "must have exactly 3 items" });
    try std.testing.expectEqualStrings("must have exactly 3 items", CustomF.messageFor(error.WrongLength).?);
}

test "Iban" {
    const iban = try Iban.init("DE89370400440532013000");
    try std.testing.expectEqualStrings("DE", iban.countryCode());
    try std.testing.expectEqual(@as(usize, 22), iban.normalizedLength());
    try std.testing.expectError(errors.ValidationError.InvalidFormat, Iban.init("DE89"));
}

test "Base58" {
    const b58 = try Base58.init("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa");
    try std.testing.expectEqual(@as(usize, 34), b58.len());
    try std.testing.expectError(errors.ValidationError.InvalidFormat, Base58.init("0OIl"));
}

test "HslColor" {
    const hsl = try HslColor.init("hsl(120, 100%, 50%)");
    try std.testing.expectEqualStrings("hsl(120, 100%, 50%)", hsl.get());
    try std.testing.expectError(errors.ValidationError.InvalidFormat, HslColor.init("rgb(255, 0, 0)"));
}

test "Duration" {
    const dur = try Duration.init("P1Y2M3DT4H5M6S");
    try std.testing.expect(dur.hasTime());
    const no_time = try Duration.init("P30D");
    try std.testing.expect(!no_time.hasTime());
    try std.testing.expectError(errors.ValidationError.InvalidFormat, Duration.init("1Y2M"));
}

test "CronExpression" {
    const cron = try CronExpression.init("0 12 * * *");
    try std.testing.expectEqual(@as(u32, 5), cron.fieldCount());
    try std.testing.expectError(errors.ValidationError.InvalidFormat, CronExpression.init("0 12 *"));
}

test "Isbn10" {
    const isbn = try Isbn10.init("0-306-40615-2");
    try std.testing.expectEqualStrings("0-306-40615-2", isbn.get());
    try std.testing.expectError(errors.ValidationError.InvalidFormat, Isbn10.init("1234567890"));
}

test "Isbn13" {
    const isbn = try Isbn13.init("978-0-306-40615-7");
    try std.testing.expectEqualStrings("978-0-306-40615-7", isbn.get());
    try std.testing.expectError(errors.ValidationError.InvalidFormat, Isbn13.init("978-0-306-40615-0"));
}

test "AsciiAlphaString" {
    const Name = AsciiAlphaString(1, 50);
    const name = try Name.init("Hello");
    try std.testing.expectEqualStrings("Hello", name.get());
    try std.testing.expectEqual(@as(usize, 5), name.len());
    try std.testing.expectError(errors.ValidationError.InvalidFormat, Name.init("Hello123"));
}

test "AsciiPrintableString" {
    const S = AsciiPrintableString(1, 100);
    const s = try S.init("Hello, World!");
    try std.testing.expectEqualStrings("Hello, World!", s.get());
}

test "StrongPasswordStrict" {
    const pwd = try StrongPasswordStrict.init("P@ssw0rd!");
    try std.testing.expectEqualStrings("P@ssw0rd!", pwd.get());
    try std.testing.expectEqualStrings("********", pwd.masked());
    try std.testing.expectError(errors.ValidationError.WeakPassword, StrongPasswordStrict.init("password"));
}

test "Email new methods" {
    const email = try Email.init("user+tag@gmail.com");
    try std.testing.expect(email.hasTag());
    try std.testing.expectEqualStrings("tag", email.tag().?);
    try std.testing.expectEqualStrings("com", email.tld());
    try std.testing.expect(email.isFreeEmail());

    const biz = try Email.init("user@company.com");
    try std.testing.expect(biz.isBusinessEmail());
    try std.testing.expect(!biz.hasTag());
    try std.testing.expect(biz.tag() == null);
}

test "Url new methods" {
    const url = try Url.init("https://example.com:8080/path?q=1#section");
    try std.testing.expectEqualStrings("example.com", url.host());
    try std.testing.expectEqualStrings("/path", url.path());
    try std.testing.expectEqualStrings("q=1", url.query().?);
    try std.testing.expectEqualStrings("section", url.fragment().?);
    try std.testing.expectEqual(@as(?u16, 8080), url.port());
    try std.testing.expect(url.hasQuery());
    try std.testing.expect(url.hasFragment());
    try std.testing.expectEqualStrings("path", url.filename());
}

test "List new methods" {
    const L = List(u32, 1, 10);
    const items = [_]u32{ 1, 2, 3, 4, 5 };
    const list = try L.init(&items);
    try std.testing.expectEqual(@as(u32, 15), list.sum());
    try std.testing.expect(list.all(struct {
        fn f(n: u32) bool {
            return n > 0;
        }
    }.f));
    try std.testing.expect(list.any(struct {
        fn f(n: u32) bool {
            return n == 3;
        }
    }.f));
    try std.testing.expectEqual(@as(?usize, 2), list.findIndex(struct {
        fn f(n: u32) bool {
            return n == 3;
        }
    }.f));
    try std.testing.expectEqual(@as(?u32, 3), list.at(2));
    try std.testing.expectEqual(@as(?u32, null), list.at(10));
}
