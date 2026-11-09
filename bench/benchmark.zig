const std = @import("std");
const builtin = @import("builtin");
const z = @import("zigantic");

const User = struct {
    name: []const u8,
    email: []const u8,
    age: u8,
};

const UserSchema = z.object(User, .{
    .name = z.string(.{ .min = 1, .max = 64 }),
    .email = z.email(.{}),
    .age = z.integer(u8, .{ .min = 18 }),
}, .{});

const Address = struct {
    city: []const u8,
    postal_code: []const u8,
};

const AddressSchema = z.object(Address, .{
    .city = z.string(.{ .min = 1, .max = 80 }),
    .postal_code = z.string(.{ .len = 5, .charset = .numeric }),
}, .{});

const Person = struct {
    name: []const u8,
    address: Address,
};

const PersonSchema = z.object(Person, .{
    .name = z.string(.{ .min = 1, .max = 64 }),
    .address = AddressSchema,
}, .{});

const Search = struct {
    query: []const u8,
    page: u16,
    active: bool,
    tags: []const []const u8,
};

const SearchSchema = z.object(Search, .{
    .query = z.string(.{ .min = 1 }),
    .page = z.integer(u16, .{ .min = 1 }),
    .active = z.boolean(.{}),
    .tags = z.array(z.string(.{ .min = 1 }), .{ .max = 8 }),
}, .{ .naming = .snake_case });

const ScoresSchema = z.record(z.integer(u16, .{ .max = 1000 }), .{ .min = 1, .key_min = 1, .key_max = 32 });

const TagSetSchema = z.set(z.string(.{ .min = 1 }), .{ .min = 1, .max = 8 });

const EntrySchema = z.tuple(.{
    z.string(.{ .min = 1 }),
    z.integer(u8, .{ .max = 120 }),
    z.boolean(.{}),
}, .{});

const Created = struct { type: []const u8, id: u64 };
const Deleted = struct { type: []const u8, id: u64 };
const Event = union(enum) { created: Created, deleted: Deleted };
const EventSchema = z.discriminatedUnion(Event, "type", .{
    .created = z.object(Created, .{
        .type = z.literal("created"),
        .id = z.integer(u64, .{}),
    }, .{}),
    .deleted = z.object(Deleted, .{
        .type = z.literal("deleted"),
        .id = z.integer(u64, .{}),
    }, .{}),
}, .{});

const Node = struct {
    value: i32,
    next: ?*const Node,
};

fn NodeSchema() type {
    return z.object(Node, .{
        .value = z.integer(i32, .{}),
        .next = z.nullish(z.lazy(NodeSchema)),
    }, .{});
}

const measure_rounds = 7;
const warmup_rounds = 1;

const Result = struct {
    name: []const u8,
    iterations: usize,
    median_ns: u64,
    min_ns: u64,
    max_ns: u64,
    ops_per_sec: u64,
};

const Timer = struct {
    io: std.Io,
    start: std.Io.Clock.Timestamp,

    fn begin(io: std.Io) Timer {
        return .{ .io = io, .start = .now(io, .awake) };
    }

    fn elapsedNanoseconds(timer: Timer) u64 {
        const end = std.Io.Clock.Timestamp.now(timer.io, .awake);
        const delta = timer.start.durationTo(end).raw.nanoseconds;
        return @intCast(@max(delta, 0));
    }
};

fn runBatch(comptime iterations: usize, context: anytype, op: anytype) !void {
    var index: usize = 0;
    while (index < iterations) : (index += 1) {
        try op(context);
    }
}

fn sortSamples(samples: []u64) void {
    var index: usize = 1;
    while (index < samples.len) : (index += 1) {
        const value = samples[index];
        var insertion = index;
        while (insertion > 0 and samples[insertion - 1] > value) : (insertion -= 1) {
            samples[insertion] = samples[insertion - 1];
        }
        samples[insertion] = value;
    }
}

