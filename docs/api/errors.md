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
| `InvalidEmail`           | must be a valid email address | E010 |
| `InvalidUrl`             | must be a valid URL   | E011 |
| `InvalidUuid`            | must be a valid UUID  | E012 |
| `InvalidIpv4`            | must be a valid IPv4 address | E013 |
| `InvalidIpv6`            | must be a valid IPv6 address | E014 |
| `InvalidPhoneNumber`     | must be a valid phone number | E015 |
| `InvalidCreditCard`      | must be a valid credit card number | E016 |
| `MissingField`           | field is required     | E020 |
| `TypeMismatch`           | wrong type          | E021 |
| `PatternMismatch`        | does not match required pattern | E022 |
| `MustBeLowercase`        | must be lowercase   | E023 |
| `MustBeUppercase`        | must be uppercase   | E024 |
| `WeakPassword`           | password is too weak   | E025 |
| `MustBeEven`             | must be even        | E030 |
| `MustBeOdd`              | must be odd         | E031 |
| `NotMultiple`            | must be a multiple of the divisor | E032 |
| `MustBeHttps`            | must be HTTPS       | E033 |
| `OutOfRange`             | value is out of range | E034 |
| `NotInStep`              | value must be in step increments | E035 |
| `InvalidInteger`         | must be a valid integer | E036 |
| `InvalidBoolean`         | must be a valid boolean | E037 |
| `InvalidArray`           | must be a valid array | E038 |
| `InvalidObject`          | must be a valid object | E039 |
| `InvalidString`          | must be a valid string | E040 |
| `UnknownField`           | unknown field        | E041 |
| `DuplicateField`         | duplicate field      | E042 |
| `InvalidDate`            | must be a valid ISO date | E043 |
| `InvalidTime`            | must be a valid ISO time | E044 |
| `LiteralMismatch`        | does not match expected literal | E045 |
| `NotInAllowedValues`     | value is not allowed | E046 |
| `WrongLength`            | wrong length        | E047 |
| `TooFewItems`            | too few items       | E050 |
| `TooManyItems`           | too many items      | E051 |
| `DuplicateItem`          | duplicate item found | E052 |
| `EmptyCollection`        | collection cannot be empty | E053 |
| `NotPositive`            | must be positive     | E054 |
| `NotNegative`            | must be negative     | E055 |
| `NotZero`                | must not be zero     | E056 |
| `DivisionByZero`         | division by zero     | E057 |
| `InvalidFormat`          | invalid format       | E058 |
| `EmptyString`            | cannot be empty      | E059 |
| `InvalidNumber`          | must be a valid number | E060 |
| `CustomValidationFailed` | validation failed   | E099 |
| `InvalidJson`            | invalid JSON syntax  | E100 |
| `NestedError`            | nested validation error | E101 |
| `ValidationFailed`       | validation failed    | E102 |
| `ParseError`             | failed to parse value | E103 |

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
err.formatColored(allocator) // colored terminal output
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
errors.formatAllColored(allocator) // colorized terminal output
errors.formatAllWith(allocator, formatter) // custom messages
errors.formatAllColoredWith(allocator, formatter) // colored custom messages
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

## ValidationMessageConfig

Comptime config for overriding validation error messages on parameterized types:

```zig
const config = errors.ValidationMessageConfig{
    .too_short = "custom too short message",
    .too_large = "custom too large message",
};

// Check if a message override exists
const msg = errors.messageForConfig(error.TooShort, config); // ?[]const u8
```

Available fields correspond to each `ValidationError` variant. Use via the `f` suffix types:

```zig
const Name = Stringf(1, 50, .{ .too_short = "name is required" });
```

Or using the config directly:

```zig
err.message = errors.messageForWithConfig(err_type, formatter, config);
```

## Color Overrides

Override the default ANSI color for specific validation error types:

```zig
// Set color overrides globally
z.setColorOverrides(.{
    .too_short = .bright_red,    // Override TooShort color
    .invalid_email = .magenta,   // Override InvalidEmail color
});

// Or set via Config
var cfg = z.getConfig();
cfg.color_overrides = .{
    .too_short = .bright_red,
    .weak_password = .yellow,
};
z.setConfig(cfg);
```

Color resolution order:
1. `ColorOverrides` field for the error type (if non-null)
2. Built-in default color from `errorPresentation()`

Disable colors entirely:
```zig
z.disableColor();  // All output becomes plain text
z.enableColor();   // Re-enable colored output
```

## Version Utilities

```zig
z.getVersion()       // "0.0.3"
z.getVersionString() // "v0.0.3"
z.ISSUES_URL         // GitHub issues URL
```

## Color Utilities

```zig
const presentation = z.errorPresentation(z.errors.ValidationError.TooShort);
presentation.message // "value is too short"
presentation.code    // "E001"
presentation.color   // ANSI color used by the formatter

// The helper also exposes the color category directly.
z.errorColor(z.errors.ValidationError.InvalidEmail) // .blue

// Reusable formatter for custom messages
const custom = struct {
    fn format(err: z.errors.ValidationError) []const u8 {
        return switch (err) {
            z.errors.ValidationError.InvalidEmail => "please provide a valid email address",
            else => z.errorMessage(err),
        };
    }
}.format;

const custom_text = try errors.formatAllWith(allocator, custom);
```

## Internal Error Reporting

::: warning
Use only for **library bugs**, NOT for validation errors!
:::

```zig
// Report unexpected internal error
z.reportInternalError("Unexpected null in parser");

// Report with error code
z.reportInternalErrorWithCode(error.OutOfMemory);
```

Output:

```
[ZIGANTIC ERROR] Unexpected null in parser

If you believe this is a bug in zigantic, please report it at:
  https://github.com/muhammad-fiaz/zigantic/issues
```

## Update Checking

```zig
// Disable automatic update checking (call before using library)
z.disableUpdateCheck();

// Or use custom config
z.setConfig(.{
    .auto_update_check = false,
    .show_update_notifications = false,
});

// Manual update check (background)
if (z.checkForUpdates(allocator)) |thread| {
    defer thread.join();
}

// Manual update check (synchronous)
var info = try z.checkForUpdatesSync(allocator);
defer info.deinit();
if (info.update_available) {
    std.debug.print("Update: {s}\n", .{info.latest_version});
}
```
