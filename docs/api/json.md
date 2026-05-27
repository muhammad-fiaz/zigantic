# JSON API

JSON parsing (deserialization) and serialization for zigantic.

::: tip Automatic Updates
JSON functions (`fromJson`, `toJson`, `toJsonPretty`) automatically trigger a background update check on first use. To disable, call `z.disableUpdateCheck()` before using these functions.
:::

## Deserialization (Parsing)

### z.fromJson

Parse JSON string into a validated Zig struct:

```zig
pub fn fromJson(
    comptime T: type,
    json_string: []const u8,
    allocator: std.mem.Allocator
) !ParseResult(T)
```

**Example:**

```zig
const User = struct {
    name: z.String(1, 50),
    age: z.Int(i32, 18, 120),
    email: z.Email,
    role: z.Default([]const u8, "user"),
};

var result = try z.fromJson(User, json, allocator);
defer result.deinit();

if (result.value) |user| {
    std.debug.print("Name: {s}\n", .{user.name.get()});
    std.debug.print("Email: {s}\n", .{user.email.get()});
    std.debug.print("Age: {d}\n", .{user.age.get()});
}
```

### ParseResult

```zig
pub fn ParseResult(comptime T: type) type {
    return struct {
        value: ?T,           // The parsed value or null if validation failed
        error_list: ErrorList, // List of validation errors
        allocator: Allocator,

        pub fn deinit(self: *Self) void;   // Free all memory
        pub fn isValid(self: Self) bool;   // Check if parsing succeeded
        pub fn unwrap(self: Self) !T;      // Get value or error
        pub fn formatErrors(self: Self) ![]const u8; // Get formatted error messages
    };
}
```

**Error Handling:**

```zig
if (result.isValid()) {
    const user = result.value.?;
    // Use validated data
} else {
    // Handle validation errors
    for (result.error_list.errors.items) |err| {
        std.debug.print("[{s}] {s}: {s}\n", .{
            z.errorCode(err.error_type),
            err.field,
            err.message,
        });
    }
}
```

## Serialization

### z.toJson

Serialize to compact JSON string:

```zig
pub fn toJson(
    value: anytype,
    allocator: std.mem.Allocator
) ![]const u8
```

**Example:**

```zig
const user = User{
    .name = try z.String(1, 50).init("Alice"),
    .age = try z.Int(i32, 18, 120).init(25),
    .email = try z.Email.init("alice@example.com"),
    .role = z.Default([]const u8, "user").initDefault(),
};

const json = try z.toJson(user, allocator);
defer allocator.free(json);
// {"name":"Alice","age":25,"email":"alice@example.com","role":"user"}
```

### z.toJsonPretty

Serialize to formatted JSON string:

```zig
pub fn toJsonPretty(
    value: anytype,
    allocator: std.mem.Allocator
) ![]const u8
```

**Example:**

```zig
const json = try z.toJsonPretty(user, allocator);
defer allocator.free(json);
// {
//   "name": "Alice",
//   "age": 25,
//   "email": "alice@example.com",
//   "role": "user"
// }
```

## Supported Types

### Primitive Types

| Zig Type       | JSON Type | Notes |
| -------------- | --------- | ----- |
| `bool`         | boolean   | `true` / `false` |
| `i8` to `i64`  | number    | Integer values |
| `u8` to `u64`  | number    | Unsigned integers |
| `f32`, `f64`   | number    | Floating point |
| `[]const u8`   | string    | UTF-8 strings |

### Optional and Nullable

| Zig Type       | JSON Type | Notes |
| -------------- | --------- | ----- |
| `?T`           | value/null | Standard optional |
| `z.Nullable(T)` | value/null | Explicit nullable with utilities |

### Zigantic Types

All zigantic types are fully supported:

