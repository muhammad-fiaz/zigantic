# Philosophy

zigantic's design principles.

## Core Principles

### 1. Types Over Metadata

Validation is expressed through types, not annotations or metadata.

```zig
// zigantic: types ARE the validation
const User = struct {
    age: z.Int(i32, 18, 120),  // Validation is the type itself
};

// Not metadata attached to types
// age: i32 @range(18, 120)  // We don't do this
```

### 2. Compile-Time Over Runtime

Validation logic is resolved at compile time. No runtime reflection.

```zig
// Compile-time generics
pub fn String(comptime min: usize, comptime max: usize) type {
    return struct {
        // Constraints baked into the type
    };
}
```

### 3. Clarity Over Cleverness

Explicit, readable code that any Zig developer understands immediately.

```zig
// Clear and explicit
const name = try z.String(1, 50).init("Alice");
const age = try z.PositiveInt(i32).init(25);

// Not magic
// name := validate("Alice")  // What does this do?
```

### 4. Zero-Cost Abstractions

Unused features have no runtime cost.

```zig
// If you don't use Email validation, it's not in your binary
const Simple = struct {
    name: []const u8,  // Plain Zig, no overhead
};
```

### 5. Zig-Native

No DSLs, no macros, no magic. Just Zig.

```zig
// Uses standard Zig patterns
const result = try z.fromJson(User, json, allocator);
defer result.deinit();  // Standard Zig memory management

// Error handling is Zig error handling
const name = z.String(1, 50).init("") catch |err| {
    // Handle error the Zig way
};
```

## Design Decisions

### Why Types for Validation?

1. **Compile-time safety**: Invalid constraints fail at compile time
2. **Self-documenting**: Types describe their constraints
3. **Composable**: Types compose naturally
4. **IDE support**: Type information available everywhere

### Why Not Annotations?

Zig doesn't have annotations. We work with the language, not against it.

### Why Wrapper Types?

```zig
// Wrapper types (what we do)
age: z.Int(i32, 18, 120)

// vs raw types with separate validation (what we don't)
age: i32,  // Where is validation? Who knows!
```

Wrapper types:

- Keep validation with the data
- Are self-documenting
- Enable useful methods (`.get()`, `.isPositive()`, etc.)

## The Golden Rule

> **zigantic must feel like Zig**

If something feels foreign to a Zig developer, we've failed.
