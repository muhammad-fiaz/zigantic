//! Version Information
//!
//! Contains version constants for the zigantic library.

/// The current version of the zigantic library.
/// This should be kept in sync with build.zig.zon
pub const version: []const u8 = "0.0.3";

/// Returns the full version string with prefix.
pub fn getVersionString() []const u8 {
    return "v" ++ version;
}

/// Returns true if this is a pre-release version (major = 0).
pub fn isPreRelease() bool {
    return version.len > 0 and version[0] == '0';
}

test "version format" {
    const std = @import("std");
    try std.testing.expectEqualStrings("0.0.3", version);
    try std.testing.expectEqualStrings("v0.0.3", getVersionString());
    try std.testing.expect(isPreRelease());
}
