const std = @import("std");
const z = @import("zigantic");
const builtin = @import("builtin");

const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_time_ns: u64,
    ops_per_sec: f64,
    avg_latency_ns: f64,
    category: []const u8,

    const categories = [_][]const u8{
        "String Validation",
        "Number Validation",
        "Format Validation",
        "Extended Types",
        "JSON Parsing",
        "Collection Validation",
        "Utility Methods",
    };
};

const ITERATIONS = 10_000;
const WARMUP = 100;

fn printResults(results: []const BenchmarkResult) void {
    std.debug.print("\n", .{});
    std.debug.print("-" ** 100 ++ "\n", .{});
    std.debug.print("                                 ZIGANTIC BENCHMARK RESULTS\n", .{});
    std.debug.print("-" ** 100 ++ "\n", .{});

    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        std.debug.print("\n[{s}]\n", .{cat});
        std.debug.print("-" ** 100 ++ "\n", .{});
        std.debug.print("{s:<50} {s:>20} {s:>25}\n", .{ "Benchmark", "Ops/sec", "Avg Latency (ns)" });
        std.debug.print("-" ** 100 ++ "\n", .{});

        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                std.debug.print("{s:<50} {d:>20.0} {d:>25.0}\n", .{
                    r.name,
                    r.ops_per_sec,
                    r.avg_latency_ns,
                });
            }
        }
    }

    std.debug.print("\n", .{});
    std.debug.print("=" ** 100 ++ "\n", .{});
}

fn runBenchmark(
    name: []const u8,
    comptime benchFn: anytype,
    category: []const u8,
) BenchmarkResult {
    for (0..WARMUP) |_| {
        benchFn();
    }

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const start_time = std.Io.Timestamp.now(io, .awake);
    for (0..ITERATIONS) |_| {
        benchFn();
    }
    const end_time = std.Io.Timestamp.now(io, .awake);
    const total_time_ns = @as(u64, @intCast(start_time.durationTo(end_time).nanoseconds));

    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(total_time_ns)) / 1_000_000_000.0);
    const avg_latency_ns = @as(f64, @floatFromInt(total_time_ns)) / @as(f64, @floatFromInt(ITERATIONS));

    return BenchmarkResult{
        .name = name,
        .iterations = ITERATIONS,
        .total_time_ns = total_time_ns,
        .ops_per_sec = ops_per_sec,
        .avg_latency_ns = avg_latency_ns,
        .category = category,
    };
}

fn benchmarkStringBasic() void {
    const Name = z.String(1, 50);
    _ = Name.init("Alice Johnson") catch {};
}

fn benchmarkStringLong() void {
    const LongString = z.String(1, 1000);
    _ = LongString.init("This is a much longer string that tests the performance of validation on larger inputs with more characters to process") catch {};
}

fn benchmarkTrimmed() void {
    const Input = z.Trimmed(1, 100);
    _ = Input.init("   trimmed content   ") catch {};
}

fn benchmarkSecret() void {
    const Password = z.Secret(8, 100);
    _ = Password.init("MyP@ssw0rd!123") catch {};
}

fn benchmarkEmail() void {
    _ = z.Email.init("user@example.com") catch {};
}

fn benchmarkEmailComplex() void {
    _ = z.Email.init("very.long.email.address+tag@subdomain.example.company.com") catch {};
}

fn benchmarkLowercase() void {
    const L = z.Lowercase(50);
    _ = L.init("hello world") catch {};
}

fn benchmarkUppercase() void {
    const U = z.Uppercase(50);
    _ = U.init("HELLO WORLD") catch {};
}

fn benchmarkAlphanumeric() void {
    const A = z.Alphanumeric(1, 50);
    _ = A.init("abc123def456") catch {};
}

fn benchmarkAsciiString() void {
    const A = z.AsciiString(1, 50);
    _ = A.init("Hello World 123!") catch {};
}

fn benchmarkIntBasic() void {
    const Age = z.Int(i32, 0, 150);
    _ = Age.init(42) catch {};
}

fn benchmarkIntRange() void {
    const Score = z.Int(i32, -1000, 1000);
    _ = Score.init(750) catch {};
}

fn benchmarkPositiveInt() void {
    const Count = z.PositiveInt(u32);
    _ = Count.init(12345) catch {};
}

fn benchmarkFloat() void {
    const Percentage = z.Percentage(f64);
    _ = Percentage.init(75.5) catch {};
}

