# Validation Types

Complete reference for all 40+ validation types.

## String Types

### z.String(min, max)

String with length constraints and utilities.

```zig
const Name = z.String(1, 50);
const name = try Name.init("Alice");
name.get()           // "Alice"
name.len()           // 5
name.isEmpty()       // false
name.startsWith("A") // true
name.endsWith("e")   // true
name.contains("lic") // true
name.charAt(0)       // 'A'
name.slice(0, 3)     // "Ali"
```

### z.Trimmed(min, max)

Auto-trims whitespace.

```zig
const input = try z.Trimmed(1, 50).init("  hello  ");
input.get()        // "hello"
input.getOriginal() // "  hello  "
input.wasTrimmed() // true
```

### z.Secret(min, max)

Password with strength checking.

```zig
const pwd = try z.Secret(8, 100).init("MyP@ss123!");
pwd.masked()       // "********"
pwd.strength()     // 0-6 score
pwd.hasUppercase() // true
pwd.hasLowercase() // true
pwd.hasDigit()     // true
pwd.hasSpecial()   // true
```

### z.StrongPassword(min, max)

Requires uppercase, lowercase, digit, and special character.

```zig
const pwd = try z.StrongPassword(8, 100).init("S3cur3P@ss!");
// z.StrongPassword(8, 100).init("password") -> WeakPassword error
```

### Other String Types

| Type                     | Description                   |
| ------------------------ | ----------------------------- |
| `NonEmptyString(max)`    | Alias for `String(1, max)`    |
| `Lowercase(max)`         | Must be all lowercase         |
| `Uppercase(max)`         | Must be all uppercase         |
| `Alphanumeric(min, max)` | Letters and digits only       |
| `AsciiString(min, max)`  | ASCII characters only (0-127) |

## Number Types

### z.Int(T, min, max)

Signed integer with range and utilities.

```zig
const n = try z.Int(i32, -100, 100).init(42);
n.get()        // 42
n.isPositive() // true
n.isNegative() // false
n.isZero()     // false
n.isEven()     // true
n.isOdd()      // false
n.abs()        // 42
n.clamp(0, 50) // 42
```

### z.Float(T, min, max)

Float with range and utilities.

```zig
const f = try z.Float(f64, -100.0, 100.0).init(3.7);
f.floor() // 3.0
f.ceil()  // 4.0
f.round() // 4.0
f.trunc() // 3.0
```

### Specialized Number Types

| Type                     | Description                 |
| ------------------------ | --------------------------- |
| `UInt(T, min, max)`      | Unsigned integer            |
| `PositiveInt(T)`         | > 0                         |
| `NonNegativeInt(T)`      | >= 0                        |
| `NegativeInt(T)`         | < 0                         |
| `EvenInt(T, min, max)`   | Even numbers only           |
| `OddInt(T, min, max)`    | Odd numbers only            |
| `MultipleOf(T, divisor)` | Must be multiple of divisor |
| `Percentage(T)`          | 0-100 range                 |
| `Probability(T)`         | 0-1 range                   |
| `PositiveFloat(T)`       | > 0                         |
| `NegativeFloat(T)`       | < 0                         |
| `FiniteFloat(T)`         | No NaN or Infinity          |

## Format Types

### z.Email

Email with domain parsing.

```zig
const email = try z.Email.init("user@company.com");
email.domain()          // "company.com"
email.localPart()       // "user"
email.isBusinessEmail() // true (not gmail/yahoo/etc)
```

### z.Url

URL with parsing utilities.

```zig
const url = try z.Url.init("https://example.com/path");
url.isHttps()  // true
url.protocol() // "https"
url.host()     // "example.com"
```

### z.Ipv4

IPv4 with network utilities.

```zig
const ip = try z.Ipv4.init("192.168.1.1");
ip.isPrivate()  // true
ip.isLoopback() // false
```

### z.CreditCard

Credit card with Luhn validation.

```zig
const card = try z.CreditCard.init("4111111111111111");
card.cardType() // "visa", "mastercard", "amex"
card.masked()   // last 4 digits
```

### Other Format Types

| Type             | Description                   |
| ---------------- | ----------------------------- |
| `HttpsUrl`       | HTTPS only                    |
| `Uuid`           | UUID with `version()` method  |
| `Ipv6`           | IPv6 with `isLoopback()`      |
| `Slug`           | URL-friendly string           |
| `Semver`         | Semantic version              |
| `PhoneNumber`    | Phone with `hasCountryCode()` |
| `Regex(pattern)` | Pattern matching              |

## Collection Types

### z.List(T, min, max)

List with length constraints.

```zig
const list = try z.List(u32, 1, 10).init(&items);
list.len()     // item count
list.isEmpty() // false
list.first()   // first item or null
list.last()    // last item or null
list.at(1)     // item at index or null
```

### z.FixedList(T, exact_len)

Exact size array.

```zig
const fixed = try z.FixedList(i32, 3).init(&[_]i32{1, 2, 3});
fixed.at(0) // 1
```

## Special Types

### z.Default(T, value)

Default value for missing fields.

```zig
const Role = z.Default([]const u8, "user");
Role.initDefault()       // { value: "user" }
Role.getOrDefault(null)  // "user"
role.isDefault()         // true/false
```

### z.OneOf(T, allowed)

Value must be in allowed list.

```zig
const Status = z.OneOf(u8, &[_]u8{ 1, 2, 3 });
const s = try Status.init(1);
s.isFirst() // true
s.isLast()  // false
```

### z.Range(T, start, end, step)

Range with step validation.

```zig
const R = z.Range(i32, 0, 100, 10);
_ = try R.init(50);  // OK
// R.init(55) -> NotInStep error
```

### z.Nullable(T)

Explicit null handling.

```zig
const N = z.Nullable(i32);
N.init(42)      // some
N.initNull()    // none
n.isNull()      // check
n.unwrapOr(0)   // get or default
```

### Other Special Types

| Type                | Description               |
| ------------------- | ------------------------- |
| `Custom(T, fn)`     | Custom validator function |
| `Transform(T, fn)`  | Transform value           |
| `Coerce(From, To)`  | Type conversion           |
| `Literal(T, value)` | Exact value match         |
| `Partial(T)`        | All fields optional       |
| `Lazy(T)`           | Lazy evaluation           |
