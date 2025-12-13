//! # Advanced Validation Types
//!
//! Compile-time validated wrapper types with advanced features.

const std = @import("std");
const validators = @import("validators.zig");
const errors = @import("errors.zig");

// ============================================================================
// STRING TYPES
// ============================================================================

/// String with length constraints and helper methods.
pub fn String(comptime min_len: usize, comptime max_len: usize) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .string;

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
            return std.mem.indexOf(u8, self.value, needle) != null;
        }
        pub fn charAt(self: Self, index: usize) ?u8 {
            return if (index < self.value.len) self.value[index] else null;
        }
        pub fn slice(self: Self, start: usize, end: usize) []const u8 {
            const s = @min(start, self.value.len);
            const e = @min(end, self.value.len);
            return self.value[s..e];
        }
    };
}

/// Non-empty string.
pub fn NonEmptyString(comptime max_len: usize) type {
    return String(1, max_len);
}

/// Trimmed string with auto-whitespace removal.
pub fn Trimmed(comptime min_len: usize, comptime max_len: usize) type {
    return struct {
        const Self = @This();
        value: []const u8,
        original: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .trimmed;

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
    };
}

/// Lowercase string.
pub fn Lowercase(comptime max_len: usize) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const max = max_len;
        pub const zigantic_type = .lowercase;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len > max_len) return errors.ValidationError.TooLong;
            for (str) |c| {
                if (c >= 'A' and c <= 'Z') return errors.ValidationError.MustBeLowercase;
            }
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
    };
}

/// Uppercase string.
pub fn Uppercase(comptime max_len: usize) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const max = max_len;
        pub const zigantic_type = .uppercase;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len > max_len) return errors.ValidationError.TooLong;
            for (str) |c| {
                if (c >= 'a' and c <= 'z') return errors.ValidationError.MustBeUppercase;
            }
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
    };
}

/// Alphanumeric string.
pub fn Alphanumeric(comptime min_len: usize, comptime max_len: usize) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .alphanumeric;

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
    };
}

/// ASCII-only string.
pub fn AsciiString(comptime min_len: usize, comptime max_len: usize) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .ascii;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            for (str) |c| {
                if (c > 127) return errors.ValidationError.InvalidFormat;
            }
            return Self{ .value = str };
        }
        pub fn get(self: Self) []const u8 {
            return self.value;
        }
    };
}

/// Secret/password string with strength checking.
pub fn Secret(comptime min_len: usize, comptime max_len: usize) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .secret;
        pub const is_secret = true;

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
                if (c >= 'A' and c <= 'Z') return true;
            }
            return false;
        }
        pub fn hasLowercase(self: Self) bool {
            for (self.value) |c| {
                if (c >= 'a' and c <= 'z') return true;
            }
            return false;
        }
        pub fn hasDigit(self: Self) bool {
            for (self.value) |c| {
                if (c >= '0' and c <= '9') return true;
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
    };
}

/// Strong password with requirements.
pub fn StrongPassword(comptime min_len: usize, comptime max_len: usize) type {
    return struct {
        const Self = @This();
        value: []const u8,
        pub const min = min_len;
        pub const max = max_len;
        pub const zigantic_type = .strong_password;

        pub fn init(str: []const u8) errors.ValidationError!Self {
            if (str.len < min_len) return errors.ValidationError.TooShort;
            if (str.len > max_len) return errors.ValidationError.TooLong;
            var has_upper = false;
            var has_lower = false;
            var has_digit = false;
            var has_special = false;
            for (str) |c| {
                if (c >= 'A' and c <= 'Z') has_upper = true else if (c >= 'a' and c <= 'z') has_lower = true else if (c >= '0' and c <= '9') has_digit = true else has_special = true;
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
    };
}

// ============================================================================
// NUMBER TYPES
// ============================================================================

/// Signed integer with range and utilities.
pub fn Int(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const IntType = T;
        pub const zigantic_type = .int;

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
    };
}

/// Unsigned integer with range.
pub fn UInt(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const IntType = T;
        pub const zigantic_type = .uint;

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
    };
}

