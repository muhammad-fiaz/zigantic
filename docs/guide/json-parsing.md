# JSON Parsing

Parse and serialize JSON with validation.

## Parsing JSON

```zig
const z = @import("zigantic");

const User = struct {
    name: z.String(1, 50),
    age: z.Int(i32, 18, 120),
    email: z.Email,
    role: z.Default([]const u8, "user"),
    website: ?z.Url = null,
};

const json =
    \\{"name": "Alice", "age": 25, "email": "alice@example.com"}
;

var result = try z.fromJson(User, json, allocator);
defer result.deinit();

if (result.value) |user| {
    std.debug.print("Name: {s}\n", .{user.name.get()});
    std.debug.print("Role: {s}\n", .{user.role.get()}); // "user" (default)
}
```

## Error Handling

```zig
if (!result.isValid()) {
    std.debug.print("Errors ({d}):\n", .{result.error_list.count()});

    for (result.error_list.errors.items) |err| {
        std.debug.print("  {s}: {s}\n", .{err.field, err.message});
    }

    // Or as JSON
    const json_errors = try result.error_list.toJsonArray(allocator);
    defer allocator.free(json_errors);
}
```

## Serialization

```zig
// Compact JSON
const compact = try z.toJson(value, allocator);
defer allocator.free(compact);
// {"name":"Alice","age":25}

// Pretty JSON
const pretty = try z.toJsonPretty(value, allocator);
defer allocator.free(pretty);
// {
//   "name": "Alice",
//   "age": 25
// }
```

## Nested Structs

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

var result = try z.fromJson(Person, json, allocator);
defer result.deinit();

if (result.value) |person| {
    std.debug.print("City: {s}\n", .{person.address.city});
}
```

## Optional Fields

```zig
const Profile = struct {
    name: z.String(1, 50),
    bio: ?z.String(1, 500) = null,      // Optional string
    website: ?z.Url = null,              // Optional URL
    role: z.Default([]const u8, "user"), // Default value
};
```

## Arrays

```zig
const Post = struct {
    title: z.String(1, 100),
    tags: z.List([]const u8, 1, 10),
};

const json =
    \\{"title": "Hello", "tags": ["zig", "zigantic"]}
;
```

## Validated Arrays

```zig
const Config = struct {
    ports: z.List(u16, 1, 5),           // 1-5 ports
    hosts: z.NonEmptyList([]const u8, 10), // At least 1
};
```

## Partial Updates

```zig
const User = struct { name: []const u8, age: i32 };
const PartialUser = z.Partial(User);

// All fields optional
const update = PartialUser{ .name = "New Name" };
// update.age is null
```

---

## URL Query String & Form URL-Encoded Parsing

Use `z.fromQueryString` and `z.toQueryString` to seamlessly validate and parse/serialize URL query strings and form payload parameters.

```zig
const std = @import("std");
const z = @import("zigantic");

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
}
```

---

## Compile-Time Field Aliases & Naming Policies

Map custom aliases or use automatic naming policies completely at compile time with zero runtime cost.

### Automatic Naming Policies

Set `pub const zigantic_naming = NamingPolicy.snake_case` in a struct to map your idiomatic camelCase fields to standard external formats like `snake_case` or `kebab-case` symmetrically.

```zig
const User = struct {
    firstName: []const u8,
    lastName: []const u8,

    // Automatically maps firstName -> first_name, lastName -> last_name
    pub const zigantic_naming = z.utils.NamingPolicy.snake_case;
};
```

### Explicit Field Aliases

Set `pub const zigantic_aliases` to specify exact individual key renames. This takes precedence over naming policies.

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

zigantic includes advanced validation decorators and dynamic factories.

### Dynamic Default Factories (`DefaultFactory`)

While `Default` is used for compile-time constant default values, `DefaultFactory` is used to dynamically generate default values at parsing/deserialization time (e.g. unique IDs or dynamic timestamps).

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


