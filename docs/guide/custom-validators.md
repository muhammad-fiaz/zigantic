# Custom Validators

zigantic provides powerful tools for creating custom validation logic beyond the built-in types.

## Custom Type

The `Custom` type allows you to define validation using any function:

```zig
const z = @import("zigantic");

// Define a validator function
fn isEven(n: i32) bool {
    return @mod(n, 2) == 0;
}

// Create the custom type
const EvenNumber = z.Custom(i32, isEven);

pub fn main() !void {
    const n = try EvenNumber.init(42);  // OK
    std.debug.print("Value: {d}\n", .{n.get()});
    
    _ = EvenNumber.init(43) catch |err| {
        std.debug.print("Error: {s}\n", .{z.errorMessage(err)});
        // Output: Error: validation failed
    };
}
```

## Using Inline Functions

For one-off validators, use inline struct functions:

```zig
const PositiveEven = z.Custom(i32, struct {
    fn validate(n: i32) bool {
        return n > 0 and @mod(n, 2) == 0;
    }
}.validate);
```

## Transform Type

Transform values during validation:

```zig
// Define a transformation function
fn toUppercase(s: []const u8) []const u8 {
    // Note: This example is simplified
    // In real code, you'd allocate and transform
    return s;
}

const UppercaseName = z.Transform([]const u8, toUppercase);

const name = UppercaseName.init("hello");
std.debug.print("Original: {s}\n", .{name.getOriginal()});
std.debug.print("Transformed: {s}\n", .{name.get()});
```

## Combining Validators

Create complex validators by combining existing types:

```zig
const z = @import("zigantic");

// Age between 18-65, must be even
const WorkingAge = struct {
    age: z.EvenInt(i32, 18, 65),
    
    pub fn init(value: i32) !@This() {
        return .{
            .age = try z.EvenInt(i32, 18, 65).init(value),
        };
    }
    
    pub fn get(self: @This()) i32 {
        return self.age.get();
    }
};
```

## Pattern Matching with Regex

Use patterns for string validation:

```zig
// Simple pattern: 3 digits, dash, 4 digits
const PhonePattern = z.Regex("[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]");

const phone = try PhonePattern.init("123-4567");
std.debug.print("Phone: {s}\n", .{phone.get()});
```

### Pattern Syntax

| Pattern | Matches |
|---------|---------|
| `[0-9]` | Single digit |
| `[a-z]` | Single lowercase letter |
| `[A-Z]` | Single uppercase letter |
| `[a-zA-Z]` | Single letter |
| `[0-9a-zA-Z]` | Single alphanumeric |
| `.` | Any single character |
| Literal | Exact character match |

## OneOf Validator

Restrict values to an allowed set:

```zig
// Status can only be 1, 2, or 3
const Status = z.OneOf(u8, &[_]u8{ 1, 2, 3 });

const status = try Status.init(2);
std.debug.print("Is first: {}\n", .{status.isFirst()});
std.debug.print("Is last: {}\n", .{status.isLast()});
```

## Range with Step

Validate values in a range with step increments:

```zig
// Values 0-100 in steps of 10
const Tens = z.Range(i32, 0, 100, 10);

_ = try Tens.init(50);  // OK
_ = try Tens.init(55);  // Error: not in step
```

## Literal Validator

Match exact values:

```zig
// Must be exactly 42
const TheAnswer = z.Literal(i32, 42);

_ = try TheAnswer.init(42);  // OK
_ = TheAnswer.init(43) catch |_| {
    std.debug.print("Not the answer!\n", .{});
};
```

## Coerce Type

Convert between types:

```zig
// Convert i64 to i32
const ToI32 = z.Coerce(i64, i32);

const value = try ToI32.init(100);
const i32_value: i32 = value.get();
```

## Composing Schemas

Create validated schemas with custom logic:

```zig
const z = @import("zigantic");

const User = struct {
    username: z.Alphanumeric(3, 20),
    email: z.Email,
    age: z.Int(i32, 18, 120),
    role: z.OneOf([]const u8, &[_][]const u8{ "user", "admin", "moderator" }),
    
    // Custom validation method
    pub fn isAdmin(self: @This()) bool {
        return std.mem.eql(u8, self.role.get(), "admin");
    }
    
    pub fn canModerate(self: @This()) bool {
        const role = self.role.get();
        return std.mem.eql(u8, role, "admin") or std.mem.eql(u8, role, "moderator");
    }
};
```

## Validator Functions

Use the standalone validator functions for checks without type wrappers:

```zig
const validators = @import("zigantic").validators;

// Check formats
const is_email = validators.isValidEmail("user@example.com");
const is_url = validators.isValidUrl("https://example.com");
const is_uuid = validators.isUuid("550e8400-e29b-41d4-a716-446655440000");

// Check strings
const is_alpha = validators.isAlpha("hello");
const is_numeric = validators.isNumeric("12345");
const is_slug = validators.isSlug("hello-world");

// Check patterns
const matches = validators.matchesPattern("[0-9][0-9][0-9]", "123");
```

## Best Practices

1. **Keep validators pure** - Validator functions should have no side effects
2. **Return bool only** - Custom validators must return `bool`
3. **Handle edge cases** - Consider empty strings, zero values, etc.
4. **Compose over complexity** - Build complex validators from simpler ones
5. **Document constraints** - Use comments to explain validation rules

```zig
/// Username: 3-20 alphanumeric characters, lowercase only
const Username = z.Custom([]const u8, struct {
    fn validate(s: []const u8) bool {
        if (s.len < 3 or s.len > 20) return false;
        for (s) |c| {
            if (!std.ascii.isAlphanumeric(c)) return false;
            if (c >= 'A' and c <= 'Z') return false;
        }
        return true;
    }
}.validate);
```

## Next Steps

- [Schemas](/guide/schemas) - Complex nested structures
- [Error Handling](/guide/error-handling) - Handle validation errors
- [Validators API](/api/validators) - All validator functions
