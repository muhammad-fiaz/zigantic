# JSON API

JSON parsing and serialization.

## Parsing

### z.fromJson

Parse JSON with validation:

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
}
```

### ParseResult

```zig
pub fn ParseResult(comptime T: type) type {
    return struct {
        value: ?T,
        error_list: ErrorList,
        allocator: Allocator,

        pub fn deinit(self: *Self) void;
        pub fn isValid(self: Self) bool;
    };
}
```

**Usage:**

```zig
if (result.isValid()) {
    const user = result.value.?;
} else {
    // Handle errors
    for (result.error_list.errors.items) |err| {
        // ...
    }
}
```

## Serialization

### z.toJson

Compact JSON output:

```zig
pub fn toJson(
    value: anytype,
    allocator: std.mem.Allocator
) ![]const u8
```

**Example:**

```zig
const json = try z.toJson(user, allocator);
defer allocator.free(json);
// {"name":"Alice","age":25}
```

### z.toJsonPretty

Pretty-printed JSON:

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
//   "age": 25
// }
```

## Supported Types

| Zig Type       | JSON Type         |
| -------------- | ----------------- |
| `bool`         | boolean           |
| integers       | number            |
| floats         | number            |
| `[]const u8`   | string            |
| `?T`           | value or null     |
| `struct`       | object            |
| `[]T`          | array             |
| zigantic types | their inner value |

## Default Values

```zig
const Config = struct {
    host: []const u8,
    port: z.Default(u16, 8080),  // Defaults to 8080
    debug: z.Default(bool, false),
};

// Missing "port" and "debug" use defaults
const json =
    \\{"host": "localhost"}
;
```

## Optional Fields

```zig
const Profile = struct {
    name: z.String(1, 50),
    bio: ?z.String(1, 500) = null,  // Optional, defaults to null
    website: ?z.Url = null,
};
```

## Nested Structs

```zig
const Address = struct {
    street: []const u8,
    city: []const u8,
};

const Person = struct {
    name: z.String(1, 50),
    address: Address,
};

// Errors have nested paths: "address.city"
```

## Arrays

```zig
const Post = struct {
    title: z.String(1, 100),
    tags: []const []const u8,  // Plain array
    scores: z.List(u32, 1, 10), // Validated list
};
```

## Secret Fields

Secret fields are excluded from JSON output:

```zig
const User = struct {
    name: z.String(1, 50),
    password: z.Secret(8, 100),  // Not serialized
};
```
