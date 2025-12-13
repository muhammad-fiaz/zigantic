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
