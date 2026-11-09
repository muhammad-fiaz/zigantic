//! zigantic: compile-time validation and schema composition for Zig 0.17+.
//!
//! Schemas are types. Constructors such as `string`, `integer` and `object`
//! return a type whose `Value` is the validated Zig type, and which exposes
//! `decode`, `check`, `encode` and `writeJsonSchema`. All allocation is
//! explicit: parsed values live in an arena owned by the parse result, which
//! the caller releases with `deinit`.

const std = @import("std");

/// Package version string for this release.
pub const version = "0.0.5";

/// Machine-readable validation failure kinds, one per stable error code.
pub const ValidationError = @import("error.zig").ValidationError;
/// Stable diagnostic codes `E001` through `E021`.
pub const Code = @import("error.zig").Code;
/// Issue category used by renderers and log filters.
pub const Category = @import("error.zig").Category;
/// Per-code message overrides keyed by `Code`.
pub const Messages = @import("error.zig").Messages;

/// A single structured validation finding.
pub const Issue = @import("issue.zig").Issue;
/// Owning list of issues; strings are copied into its arena.
pub const IssueList = @import("issue.zig").List;
/// Options controlling issue text rendering.
pub const RenderOptions = @import("issue.zig").RenderOptions;
/// Tint ANSI color capability selected per render call.
pub const Capability = @import("issue.zig").Capability;

/// Schema discriminant for protocol dispatch (query encoding, JSON Schema).
pub const Kind = @import("schema.zig").Kind;
/// Policy for object keys with no schema field.
pub const UnknownFields = @import("schema.zig").UnknownFields;
/// Policy for repeated JSON object keys.
pub const Duplicates = @import("schema.zig").Duplicates;
/// Lifecycle callbacks invoked during parsing and validation.
pub const Hooks = @import("schema.zig").Hooks;
/// Shared options for parsing and typed validation.
pub const Options = @import("schema.zig").Options;
/// Decode-time state threaded through every schema.
pub const State = @import("schema.zig").State;
/// Context passed to custom `validate` callbacks.
pub const Context = @import("schema.zig").Context;

/// Field-naming policy applied to object keys at compile time.
pub const Naming = @import("naming.zig").Policy;
/// An extra accepted input key for a named object field.
pub const Alias = @import("naming.zig").Alias;

/// String schema producing `[]const u8`. Takes `StringConfig`.
pub const string = @import("string.zig").string;
/// Email address schema. Takes `StringConfig`.
pub const email = @import("string.zig").email;
/// Absolute URL schema. Takes `StringConfig`.
pub const url = @import("string.zig").url;
/// Absolute URI schema. Takes `StringConfig`.
pub const uri = @import("string.zig").uri;
/// HTTPS URL schema. Takes `StringConfig`.
pub const httpsUrl = @import("string.zig").httpsUrl;
/// UUID schema. Takes `StringConfig`.
pub const uuid = @import("string.zig").uuid;
/// GUID schema, identical to `uuid`. Takes `StringConfig`.
pub const guid = @import("string.zig").guid;
/// ULID schema. Takes `StringConfig`.
pub const ulid = @import("string.zig").ulid;
/// Lowercase hyphenated slug schema. Takes `StringConfig`.
pub const slug = @import("string.zig").slug;
/// Semantic Version schema. Takes `StringConfig`.
pub const semver = @import("string.zig").semver;
/// Phone number schema. Takes `StringConfig`.
pub const phoneNumber = @import("string.zig").phoneNumber;
/// Payment card number schema (Luhn checksum). Takes `StringConfig`.
pub const creditCard = @import("string.zig").creditCard;
/// JSON Web Token structure schema. Takes `StringConfig`.
pub const jwt = @import("string.zig").jwt;
/// Standard base64 text schema. Takes `StringConfig`.
pub const base64 = @import("string.zig").base64;
/// Unpadded base64url text schema. Takes `StringConfig`.
pub const base64Url = @import("string.zig").base64Url;
/// Even-length hexadecimal text schema. Takes `StringConfig`.
pub const hex = @import("string.zig").hex;
/// Hex colour schema. Takes `StringConfig`.
pub const hexColor = @import("string.zig").hexColor;
/// MAC address schema. Takes `StringConfig`.
pub const macAddress = @import("string.zig").macAddress;
/// IPv4 address schema. Takes `StringConfig`.
pub const ipv4 = @import("string.zig").ipv4;
/// IPv6 address schema. Takes `StringConfig`.
pub const ipv6 = @import("string.zig").ipv6;
/// ISO 8601 date text schema. Takes `StringConfig`.
pub const isoDate = @import("string.zig").isoDate;
/// ISO 8601 time text schema. Takes `StringConfig`.
pub const isoTime = @import("string.zig").isoTime;
/// ISO 8601 date-time text schema. Takes `StringConfig`.
pub const isoDateTime = @import("string.zig").isoDateTime;
/// ISO 8601 duration text schema. Takes `StringConfig`.
pub const isoDuration = @import("string.zig").isoDuration;

