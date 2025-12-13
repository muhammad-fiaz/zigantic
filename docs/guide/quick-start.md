# Quick Start

Complete guide to using zigantic's 40+ validation types.

## String Types

```zig
const z = @import("zigantic");

// Basic string
const name = try z.String(1, 50).init("Alice");
name.get()           // "Alice"
name.len()           // 5
name.startsWith("A") // true
name.contains("lic") // true
name.charAt(0)       // 'A'
name.slice(0, 3)     // "Ali"

// Trimmed (auto-removes whitespace)
const input = try z.Trimmed(1, 50).init("  hello  ");
input.get()         // "hello"
input.wasTrimmed()  // true

// Case validation
const lower = try z.Lowercase(50).init("hello");
const upper = try z.Uppercase(50).init("HELLO");
const alnum = try z.Alphanumeric(1, 50).init("abc123");
const ascii = try z.AsciiString(1, 50).init("hello");

// Password with strength
const pwd = try z.Secret(8, 100).init("MyP@ss123!");
pwd.masked()       // "********"
pwd.strength()     // 0-6 score
pwd.hasUppercase() // true
pwd.hasDigit()     // true
pwd.hasSpecial()   // true

// Strong password (requires all)
const strong = try z.StrongPassword(8, 100).init("S3cur3P@ss!");
```

## Number Types

```zig
// Integer with utilities
const age = try z.Int(i32, 0, 150).init(42);
age.isEven()     // true
age.isOdd()      // false
age.isPositive() // true
age.clamp(0, 50) // 42

// Specialized integers
const pos = try z.PositiveInt(i32).init(5);      // > 0
const non = try z.NonNegativeInt(i32).init(0);   // >= 0
const neg = try z.NegativeInt(i32).init(-5);     // < 0
const even = try z.EvenInt(i32, 0, 100).init(42);
const odd = try z.OddInt(i32, 0, 100).init(43);
const mult = try z.MultipleOf(i32, 5).init(25);

// Float with utilities
const f = try z.Float(f64, -100.0, 100.0).init(3.7);
f.floor() // 3.0
f.ceil()  // 4.0
f.round() // 4.0

// Specialized floats
const pct = try z.Percentage(f64).init(75.5);   // 0-100
const prob = try z.Probability(f64).init(0.85); // 0-1
const finite = try z.FiniteFloat(f64).init(3.14); // no NaN/Inf
```

## Format Types

```zig
// Email
const email = try z.Email.init("user@company.com");
email.domain()          // "company.com"
email.localPart()       // "user"
email.isBusinessEmail() // true (not gmail/yahoo)

// URL
const url = try z.Url.init("https://example.com/path");
url.isHttps()   // true
url.protocol()  // "https"
url.host()      // "example.com"

// HTTPS only
const https = try z.HttpsUrl.init("https://secure.com");

// UUID with version
const uuid = try z.Uuid.init("550e8400-e29b-41d4-a716-446655440000");
uuid.version() // 4

// IP addresses
const ipv4 = try z.Ipv4.init("192.168.1.1");
ipv4.isPrivate()  // true
ipv4.isLoopback() // false

const ipv6 = try z.Ipv6.init("::1");
ipv6.isLoopback() // true

// Phone and credit card
const phone = try z.PhoneNumber.init("+1234567890");
phone.hasCountryCode() // true

const card = try z.CreditCard.init("4111111111111111");
card.cardType() // "visa"
card.masked()   // "1111"

// Other formats
const slug = try z.Slug.init("hello-world");
const ver = try z.Semver.init("1.2.3");
```

## Collection Types

```zig
// List with utilities
const items = [_][]const u8{ "a", "b", "c" };
const list = try z.List([]const u8, 1, 10).init(&items);
list.len()    // 3
list.first()  // "a"
list.last()   // "c"
list.at(1)    // "b"
list.isEmpty() // false

// Fixed size
const coords = [_]i32{ 10, 20, 30 };
const fixed = try z.FixedList(i32, 3).init(&coords);
```

## Special Types

```zig
// Default values
const Role = z.Default([]const u8, "user");
const role = Role.initDefault();
role.get()       // "user"
role.isDefault() // true
Role.getOrDefault(null) // "user"

// OneOf (enum-like)
const Status = z.OneOf(u8, &[_]u8{ 1, 2, 3 });
const s = try Status.init(1);
s.isFirst() // true
s.isLast()  // false

// Range with step
const R = z.Range(i32, 0, 100, 10);
_ = try R.init(50);  // OK
// R.init(55) - error: NotInStep

// Nullable
const N = z.Nullable(i32);
const some = N.init(42);
const none = N.initNull();
some.unwrapOr(0) // 42
none.unwrapOr(0) // 0

// Custom validator
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
const p = try Prime.init(17);
```

## All Types Summary

| Category       | Types                                                                                                                                                                                   |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **String**     | `String`, `NonEmptyString`, `Trimmed`, `Lowercase`, `Uppercase`, `Alphanumeric`, `AsciiString`, `Secret`, `StrongPassword`                                                              |
| **Number**     | `Int`, `UInt`, `PositiveInt`, `NonNegativeInt`, `NegativeInt`, `EvenInt`, `OddInt`, `MultipleOf`, `Float`, `Percentage`, `Probability`, `PositiveFloat`, `NegativeFloat`, `FiniteFloat` |
| **Format**     | `Email`, `Url`, `HttpsUrl`, `Uuid`, `Ipv4`, `Ipv6`, `Slug`, `Semver`, `PhoneNumber`, `CreditCard`, `Regex`                                                                              |
| **Collection** | `List`, `NonEmptyList`, `FixedList`                                                                                                                                                     |
| **Special**    | `Default`, `Custom`, `Transform`, `Coerce`, `Literal`, `Partial`, `OneOf`, `Range`, `Nullable`, `Lazy`                                                                                  |
