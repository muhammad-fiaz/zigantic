//! Validation error classification shared by every schema.
//!
//! Errors describe the failure class; `Code` maps that class to a stable
//! machine-readable code and a default human message. Callers may override any
//! message through `Messages` at the call site, so no global state exists.

const std = @import("std");

pub const ValidationError = error{
    TypeMismatch,
    TooSmall,
    TooLarge,
    LengthMismatch,
    InvalidValue,
    InvalidFormat,
    MissingField,
    UnknownField,
    DuplicateField,
    NotInEnum,
    InvalidLiteral,
    RefinementFailed,
    TransformFailed,
    CoercionFailed,
    UnionMismatch,
    OutOfRange,
    NotFinite,
    NotInteger,
    MissingDiscriminator,
    InvalidDiscriminator,
    Unsupported,
};

pub const Category = enum {
    type_mismatch,
    length,
    range,
    format,
    structure,
    refinement,
    coercion,
    unsupported,
};

pub const Code = enum {
    type_mismatch,
    too_small,
    too_large,
    length_mismatch,
    invalid_value,
    invalid_format,
    missing_field,
    unknown_field,
    duplicate_field,
    not_in_enum,
    invalid_literal,
    refinement_failed,
    transform_failed,
    coercion_failed,
    union_mismatch,
    out_of_range,
    not_finite,
    not_integer,
    missing_discriminator,
    invalid_discriminator,
    unsupported,

    pub fn label(self: Code) []const u8 {
        return switch (self) {
            .type_mismatch => "E001",
            .too_small => "E002",
            .too_large => "E003",
            .length_mismatch => "E004",
            .invalid_value => "E005",
            .invalid_format => "E006",
            .missing_field => "E007",
            .unknown_field => "E008",
            .duplicate_field => "E009",
            .not_in_enum => "E010",
            .invalid_literal => "E011",
            .refinement_failed => "E012",
            .transform_failed => "E013",
            .coercion_failed => "E014",
            .union_mismatch => "E015",
            .out_of_range => "E016",
            .not_finite => "E017",
            .not_integer => "E018",
            .missing_discriminator => "E019",
            .invalid_discriminator => "E020",
            .unsupported => "E021",
        };
    }

    pub fn category(self: Code) Category {
        return switch (self) {
            .type_mismatch, .not_integer => .type_mismatch,
            .too_small, .too_large, .length_mismatch, .out_of_range => .length,
            .invalid_format => .format,
            .missing_field, .unknown_field, .duplicate_field, .missing_discriminator, .invalid_discriminator => .structure,
            .not_in_enum, .invalid_literal, .invalid_value, .union_mismatch => .structure,
            .refinement_failed => .refinement,
            .transform_failed, .coercion_failed => .coercion,
            .not_finite => .range,
            .unsupported => .unsupported,
        };
    }

    pub fn message(self: Code) []const u8 {
        return switch (self) {
            .type_mismatch => "invalid type",
            .too_small => "value is too small",
            .too_large => "value is too large",
            .length_mismatch => "invalid length",
            .invalid_value => "invalid value",
            .invalid_format => "invalid format",
            .missing_field => "required field is missing",
            .unknown_field => "unknown field is not allowed",
            .duplicate_field => "duplicate field",
            .not_in_enum => "value is not an allowed enum member",
            .invalid_literal => "value does not match the required literal",
            .refinement_failed => "value failed a refinement check",
            .transform_failed => "value could not be transformed",
            .coercion_failed => "value could not be coerced",
            .union_mismatch => "value does not match any union variant",
            .out_of_range => "value is outside the allowed range",
            .not_finite => "value must be finite",
            .not_integer => "value must be an integer",
            .missing_discriminator => "discriminator field is missing",
            .invalid_discriminator => "discriminator selects an unknown variant",
            .unsupported => "operation is not supported by this schema",
        };
    }
};

const no_message: ?[]const u8 = null;

/// Per-code message overrides; every field defaults to null (use the code's
/// built-in message).
pub const Messages = std.enums.EnumFieldStruct(Code, ?[]const u8, no_message);

pub fn codeFor(err: ValidationError) Code {
    return switch (err) {
        error.TypeMismatch => .type_mismatch,
        error.TooSmall => .too_small,
        error.TooLarge => .too_large,
        error.LengthMismatch => .length_mismatch,
        error.InvalidValue => .invalid_value,
        error.InvalidFormat => .invalid_format,
        error.MissingField => .missing_field,
        error.UnknownField => .unknown_field,
        error.DuplicateField => .duplicate_field,
        error.NotInEnum => .not_in_enum,
        error.InvalidLiteral => .invalid_literal,
        error.RefinementFailed => .refinement_failed,
        error.TransformFailed => .transform_failed,
        error.CoercionFailed => .coercion_failed,
        error.UnionMismatch => .union_mismatch,
        error.OutOfRange => .out_of_range,
        error.NotFinite => .not_finite,
        error.NotInteger => .not_integer,
        error.MissingDiscriminator => .missing_discriminator,
        error.InvalidDiscriminator => .invalid_discriminator,
        error.Unsupported => .unsupported,
    };
}

/// Returns the caller-supplied message override for `code`, if any.
pub fn overrideFor(code: Code, messages: Messages) ?[]const u8 {
    inline for (std.enums.values(Code)) |candidate| {
        if (candidate == code) return @field(messages, @tagName(candidate));
    }
    unreachable;
}

/// Resolves the message for `code`: override first, default second.
pub fn resolveMessage(code: Code, messages: Messages) []const u8 {
    if (overrideFor(code, messages)) |text| return text;
    return code.message();
}

test "codes are stable and unique" {
    const codes = std.enums.values(Code);
    try std.testing.expectEqual(@as(usize, 21), codes.len);
    for (codes, 0..) |code, i| {
        for (codes[i + 1 ..]) |other| {
            try std.testing.expect(!std.mem.eql(u8, code.label(), other.label()));
        }
    }
}

test "message overrides" {
    const messages = Messages{ .too_small = "must be at least 18" };
    try std.testing.expectEqualStrings("must be at least 18", resolveMessage(.too_small, messages));
    try std.testing.expectEqualStrings("value is too large", resolveMessage(.too_large, messages));
    try std.testing.expectEqualStrings("E002", (codeFor(error.TooSmall)).label());
}