| Category | Types |
|----------|-------|
| **String Types** | `String`, `NonEmptyString`, `Trimmed`, `Lowercase`, `Uppercase`, `Alphanumeric`, `AsciiString`, `Secret`, `StrongPassword` |
| **Number Types** | `Int`, `UInt`, `PositiveInt`, `NonNegativeInt`, `NegativeInt`, `EvenInt`, `OddInt`, `MultipleOf`, `Float`, `Percentage`, `Probability`, `PositiveFloat`, `NegativeFloat`, `FiniteFloat` |
| **Format Types** | `Email`, `Url`, `HttpsUrl`, `Uuid`, `Ipv4`, `Ipv6`, `Slug`, `Semver`, `PhoneNumber`, `CreditCard`, `Regex`, `Base64`, `HexString`, `HexColor`, `MacAddress`, `IsoDateTime`, `IsoDate`, `CountryCode`, `CurrencyCode`, `Latitude`, `Longitude`, `Port` |
| **Collection Types** | `List`, `NonEmptyList`, `FixedList` |
| **Special Types** | `Default`, `Custom`, `Transform`, `Coerce`, `Literal`, `Nullable` |

## Default Values

Use `z.Default` for fields with default values when missing from JSON:

```zig
const Config = struct {
    host: []const u8,
    port: z.Default(u16, 8080),     // Defaults to 8080
    debug: z.Default(bool, false),   // Defaults to false
    timeout: z.Default(u32, 30),     // Defaults to 30
};

// Only "host" is provided - other fields use defaults
const json =
    \\{"host": "localhost"}
;

var result = try z.fromJson(Config, json, allocator);
defer result.deinit();

const config = result.value.?;
// config.port == 8080
// config.debug == false
// config.timeout == 30
```

## Optional Fields

Use Zig's `?T` syntax for optional fields:

```zig
const Profile = struct {
    name: z.String(1, 50),
    bio: ?z.String(1, 500) = null,   // Optional bio
    website: ?z.Url = null,           // Optional website
    location: ?[]const u8 = null,     // Optional plain string
};

// Missing optional fields become null
const json =
    \\{"name": "Alice"}
;
```

## Nested Structs

Nested structures are fully supported with path-aware error messages:

```zig
const Address = struct {
    street: []const u8,
    city: []const u8,
    zip: z.String(5, 10),
};

const Person = struct {
    name: z.String(1, 50),
    address: Address,
};

const json =
    \\{"name": "Bob", "address": {"street": "123 Main", "city": "NYC", "zip": "10001"}}
;

// Errors include full path: "address.zip"
```

## Arrays and Lists

### Plain Arrays

```zig
const Post = struct {
    title: z.String(1, 100),
    tags: []const []const u8,    // Array of strings
    scores: []const u32,         // Array of integers
};
```

### Validated Lists

```zig
const Article = struct {
    title: z.String(1, 100),
    tags: z.List([]const u8, 1, 10),  // 1-10 tags required
    ratings: z.NonEmptyList(u8, 100), // At least one rating
};
```

## Custom Validators

Custom types work with JSON parsing:

```zig
const isEven = struct {
    fn f(n: i32) bool {
        return @mod(n, 2) == 0;
    }
}.f;

const Data = struct {
    even_number: z.Custom(i32, isEven),
};

const json =
    \\{"even_number": 42}
;
// Valid: 42 is even

const bad_json =
    \\{"even_number": 43}
;
// Error: failed custom validation
```

## Format Types

All format types parse from strings:

```zig
const Location = struct {
    latitude: z.Latitude,         // -90 to 90
    longitude: z.Longitude,       // -180 to 180
    country: z.CountryCode,       // "US", "GB", etc.
    currency: z.CurrencyCode,     // "USD", "EUR", etc.
};

const json =
    \\{"latitude": 40.7128, "longitude": -74.0060, "country": "US", "currency": "USD"}
;
```

## Date/Time Types

```zig
const Event = struct {
    name: z.String(1, 100),
    date: z.IsoDate,              // "2024-01-15"
    timestamp: z.IsoDateTime,     // "2024-01-15T10:30:00Z"
};

const json =
    \\{"name": "Meeting", "date": "2024-01-15", "timestamp": "2024-01-15T10:30:00Z"}
;
```

