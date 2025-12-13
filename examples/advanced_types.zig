//! Advanced Types Example - All validation types and features

const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    std.debug.print("=== zigantic Advanced Types ===\n\n", .{});

    // String types
    std.debug.print("--- String Types ---\n", .{});
    const name = try z.String(1, 50).init("Alice");
    std.debug.print("String: '{s}' (len: {d}, starts with 'Ali': {})\n", .{ name.get(), name.len(), name.startsWith("Ali") });

    const trimmed = try z.Trimmed(1, 50).init("  hello world  ");
    std.debug.print("Trimmed: '{s}' (was trimmed: {})\n", .{ trimmed.get(), trimmed.wasTrimmed() });

    const lowercase = try z.Lowercase(50).init("hello");
    std.debug.print("Lowercase: '{s}'\n", .{lowercase.get()});

    const ascii = try z.AsciiString(1, 50).init("hello123");
    std.debug.print("ASCII: '{s}'\n", .{ascii.get()});

    const password = try z.Secret(8, 100).init("MyP@ss123!");
    std.debug.print("Secret: {s} (strength: {d}/6)\n", .{ password.masked(), password.strength() });

    const strong = try z.StrongPassword(8, 100).init("S3cur3P@ss!");
    std.debug.print("StrongPassword: {s}\n", .{strong.masked()});

    // Number types
    std.debug.print("\n--- Number Types ---\n", .{});
    const age = try z.Int(i32, 0, 150).init(25);
    std.debug.print("Int: {d} (even: {}, odd: {})\n", .{ age.get(), age.isEven(), age.isOdd() });

    const positive = try z.PositiveInt(i32).init(42);
    std.debug.print("PositiveInt: {d} (clamped to 0-50: {d})\n", .{ positive.get(), positive.clamp(0, 50) });

    const even = try z.EvenInt(i32, 0, 100).init(42);
    std.debug.print("EvenInt: {d}\n", .{even.get()});

    const odd = try z.OddInt(i32, 0, 100).init(43);
    std.debug.print("OddInt: {d}\n", .{odd.get()});

    const mult = try z.MultipleOf(i32, 5).init(25);
    std.debug.print("MultipleOf(5): {d}\n", .{mult.get()});

    const pct = try z.Percentage(f64).init(75.5);
    std.debug.print("Percentage: {d}%\n", .{pct.get()});

    const prob = try z.Probability(f64).init(0.85);
    std.debug.print("Probability: {d}\n", .{prob.get()});

    const flt = try z.Float(f64, -100.0, 100.0).init(3.7);
    std.debug.print("Float: {d} (floor: {d}, ceil: {d})\n", .{ flt.get(), flt.floor(), flt.ceil() });

    const finite = try z.FiniteFloat(f64).init(3.14);
    std.debug.print("FiniteFloat: {d}\n", .{finite.get()});

    // Format types
    std.debug.print("\n--- Format Types ---\n", .{});
    const email = try z.Email.init("user@company.com");
    std.debug.print("Email: {s} (business: {})\n", .{ email.get(), email.isBusinessEmail() });

    const url = try z.Url.init("https://example.com/path");
    std.debug.print("URL: {s} (host: {s})\n", .{ url.get(), url.host() });

    const https = try z.HttpsUrl.init("https://secure.com");
    std.debug.print("HttpsUrl: {s}\n", .{https.get()});

    const uuid = try z.Uuid.init("550e8400-e29b-41d4-a716-446655440000");
    std.debug.print("UUID: {s} (version: {d})\n", .{ uuid.get(), uuid.version().? });

    const ip = try z.Ipv4.init("192.168.1.1");
    std.debug.print("IPv4: {s} (private: {}, loopback: {})\n", .{ ip.get(), ip.isPrivate(), ip.isLoopback() });

    const ipv6 = try z.Ipv6.init("::1");
    std.debug.print("IPv6: {s} (loopback: {})\n", .{ ipv6.get(), ipv6.isLoopback() });

    const semver = try z.Semver.init("1.2.3");
    std.debug.print("Semver: {s}\n", .{semver.get()});

    const phone = try z.PhoneNumber.init("+1234567890");
    std.debug.print("Phone: {s} (has country code: {})\n", .{ phone.get(), phone.hasCountryCode() });

    const card = try z.CreditCard.init("4111111111111111");
    std.debug.print("CreditCard: ****{s} (type: {s})\n", .{ card.masked(), card.cardType() });

    // Collection types
    std.debug.print("\n--- Collection Types ---\n", .{});
    const tags = [_][]const u8{ "zig", "rust", "go" };
    const tag_list = try z.List([]const u8, 1, 10).init(&tags);
    std.debug.print("List: {d} items, at(1): '{s}'\n", .{ tag_list.len(), tag_list.at(1).? });

    const coords = [_]i32{ 10, 20, 30 };
    const fixed = try z.FixedList(i32, 3).init(&coords);
    std.debug.print("FixedList(3): [{d}, {d}, {d}]\n", .{ fixed.at(0), fixed.at(1), fixed.at(2) });

    // Special types
    std.debug.print("\n--- Special Types ---\n", .{});
    const Role = z.Default([]const u8, "user");
    const role = Role.initDefault();
    std.debug.print("Default: '{s}' (is default: {})\n", .{ role.get(), role.isDefault() });
    std.debug.print("getOrDefault(null): '{s}'\n", .{Role.getOrDefault(null)});

    const Status = z.OneOf(u8, &[_]u8{ 1, 2, 3 });
    const status = try Status.init(1);
    std.debug.print("OneOf: {d} (first: {}, last: {})\n", .{ status.get(), status.isFirst(), status.isLast() });

    const R = z.Range(i32, 0, 100, 10);
    const r = try R.init(50);
    std.debug.print("Range(0-100, step 10): {d}\n", .{r.get()});

    const N = z.Nullable(i32);
    const some = N.init(42);
    const none = N.initNull();
    std.debug.print("Nullable: some={d}, none=null, unwrapOr(99)={d}\n", .{ some.unwrapOr(0), none.unwrapOr(99) });

    // Custom validator
    std.debug.print("\n--- Custom Validator ---\n", .{});
    const isPrime = struct {
        fn f(n: i32) bool {
            if (n < 2) return false;
            var i: i32 = 2;
            while (i * i <= n) : (i += 1) {
                if (@mod(n, i) == 0) return false;
            }
            return true;
        }
    }.f;
    const Prime = z.Custom(i32, isPrime);
    const prime = try Prime.init(17);
    std.debug.print("Custom (isPrime): {d}\n", .{prime.get()});

    std.debug.print("\n=== Done ===\n", .{});
}
