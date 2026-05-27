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

// Colorized output for terminals that support ANSI colors
const colored = try errors.formatAllColored(allocator);
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

## Validation Errors vs Library Bugs

::: tip Important Distinction
**Validation errors** are expected behavior when users provide invalid data. Handle them normally.

**Library bugs** are unexpected internal errors that might indicate a problem with zigantic itself.
:::

### Validation Errors (Expected)

```zig
// This is normal - user provided invalid data
if (z.String(3, 50).init("Jo")) |name| {
    std.debug.print("Valid: {s}\n", .{name.get()});
} else |err| {
    // Handle normally - this is NOT a library bug
    std.debug.print("Error: {s}\n", .{z.errorMessage(err)});
}
```

### Library Bugs (Unexpected)

Only use `reportInternalError` for unexpected situations that might be library bugs:

```zig
// Only for unexpected internal errors
z.reportInternalError("Unexpected null during parsing");
```

This will print a message with the GitHub issues URL for reporting.

## Colorized Output

zigantic includes built-in ANSI colors for validation errors so terminal output stays readable and consistent:

```zig
const presentation = z.errorPresentation(z.errors.ValidationError.TooShort);
std.debug.print("[{s}] {s}\n", .{ presentation.code, presentation.message });
```

Use `FieldError.formatColored()` or `ErrorList.formatAllColored()` for colored terminal output.

## Color Overrides

Override the default color for specific error types:

```zig
// Set globally via helper
z.setColorOverrides(.{
    .too_short = .bright_red,
    .invalid_email = .magenta,
    .weak_password = .yellow,
});

// Or via Config
var cfg = z.getConfig();
cfg.color_overrides = .{
    .too_short = .bright_red,
};
z.setConfig(cfg);
```

Disable colors entirely:
```zig
z.disableColor();  // Plain text output
z.enableColor();   // Re-enable
```

## Custom Error Messages

Override error messages per-type via the `f` suffix variant with a comptime `messages` parameter:

```zig
const Name = z.Stringf(3, 50, .{ .too_short = "name is required" });
const Age = z.Intf(i32, 18, 120, .{ .too_small = "must be 18+" });

if (Name.init("Jo")) |_| {} else |err| {
    std.debug.print("{s}\n", .{Name.messageFor(err).?});
    // "name is required"
}
```

Available on all parameterized types: `Stringf`, `Intf`, `Floatf`, `Listf`, `Trimmedf`, `Secretf`, `StrongPasswordf`, `HexStringf`, etc.

## Global Message Formatter

Set a global formatter function to customize messages across all types (including format types like `Email`, `Url`, etc.):

```zig
z.Config.validation_message_formatter = struct {
    fn f(err: z.errors.ValidationError) []const u8 {
        return switch (err) {
            .InvalidEmail => "please enter a valid email address",
            .TooShort => "the value is too short",
            else => z.errorMessage(err),
        };
    }
}.f;
```

## Lifecycle Callbacks

Register hooks for validation and serialization lifecycle events:

```zig
// Called before validation starts
z.Config.before_validation_callback = struct {
    fn call(type_name: []const u8) void {
        std.debug.print("Validating: {s}\n", .{type_name});
    }
}.call;

// Called after each field is validated
z.Config.on_field_validated_callback = struct {
    fn call(field: []const u8, valid: bool) void {
        std.debug.print("Field {s}: {s}\n", .{ field, if (valid) "OK" else "FAIL" });
    }
}.call;

// Called when a field validation fails
z.Config.on_field_error_callback = struct {
    fn call(field: []const u8, err_type: z.errors.ValidationError, msg: []const u8) void {
        std.debug.print("Error in {s}: {s} ({s})\n", .{ field, msg, @tagName(err_type) });
    }
}.call;

// Called after all validation is complete
z.Config.on_validation_complete_callback = struct {
    fn call(valid: bool, error_count: usize) void {
        std.debug.print("Validation complete: valid={}, errors={d}\n", .{ valid, error_count });
    }
}.call;

// Called before JSON serialization
z.Config.before_serialize_callback = struct {
    fn call() void {
        std.debug.print("Starting serialization\n", .{});
    }
}.call;

// Called after JSON serialization with the result
z.Config.after_serialize_callback = struct {
    fn call(result: []const u8) void {
        std.debug.print("Serialized to {d} bytes\n", .{result.len});
    }
}.call;
```

## Optional Error Policies

If you want zigantic to handle failures more aggressively, you can set callbacks or exit flags once at startup:

```zig
const z = @import("zigantic");

pub fn main() !void {
    z.setConfig(.{
        .exit_on_validation_error = true,
        .exit_on_serialization_error = true,
        .validation_message_formatter = struct {
            pub fn format(err: z.errors.ValidationError) []const u8 {
                return switch (err) {
                    z.errors.ValidationError.InvalidEmail => "please provide a valid email address",
                    z.errors.ValidationError.TooShort => "the value is too short",
                    else => z.errorMessage(err),
                };
            }
        }.format,
        .validation_error_callback = struct {
            pub fn handle(msg: []const u8) void {
                std.debug.print("VALIDATION: {s}\n", .{msg});
            }
        }.handle,
        .serialization_error_formatter = struct {
            pub fn format(err: anyerror) []const u8 {
                return switch (err) {
                    else => @errorName(err),
                };
            }
        }.format,
        .serialization_error_callback = struct {
            pub fn handle(msg: []const u8) void {
                std.debug.print("SERIALIZATION: {s}\n", .{msg});
            }
        }.handle,
    });
}
```
