const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    z.disableUpdateCheck();
    std.debug.print("=== Extended Types & Features ===\n\n", .{});

    // --- IBAN Validation ---
    std.debug.print("--- IBAN Validation ---\n", .{});
    const iban = try z.Iban.init("DE89370400440532013000");
    std.debug.print("IBAN: {s}\n", .{iban.get()});
    std.debug.print("Country: {s}\n", .{iban.countryCode()});
    std.debug.print("Length: {d}\n\n", .{iban.normalizedLength()});

    // --- Base58 Validation ---
    std.debug.print("--- Base58 Validation ---\n", .{});
    const b58 = try z.Base58.init("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa");
    std.debug.print("Base58: {s} (len: {d})\n\n", .{ b58.get(), b58.len() });

    // --- Duration Validation ---
    std.debug.print("--- Duration Validation ---\n", .{});
    const dur = try z.Duration.init("P1Y2M3DT4H5M6S");
    std.debug.print("Duration: {s} (has time: {})\n\n", .{ dur.get(), dur.hasTime() });

    // --- Cron Expression ---
    std.debug.print("--- Cron Expression ---\n", .{});
    const cron = try z.CronExpression.init("0 12 * * *");
    std.debug.print("Cron: {s} (fields: {d})\n\n", .{ cron.get(), cron.fieldCount() });

    // --- ISBN Validation ---
    std.debug.print("--- ISBN Validation ---\n", .{});
    const isbn10 = try z.Isbn10.init("0-306-40615-2");
    std.debug.print("ISBN-10: {s}\n", .{isbn10.get()});
    const isbn13 = try z.Isbn13.init("978-0-306-40615-7");
    std.debug.print("ISBN-13: {s}\n\n", .{isbn13.get()});

    // --- Strong Password (built-in) ---
    std.debug.print("--- Strong Password ---\n", .{});
    const pwd = try z.StrongPasswordStrict.init("P@ssw0rd!");
    std.debug.print("Password masked: {s} (len: {d})\n\n", .{ pwd.masked(), pwd.len() });

    // --- Email Extended Methods ---
    std.debug.print("--- Email Extended Methods ---\n", .{});
    const email = try z.Email.init("user+tag@gmail.com");
    std.debug.print("Email: {s}\n", .{email.get()});
    std.debug.print("  Domain: {s}\n", .{email.domain()});
    std.debug.print("  TLD: {s}\n", .{email.tld()});
    std.debug.print("  Local: {s}\n", .{email.localPart()});
    std.debug.print("  Tag: {s}\n", .{email.tag() orelse "none"});
    std.debug.print("  Has tag: {}\n", .{email.hasTag()});
    std.debug.print("  Free email: {}\n", .{email.isFreeEmail()});
    std.debug.print("  Business email: {}\n\n", .{email.isBusinessEmail()});

    // --- URL Extended Methods ---
    std.debug.print("--- URL Extended Methods ---\n", .{});
    const url = try z.Url.init("https://example.com:8080/path?q=1#section");
    std.debug.print("URL: {s}\n", .{url.get()});
    std.debug.print("  Protocol: {s}\n", .{url.protocol()});
    std.debug.print("  Host: {s}\n", .{url.host()});
    std.debug.print("  Port: {d}\n", .{url.port() orelse 0});
    std.debug.print("  Path: {s}\n", .{url.path()});
    std.debug.print("  Query: {s}\n", .{url.query() orelse "none"});
    std.debug.print("  Fragment: {s}\n", .{url.fragment() orelse "none"});
    std.debug.print("  Filename: {s}\n\n", .{url.filename()});

    // --- List Extended Methods ---
    std.debug.print("--- List Extended Methods ---\n", .{});
    const L = z.List(u32, 1, 10);
    const items = [_]u32{ 10, 20, 30, 40, 50 };
    const list = try L.init(&items);
    std.debug.print("List: ", .{});
    for (list.get()) |item| {
        std.debug.print("{d} ", .{item});
    }
    std.debug.print("\n", .{});
    std.debug.print("  Sum: {d}\n", .{list.sum()});
    std.debug.print("  All > 0: {}\n", .{list.all(struct {
        fn f(n: u32) bool {
            return n > 0;
        }
    }.f)});
    std.debug.print("  Any == 30: {}\n", .{list.any(struct {
        fn f(n: u32) bool {
            return n == 30;
        }
    }.f)});
    std.debug.print("  Index of 30: {d}\n\n", .{list.findIndex(struct {
        fn f(n: u32) bool {
            return n == 30;
        }
    }.f) orelse 999});

    // --- Config Options ---
    std.debug.print("--- Config Options ---\n", .{});
    z.setConfig(.{
        .max_errors = 5,
        .reject_unknown_fields = true,
        .trim_strings = true,
        .lowercase_strings = false,
        .collect_all_errors = true,
        .include_value_in_error = true,
    });
    const cfg = z.getConfig();
    std.debug.print("max_errors: {d}\n", .{cfg.max_errors orelse 0});
    std.debug.print("reject_unknown_fields: {}\n", .{cfg.reject_unknown_fields});
    std.debug.print("trim_strings: {}\n", .{cfg.trim_strings});
    std.debug.print("collect_all_errors: {}\n\n", .{cfg.collect_all_errors});

    // --- Color Overrides ---
    std.debug.print("--- Color Overrides ---\n", .{});
    z.setColorOverrides(.{
        .too_short = .bright_red,
        .invalid_email = .magenta,
        .weak_password = .yellow,
    });
    std.debug.print("Color overrides set successfully\n\n", .{});

    // --- AsciiAlphaString ---
    std.debug.print("--- AsciiAlphaString ---\n", .{});
    const AlphaName = z.AsciiAlphaString(3, 20);
    const name = try AlphaName.init("Alice");
    std.debug.print("Name: {s} (len: {d})\n\n", .{ name.get(), name.len() });

    std.debug.print("=== Done ===\n", .{});
}
