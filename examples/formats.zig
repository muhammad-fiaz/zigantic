const std = @import("std");
const z = @import("zigantic");

const Contact = struct {
    email: []const u8,
    website: []const u8,
    identifier: []const u8,
    address: []const u8,
    expires: []const u8,
};

const ContactSchema = z.object(Contact, .{
    .email = z.email(.{}),
    .website = z.httpsUrl(.{}),
    .identifier = z.uuid(.{}),
    .address = z.ipv4(.{}),
    .expires = z.isoDateTime(.{}),
}, .{});

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const document =
        \\{"email":"ada@example.com","website":"https://example.com","identifier":"550e8400-e29b-41d4-a716-446655440000","address":"192.168.0.1","expires":"2027-01-01T09:00:00Z"}
    ;

    var result = try z.parse(ContactSchema, allocator, document, .{});
    defer result.deinit();
    std.debug.print("contact valid: {any}\n", .{result.ok()});

    const checks = [_]struct { name: []const u8, ok: bool }{
        .{ .name = "email", .ok = z.validators.isEmail("user+tag@example.co.uk") },
        .{ .name = "ipv6", .ok = z.validators.isIpv6("2001:db8::1") },
        .{ .name = "semver", .ok = z.validators.isSemver("1.2.3-rc.1") },
        .{ .name = "credit card", .ok = z.validators.isCreditCard("4242 4242 4242 4242") },
        .{ .name = "iso duration", .ok = z.validators.isIsoDuration("PT30M") },
    };
    for (checks) |check| {
        std.debug.print("{s}: {any}\n", .{ check.name, check.ok });
    }
}