fn benchmarkMultipleOf() void {
    const Multiple = z.MultipleOf(i32, 5);
    _ = Multiple.init(100) catch {};
}

fn benchmarkEvenInt() void {
    const E = z.EvenInt(i32, 0, 1000);
    _ = E.init(42) catch {};
}

fn benchmarkOddInt() void {
    const O = z.OddInt(i32, 0, 1000);
    _ = O.init(43) catch {};
}

fn benchmarkUrl() void {
    _ = z.Url.init("https://example.com/path/to/resource?query=value") catch {};
}

fn benchmarkUuid() void {
    _ = z.Uuid.init("550e8400-e29b-41d4-a716-446655440000") catch {};
}

fn benchmarkIpv4() void {
    _ = z.Ipv4.init("192.168.1.100") catch {};
}

fn benchmarkIpv6() void {
    _ = z.Ipv6.init("2001:0db8:85a3:0000:0000:8a2e:0370:7334") catch {};
}

fn benchmarkSlug() void {
    _ = z.Slug.init("hello-world-example-slug") catch {};
}

fn benchmarkSemver() void {
    _ = z.Semver.init("1.2.3") catch {};
}

fn benchmarkCreditCard() void {
    _ = z.CreditCard.init("4111111111111111") catch {};
}

fn benchmarkPhoneNumber() void {
    _ = z.PhoneNumber.init("+1234567890") catch {};
}

fn benchmarkHexColor() void {
    _ = z.HexColor().init("#ff5733") catch {};
}

fn benchmarkMacAddress() void {
    _ = z.MacAddress().init("00:1A:2B:3C:4D:5E") catch {};
}

fn benchmarkIsoDateTime() void {
    _ = z.IsoDateTime().init("2024-01-15T10:30:00Z") catch {};
}

fn benchmarkIsoDate() void {
    _ = z.IsoDate().init("2024-01-15") catch {};
}

fn benchmarkCountryCode() void {
    _ = z.CountryCode().init("US") catch {};
}

fn benchmarkCurrencyCode() void {
    _ = z.CurrencyCode().init("USD") catch {};
}

fn benchmarkLatitude() void {
    _ = z.Latitude().init(45.0) catch {};
}

fn benchmarkLongitude() void {
    _ = z.Longitude().init(-75.0) catch {};
}

fn benchmarkPort() void {
    _ = z.Port().init(443) catch {};
}

fn benchmarkIban() void {
    _ = z.Iban.init("DE89370400440532013000") catch {};
}

fn benchmarkBase58() void {
    _ = z.Base58.init("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa") catch {};
}

fn benchmarkHslColor() void {
    _ = z.HslColor.init("hsl(120, 100%, 50%)") catch {};
}

fn benchmarkDuration() void {
    _ = z.Duration.init("P1Y2M3DT4H5M6S") catch {};
}

fn benchmarkCronExpression() void {
    _ = z.CronExpression.init("0 12 * * *") catch {};
}

fn benchmarkIsbn10() void {
    _ = z.Isbn10.init("0-306-40615-2") catch {};
}

fn benchmarkIsbn13() void {
    _ = z.Isbn13.init("978-0-306-40615-7") catch {};
}

fn benchmarkStrongPasswordStrict() void {
    _ = z.StrongPasswordStrict.init("P@ssw0rd!") catch {};
}

fn benchmarkAsciiAlphaString() void {
    const A = z.AsciiAlphaString(1, 50);
    _ = A.init("HelloWorld") catch {};
}

fn benchmarkJsonSimple() void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const SimpleUser = struct {
        name: z.String(1, 50),
        age: z.Int(i32, 0, 150),
    };

    const json_str = "{\"name\": \"Alice\", \"age\": 30}";
    var result = z.fromJson(SimpleUser, json_str, allocator) catch return;
    result.deinit();
}

fn benchmarkJsonComplex() void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const ComplexUser = struct {
        id: z.PositiveInt(u32),
        name: z.String(1, 50),
        email: z.Email,
        age: z.Int(i32, 18, 120),
        role: z.Default([]const u8, "user"),
    };

    const json_str =
        \\{"id": 123, "name": "Alice Johnson", "email": "alice@example.com", "age": 30}
    ;
    var result = z.fromJson(ComplexUser, json_str, allocator) catch return;
    result.deinit();
}