pub fn PositiveInt(comptime T: type) type {
    return Int(T, 1, std.math.maxInt(T));
}
pub fn NonNegativeInt(comptime T: type) type {
    return Int(T, 0, std.math.maxInt(T));
}
pub fn NegativeInt(comptime T: type) type {
    return Int(T, std.math.minInt(T), -1);
}

/// Even number only.
pub fn EvenInt(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const zigantic_type = .even;

        pub fn init(val: T) errors.ValidationError!Self {
            if (val < min_val) return errors.ValidationError.TooSmall;
            if (val > max_val) return errors.ValidationError.TooLarge;
            if (@mod(val, 2) != 0) return errors.ValidationError.MustBeEven;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

/// Odd number only.
pub fn OddInt(comptime T: type, comptime min_val: comptime_int, comptime max_val: comptime_int) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const zigantic_type = .odd;

        pub fn init(val: T) errors.ValidationError!Self {
            if (val < min_val) return errors.ValidationError.TooSmall;
            if (val > max_val) return errors.ValidationError.TooLarge;
            if (@mod(val, 2) == 0) return errors.ValidationError.MustBeOdd;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

/// Multiple of N.
pub fn MultipleOf(comptime T: type, comptime divisor: comptime_int) type {
    return struct {
        const Self = @This();
        value: T,
        pub const multiple = divisor;
        pub const zigantic_type = .multiple;

        pub fn init(val: T) errors.ValidationError!Self {
            if (@mod(val, divisor) != 0) return errors.ValidationError.NotMultiple;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

/// Float with range and utilities.
pub fn Float(comptime T: type, comptime min_val: comptime_float, comptime max_val: comptime_float) type {
    return struct {
        const Self = @This();
        value: T,
        pub const min = min_val;
        pub const max = max_val;
        pub const FloatType = T;
        pub const zigantic_type = .float;

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
    };
}

pub fn Percentage(comptime T: type) type {
    return Float(T, 0.0, 100.0);
}
pub fn Probability(comptime T: type) type {
    return Float(T, 0.0, 1.0);
}
pub fn PositiveFloat(comptime T: type) type {
    return Float(T, 0.0, std.math.floatMax(T));
}
pub fn NegativeFloat(comptime T: type) type {
    return Float(T, -std.math.floatMax(T), 0.0);
}

/// Finite float (no NaN or Inf).
pub fn FiniteFloat(comptime T: type) type {
    return struct {
        const Self = @This();
        value: T,
        pub const FloatType = T;
        pub const zigantic_type = .finite_float;

        pub fn init(val: T) errors.ValidationError!Self {
            if (std.math.isNan(val) or std.math.isInf(val)) return errors.ValidationError.InvalidNumber;
            return Self{ .value = val };
        }
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

// ============================================================================
// FORMAT TYPES
// ============================================================================

/// Email with utilities.
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

// ============================================================================
// COLLECTION TYPES
// ============================================================================

pub fn List(comptime T: type, comptime min_len: usize, comptime max_len: usize) type {
    return struct {
        const Self = @This();
        items: []const T,
        pub const min = min_len;
        pub const max = max_len;
        pub const ItemType = T;
        pub const zigantic_type = .list;

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
    };
}

pub fn NonEmptyList(comptime T: type, comptime max_len: usize) type {
    return List(T, 1, max_len);
}

/// Fixed-size tuple/array.
pub fn FixedList(comptime T: type, comptime exact_len: usize) type {
    return struct {
        const Self = @This();
        items: []const T,
        pub const length = exact_len;
        pub const ItemType = T;
        pub const zigantic_type = .fixed_list;

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
    };
}

// ============================================================================
// SPECIAL TYPES
// ============================================================================

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
    var new_fields: [fields.len]std.builtin.Type.StructField = undefined;

    for (fields, 0..) |field, i| {
        const OptionalType = ?field.type;
        new_fields[i] = .{
            .name = field.name,
            .type = OptionalType,
            .default_value_ptr = @ptrCast(&@as(OptionalType, null)),
            .is_comptime = false,
            .alignment = @alignOf(OptionalType),
        };
    }

    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &new_fields,
        .decls = &.{},
        .is_tuple = false,
    } });
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

// ============================================================================
// TESTS
// ============================================================================

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
