//! Validators Example - Using validation functions directly

const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    std.debug.print("=== zigantic Validators ===\n\n", .{});

    const v = z.validators;

    // Email validation
    std.debug.print("--- Email ---\n", .{});
    std.debug.print("user@example.com: {}\n", .{v.isValidEmail("user@example.com")});
    std.debug.print("invalid: {}\n", .{v.isValidEmail("invalid")});
    std.debug.print("user@: {}\n", .{v.isValidEmail("user@")});

    // URL validation
    std.debug.print("\n--- URL ---\n", .{});
    std.debug.print("https://example.com: {}\n", .{v.isValidUrl("https://example.com")});
    std.debug.print("example.com: {}\n", .{v.isValidUrl("example.com")});

    // UUID validation
    std.debug.print("\n--- UUID ---\n", .{});
    std.debug.print("550e8400-e29b-41d4-a716-446655440000: {}\n", .{v.isUuid("550e8400-e29b-41d4-a716-446655440000")});
    std.debug.print("invalid-uuid: {}\n", .{v.isUuid("invalid-uuid")});

    // IP validation
    std.debug.print("\n--- IP Addresses ---\n", .{});
    std.debug.print("192.168.1.1: {}\n", .{v.isIpv4("192.168.1.1")});
    std.debug.print("256.1.1.1: {}\n", .{v.isIpv4("256.1.1.1")});
    std.debug.print("2001:0db8:85a3:0000:0000:8a2e:0370:7334: {}\n", .{v.isIpv6("2001:0db8:85a3:0000:0000:8a2e:0370:7334")});

    // Slug validation
    std.debug.print("\n--- Slug ---\n", .{});
    std.debug.print("hello-world: {}\n", .{v.isSlug("hello-world")});
    std.debug.print("Hello-World: {}\n", .{v.isSlug("Hello-World")});
    std.debug.print("-hello: {}\n", .{v.isSlug("-hello")});

    // Semver validation
    std.debug.print("\n--- Semver ---\n", .{});
    std.debug.print("1.2.3: {}\n", .{v.isSemver("1.2.3")});
    std.debug.print("1.0.0-alpha: {}\n", .{v.isSemver("1.0.0-alpha")});
    std.debug.print("1.2: {}\n", .{v.isSemver("1.2")});

    // Phone validation
    std.debug.print("\n--- Phone ---\n", .{});
    std.debug.print("+1234567890: {}\n", .{v.isPhoneNumber("+1234567890")});
    std.debug.print("123-456-7890: {}\n", .{v.isPhoneNumber("123-456-7890")});
    std.debug.print("123: {}\n", .{v.isPhoneNumber("123")});

    // String validators
    std.debug.print("\n--- String Validators ---\n", .{});
    std.debug.print("isAlphanumeric('abc123'): {}\n", .{v.isAlphanumeric("abc123")});
    std.debug.print("isAlpha('hello'): {}\n", .{v.isAlpha("hello")});
    std.debug.print("isNumeric('12345'): {}\n", .{v.isNumeric("12345")});
    std.debug.print("isLowercase('hello'): {}\n", .{v.isLowercase("hello")});
    std.debug.print("isUppercase('HELLO'): {}\n", .{v.isUppercase("HELLO")});
    std.debug.print("isHexString('0123abcdef'): {}\n", .{v.isHexString("0123abcdef")});
    std.debug.print("isBlank('   '): {}\n", .{v.isBlank("   ")});

    // Pattern matching
    std.debug.print("\n--- Pattern Matching ---\n", .{});
    std.debug.print("[0-9][0-9][0-9] matches '123': {}\n", .{v.matchesPattern("[0-9][0-9][0-9]", "123")});
    std.debug.print("[0-9][0-9][0-9] matches 'abc': {}\n", .{v.matchesPattern("[0-9][0-9][0-9]", "abc")});
    std.debug.print("[a-z][0-9] matches 'a1': {}\n", .{v.matchesPattern("[a-z][0-9]", "a1")});

    // JWT validation
    std.debug.print("\n--- JWT ---\n", .{});
    std.debug.print("header.payload.signature: {}\n", .{v.isJwt("header.payload.signature")});
    std.debug.print("invalid: {}\n", .{v.isJwt("invalid")});

    // Utility functions
    std.debug.print("\n--- Utilities ---\n", .{});
    std.debug.print("startsWith('hello', 'he'): {}\n", .{v.startsWith("hello", "he")});
    std.debug.print("endsWith('hello', 'lo'): {}\n", .{v.endsWith("hello", "lo")});
    std.debug.print("containsOnly('aab', 'ab'): {}\n", .{v.containsOnly("aab", "ab")});

    std.debug.print("\n=== Done ===\n", .{});
}
