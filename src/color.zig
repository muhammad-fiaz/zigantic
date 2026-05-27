//! ANSI Color Support
//!
//! Provides terminal color constants and ANSI escape code generation
//! for styled validation error output. Colors are used to visually
//! distinguish error categories (e.g., red for string errors,
//! yellow for number errors, blue for format errors).

/// Supported ANSI terminal colors for validation error presentation.
///
/// Each color maps to a standard ANSI escape sequence. The color
/// assignment follows a semantic convention:
/// - **Red**: string/constraint errors (too short, too long, empty)
/// - **Yellow**: number/range errors (too small, too large, out of range)
/// - **Blue**: format validation errors (email, URL, UUID, pattern)
/// - **Cyan**: structural errors (missing field, unknown field)
/// - **Green**: collection errors (too few/many items)
/// - **Bright Red**: critical/custom errors (validation failed, invalid JSON)
pub const Color = enum {
    reset,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
};

/// Returns the ANSI escape code string for the given color.
///
/// The returned string is a compile-time constant that can be
/// embedded directly into formatted output. Always pair with
/// `Color.reset` to restore default terminal styling.
///
/// Example:
/// ```zig
/// const colored = ansi(.red) ++ "error" ++ ansi(.reset);
/// ```
pub fn ansi(color: Color) []const u8 {
    return switch (color) {
        .reset => "\x1b[0m",
        .red => "\x1b[31m",
        .green => "\x1b[32m",
        .yellow => "\x1b[33m",
        .blue => "\x1b[34m",
        .magenta => "\x1b[35m",
        .cyan => "\x1b[36m",
        .white => "\x1b[37m",
        .bright_red => "\x1b[91m",
        .bright_green => "\x1b[92m",
        .bright_yellow => "\x1b[93m",
        .bright_blue => "\x1b[94m",
        .bright_magenta => "\x1b[95m",
        .bright_cyan => "\x1b[96m",
    };
}