/// Options shared by every string constructor.
pub const StringConfig = @import("string.zig").Config;
/// Case constraint for string schemas.
pub const StringCase = @import("string.zig").Case;
/// Character-set constraint for string schemas.
pub const StringCharset = @import("string.zig").Charset;
/// Named string format checked after the other constraints.
pub const StringFormat = @import("string.zig").Format;

/// Integer schema producing the requested integer type `T`.
pub const integer = @import("number.zig").integer;
/// Floating-point schema producing the requested float type `T`.
pub const float = @import("number.zig").float;
/// Integer schema with the minimum raised to at least 1.
pub const positiveInt = @import("number.zig").positiveInt;
/// Integer schema with the maximum lowered to at most -1.
pub const negativeInt = @import("number.zig").negativeInt;
/// Integer schema with the minimum raised to at least 0.
pub const nonNegativeInt = @import("number.zig").nonNegativeInt;
/// Integer schema with the maximum lowered to at most 0.
pub const nonPositiveInt = @import("number.zig").nonPositiveInt;
/// Integer schema intersected with the IEEE-754 safe integer range.
pub const safeInt = @import("number.zig").safeInt;
/// Unsigned integer schema; a signed type is a compile error.
pub const unsignedInt = @import("number.zig").unsignedInt;
/// Float schema bounded to `0..100`.
pub const percentage = @import("number.zig").percentage;
/// Float schema bounded to `0..1`.
pub const probability = @import("number.zig").probability;
/// Options for every integer constructor.
pub const IntConfig = @import("number.zig").IntConfig;
/// Options for every float constructor.
pub const FloatConfig = @import("number.zig").FloatConfig;

/// Boolean schema producing `bool`. Accepts `1`/`0` and `"true"`/`"false"`
/// only under `.coerce`.
pub const boolean = @import("primitive.zig").boolean;
/// Enum schema matching member names exactly. `E` must be an enum type.
pub const enumType = @import("primitive.zig").enumType;
/// Exact-value schema for a string, integer or boolean literal.
pub const literal = @import("primitive.zig").literal;
/// JSON `null` schema producing `void`.
pub const nullValue = @import("primitive.zig").nullValue;
/// Binary data schema producing arena-owned `[]const u8`.
pub const bytes = @import("primitive.zig").bytes;
/// Options for the `bytes` schema.
pub const BytesConfig = @import("primitive.zig").BytesConfig;
/// Text encodings understood by the `bytes` schema.
pub const ByteEncoding = @import("primitive.zig").ByteEncoding;
/// Options for the `boolean` schema.
pub const BoolConfig = @import("primitive.zig").BoolConfig;
/// Options for the `enumType` schema.
pub const EnumConfig = @import("primitive.zig").EnumConfig;
/// Options for the `nullValue` schema.
pub const NullConfig = @import("primitive.zig").NullConfig;