fn benchmarkToJson() void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const User = struct {
        name: z.String(1, 50),
        age: z.Int(i32, 0, 150),
    };

    const user = User{
        .name = z.String(1, 50).init("Alice") catch unreachable,
        .age = z.Int(i32, 0, 150).init(30) catch unreachable,
    };

    const json_str = z.toJson(user, allocator) catch return;
    allocator.free(json_str);
}

fn benchmarkFromQueryString() void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const User = struct {
        name: z.String(1, 50),
        age: z.Int(i32, 0, 150),
    };

    const qs = "name=Alice&age=25";
    var result = z.fromQueryString(User, qs, allocator) catch return;
    result.deinit();
}

fn benchmarkList() void {
    const Tags = z.List([]const u8, 1, 10);
    const items = [_][]const u8{ "zig", "validation", "types" };
    _ = Tags.init(&items) catch {};
}

fn benchmarkFixedList() void {
    const Coords = z.FixedList(i32, 3);
    const values = [_]i32{ 10, 20, 30 };
    _ = Coords.init(&values) catch {};
}

fn benchmarkListSum() void {
    const L = z.List(u32, 1, 10);
    const items = [_]u32{ 10, 20, 30, 40, 50 };
    const list = L.init(&items) catch return;
    _ = list.sum();
}

fn benchmarkListContains() void {
    const L = z.List(u32, 1, 10);
    const items = [_]u32{ 10, 20, 30, 40, 50 };
    const list = L.init(&items) catch return;
    _ = list.contains(30);
}

fn benchmarkEmailMethods() void {
    const email = z.Email.init("user+tag@example.com") catch return;
    _ = email.hasTag();
    _ = email.tld();
    _ = email.isFreeEmail();
}

fn benchmarkUrlMethods() void {
    const url = z.Url.init("https://example.com:8080/path?q=1#section") catch return;
    _ = url.port();
    _ = url.query();
    _ = url.fragment();
    _ = url.filename();
}

fn benchmarkStrongPassword() void {
    const Pwd = z.StrongPassword(8, 100);
    _ = Pwd.init("P@ssw0rd!") catch {};
}

fn benchmarkOneOf() void {
    const Status = z.OneOf(u8, &[_]u8{ 1, 2, 3 });
    _ = Status.init(2) catch {};
}

fn benchmarkRange() void {
    const R = z.Range(i32, 0, 100, 10);
    _ = R.init(50) catch {};
}

fn benchmarkNullable() void {
    const N = z.Nullable(u32);
    _ = N.init(42);
}