fn measure(
    comptime name: []const u8,
    comptime iterations: usize,
    context: anytype,
    op: anytype,
    io: std.Io,
) !Result {
    const warmup_iterations = @max(iterations / 10, 1);
    var warmup: usize = 0;
    while (warmup < warmup_rounds) : (warmup += 1) {
        try runBatch(warmup_iterations, context, op);
    }

    var samples: [measure_rounds]u64 = undefined;
    for (&samples) |*sample| {
        const timer = Timer.begin(io);
        try runBatch(iterations, context, op);
        sample.* = timer.elapsedNanoseconds();
    }
    sortSamples(&samples);

    const median_raw = samples[measure_rounds / 2];
    const median_ns = @max(median_raw / iterations, 1);
    const min_ns = @max(samples[0] / iterations, 1);
    const max_ns = @max(samples[measure_rounds - 1] / iterations, 1);

    return .{
        .name = name,
        .iterations = iterations,
        .median_ns = median_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .ops_per_sec = 1_000_000_000 / median_ns,
    };
}

const JsonContext = struct {
    allocator: std.mem.Allocator,
    document: []const u8,
};

const StringifyContext = struct {
    allocator: std.mem.Allocator,
    value: User,
};

const ValidateContext = struct {
    allocator: std.mem.Allocator,
    value: User,
};

const QueryParseContext = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
};

const QueryStringifyContext = struct {
    allocator: std.mem.Allocator,
    value: Search,
};

const SchemaContext = struct {
    allocator: std.mem.Allocator,
};

const ValidatorContext = struct {
    inputs: []const []const u8,
    index: *usize,
};

const DateTimeContext = struct {
    inputs: []const []const u8,
    index: *usize,
};

fn jsonModelParse(context: JsonContext) !void {
    var result = try z.parse(UserSchema, context.allocator, context.document, .{});
    defer result.deinit();
    if (!result.ok()) return error.InvalidBenchmarkInput;
}

fn jsonNestedParse(context: JsonContext) !void {
    var result = try z.parse(PersonSchema, context.allocator, context.document, .{});
    defer result.deinit();
    if (!result.ok()) return error.InvalidBenchmarkInput;
}

fn integerParse(context: JsonContext) !void {
    const Age = z.integer(u8, .{ .min = 18, .max = 120 });
    var result = try z.parse(Age, context.allocator, context.document, .{});
    defer result.deinit();
    if (!result.ok() or result.value.? != 42) return error.InvalidBenchmarkInput;
}

fn jsonModelStringify(context: StringifyContext) !void {
    const text = try z.stringify(UserSchema, context.allocator, context.value, .{});
    defer context.allocator.free(text);
}

fn queryModelParse(context: QueryParseContext) !void {
    var result = try z.parseQuery(SearchSchema, context.allocator, context.input, .{});
    defer result.deinit();
    if (!result.ok()) return error.InvalidBenchmarkInput;
}

fn formModelParse(context: QueryParseContext) !void {
    var result = try z.parseForm(SearchSchema, context.allocator, context.input, .{});
    defer result.deinit();
    if (!result.ok()) return error.InvalidBenchmarkInput;
}

fn queryModelStringify(context: QueryStringifyContext) !void {
    const text = try z.stringifyQuery(SearchSchema, context.allocator, context.value, .{});
    defer context.allocator.free(text);
}

fn jsonSchemaGenerate(context: SchemaContext) !void {
    const text = try z.jsonSchema(UserSchema, context.allocator, .{});
    defer context.allocator.free(text);
    if (text.len == 0) return error.InvalidBenchmarkInput;
}

fn typedValidate(context: ValidateContext) !void {
    var issues = try z.validate(UserSchema, context.allocator, context.value, .{});
    defer issues.deinit();
    if (!issues.isEmpty()) return error.InvalidBenchmarkInput;
}

