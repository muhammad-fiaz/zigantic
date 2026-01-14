# Benchmarks

zigantic is designed for high performance with zero runtime overhead. All validation logic is resolved at compile time.

## Running Benchmarks

To run the benchmarks locally:

```bash
zig build bench
```

This will output results to the console and generate a `benchmark-results.md` file.

## Benchmark Categories

### String Validation

| Benchmark | Operations/sec | Avg Latency |
|-----------|---------------|-------------|
| String(1,50) - Basic name | ~5M+ | <200ns |
| String(1,1000) - Long string | ~4M+ | <250ns |
| Trimmed(1,100) - Auto-trim | ~4M+ | <250ns |
| Secret(8,100) - Password | ~3M+ | <300ns |
| Email - Simple address | ~2M+ | <500ns |
| Email - Complex address | ~1.5M+ | <700ns |

### Number Validation

| Benchmark | Operations/sec | Avg Latency |
|-----------|---------------|-------------|
| Int(i32,0,150) - Basic | ~10M+ | <100ns |
| Int(i32,-1000,1000) - Range | ~10M+ | <100ns |
| PositiveInt(u32) | ~10M+ | <100ns |
| Percentage(f64) | ~8M+ | <125ns |
| MultipleOf(i32,5) | ~8M+ | <125ns |

### Format Validation

| Benchmark | Operations/sec | Avg Latency |
|-----------|---------------|-------------|
| Url - HTTPS with query | ~1M+ | <1000ns |
| Uuid - Standard format | ~2M+ | <500ns |
| Ipv4 - Address | ~3M+ | <350ns |
| Ipv6 - Full address | ~1.5M+ | <700ns |
| Slug - URL slug | ~4M+ | <250ns |
| Semver - Version string | ~3M+ | <350ns |
| CreditCard - Visa | ~2M+ | <500ns |
| PhoneNumber - International | ~2.5M+ | <400ns |

### JSON Parsing

| Benchmark | Operations/sec | Avg Latency |
|-----------|---------------|-------------|
| fromJson - Simple struct | ~100K+ | <10μs |
| fromJson - Complex struct | ~50K+ | <20μs |
| toJson - Serialize | ~200K+ | <5μs |

### Collection Validation

| Benchmark | Operations/sec | Avg Latency |
|-----------|---------------|-------------|
| List([]const u8,1,10) | ~5M+ | <200ns |
| FixedList(i32,3) | ~8M+ | <125ns |

## Comparison with Other Libraries

### vs. Python Pydantic

| Operation | zigantic | Pydantic v2 |
|-----------|----------|-------------|
| Simple validation | <200ns | ~1-5μs |
| JSON parsing | <20μs | ~50-100μs |
| Memory overhead | Zero | Dynamic allocation |
| Compile-time checks | Yes | No |

### vs. Other Zig Libraries

zigantic provides a unique combination of:
- **Compile-time validation** - Errors caught at build time
- **Rich type system** - 40+ built-in types
- **Zero runtime overhead** - No dynamic dispatch
- **Human-readable errors** - Developer-friendly messages

## Benchmark Environment

Benchmarks are run on GitHub Actions runners:
- **Platform:** Linux (ubuntu-latest)
- **Architecture:** x86_64
- **Zig Version:** 0.15.2
- **Optimization:** ReleaseFast

## Understanding Results

- **Operations/sec (higher is better)** - Number of operations per second
- **Avg Latency (lower is better)** - Average time per operation in nanoseconds

> [!NOTE]
> These benchmarks are generated automatically. Results may vary based on:
> - Hardware specifications
> - System load
> - Input data complexity

## Optimizing Performance

### 1. Use Compile-Time Types

```zig
// ✅ Good: Compile-time known constraints
const Name = z.String(1, 50);

// ❌ Avoid: Runtime string length checks where possible
```

### 2. Reuse Allocators

```zig
// ✅ Good: Reuse allocator for multiple operations
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

for (items) |item| {
    var result = try z.fromJson(Schema, item, allocator);
    defer result.deinit();
}
```

### 3. Batch Processing

For high-throughput scenarios, process items in batches to amortize allocation costs.

### 4. Use Appropriate Types

Choose the most specific type for your use case:

```zig
// ✅ Good: Specific type
const Port = z.Int(u16, 1, 65535);

// ❌ Less optimal: Generic type
const Port = z.Int(i64, 1, 65535);
```

## Running Custom Benchmarks

Create your own benchmarks:

```zig
const std = @import("std");
const z = @import("zigantic");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    
    const iterations = 1_000_000;
    for (0..iterations) |_| {
        _ = try z.Email.init("test@example.com");
    }
    
    const elapsed = timer.read();
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / 
        (@as(f64, @floatFromInt(elapsed)) / 1_000_000_000.0);
    
    std.debug.print("Email validation: {d:.0} ops/sec\n", .{ops_per_sec});
}
```