fn benchmarkDefault() void {
    const Role = z.Default([]const u8, "user");
    _ = Role.initDefault();
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var results = std.ArrayList(BenchmarkResult).empty;
    defer results.deinit(allocator);

    z.disableUpdateCheck();

    std.debug.print("\n[INFO] Running zigantic benchmarks...\n", .{});
    std.debug.print("[INFO] Warmup iterations: {d}\n", .{WARMUP});
    std.debug.print("[INFO] Benchmark iterations: {d}\n", .{ITERATIONS});

    // String Validation
    try results.append(allocator, runBenchmark("String(1,50) - Basic name", benchmarkStringBasic, "String Validation"));
    try results.append(allocator, runBenchmark("String(1,1000) - Long string", benchmarkStringLong, "String Validation"));
    try results.append(allocator, runBenchmark("Trimmed(1,100) - Auto-trim", benchmarkTrimmed, "String Validation"));
    try results.append(allocator, runBenchmark("Secret(8,100) - Password", benchmarkSecret, "String Validation"));
    try results.append(allocator, runBenchmark("StrongPassword(8,100)", benchmarkStrongPassword, "String Validation"));
    try results.append(allocator, runBenchmark("Lowercase(50)", benchmarkLowercase, "String Validation"));
    try results.append(allocator, runBenchmark("Uppercase(50)", benchmarkUppercase, "String Validation"));
    try results.append(allocator, runBenchmark("Alphanumeric(1,50)", benchmarkAlphanumeric, "String Validation"));
    try results.append(allocator, runBenchmark("AsciiString(1,50)", benchmarkAsciiString, "String Validation"));

    // Number Validation
    try results.append(allocator, runBenchmark("Int(i32,0,150) - Basic", benchmarkIntBasic, "Number Validation"));
    try results.append(allocator, runBenchmark("Int(i32,-1000,1000) - Range", benchmarkIntRange, "Number Validation"));
    try results.append(allocator, runBenchmark("PositiveInt(u32)", benchmarkPositiveInt, "Number Validation"));
    try results.append(allocator, runBenchmark("EvenInt(i32,0,1000)", benchmarkEvenInt, "Number Validation"));
    try results.append(allocator, runBenchmark("OddInt(i32,0,1000)", benchmarkOddInt, "Number Validation"));
    try results.append(allocator, runBenchmark("Percentage(f64)", benchmarkFloat, "Number Validation"));
    try results.append(allocator, runBenchmark("MultipleOf(i32,5)", benchmarkMultipleOf, "Number Validation"));

    // Format Validation
    try results.append(allocator, runBenchmark("Email - Simple", benchmarkEmail, "Format Validation"));
    try results.append(allocator, runBenchmark("Email - Complex", benchmarkEmailComplex, "Format Validation"));
    try results.append(allocator, runBenchmark("Url - HTTPS with query", benchmarkUrl, "Format Validation"));
    try results.append(allocator, runBenchmark("Uuid", benchmarkUuid, "Format Validation"));
    try results.append(allocator, runBenchmark("Ipv4", benchmarkIpv4, "Format Validation"));
    try results.append(allocator, runBenchmark("Ipv6", benchmarkIpv6, "Format Validation"));
    try results.append(allocator, runBenchmark("Slug", benchmarkSlug, "Format Validation"));
    try results.append(allocator, runBenchmark("Semver", benchmarkSemver, "Format Validation"));
    try results.append(allocator, runBenchmark("CreditCard - Visa", benchmarkCreditCard, "Format Validation"));
    try results.append(allocator, runBenchmark("PhoneNumber", benchmarkPhoneNumber, "Format Validation"));
    try results.append(allocator, runBenchmark("HexColor", benchmarkHexColor, "Format Validation"));
    try results.append(allocator, runBenchmark("MacAddress", benchmarkMacAddress, "Format Validation"));
    try results.append(allocator, runBenchmark("IsoDateTime", benchmarkIsoDateTime, "Format Validation"));
    try results.append(allocator, runBenchmark("IsoDate", benchmarkIsoDate, "Format Validation"));
    try results.append(allocator, runBenchmark("CountryCode", benchmarkCountryCode, "Format Validation"));
    try results.append(allocator, runBenchmark("CurrencyCode", benchmarkCurrencyCode, "Format Validation"));
    try results.append(allocator, runBenchmark("Latitude", benchmarkLatitude, "Format Validation"));
    try results.append(allocator, runBenchmark("Longitude", benchmarkLongitude, "Format Validation"));
    try results.append(allocator, runBenchmark("Port", benchmarkPort, "Format Validation"));

    // Extended Types
    try results.append(allocator, runBenchmark("Iban", benchmarkIban, "Extended Types"));
    try results.append(allocator, runBenchmark("Base58", benchmarkBase58, "Extended Types"));
    try results.append(allocator, runBenchmark("HslColor", benchmarkHslColor, "Extended Types"));
    try results.append(allocator, runBenchmark("Duration", benchmarkDuration, "Extended Types"));
    try results.append(allocator, runBenchmark("CronExpression", benchmarkCronExpression, "Extended Types"));
    try results.append(allocator, runBenchmark("Isbn10", benchmarkIsbn10, "Extended Types"));
    try results.append(allocator, runBenchmark("Isbn13", benchmarkIsbn13, "Extended Types"));
    try results.append(allocator, runBenchmark("StrongPasswordStrict", benchmarkStrongPasswordStrict, "Extended Types"));
    try results.append(allocator, runBenchmark("AsciiAlphaString(1,50)", benchmarkAsciiAlphaString, "Extended Types"));

    // JSON Parsing
    try results.append(allocator, runBenchmark("fromJson - Simple struct", benchmarkJsonSimple, "JSON Parsing"));
    try results.append(allocator, runBenchmark("fromJson - Complex struct", benchmarkJsonComplex, "JSON Parsing"));
    try results.append(allocator, runBenchmark("toJson - Serialize", benchmarkToJson, "JSON Parsing"));
    try results.append(allocator, runBenchmark("fromQueryString", benchmarkFromQueryString, "JSON Parsing"));

    // Collection Validation
    try results.append(allocator, runBenchmark("List([]const u8,1,10)", benchmarkList, "Collection Validation"));
    try results.append(allocator, runBenchmark("FixedList(i32,3)", benchmarkFixedList, "Collection Validation"));
    try results.append(allocator, runBenchmark("List.sum()", benchmarkListSum, "Collection Validation"));
    try results.append(allocator, runBenchmark("List.contains()", benchmarkListContains, "Collection Validation"));

    // Utility Methods
    try results.append(allocator, runBenchmark("Email methods (hasTag, tld, isFreeEmail)", benchmarkEmailMethods, "Utility Methods"));
    try results.append(allocator, runBenchmark("Url methods (port, query, fragment, filename)", benchmarkUrlMethods, "Utility Methods"));
    try results.append(allocator, runBenchmark("OneOf(u8)", benchmarkOneOf, "Utility Methods"));
    try results.append(allocator, runBenchmark("Range(i32,0,100,10)", benchmarkRange, "Utility Methods"));
    try results.append(allocator, runBenchmark("Nullable(u32)", benchmarkNullable, "Utility Methods"));
    try results.append(allocator, runBenchmark("Default([]const u8,\"user\")", benchmarkDefault, "Utility Methods"));

    // Print all results to console
    printResults(results.items);

    // Summary Statistics
    var total_ops: f64 = 0;
    var max_ops: f64 = 0;
    var min_ops: f64 = std.math.floatMax(f64);
    var count: usize = 0;
    var max_name: []const u8 = "";
    var min_name: []const u8 = "";

    for (results.items) |r| {
        total_ops += r.ops_per_sec;
        count += 1;
        if (r.ops_per_sec > max_ops) {
            max_ops = r.ops_per_sec;
            max_name = r.name;
        }
        if (r.ops_per_sec < min_ops) {
            min_ops = r.ops_per_sec;
            min_name = r.name;
        }
    }

    const avg_ops = if (count > 0) total_ops / @as(f64, @floatFromInt(count)) else 0;
    const avg_latency = if (avg_ops > 0) 1_000_000_000.0 / avg_ops else 0;

    // Write Markdown report
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const cwd = std.Io.Dir.cwd();
    const md_file = cwd.createFile(io, "benchmark-results.md", .{}) catch |err| {
        std.debug.print("Warning: Could not create benchmark-results.md: {}\n", .{err});
        return;
    };
    defer md_file.close(io);

    var buf: [4096]u8 = undefined;

    const header = std.fmt.bufPrint(&buf,
        \\#### ZIGANTIC BENCHMARK RESULTS
        \\
        \\**Environment Details:**
        \\- **Platform:** {s}
        \\- **Architecture:** {s}
        \\- **Version:** {s}
        \\- **Warmup Iterations:** {d}
        \\- **Benchmark Iterations:** {d}
        \\
        \\
    , .{
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        z.getVersion(),
        WARMUP,
        ITERATIONS,
    }) catch "";
    try md_file.writeStreamingAll(io, header);

    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results.items) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        const cat_header = std.fmt.bufPrint(&buf,
            \\
            \\<details>
            \\<summary><strong>{s}</strong></summary>
            \\
            \\| Benchmark | Ops/sec (higher is better) | Avg Latency (ns) (lower is better) |
            \\| :--- | :--- | :--- |
            \\
        , .{cat}) catch continue;
        try md_file.writeStreamingAll(io, cat_header);

        for (results.items) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                const line = std.fmt.bufPrint(&buf, "| {s} | {d:.0} | {d:.0} |\n", .{
                    r.name,
                    r.ops_per_sec,
                    r.avg_latency_ns,
                }) catch continue;
                try md_file.writeStreamingAll(io, line);
            }
        }
        try md_file.writeStreamingAll(io, "</details>\n");
    }

    if (count > 0) {
        try md_file.writeStreamingAll(io, "\n### Benchmark Summary\n\n");
        const summary = std.fmt.bufPrint(&buf,
            \\- **Total benchmarks run:** {d}
            \\- **Average throughput:** {d:.0} ops/sec
            \\- **Maximum throughput:** {d:.0} ops/sec ({s})
            \\- **Minimum throughput:** {d:.0} ops/sec ({s})
            \\- **Average latency:** {d:.0} ns
            \\
        , .{ count, avg_ops, max_ops, max_name, min_ops, min_name, avg_latency }) catch "";
        try md_file.writeStreamingAll(io, summary);
    }

    std.debug.print("\n[OK] Benchmarks completed successfully!\n", .{});
    std.debug.print("[OK] Results written to benchmark-results.md\n", .{});
}