/// Object schema bound to the declared model `T`. Field types are checked
/// against `T` at compile time.
pub const object = @import("model.zig").object;
/// Object schema whose value type is synthesized with `@Struct`.
pub const objectOf = @import("model.zig").objectOf;
/// Merge two inferred-object field sets; duplicate fields are a compile error.
pub const merge = @import("model.zig").merge;
/// Same as `merge`; kept as a descriptive alias.
pub const extend = @import("model.zig").extend;
/// Select existing fields into a new inferred object.
pub const pick = @import("model.zig").pick;
/// Remove fields; unknown names are ignored.
pub const omit = @import("model.zig").omit;
/// Options shared by `object` and `objectOf`.
pub const ObjectConfig = @import("model.zig").Config;

/// Heterogeneous fixed-length tuple schema; value type is `@Tuple`.
pub const tuple = @import("tuple.zig").tuple;
/// Options for the `tuple` schema.
pub const TupleConfig = @import("tuple.zig").Config;

/// Intersection schema: every member must accept the same decoded value.
pub const intersection = @import("intersection.zig").intersection;
/// Options for the `intersection` schema.
pub const IntersectionConfig = @import("intersection.zig").Config;

/// Ordered array schema producing `[]const S.Value`.
pub const array = @import("collection.zig").array;
/// Fixed-length array schema producing `[N]S.Value`.
pub const fixedArray = @import("collection.zig").fixedArray;
/// Ordered uniqueness-constrained slice schema. Takes `ArrayConfig`.
pub const set = @import("collection.zig").set;
/// String-keyed map schema producing `std.array_hash_map.String(S.Value)`.
pub const record = @import("collection.zig").record;
/// Options for `array` and `set`.
pub const ArrayConfig = @import("collection.zig").ArrayConfig;
/// Options for `fixedArray`.
pub const FixedConfig = @import("collection.zig").FixedConfig;
/// Options for `record`.
pub const RecordConfig = @import("collection.zig").RecordConfig;

/// Untagged union schema; variants are tried in declaration order.
pub const unionOf = @import("composite.zig").unionOf;
/// Union schema selecting a variant by a string discriminator field.
pub const discriminatedUnion = @import("composite.zig").discriminatedUnion;
/// Options for `unionOf`.
pub const UnionConfig = @import("composite.zig").UnionConfig;
/// Options for `discriminatedUnion`.
pub const DiscriminatedConfig = @import("composite.zig").DiscriminatedConfig;

/// Optional field: absence is allowed, explicit `null` is not.
pub const optional = @import("modifiers.zig").optional;
/// Nullable field: explicit `null` is allowed.
pub const nullable = @import("modifiers.zig").nullable;
/// Absence or `null`; value type is `?S.Value`.
pub const nullish = @import("modifiers.zig").nullish;
/// Attach JSON Schema metadata without changing validation or encoding.
pub const meta = @import("modifiers.zig").meta;
/// JSON Schema metadata attached by `meta`.
pub const Metadata = @import("modifiers.zig").Metadata;
/// Supply a compile-time default for a missing field.
pub const withDefault = @import("modifiers.zig").withDefault;
/// Supply a default through a factory called for every missing field.
pub const withDefaultFactory = @import("modifiers.zig").withDefaultFactory;
/// Return a value instead of failing when decoding fails.
pub const fallback = @import("modifiers.zig").fallback;
/// Predicate checked after the inner schema succeeds.
pub const refine = @import("modifiers.zig").refine;
/// Options for `refine`.
pub const RefineConfig = @import("modifiers.zig").RefineConfig;
/// One-way (or reversible) typed transformation.
pub const transform = @import("modifiers.zig").transform;
/// Options describing a `transform` mapping.
pub const TransformConfig = @import("modifiers.zig").TransformConfig;
/// Bidirectional codec between input and output schemas.
pub const codec = @import("modifiers.zig").codec;
/// Options for `codec`.
pub const CodecConfig = @import("modifiers.zig").CodecConfig;
/// Deferred schema lookup for recursive types; value is `*const Inner.Value`.
pub const lazy = @import("modifiers.zig").lazy;
/// Typed-only validation with no JSON representation.
pub const custom = @import("modifiers.zig").custom;
/// Options for `custom`.
pub const CustomConfig = @import("modifiers.zig").CustomConfig;

