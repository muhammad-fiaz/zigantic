//! Version Information
//!
//! Contains version constants for the zigantic library.

/// The current version of the zigantic library.
/// This should be kept in sync with build.zig.zon
pub const version: []const u8 = "0.0.2";

/// The major version number.
pub const major: u32 = 0;

/// The minor version number.
pub const minor: u32 = 0;

/// The patch version number.
pub const patch: u32 = 2;

/// Returns the full version string with prefix.
pub fn getVersionString() []const u8 {
    return "v" ++ version;
}

/// Returns true if this is a pre-release version (major = 0).
pub fn isPreRelease() bool {
    return major == 0;
}

test "version format" {
    const std = @import("std");
    try std.testing.expectEqualStrings("0.0.2", version);
    try std.testing.expectEqualStrings("v0.0.2", getVersionString());
    try std.testing.expect(isPreRelease());
}
