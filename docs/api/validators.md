# Validators API

Direct validation utility functions.

## Format Validators

| Function                 | Description      |
| ------------------------ | ---------------- |
| `isValidEmail(str)`      | Email format     |
| `isValidUrl(str)`        | HTTP/HTTPS URL   |
| `isUuid(str)`            | UUID format      |
| `isIpv4(str)`            | IPv4 address     |
| `isIpv6(str)`            | IPv6 address     |
| `isSlug(str)`            | URL slug format  |
| `isSemver(str)`          | Semantic version |
| `isPhoneNumber(str)`     | Phone number     |
| `isValidCreditCard(str)` | Luhn algorithm   |
| `isJwt(str)`             | JWT format       |
| `isHexString(str)`       | Hex characters   |
| `isBase64(str)`          | Base64 format    |

## String Validators

| Function              | Description        |
| --------------------- | ------------------ |
| `isAlphanumeric(str)` | Letters and digits |
| `isAlpha(str)`        | Letters only       |
| `isNumeric(str)`      | Digits only        |
| `isLowercase(str)`    | No uppercase       |
| `isUppercase(str)`    | No lowercase       |
| `isAscii(str)`        | ASCII only (0-127) |
| `isPrintable(str)`    | Printable chars    |
| `isEmpty(str)`        | Empty string       |
| `isBlank(str)`        | Whitespace only    |

## Utility Functions

| Function                   | Description        |
| -------------------------- | ------------------ |
| `startsWith(str, prefix)`  | Prefix check       |
| `endsWith(str, suffix)`    | Suffix check       |
| `containsOnly(str, chars)` | Only allowed chars |

## Pattern Matching

```zig
const v = z.validators;

// Pattern syntax:
// [0-9]     - digit
// [a-z]     - lowercase letter
// [A-Z]     - uppercase letter
// [a-zA-Z]  - any letter
// [0-9a-zA-Z] - alphanumeric
// .         - any character

v.matchesPattern("[0-9][0-9][0-9]", "123")     // true
v.matchesPattern("[a-z][0-9]", "a1")           // true
v.matchesPattern("[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]", "123-4567") // true
```

## Examples

```zig
const v = @import("zigantic").validators;

// Format validation
v.isValidEmail("user@example.com")  // true
v.isValidUrl("https://example.com") // true
v.isUuid("550e8400-e29b-41d4-a716-446655440000") // true
v.isIpv4("192.168.1.1")   // true
v.isIpv4("256.1.1.1")     // false
v.isIpv6("::1")           // true
v.isSlug("hello-world")   // true
v.isSemver("1.2.3")       // true
v.isPhoneNumber("+1234567890") // true
v.isJwt("header.payload.signature") // true

// String validation
v.isAlphanumeric("abc123") // true
v.isAlpha("hello")         // true
v.isNumeric("12345")       // true
v.isLowercase("hello")     // true
v.isUppercase("HELLO")     // true
v.isHexString("0123abcdef") // true
v.isBlank("   ")           // true

// Utilities
v.startsWith("hello", "he") // true
v.endsWith("hello", "lo")   // true
v.containsOnly("aab", "ab") // true
```
