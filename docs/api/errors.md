# Errors API

Error types and handling utilities.

## ValidationError

All possible validation errors:

| Error                    | Message             | Code |
| ------------------------ | ------------------- | ---- |
| `TooShort`               | value is too short  | E001 |
| `TooLong`                | value is too long   | E002 |
| `TooSmall`               | value is too small  | E003 |
| `TooLarge`               | value is too large  | E004 |
| `InvalidEmail`           | must be valid email | E010 |
| `InvalidUrl`             | must be valid URL   | E011 |
| `InvalidUuid`            | must be valid UUID  | -    |
| `InvalidIpv4`            | must be valid IPv4  | -    |
| `InvalidIpv6`            | must be valid IPv6  | -    |
| `InvalidPhoneNumber`     | invalid phone       | -    |
| `InvalidCreditCard`      | invalid card        | -    |
| `MissingField`           | field required      | E020 |
| `TypeMismatch`           | wrong type          | E021 |
| `PatternMismatch`        | doesn't match       | -    |
| `MustBeLowercase`        | must be lowercase   | -    |
| `MustBeUppercase`        | must be uppercase   | -    |
| `WeakPassword`           | password too weak   | -    |
| `MustBeEven`             | must be even        | -    |
| `MustBeOdd`              | must be odd         | -    |
| `NotMultiple`            | not multiple        | -    |
| `MustBeHttps`            | must be HTTPS       | -    |
| `OutOfRange`             | out of range        | -    |
| `NotInStep`              | not in step         | -    |
| `WrongLength`            | wrong length        | -    |
| `TooFewItems`            | too few items       | -    |
| `TooManyItems`           | too many items      | -    |
| `NotInAllowedValues`     | not allowed         | -    |
| `CustomValidationFailed` | validation failed   | E099 |

## Error Functions

```zig
const err = z.errors.ValidationError.TooShort;

z.errorMessage(err) // "value is too short"
z.errorCode(err)    // "E001"
```

## FieldError

```zig
pub const FieldError = struct {
    field: []const u8,      // Field path
    message: []const u8,    // Human message
    error_type: ValidationError,
    value: ?[]const u8,     // Actual value
    code: ?[]const u8,      // Error code
};

// Methods
err.format(allocator)  // "field: message (got: value)"
err.toJson(allocator)  // {"field":"...","message":"..."}
```

## ErrorList

```zig
var errors = z.errors.ErrorList.init(allocator);
defer errors.deinit();

// Add errors
try errors.add("name", error.TooShort, "too short", "Jo");
try errors.addWithPath("user", "email", error.InvalidEmail, "invalid", null);
try errors.addIndexed("items", 2, error.TooLong, "too long", null);
try errors.addWithCode("field", error.TooShort, "msg", null, "E001");

// Limited collection
var limited = z.errors.ErrorList.initWithMax(allocator, 5);

// Check errors
errors.hasErrors()           // bool
errors.count()               // usize
errors.first()               // ?FieldError
errors.last()                // ?FieldError
errors.containsField("name") // bool
errors.containsErrorType(error.TooShort) // bool

// Format
errors.formatAll(allocator)  // "field: msg\nfield2: msg2\n"
errors.toJsonArray(allocator) // [{"field":"..."},...]

// Merge
try errors.merge(other_errors);

// Clear
errors.clear();

// Get errors for field
const field_errors = try errors.getErrorsForField("name", allocator);
```

## JSON Parsing Errors

```zig
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

    // JSON output
    const json_errors = try result.error_list.toJsonArray(allocator);
    defer allocator.free(json_errors);
}
```
