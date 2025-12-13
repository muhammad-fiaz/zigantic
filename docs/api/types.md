# Types API

Complete API reference for all zigantic types.

## String Types

| Type                       | Description                        |
| -------------------------- | ---------------------------------- |
| `String(min, max)`         | String with length constraints     |
| `NonEmptyString(max)`      | Non-empty string                   |
| `Trimmed(min, max)`        | Auto-trimmed string                |
| `Lowercase(max)`           | Lowercase only                     |
| `Uppercase(max)`           | Uppercase only                     |
| `Alphanumeric(min, max)`   | Letters and digits                 |
| `AsciiString(min, max)`    | ASCII only (0-127)                 |
| `Secret(min, max)`         | Password with strength             |
| `StrongPassword(min, max)` | Requires upper+lower+digit+special |

### String Methods

```zig
str.get()           // Get value
str.len()           // Length
str.isEmpty()       // Check empty
str.startsWith(p)   // Prefix check
str.endsWith(s)     // Suffix check
str.contains(n)     // Contains check
str.charAt(i)       // Char at index
str.slice(s, e)     // Substring
```

### Secret Methods

```zig
pwd.masked()       // "********"
pwd.strength()     // 0-6 score
pwd.hasUppercase() // bool
pwd.hasLowercase() // bool
pwd.hasDigit()     // bool
pwd.hasSpecial()   // bool
```

## Number Types

| Type                     | Description                 |
| ------------------------ | --------------------------- |
| `Int(T, min, max)`       | Signed integer with range   |
| `UInt(T, min, max)`      | Unsigned integer with range |
| `PositiveInt(T)`         | > 0                         |
| `NonNegativeInt(T)`      | >= 0                        |
| `NegativeInt(T)`         | < 0                         |
| `EvenInt(T, min, max)`   | Even only                   |
| `OddInt(T, min, max)`    | Odd only                    |
| `MultipleOf(T, divisor)` | Multiple of N               |
| `Float(T, min, max)`     | Float with range            |
| `Percentage(T)`          | 0-100                       |
| `Probability(T)`         | 0-1                         |
| `PositiveFloat(T)`       | > 0                         |
| `NegativeFloat(T)`       | < 0                         |
| `FiniteFloat(T)`         | No NaN/Inf                  |

### Number Methods

```zig
n.get()        // Get value
n.isPositive() // bool
n.isNegative() // bool
n.isZero()     // bool
n.isEven()     // bool
n.isOdd()      // bool
n.abs()        // Absolute value
n.clamp(lo,hi) // Clamp to range

f.floor()      // Floor
f.ceil()       // Ceiling
f.round()      // Round
f.trunc()      // Truncate
```

## Format Types

| Type             | Description        |
| ---------------- | ------------------ |
| `Email`          | Email address      |
| `Url`            | HTTP/HTTPS URL     |
| `HttpsUrl`       | HTTPS only         |
| `Uuid`           | UUID format        |
| `Ipv4`           | IPv4 address       |
| `Ipv6`           | IPv6 address       |
| `Slug`           | URL slug           |
| `Semver`         | Semantic version   |
| `PhoneNumber`    | Phone number       |
| `CreditCard`     | Credit card (Luhn) |
| `Regex(pattern)` | Pattern matching   |

### Format Methods

```zig
// Email
email.domain()          // Domain part
email.localPart()       // Local part
email.isBusinessEmail() // Not free email

// Url
url.isHttps()   // HTTPS check
url.protocol()  // "http" or "https"
url.host()      // Host part

// Uuid
uuid.version()  // Version number

// Ipv4/6
ip.isPrivate()  // Private range
ip.isLoopback() // Loopback

// PhoneNumber
phone.hasCountryCode() // Has +

// CreditCard
card.cardType() // visa/mastercard/amex
card.masked()   // Last 4 digits
```

## Collection Types

| Type                   | Description      |
| ---------------------- | ---------------- |
| `List(T, min, max)`    | List with length |
| `NonEmptyList(T, max)` | Non-empty list   |
| `FixedList(T, len)`    | Exact size       |

### Collection Methods

```zig
list.get()     // Get items
list.len()     // Length
list.isEmpty() // Empty check
list.first()   // First or null
list.last()    // Last or null
list.at(i)     // At index or null
```

## Special Types

| Type                   | Description         |
| ---------------------- | ------------------- |
| `Default(T, value)`    | Default value       |
| `Custom(T, fn)`        | Custom validator    |
| `Transform(T, fn)`     | Transform value     |
| `Coerce(From, To)`     | Type conversion     |
| `Literal(T, value)`    | Exact match         |
| `Partial(T)`           | All fields optional |
| `OneOf(T, values)`     | Allowed values      |
| `Range(T, s, e, step)` | Range with step     |
| `Nullable(T)`          | Explicit null       |
| `Lazy(T)`              | Lazy evaluation     |

### Special Methods

```zig
// Default
d.isDefault()        // Is default value
D.getOrDefault(opt)  // Get or default

// OneOf
o.isFirst()  // First value
o.isLast()   // Last value

// Nullable
n.isNull()      // Null check
n.unwrapOr(d)   // Get or default

// Transform
t.getOriginal() // Original value
```