fn emailValidator(context: ValidatorContext) !void {
    const text = context.inputs[context.index.* % context.inputs.len];
    context.index.* +%= 1;
    if (!z.validators.isEmail(text)) return error.InvalidBenchmarkInput;
}

fn datetimeParse(context: DateTimeContext) !void {
    const text = context.inputs[context.index.* % context.inputs.len];
    context.index.* +%= 1;
    const value = try z.DateTime.parse(text);
    if (value.date.day == 0) return error.InvalidBenchmarkInput;
}

fn recordParse(context: JsonContext) !void {
    var result = try z.parse(ScoresSchema, context.allocator, context.document, .{});
    defer result.deinit();
    if (!result.ok() or result.value.?.count() != 3) return error.InvalidBenchmarkInput;
}

fn setParse(context: JsonContext) !void {
    var result = try z.parse(TagSetSchema, context.allocator, context.document, .{});
    defer result.deinit();
    if (!result.ok() or result.value.?.len != 3) return error.InvalidBenchmarkInput;
}

fn tupleParse(context: JsonContext) !void {
    var result = try z.parse(EntrySchema, context.allocator, context.document, .{});
    defer result.deinit();
    if (!result.ok() or result.value.?[1] != 36) return error.InvalidBenchmarkInput;
}

fn unionParse(context: JsonContext) !void {
    var result = try z.parse(EventSchema, context.allocator, context.document, .{});
    defer result.deinit();
    if (!result.ok()) return error.InvalidBenchmarkInput;
    switch (result.value.?) {
        .deleted => |deleted| if (deleted.id != 42) return error.InvalidBenchmarkInput,
        else => return error.InvalidBenchmarkInput,
    }
}

fn recursiveParse(context: JsonContext) !void {
    var result = try z.parse(NodeSchema(), context.allocator, context.document, .{});
    defer result.deinit();
    if (!result.ok() or result.value.?.next == null) return error.InvalidBenchmarkInput;
}

fn durationParse(context: DateTimeContext) !void {
    const text = context.inputs[context.index.* % context.inputs.len];
    context.index.* +%= 1;
    const value = try z.Duration.parse(text);
    if (value.isZero() and !std.mem.eql(u8, text, "PT0S")) return error.InvalidBenchmarkInput;
}

