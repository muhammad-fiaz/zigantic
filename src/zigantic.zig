//! zigantic: compile-time validation and schema composition for Zig 0.17+.
//!
//! Schemas are types. Constructors such as `string`, `integer` and `object`
//! return a type whose `Value` is the validated Zig type, and which exposes
//! `decode`, `check`, `encode` and `writeJsonSchema`. All allocation is
//! explicit: parsed values live in an arena owned by the parse result, which
//! the caller releases with `deinit`.

const std = @import("std");

pub const version = "0.0.4";

pub const ValidationError = @import("error.zig").ValidationError;
pub const Code = @import("error.zig").Code;
pub const Category = @import("error.zig").Category;
pub const Messages = @import("error.zig").Messages;

pub const Issue = @import("issue.zig").Issue;
pub const IssueList = @import("issue.zig").List;
pub const RenderOptions = @import("issue.zig").RenderOptions;
pub const Capability = @import("issue.zig").Capability;

pub const Kind = @import("schema.zig").Kind;
pub const UnknownFields = @import("schema.zig").UnknownFields;
pub const Duplicates = @import("schema.zig").Duplicates;
pub const Hooks = @import("schema.zig").Hooks;
pub const Options = @import("schema.zig").Options;
pub const State = @import("schema.zig").State;

pub const Naming = @import("naming.zig").Policy;
pub const Alias = @import("naming.zig").Alias;

pub const string = @import("string.zig").string;
pub const email = @import("string.zig").email;
pub const url = @import("string.zig").url;
pub const httpsUrl = @import("string.zig").httpsUrl;
pub const uuid = @import("string.zig").uuid;
pub const ulid = @import("string.zig").ulid;
pub const slug = @import("string.zig").slug;
pub const semver = @import("string.zig").semver;
pub const phoneNumber = @import("string.zig").phoneNumber;
pub const creditCard = @import("string.zig").creditCard;
pub const jwt = @import("string.zig").jwt;
pub const base64 = @import("string.zig").base64;
pub const base64Url = @import("string.zig").base64Url;
pub const hex = @import("string.zig").hex;
pub const hexColor = @import("string.zig").hexColor;
pub const macAddress = @import("string.zig").macAddress;
pub const ipv4 = @import("string.zig").ipv4;
pub const ipv6 = @import("string.zig").ipv6;
pub const isoDate = @import("string.zig").isoDate;
pub const isoTime = @import("string.zig").isoTime;
pub const isoDateTime = @import("string.zig").isoDateTime;
pub const isoDuration = @import("string.zig").isoDuration;

pub const StringConfig = @import("string.zig").Config;
pub const StringCase = @import("string.zig").Case;
pub const StringCharset = @import("string.zig").Charset;
pub const StringFormat = @import("string.zig").Format;

pub const integer = @import("number.zig").integer;
pub const float = @import("number.zig").float;
pub const positiveInt = @import("number.zig").positiveInt;
pub const nonNegativeInt = @import("number.zig").nonNegativeInt;
pub const percentage = @import("number.zig").percentage;
pub const probability = @import("number.zig").probability;
pub const IntConfig = @import("number.zig").IntConfig;
pub const FloatConfig = @import("number.zig").FloatConfig;

pub const boolean = @import("primitive.zig").boolean;
pub const enumType = @import("primitive.zig").enumType;
pub const literal = @import("primitive.zig").literal;
pub const nullValue = @import("primitive.zig").nullValue;
pub const BoolConfig = @import("primitive.zig").BoolConfig;
pub const EnumConfig = @import("primitive.zig").EnumConfig;
pub const NullConfig = @import("primitive.zig").NullConfig;

pub const object = @import("model.zig").object;
pub const objectOf = @import("model.zig").objectOf;
pub const ObjectConfig = @import("model.zig").Config;

pub const tuple = @import("tuple.zig").tuple;
pub const TupleConfig = @import("tuple.zig").Config;

pub const intersection = @import("intersection.zig").intersection;
pub const IntersectionConfig = @import("intersection.zig").Config;

pub const array = @import("collection.zig").array;
pub const record = @import("collection.zig").record;
pub const ArrayConfig = @import("collection.zig").ArrayConfig;
pub const RecordConfig = @import("collection.zig").RecordConfig;

pub const unionOf = @import("composite.zig").unionOf;
pub const discriminatedUnion = @import("composite.zig").discriminatedUnion;
pub const UnionConfig = @import("composite.zig").UnionConfig;
pub const DiscriminatedConfig = @import("composite.zig").DiscriminatedConfig;

pub const optional = @import("modifiers.zig").optional;
pub const nullable = @import("modifiers.zig").nullable;
pub const withDefault = @import("modifiers.zig").withDefault;
pub const withDefaultFactory = @import("modifiers.zig").withDefaultFactory;
pub const fallback = @import("modifiers.zig").fallback;
pub const refine = @import("modifiers.zig").refine;
pub const RefineConfig = @import("modifiers.zig").RefineConfig;
pub const transform = @import("modifiers.zig").transform;
pub const TransformConfig = @import("modifiers.zig").TransformConfig;
pub const lazy = @import("modifiers.zig").lazy;
pub const custom = @import("modifiers.zig").custom;
pub const CustomConfig = @import("modifiers.zig").CustomConfig;

pub const parse = @import("json.zig").parse;
pub const stringify = @import("json.zig").stringify;
pub const EncodeOptions = @import("json.zig").EncodeOptions;
pub const ParseResult = @import("json.zig").Result;

pub const jsonSchema = @import("json_schema.zig").generate;

pub const parseQuery = @import("query.zig").parse;
pub const parseForm = @import("query.zig").parseForm;
pub const stringifyQuery = @import("query.zig").stringify;
pub const QueryStringifyOptions = @import("query.zig").StringifyOptions;

pub const validate = @import("validator.zig").validate;

pub const datetime = @import("datetime.zig");
pub const Date = datetime.Date;
pub const Time = datetime.Time;
pub const DateTime = datetime.DateTime;
pub const Weekday = datetime.Weekday;

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
}
