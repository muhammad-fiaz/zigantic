//! Allocation-free civil date and time arithmetic.
//!
//! Dates use the proleptic Gregorian calendar and days are counted from
//! 1970-01-01. `DateTime` keeps a fixed UTC offset, so arithmetic is exact for
//! the offset supplied by the caller; time-zone database transitions are not
//! modelled.

const std = @import("std");

pub const Error = error{ InvalidDate, InvalidTime, InvalidDateTime };

pub const Weekday = enum(u3) {
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
};

pub fn isLeapYear(year: i32) bool {
    return (@mod(year, 4) == 0 and @mod(year, 100) != 0) or @mod(year, 400) == 0;
}

pub fn daysInMonth(year: i32, month: u8) u8 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => 0,
    };
}

fn daysFromCivil(year: i32, month: u8, day: u8) i64 {
    var y: i64 = year;
    if (month <= 2) y -= 1;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const mp: i64 = @mod(@as(i64, month) + 9, 12);
    const doy = @divFloor(153 * mp + 2, 5) + @as(i64, day) - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

fn civilFromDays(days: i64) struct { year: i32, month: u8, day: u8 } {
    const z = days + 719468;
    const era = @divFloor(z, 146097);
    const doe = z - era * 146097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    const y = yoe + era * 400;
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const d = doy - @divFloor(153 * mp + 2, 5) + 1;
    const m = mp + (if (mp < 10) @as(i64, 3) else -9);
    const year = y + (if (m <= 2) @as(i64, 1) else 0);
    return .{ .year = @intCast(year), .month = @intCast(m), .day = @intCast(d) };
}

fn twoDigits(text: []const u8) ?u8 {
    if (text.len != 2 or !std.ascii.isDigit(text[0]) or !std.ascii.isDigit(text[1])) return null;
    return (text[0] - '0') * 10 + (text[1] - '0');
}

pub const Date = struct {
    year: i32,
    month: u8,
    day: u8,

    pub fn init(year: i32, month: u8, day: u8) Error!Date {
        if (month < 1 or month > 12 or day < 1 or day > daysInMonth(year, month)) return error.InvalidDate;
        return .{ .year = year, .month = month, .day = day };
    }

    pub fn parse(text: []const u8) Error!Date {
        if (text.len != 10 or text[4] != '-' or text[7] != '-') return error.InvalidDate;
        const year = std.fmt.parseInt(i32, text[0..4], 10) catch return error.InvalidDate;
        const month = twoDigits(text[5..7]) orelse return error.InvalidDate;
        const day = twoDigits(text[8..10]) orelse return error.InvalidDate;
        return init(year, month, day);
    }

    pub fn format(self: Date, buffer: []u8) error{NoSpaceLeft}![]const u8 {
        if (self.year < 0) {
            return std.fmt.bufPrint(buffer, "-{d:0>4}-{d:0>2}-{d:0>2}", .{ @as(u32, @intCast(-self.year)), self.month, self.day });
        }
        return std.fmt.bufPrint(buffer, "{d:0>4}-{d:0>2}-{d:0>2}", .{ @as(u32, @intCast(self.year)), self.month, self.day });
    }

    pub fn daysSinceEpoch(self: Date) i64 {
        return daysFromCivil(self.year, self.month, self.day);
    }

    pub fn fromDaysSinceEpoch(days: i64) Date {
        const civil = civilFromDays(days);
        return .{ .year = civil.year, .month = civil.month, .day = civil.day };
    }

    pub fn weekday(self: Date) Weekday {
        const index: u3 = @intCast(@mod(self.daysSinceEpoch() + 3, 7));
        return @fromBackingInt(@intCast(index));
    }

    pub fn dayOfYear(self: Date) u16 {
        var total: u16 = self.day;
        var month: u8 = 1;
        while (month < self.month) : (month += 1) total += daysInMonth(self.year, month);
        return total;
    }

    pub fn addDays(self: Date, days: i64) Date {
        return fromDaysSinceEpoch(self.daysSinceEpoch() + days);
    }

    pub fn addMonths(self: Date, months: i64) Date {
        const total = @as(i64, self.year) * 12 + @as(i64, self.month) - 1 + months;
        const year: i32 = @intCast(@divFloor(total, 12));
        const month: u8 = @intCast(@mod(total, 12) + 1);
        const day = @min(self.day, daysInMonth(year, month));
        return .{ .year = year, .month = month, .day = day };
    }

    pub fn addYears(self: Date, years: i32) Date {
        return self.addMonths(@as(i64, years) * 12);
    }

    /// Signed number of days from `self` to `other`.
    pub fn daysUntil(self: Date, other: Date) i64 {
        return other.daysSinceEpoch() - self.daysSinceEpoch();
    }

    pub fn compare(self: Date, other: Date) std.math.Order {
        return std.math.order(self.daysSinceEpoch(), other.daysSinceEpoch());
    }

    pub fn eql(self: Date, other: Date) bool {
        return self.year == other.year and self.month == other.month and self.day == other.day;
    }
};

pub const Time = struct {
    hour: u8 = 0,
    minute: u8 = 0,
    second: u8 = 0,
    nanosecond: u32 = 0,

    pub fn init(hour: u8, minute: u8, second: u8, nanosecond: u32) Error!Time {
        if (hour > 23 or minute > 59 or second > 59 or nanosecond > 999_999_999) return error.InvalidTime;
        return .{ .hour = hour, .minute = minute, .second = second, .nanosecond = nanosecond };
    }

    pub fn parse(text: []const u8) Error!Time {
        if (text.len < 5 or text[2] != ':') return error.InvalidTime;
        const hour = twoDigits(text[0..2]) orelse return error.InvalidTime;
        const minute = twoDigits(text[3..5]) orelse return error.InvalidTime;
        var second: u8 = 0;
        var nanosecond: u32 = 0;
        if (text.len > 5) {
            if (text[5] != ':' or text.len < 8) return error.InvalidTime;
            second = twoDigits(text[6..8]) orelse return error.InvalidTime;
            if (text.len > 8) {
                if (text[8] != '.') return error.InvalidTime;
                const fraction = text[9..];
                if (fraction.len == 0) return error.InvalidTime;
                var value: u32 = 0;
                for (fraction, 0..) |c, index| {
                    if (!std.ascii.isDigit(c)) return error.InvalidTime;
                    if (index < 9) value = value * 10 + (c - '0');
                }
                var scale = fraction.len;
                while (scale < 9) : (scale += 1) value *= 10;
                nanosecond = value;
            }
        }
        return init(hour, minute, second, nanosecond);
    }

    pub fn format(self: Time, buffer: []u8) error{NoSpaceLeft}![]const u8 {
        if (self.nanosecond == 0) {
            return std.fmt.bufPrint(buffer, "{d:0>2}:{d:0>2}:{d:0>2}", .{ self.hour, self.minute, self.second });
        }
        return std.fmt.bufPrint(buffer, "{d:0>2}:{d:0>2}:{d:0>2}.{d:0>9}", .{ self.hour, self.minute, self.second, self.nanosecond });
    }

    pub fn seconds(self: Time) u32 {
        return @as(u32, self.hour) * 3600 + @as(u32, self.minute) * 60 + self.second;
    }

    pub fn addSeconds(self: Time, amount: i64) struct { time: Time, days: i32 } {
        const total = @as(i64, self.seconds()) + amount;
        const days = @divFloor(total, 86400);
        const in_day = @mod(total, 86400);
        const hour: u8 = @intCast(@divFloor(in_day, 3600));
        const minute: u8 = @intCast(@divFloor(@mod(in_day, 3600), 60));
        const second: u8 = @intCast(@mod(in_day, 60));
        return .{ .time = .{ .hour = hour, .minute = minute, .second = second, .nanosecond = self.nanosecond }, .days = @intCast(days) };
    }

    pub fn compare(self: Time, other: Time) std.math.Order {
        if (self.hour != other.hour) return std.math.order(self.hour, other.hour);
        if (self.minute != other.minute) return std.math.order(self.minute, other.minute);
        if (self.second != other.second) return std.math.order(self.second, other.second);
        return std.math.order(self.nanosecond, other.nanosecond);
    }
};

const Offset = struct {
    minutes: i16 = 0,

    fn parse(text: []const u8) ?Offset {
        if (text.len == 1 and (text[0] == 'Z' or text[0] == 'z')) return .{};
        if (text.len != 6 or (text[0] != '+' and text[0] != '-') or text[3] != ':') return null;
        const hour = twoDigits(text[1..3]) orelse return null;
        const minute = twoDigits(text[4..6]) orelse return null;
        if (hour > 23 or minute > 59) return null;
        const sign: i16 = if (text[0] == '-') -1 else 1;
        return .{ .minutes = sign * (@as(i16, hour) * 60 + @as(i16, minute)) };
    }

    fn format(self: Offset, buffer: []u8) error{NoSpaceLeft}![]const u8 {
        if (self.minutes == 0) {
            if (buffer.len == 0) return error.NoSpaceLeft;
            buffer[0] = 'Z';
            return buffer[0..1];
        }
        const total: i16 = if (self.minutes < 0) -self.minutes else self.minutes;
        return std.fmt.bufPrint(buffer, "{c}{d:0>2}:{d:0>2}", .{
            if (self.minutes < 0) @as(u8, '-') else @as(u8, '+'),
            @as(u32, @intCast(@divFloor(total, 60))),
            @as(u32, @intCast(@mod(total, 60))),
        });
    }
};

pub const DateTime = struct {
    date: Date,
    time: Time,
    offset_minutes: i16 = 0,

    pub fn init(date: Date, time: Time, offset_minutes: i16) Error!DateTime {
        if (offset_minutes < -1439 or offset_minutes > 1439) return error.InvalidDateTime;
        return .{ .date = date, .time = time, .offset_minutes = offset_minutes };
    }

    pub fn parse(text: []const u8) Error!DateTime {
        const separator = std.mem.findScalar(u8, text, 'T') orelse
            std.mem.findScalar(u8, text, 't') orelse
            std.mem.findScalar(u8, text, ' ') orelse return error.InvalidDateTime;
        const date = try Date.parse(text[0..separator]);
        var rest = text[separator + 1 ..];
        var offset: Offset = .{};
        if (rest.len > 0) {
            const last = rest.len - 1;
            if (rest[last] == 'Z' or rest[last] == 'z') {
                offset = .{};
                rest = rest[0..last];
            } else if (std.mem.lastIndexOfScalar(u8, rest, '+') orelse std.mem.lastIndexOfScalar(u8, rest, '-')) |position| {
                if (position > 0) {
                    offset = Offset.parse(rest[position..]) orelse return error.InvalidDateTime;
                    rest = rest[0..position];
                }
            }
        }
        const time = try Time.parse(rest);
        return init(date, time, offset.minutes);
    }

    pub fn format(self: DateTime, buffer: []u8) error{NoSpaceLeft}![]const u8 {
        var date_buffer: [16]u8 = undefined;
        const date_text = try self.date.format(&date_buffer);
        var time_buffer: [24]u8 = undefined;
        const time_text = try self.time.format(&time_buffer);
        var offset_buffer: [8]u8 = undefined;
        const offset_text = try (Offset{ .minutes = self.offset_minutes }).format(&offset_buffer);
        return std.fmt.bufPrint(buffer, "{s}T{s}{s}", .{ date_text, time_text, offset_text });
    }

    /// Seconds since the Unix epoch, adjusted for the fixed offset.
    pub fn timestamp(self: DateTime) i64 {
        return self.date.daysSinceEpoch() * 86400 + self.time.seconds() - @as(i64, self.offset_minutes) * 60;
    }

    pub fn fromTimestamp(unix_seconds: i64, offset_minutes: i16) DateTime {
        const local = unix_seconds + @as(i64, offset_minutes) * 60;
        const days = @divFloor(local, 86400);
        const seconds = @mod(local, 86400);
        return .{
            .date = Date.fromDaysSinceEpoch(days),
            .time = .{
                .hour = @intCast(@divFloor(seconds, 3600)),
                .minute = @intCast(@divFloor(@mod(seconds, 3600), 60)),
                .second = @intCast(@mod(seconds, 60)),
            },
            .offset_minutes = offset_minutes,
        };
    }

    pub fn addSeconds(self: DateTime, seconds: i64) DateTime {
        return fromTimestamp(self.timestamp() + seconds, self.offset_minutes);
    }

    pub fn addDays(self: DateTime, days: i64) DateTime {
        return self.addSeconds(days * 86400);
    }

    pub fn dateDifference(self: DateTime, other: DateTime) i64 {
        return other.date.daysUntil(self.date);
    }

    pub fn compare(self: DateTime, other: DateTime) std.math.Order {
        return std.math.order(self.timestamp(), other.timestamp());
    }
};

test "date parsing, weekdays and arithmetic" {
    const date = try Date.parse("2024-02-29");
    try std.testing.expectEqual(Weekday.thursday, date.weekday());
    try std.testing.expectEqual(@as(u16, 60), date.dayOfYear());
    try std.testing.expect(date.addDays(1).eql(try Date.parse("2024-03-01")));
    try std.testing.expect(date.addYears(1).eql(try Date.parse("2025-02-28")));
    try std.testing.expect(date.addMonths(-1).eql(try Date.parse("2024-01-29")));
    try std.testing.expectEqual(@as(i64, 2), date.daysUntil(try Date.parse("2024-03-02")));

    var buffer: [16]u8 = undefined;
    try std.testing.expectEqualStrings("2024-02-29", try date.format(&buffer));
    try std.testing.expectError(error.InvalidDate, Date.parse("2023-02-29"));
}

test "time and datetime arithmetic honour offsets" {
    const time = try Time.parse("23:59:59.5");
    const shifted = time.addSeconds(2);
    try std.testing.expectEqual(@as(u8, 0), shifted.time.hour);
    try std.testing.expectEqual(@as(u8, 1), shifted.time.second);
    try std.testing.expectEqual(@as(i32, 1), shifted.days);

    const value = try DateTime.parse("2024-02-29T23:30:00+02:00");
    try std.testing.expectEqual(@as(i16, 120), value.offset_minutes);
    const next = value.addSeconds(3600);
    try std.testing.expectEqual(@as(u8, 0), next.time.hour);
    try std.testing.expectEqual(@as(u16, 1), next.date.day);

    var buffer: [40]u8 = undefined;
    try std.testing.expectEqualStrings("2024-03-01T00:30:00+02:00", try next.format(&buffer));
    try std.testing.expectEqual(value.timestamp(), (try DateTime.parse("2024-02-29T21:30:00Z")).timestamp());
}
