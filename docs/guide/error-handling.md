# Error Handling

Comprehensive error handling with codes and utilities.

## Basic Error Handling

```zig
const z = @import("zigantic");

// Check validation result
if (z.String(3, 50).init("Jo")) |name| {
    std.debug.print("Valid: {s}\n", .{name.get()});
} else |err| {
    std.debug.print("Error: {s}\n", .{z.errorMessage(err)});
    std.debug.print("Code: {s}\n", .{z.errorCode(err)});
}
```

## Error Types

| Error                | Message               | Code |
| -------------------- | --------------------- | ---- |
| `TooShort`           | value is too short    | E001 |
| `TooLong`            | value is too long     | E002 |
| `TooSmall`           | value is too small    | E003 |
| `TooLarge`           | value is too large    | E004 |
| `InvalidEmail`       | must be a valid email | E010 |
| `InvalidUrl`         | must be a valid URL   | E011 |
| `MissingField`       | field is required     | E020 |
| `TypeMismatch`       | wrong type            | E021 |
| `WeakPassword`       | password is too weak  | -    |
| `MustBeEven`         | must be even          | -    |
| `MustBeOdd`          | must be odd           | -    |
| `NotMultiple`        | must be multiple      | -    |
| `MustBeHttps`        | must be HTTPS         | -    |
| `NotInAllowedValues` | not in allowed        | -    |

## ErrorList

Collect multiple errors:

```zig
var errors = z.errors.ErrorList.init(allocator);
defer errors.deinit();

// Add errors
try errors.add("name", error.TooShort, "too short", "Jo");
try errors.addWithPath("user", "email", error.InvalidEmail, "invalid", null);
try errors.addIndexed("tags", 2, error.TooLong, "too long", null);
try errors.addWithCode("field", error.TooShort, "msg", null, "E001");

// Check errors
errors.hasErrors()     // true
errors.count()         // number of errors
errors.first()         // first error or null
errors.last()          // last error or null
errors.containsField("name")  // true
errors.containsErrorType(error.TooShort) // true

// Format output
const text = try errors.formatAll(allocator);
const json = try errors.toJsonArray(allocator);
```

## Limited Error Collection

```zig
// Collect max 5 errors
var errors = z.errors.ErrorList.initWithMax(allocator, 5);
defer errors.deinit();
```

## JSON Output

```zig
const json = try errors.toJsonArray(allocator);
// [{"field":"name","message":"too short","value":"Jo"},...]
```

## Error Codes

```zig
const err = z.errors.ValidationError.TooShort;
z.errorMessage(err) // "value is too short"
z.errorCode(err)    // "E001"
```

## JSON Parsing Errors

```zig
const User = struct {
    name: z.String(3, 50),
    age: z.Int(i32, 18, 120),
};

var result = try z.fromJson(User, json, allocator);
defer result.deinit();

if (!result.isValid()) {
    for (result.error_list.errors.items) |err| {
        std.debug.print("[{s}] {s}: {s}\n", .{
            z.errorCode(err.error_type),
            err.field,
            err.message,
        });
    }
}
```

## Merge Error Lists

```zig
var errors1 = z.errors.ErrorList.init(allocator);
var errors2 = z.errors.ErrorList.init(allocator);
// ... add errors ...
try errors1.merge(errors2);
```