---

## URL Query String & Form URL-Encoded Parsing

### z.fromQueryString

Parse form-urlencoded parameter payload or URL query string into a validated struct. Characters like `+` are automatically decoded to spaces, and percent encodings (`%XX`) are resolved in place with high efficiency.

```zig
pub fn fromQueryString(
    comptime T: type,
    query_string: []const u8,
    allocator: std.mem.Allocator
) !ParseResult(T)
```

### z.toQueryString

Serialize a struct instance into a form-urlencoded parameters string:

```zig
pub fn toQueryString(
    value: anytype,
    allocator: std.mem.Allocator
) ![]const u8
```

**Example:**

```zig
const Search = struct {
    query: z.String(1, 50),
    page: z.Default(u32, 1),
    active: bool,
};

const qs = "query=Mechanical+Keyboard&page=2&active=true";
var result = try z.fromQueryString(Search, qs, allocator);
defer result.deinit();

if (result.isValid()) {
    const s = result.value.?;
    // s.query.get() == "Mechanical Keyboard"
    // s.page.get() == 2
    // s.active == true
}
```

---

## Compile-Time Field Aliases & Naming Policies

Map custom aliases or use automatic naming policies completely at compile time with zero runtime cost.

### Automatic Naming Policies

Use `pub const zigantic_naming` to map `camelCase` struct fields to common formatting styles like `snake_case` or `kebab-case` when serializing and deserializing.

```zig
const User = struct {
    firstName: []const u8,
    lastName: []const u8,

    // Maps firstName -> first_name, lastName -> last_name automatically
    pub const zigantic_naming = z.utils.NamingPolicy.snake_case;
};
```

### Explicit Field Aliases

Use `pub const zigantic_aliases` to specify exact custom key mappings for individual fields. This takes precedence over automatic naming policies.

```zig
const Product = struct {
    productName: []const u8,
    priceInUsd: f64,

    pub const zigantic_aliases = .{
        .productName = "name",
        .priceInUsd = "price",
    };
};
```

---

## Advanced Features

zigantic includes advanced, high-value validation decorators and dynamic factories.

### Dynamic Default Factories (`DefaultFactory`)

While `Default` is used for compile-time constant default values, `DefaultFactory` is used to dynamically generate default values at parsing/deserialization time (e.g. timestamps, UUIDs, or counter-based IDs).

```zig
const std = @import("std");
const z = @import("zigantic");

var call_counter: i32 = 0;
fn nextId() i32 {
    call_counter += 1;
    return call_counter;
}

const Device = struct {
    name: []const u8,
    id: z.DefaultFactory(i32, nextId),
};

// If "id" is missing in JSON, nextId() is automatically called to supply the value.
```

### Field-Level Validators (`validate_[field_name]`)

Structs can define field-level validator functions that run automatically when parsing a field from JSON or URL Query maps. A field-level validator:
- Must have the name `validate_[field_name]` (e.g. `validate_age`).
- Receives the parsed field value.
- Returns either a validated/modified value or a Zig validation error.

```zig
const User = struct {
    username: z.String(3, 50),
    age: i32,

    pub fn validate_age(val: i32) !i32 {
        if (val < 18) return error.AgeTooYoung;
        // Normalizes age to a maximum of 100
        if (val > 100) return 100;
        return val;
    }
};
```

### Model-Level Validation (`validateModel`)

Structs can define a model-level validator function that runs automatically after all struct fields have been parsed and individually validated. It is extremely useful for verifying cross-field constraints (e.g. checking if password fields match or if a date range is valid).

- Must have the name `validateModel`.
- Can accept a pointer receiver (`self: *const @This()`) or a value receiver (`self: @This()`).
- Returns either `void` or a Zig validation error.

```zig
const DateRange = struct {
    start_date: z.IsoDate,
    end_date: z.IsoDate,

    pub fn validateModel(self: *const @This()) !void {
        // Run cross-field checks
        // (Ensure start_date is before end_date)
    }
};
```