pub fn main() !void {
    var threaded: std.Io.Threaded = .init(std.heap.smp_allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const allocator = std.heap.smp_allocator;

    const user_document =
        \\{"name":"Ada","email":"ada@example.com","age":36}
    ;
    const nested_document =
        \\{"name":"Ada","address":{"city":"London","postal_code":"12345"}}
    ;
    const query_document = "query=zig+validation&page=2&active=true&tags=fast&tags=safe";
    const form_document = "query=login&page=1&active=false&tags=fast&tags=safe";

    const user_value = User{
        .name = "Ada",
        .email = "ada@example.com",
        .age = 36,
    };
    const search_value = Search{
        .query = "zig validation",
        .page = 2,
        .active = true,
        .tags = &.{ "fast", "safe" },
    };

    const email_inputs = [_][]const u8{
        "ada@example.com",
        "user+tag@example.co.uk",
        "grace@example.org",
    };
    const datetime_inputs = [_][]const u8{
        "2024-02-29T23:30:00+02:00",
        "2025-01-01T00:00:00Z",
        "2024-12-31 23:59:59-05:00",
    };
    const duration_inputs = [_][]const u8{
        "P3Y6M4DT12H30M5S",
        "P2W",
        "-PT5M",
    };

    var email_index: usize = 0;
    var datetime_index: usize = 0;

    var results: [17]Result = undefined;
    results[0] = try measure("json_model_parse", 20_000, JsonContext{
        .allocator = allocator,
        .document = user_document,
    }, jsonModelParse, io);
    results[1] = try measure("json_nested_parse", 20_000, JsonContext{
        .allocator = allocator,
        .document = nested_document,
    }, jsonNestedParse, io);
    results[2] = try measure("integer_parse", 200_000, JsonContext{
        .allocator = allocator,
        .document = "42",
    }, integerParse, io);
    results[3] = try measure("json_model_stringify", 20_000, StringifyContext{
        .allocator = allocator,
        .value = user_value,
    }, jsonModelStringify, io);
    results[4] = try measure("query_model_parse", 20_000, QueryParseContext{
        .allocator = allocator,
        .input = query_document,
    }, queryModelParse, io);
    results[5] = try measure("form_model_parse", 20_000, QueryParseContext{
        .allocator = allocator,
        .input = form_document,
    }, formModelParse, io);
    results[6] = try measure("query_model_stringify", 20_000, QueryStringifyContext{
        .allocator = allocator,
        .value = search_value,
    }, queryModelStringify, io);
    results[7] = try measure("json_schema_generate", 5_000, SchemaContext{
        .allocator = allocator,
    }, jsonSchemaGenerate, io);
    results[8] = try measure("typed_validate", 100_000, ValidateContext{
        .allocator = allocator,
        .value = user_value,
    }, typedValidate, io);
    results[9] = try measure("email_validator", 1_000_000, ValidatorContext{
        .inputs = &email_inputs,
        .index = &email_index,
    }, emailValidator, io);
    results[10] = try measure("datetime_parse", 500_000, DateTimeContext{
        .inputs = &datetime_inputs,
        .index = &datetime_index,
    }, datetimeParse, io);
    results[11] = try measure("record_parse", 20_000, JsonContext{
        .allocator = allocator,
        .document = "{\"ada\":95,\"grace\":99,\"linus\":88}",
    }, recordParse, io);
    results[12] = try measure("set_parse", 20_000, JsonContext{
        .allocator = allocator,
        .document = "[\"fast\",\"safe\",\"simple\"]",
    }, setParse, io);
    results[13] = try measure("tuple_parse", 20_000, JsonContext{
        .allocator = allocator,
        .document = "[\"Ada\",36,true]",
    }, tupleParse, io);
    results[14] = try measure("union_parse", 20_000, JsonContext{
        .allocator = allocator,
        .document = "{\"type\":\"deleted\",\"id\":42}",
    }, unionParse, io);
    results[15] = try measure("recursive_parse", 10_000, JsonContext{
        .allocator = allocator,
        .document = "{\"value\":1,\"next\":{\"value\":2,\"next\":null}}",
    }, recursiveParse, io);
    results[16] = try measure("duration_parse", 500_000, DateTimeContext{
        .inputs = duration_inputs[0..],
        .index = &datetime_index,
    }, durationParse, io);

    std.debug.print("zigantic benchmarks\n", .{});
    std.debug.print("zig {s} | {s}-{s} | ReleaseFast | smp_allocator\n", .{
        builtin.zig_version_string,
        @tagName(builtin.target.cpu.arch),
        @tagName(builtin.target.os.tag),
    });
    std.debug.print("{d} measured rounds, {d} warmup round(s); median reported\n\n", .{
        measure_rounds,
        warmup_rounds,
    });
    std.debug.print("benchmark                    iterations   median ns/op  min ns/op  max ns/op  ops/sec\n", .{});
    for (results) |result| {
        std.debug.print("{s:<27} {d:>10} {d:>13} {d:>10} {d:>10} {d:>9}\n", .{
            result.name,
            result.iterations,
            result.median_ns,
            result.min_ns,
            result.max_ns,
            result.ops_per_sec,
        });
    }

    var counting = std.testing.FailingAllocator.init(allocator, .{});
    var counted = try z.parse(UserSchema, counting.allocator(), user_document, .{});
    const allocations = counting.allocations;
    const deallocations = counting.deallocations;
    const bytes = counting.allocated_bytes;
    counted.deinit();
    std.debug.print("\njson_model_parse allocation profile: {d} allocations, {d} bytes, {d} deallocations\n", .{
        allocations,
        bytes,
        deallocations,
    });
}
