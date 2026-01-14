# Schemas

Schemas in zigantic allow you to define complex data structures with validation rules. This is similar to Pydantic models in Python.

## Defining a Schema

A schema in zigantic is simply a Zig struct with validated fields:

```zig
const z = @import("zigantic");

const UserSchema = struct {
    // Required fields with validation
    id: z.PositiveInt(u32),
    name: z.String(1, 100),
    email: z.Email,
    
    // Optional fields
    bio: ?z.String(0, 500) = null,
    website: ?z.Url = null,
    
    // Fields with defaults
    role: z.Default([]const u8, "user"),
    active: z.Default(bool, true),
};
```

## Parsing JSON into a Schema

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json =
        \\{
        \\  "id": 123,
        \\  "name": "Alice Johnson",
        \\  "email": "alice@example.com",
        \\  "bio": "Software developer",
        \\  "role": "admin"
        \\}
    ;

    var result = try z.fromJson(UserSchema, json, allocator);
    defer result.deinit();

    if (result.value) |user| {
        std.debug.print("User: {s} ({s})\n", .{user.name.get(), user.email.get()});
        std.debug.print("Role: {s}\n", .{user.role.get()});
    }
}
```

## Nested Schemas

Schemas can be nested for complex data structures:

```zig
const Address = struct {
    street: z.String(1, 200),
    city: z.String(1, 100),
    country: z.String(2, 100),
    postal_code: z.String(1, 20),
};

const Company = struct {
    name: z.String(1, 100),
    website: z.HttpsUrl,
    employees: z.PositiveInt(u32),
};

const Profile = struct {
    user: UserSchema,
    address: Address,
    company: ?Company = null,
};
```

## Schema with Collections

Use validated collections in your schemas:

```zig
const BlogPost = struct {
    title: z.String(1, 200),
    content: z.String(1, 50000),
    author: z.Email,
    tags: z.List([]const u8, 1, 10),  // 1-10 tags
    published: z.Default(bool, false),
};
```

## Schema Validation

All fields are validated when parsing:

```zig
const json =
    \\{
    \\  "title": "",
    \\  "content": "Hello",
    \\  "author": "invalid-email",
    \\  "tags": []
    \\}
;

var result = try z.fromJson(BlogPost, json, allocator);
defer result.deinit();

if (!result.isValid()) {
    for (result.error_list.errors.items) |err| {
        std.debug.print("[{s}] {s}: {s}\n", .{
            z.errorCode(err.error_type),
            err.field,
            err.message,
        });
    }
    // Output:
    // [E001] title: value is too short
    // [E010] author: must be a valid email
    // [E030] tags: too few items
}
```

## Serializing Schemas

Convert schemas back to JSON:

```zig
const post = BlogPost{
    .title = try z.String(1, 200).init("My First Post"),
    .content = try z.String(1, 50000).init("Hello, world!"),
    .author = try z.Email.init("author@example.com"),
    .tags = try z.List([]const u8, 1, 10).init(&.{"zig", "tutorial"}),
    .published = z.Default(bool, false).init(),
};

const json_str = try z.toJsonPretty(post, allocator);
defer allocator.free(json_str);
std.debug.print("{s}\n", .{json_str});
```

## Best Practices

1. **Use meaningful type aliases** - Create type aliases for reusable validation types
2. **Group related fields** - Use nested structs for logical grouping
3. **Set sensible defaults** - Use `Default` type for optional configuration
4. **Document constraints** - Add comments explaining validation rules
5. **Handle errors gracefully** - Always check `result.isValid()` before using values

```zig
// Good: Meaningful type aliases
const Username = z.String(3, 30);
const Bio = z.String(0, 500);
const Age = z.Int(i32, 13, 120);

const UserProfile = struct {
    username: Username,
    bio: ?Bio = null,
    age: Age,
};
```