/// Parse JSON text into a validated value; violations become issues.
pub const parse = @import("json.zig").parse;
/// Serialize a value to owned JSON text.
pub const stringify = @import("json.zig").stringify;
/// Options for `stringify`.
pub const EncodeOptions = @import("json.zig").EncodeOptions;
/// Owning parse result: value plus issue list, released by `deinit`.
pub const ParseResult = @import("json.zig").Result;

/// Generate a JSON Schema document for a schema.
pub const jsonSchema = @import("json_schema.zig").generate;
/// Options for `jsonSchema`, selecting the target draft.
pub const JsonSchemaOptions = @import("schema.zig").JsonSchemaOptions;
/// Supported JSON Schema drafts.
pub const JsonSchemaTarget = @import("schema.zig").JsonSchemaTarget;

/// Parse a query string into an object schema (coercion enabled).
pub const parseQuery = @import("query.zig").parse;
/// Parse an `application/x-www-form-urlencoded` body (same as `parseQuery`).
pub const parseForm = @import("query.zig").parseForm;
/// Serialize an object value into a query string.
pub const stringifyQuery = @import("query.zig").stringify;
/// Options for `stringifyQuery`.
pub const QueryStringifyOptions = @import("query.zig").StringifyOptions;

/// Check a typed value against a schema; returns an owning issue list.
pub const validate = @import("validator.zig").validate;
/// Check a typed value with caller scratch memory; returns the first issue.
pub const checkFirst = @import("validator.zig").checkFirst;

/// Calendar and clock value types.
pub const datetime = @import("datetime.zig");
/// Calendar date (`YYYY-MM-DD`).
pub const Date = datetime.Date;
/// Clock time with optional nanoseconds.
pub const Time = datetime.Time;
/// Date and time with a fixed UTC offset.
pub const DateTime = datetime.DateTime;
/// ISO 8601 duration (`PnYnMnDTnHnMnS`).
pub const Duration = datetime.Duration;
/// Day of the week.
pub const Weekday = datetime.Weekday;

/// ISO 8601 date schema producing `Date`.
pub const date = @import("temporal.zig").date;
/// ISO 8601 time schema producing `Time`.
pub const time = @import("temporal.zig").time;
/// ISO 8601 date-time schema producing `DateTime`.
pub const dateTime = @import("temporal.zig").dateTime;
/// ISO 8601 duration schema producing `Duration`.
pub const duration = @import("temporal.zig").duration;
/// Options for every temporal schema.
pub const TemporalConfig = @import("temporal.zig").Config;

/// Pure, allocation-free format predicates such as `isEmail`.
pub const validators = @import("validators.zig");

test {
    _ = @import("error.zig");
    _ = @import("issue.zig");
    _ = @import("naming.zig");
    _ = @import("schema.zig");
    _ = @import("string.zig");
    _ = @import("number.zig");
    _ = @import("primitive.zig");
    _ = @import("model.zig");
    _ = @import("tuple.zig");
    _ = @import("intersection.zig");
    _ = @import("collection.zig");
    _ = @import("composite.zig");
    _ = @import("modifiers.zig");
    _ = @import("json.zig");
    _ = @import("json_schema.zig");
    _ = @import("query.zig");
    _ = @import("validator.zig");
    _ = @import("datetime.zig");
    _ = @import("temporal.zig");
}
